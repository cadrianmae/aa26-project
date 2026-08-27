# Swarm Command MVP Vertical Slice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable Godot build in which the player flies a wireframe commander ship across a plane while five autonomous wireframe swarm units hold formation around it.

**Architecture:** Every agent is a `CharacterBody3D` that owns child `SteeringBehaviour` nodes. The agent sums their weighted forces using Duggan's WTPRS algorithm, integrates with Euler, and orients itself along its velocity. Movement is constrained to the XZ plane. Rendering is Elite-style wireframe: line-primitive meshes drawn through an unlit emissive shader.

**Tech Stack:** Godot 4.7.1 (project targets 4.6 features), GDScript, `debug_draw_3d` addon for gizmos.

**Spec:** `docs/superpowers/specs/2026-08-27-swarm-command-rts-design.md`

## Global Constraints

- **Engine:** Godot 4.6 feature level, run under 4.7.1. Binary is `godot`; the `godot-dev` wrapper resolves it.
- **File and folder names:** `snake_case`. **Node names in scenes:** `PascalCase`.
- **GDScript member order:** doc comment, `class_name`, `extends`, signals, enums,
  constants, `@export`, vars, `@onready`, then `_init` / `_ready` / virtuals /
  public / private. Note the doc comment goes at the very top of the file, above
  `class_name` — Godot only attaches a `##` block to the class documentation when
  it sits directly above `class_name`. The official style guide lists it after
  `extends`, which does not actually produce class docs.
- **Indentation:** tabs. **Line length:** under 100 characters. **Quotes:** double.
- **Type annotations:** explicit `var x: Vector3 = ...` is preferred over `:=` on
  steering-maths locals, matching the style already used in `aa-26-refactored`.
  Consistency with the existing codebase beats the style guide's `:=` preference,
  and spelling out Vector3 against float makes the formulas readable.
- **Forward axis is +Z**, following Duggan: orient with `look_at(global_position - velocity, up)`. A formation slot behind the leader needs a **negative** Z offset.
- **Movement plane:** XZ. Y is held constant for all agents in the MVP.
- **Attribution:** every file adapted from Duggan carries a comment naming the source file and line range.
- **Language:** British and Irish English in all prose. Student number **C21348423** in the README.
- **Mae authors** `swarm_unit.gd`'s force accumulation and every FSM state. Those arrive as `TODO(human)`.
- **No emoji or non-ASCII symbols** in code or documents.
- **Commit messages are ONE LINE**, in Conventional Commits form:
  `type(scope): message` or `type: message`. No body, no trailers, no co-author
  lines. `git commit -m "feat(steering): add arrive behaviour"` and nothing more.

---

### Task 1: Project configuration

Establishes the project so every later task has something that boots.

**Files:**
- Modify: `godot/project.godot`
- Modify: `aa26-project/.gitignore`
- Delete: unused platform binaries under `godot/addons/debug_draw_3d/libs/`

**Interfaces:**
- Consumes: nothing.
- Produces: input actions `move_forward`, `move_back`, `turn_left`, `turn_right`, `fire`; a project that boots headless.

- [ ] **Step 1: Trim the vendored addon to the platforms in use**

The addon ships 39 MB of binaries for every platform. Keep Linux and Windows; the originals remain in `aa-26/addons/` if another platform is ever needed.

```bash
cd aa26-project/godot/addons/debug_draw_3d/libs
rm -rf *.android.* *.ios.* *macos* *.web.*
du -sh ../../debug_draw_3d
```

Expected: well under 39 MB.

- [ ] **Step 2: Write `project.godot`**

```ini
config_version=5

[application]

config/name="Hybrid Bio-Tech Swarm Command"
config/description="CMPU 4031 Autonomous Agents artifact. Mae Capacite C21348423."
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "Forward Plus")

[input]

move_forward={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":87,"pressed":true)]
}
move_back={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":83,"pressed":true)]
}
turn_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":65,"pressed":true)]
}
turn_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":68,"pressed":true)]
}
fire={
"deadzone": 0.2,
"events": [Object(InputEventKey,"keycode":32,"pressed":true)]
}

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

renderer/rendering_method="forward_plus"
rendering_device/driver.windows="d3d12"
environment/defaults/default_clear_color=Color(0.02, 0.02, 0.04, 1)
```

`debug_draw_3d` needs no `[editor_plugins]` entry. It is a pure GDExtension:
it self-registers through `debug_draw_3d.gdextension` and never uses the
classic `plugin.cfg` mechanism. Enabling a plugin.cfg that does not exist is
a silent editor-only failure that headless boots do not catch.

The Windows rendering driver is set because a Windows export may be needed;
the addon's Windows binaries are retained for the same reason.

Note: the `[input]` block above is the shape, not the literal serialisation. Godot rewrites it on save. If the hand-written form fails to parse, define the five actions in **Project Settings > Input Map** in the editor instead and let Godot write the file.

- [ ] **Step 3: Confirm the project boots headless**

Run: `godot --headless --path godot --quit-after 5`
Expected: exits 0. Errors about the missing `main.tscn` are expected until Task 8; errors about `project.godot` itself are not.

- [ ] **Step 4: Update `.gitignore`**

Append to `aa26-project/.gitignore`:

```gitignore
# Godot export artefacts
godot/build/
godot/export_presets.cfg
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore godot/project.godot godot/addons docs CLAUDE_SOURCES.md
git commit -m "chore: scaffold Godot project, vendor debug_draw_3d, add design spec"
```

---

### Task 2: Wireframe rendering

Elite-style wireframe hulls. Built as line-primitive meshes rather than a barycentric shader, because CSG and primitive meshes carry no barycentric attribute — a derivative-based wireframe shader would need unindexed custom meshes anyway, so building the edges directly is both simpler and crisper at any zoom.

**Files:**
- Create: `godot/shaders/wireframe.gdshader`
- Create: `godot/scripts/world/wireframe_hull.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `WireframeHull extends MeshInstance3D` with `@export var hull_colour: Color` and `@export var hull_shape: HullShape` (enum `DART`, `POD`, `ROCK`); builds its own `ArrayMesh` on `_ready()`.

- [ ] **Step 1: Write the shader**

Create `godot/shaders/wireframe.gdshader`:

```glsl
// Unlit emissive line shader for Elite-style wireframe hulls.
// Lines carry their colour in COLOR; brightness is pushed above 1.0 so the
// world environment's glow picks them up.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform float brightness : hint_range(0.5, 6.0) = 2.5;
uniform float fade_start : hint_range(1.0, 500.0) = 120.0;

varying float distance_to_camera;

void vertex() {
	distance_to_camera = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float fade = 1.0 - smoothstep(fade_start * 0.5, fade_start, distance_to_camera);
	ALBEDO = COLOR.rgb * brightness * fade;
	ALPHA = COLOR.a * fade;
}
```

- [ ] **Step 2: Write the hull builder**

Create `godot/scripts/world/wireframe_hull.gd`:

```gdscript
## A wireframe hull drawn as line primitives, in the style of Elite (1984).
##
## Builds an [ArrayMesh] of [constant Mesh.PRIMITIVE_LINES] on ready. Line
## primitives are used rather than a barycentric wireframe shader because
## Godot's primitive and CSG meshes carry no barycentric attribute, so a
## derivative-based shader would require custom unindexed meshes regardless.
## Drawing the edges directly is simpler and stays crisp at any zoom.
class_name WireframeHull
extends MeshInstance3D

## Which hull to build. Each is a hand-authored vertex and edge list.
enum HullShape {
	## The commander ship: an elongated dart.
	DART,
	## A swarm unit: a small octahedral pod.
	POD,
	## An asteroid: an irregular lump.
	ROCK,
}

@export var hull_shape: HullShape = HullShape.POD

## Line colour. Player cyan, enemy amber, asteroids a dull green.
@export var hull_colour: Color = Color(0.2, 0.9, 1.0)

## Uniform scale applied to the authored vertex list.
@export var hull_scale: float = 1.0


func _ready() -> void:
	mesh = _build_mesh()
	material_override = _build_material()


## Assemble the line mesh for [member hull_shape].
func _build_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = _vertices_for(hull_shape)
	var edges: PackedInt32Array = _edges_for(hull_shape)

	var points := PackedVector3Array()
	var colours := PackedColorArray()
	for i in edges.size():
		points.append(vertices[edges[i]] * hull_scale)
		colours.append(hull_colour)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colours

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return array_mesh


## Build the unlit material that draws the lines.
func _build_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/wireframe.gdshader")
	return material


## Corner positions for a hull, in model space with +Z as forward.
func _vertices_for(shape: HullShape) -> PackedVector3Array:
	match shape:
		HullShape.DART:
			return PackedVector3Array([
				Vector3(0.0, 0.0, 2.0),      # 0 nose
				Vector3(-1.2, 0.0, -1.0),    # 1 port wingtip
				Vector3(1.2, 0.0, -1.0),     # 2 starboard wingtip
				Vector3(0.0, 0.5, -0.6),     # 3 dorsal fin
				Vector3(0.0, 0.0, -1.4),     # 4 tail
			])
		HullShape.ROCK:
			return PackedVector3Array([
				Vector3(0.0, 1.3, 0.0),
				Vector3(1.1, 0.3, 0.4),
				Vector3(0.2, 0.4, 1.2),
				Vector3(-1.0, 0.2, 0.5),
				Vector3(-0.6, 0.1, -1.0),
				Vector3(0.8, 0.3, -0.9),
				Vector3(0.0, -1.1, 0.0),
			])
		_:
			# POD: an octahedron.
			return PackedVector3Array([
				Vector3(0.0, 0.0, 1.0),
				Vector3(0.7, 0.0, 0.0),
				Vector3(0.0, 0.0, -1.0),
				Vector3(-0.7, 0.0, 0.0),
				Vector3(0.0, 0.6, 0.0),
				Vector3(0.0, -0.6, 0.0),
			])


## Vertex-index pairs, two per line segment.
func _edges_for(shape: HullShape) -> PackedInt32Array:
	match shape:
		HullShape.DART:
			return PackedInt32Array([
				0, 1, 0, 2, 1, 4, 2, 4, 1, 2, 0, 3, 3, 4,
			])
		HullShape.ROCK:
			return PackedInt32Array([
				0, 1, 0, 2, 0, 3, 0, 4, 0, 5,
				1, 2, 2, 3, 3, 4, 4, 5, 5, 1,
				6, 1, 6, 2, 6, 3, 6, 4, 6, 5,
			])
		_:
			return PackedInt32Array([
				0, 1, 1, 2, 2, 3, 3, 0,
				4, 0, 4, 1, 4, 2, 4, 3,
				5, 0, 5, 1, 5, 2, 5, 3,
			])
```

- [ ] **Step 3: Verify it parses**

Run: `godot --headless --path godot --check-only --script res://scripts/world/wireframe_hull.gd`
Expected: exits 0, no parse errors.

- [ ] **Step 4: Commit**

```bash
git add godot/shaders/wireframe.gdshader godot/scripts/world/wireframe_hull.gd
git commit -m "feat: add Elite-style wireframe hull renderer"
```

---

### Task 3: Steering behaviour base class

**Files:**
- Create: `godot/scripts/steering/steering_behaviour.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `SteeringBehaviour extends Node` with `@export var enabled: bool`, `@export var weight: float`, `@export var draw_gizmos: bool`, `var agent: CharacterBody3D`, `func calculate() -> Vector3`, `func on_draw_gizmos() -> void`.

- [ ] **Step 1: Write the base class**

Create `godot/scripts/steering/steering_behaviour.gd`:

```gdscript
## Base class for every steering behaviour a [SwarmUnit] or [Ship] can run.
##
## A behaviour is a [Node] child of the agent it steers. The agent collects its
## behaviours at run time and never names a concrete one, so adding a behaviour
## is a new file plus a node in the scene -- the Open/Closed principle made
## concrete.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/steering_behavior.gd.
## Two deliberate departures from that original:
##   1. [method calculate] is declared here and returns [constant Vector3.ZERO],
##      rather than being discovered by duck typing. A typo in a subclass then
##      fails loudly instead of silently never being collected.
##   2. [member agent] is typed [CharacterBody3D] rather than the agent class,
##      because two scripts whose [code]class_name[/code]s reference each other
##      are a cyclic dependency that GDScript rejects at parse time.
class_name SteeringBehaviour
extends Node

## When false the agent skips this behaviour entirely. Toggle in the Inspector
## to isolate one behaviour while debugging.
@export var enabled: bool = true

## Multiplier applied before the agent sums this force with the others.
## Weights are absolute, not normalised, because the agent truncates the
## running sum at its own max_force.
@export var weight: float = 1.0

## Draw this behaviour's own gizmos through DebugDraw3D.
@export var draw_gizmos: bool = true

## The agent being steered. Set from the parent on ready.
var agent: CharacterBody3D


func _ready() -> void:
	agent = get_parent() as CharacterBody3D
	if agent == null:
		push_error("%s must be a child of a CharacterBody3D agent." % name)


func _process(_delta: float) -> void:
	if draw_gizmos and enabled:
		on_draw_gizmos()


## Return the steering force this behaviour wants, in world space.
## Override in a subclass. The base contributes nothing.
func calculate() -> Vector3:
	return Vector3.ZERO


## Draw this behaviour's debug visualisation. Override in a subclass.
func on_draw_gizmos() -> void:
	pass


## Steer flat out towards [param destination]: Reynolds seek.
##
## Shared helper rather than a behaviour of its own, because cohesion, path
## following and pursuit are all "seek, at a point I worked out first".
func seek_towards(destination: Vector3) -> Vector3:
	var to_target: Vector3 = destination - agent.global_position
	var desired: Vector3 = to_target.normalized() * agent.max_speed
	return desired - agent.velocity


## Steer towards [param destination], braking inside [param slowing_distance].
##
## The [code]dist < 2.0[/code] dead zone is a numerical-stability guard: the
## line below it divides by [code]dist[/code], which blows up at the target and
## makes the agent jitter or emit NaN. It also gives a clean stop condition.
## Adapted from Duggan, behaviors/boid.gd:106-116.
func arrive_towards(destination: Vector3, slowing_distance: float) -> Vector3:
	var to_target: Vector3 = destination - agent.global_position
	var dist: float = to_target.length()
	if dist < 2.0:
		return Vector3.ZERO
	var ramped: float = (dist / slowing_distance) * agent.max_speed
	var clamped: float = minf(agent.max_speed, ramped)
	var desired: Vector3 = (to_target * clamped) / dist
	return desired - agent.velocity
```

- [ ] **Step 2: Verify it parses**

Run: `godot --headless --path godot --check-only --script res://scripts/steering/steering_behaviour.gd`
Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/steering/steering_behaviour.gd
git commit -m "feat: add SteeringBehaviour base with seek and arrive helpers"
```

---

### Task 4: The swarm unit agent

The core autonomous agent. **Mae writes the force accumulation**; this task scaffolds everything around it and leaves a single `TODO(human)`.

**Files:**
- Create: `godot/scripts/agents/swarm_unit.gd`

**Interfaces:**
- Consumes: `SteeringBehaviour.calculate()`, `.weight`, `.enabled`.
- Produces: `SwarmUnit extends CharacterBody3D` with `@export var mass: float`, `max_speed: float`, `max_force: float`, `banking: float`, `damping: float`, `allegiance: int`, `health: float`; `func calculate_force() -> Vector3`.

- [ ] **Step 1: Write the agent with the accumulation left open**

Create `godot/scripts/agents/swarm_unit.gd`:

```gdscript
## An autonomous swarm creature, steered by its child [SteeringBehaviour] nodes.
##
## The unit owns movement and nothing else: mass, limits, banking, and the
## integration step. It never names a concrete behaviour, so adding seek, flee
## or flocking means adding a file and a node -- this script does not change.
##
## Each physics tick:
## [codeblock]
## force        = WTPRS sum of enabled behaviours
## acceleration = force / mass
## velocity    += acceleration * delta
## [/codeblock]
##
## Movement is constrained to the XZ plane: the Y component of both force and
## velocity is zeroed, because this is a 2.5D game.
class_name SwarmUnit
extends CharacterBody3D

## Emitted when health reaches zero, before the node is freed.
signal died(unit: SwarmUnit)

## Which side this unit fights for. Player is 0, enemy is 1.
@export var allegiance: int = 0

## Higher mass means the same force produces less acceleration, so the unit
## turns more sluggishly and feels heavier. Never set this to zero.
@export var mass: float = 1.0

## Speed ceiling in units per second. Behaviours read this to size the
## velocity they ask for, so it is an input, not a readout.
@export var max_speed: float = 12.0

## Ceiling on the summed steering force. Without it, several behaviours pulling
## the same way produce unbounded acceleration and the motion reads as robotic.
@export var max_force: float = 20.0

## How far the unit rolls into a turn. 0 keeps it upright.
@export var banking: float = 0.1

## Continuous velocity decay, applied on top of the speed clamp. This is what
## makes the unit coast to rest when the forces vanish.
@export var damping: float = 0.1

@export_group("Combat")

## Current health. Corrosion and enemy fire reduce it.
@export var health: float = 100.0

@export_group("Debug")

## Draw the accumulated force and the velocity through DebugDraw3D.
@export var draw_gizmos: bool = true

## Behaviours found among this unit's children, in scene-tree order.
## That order IS priority order -- see [method calculate_force].
var behaviours: Array[SteeringBehaviour] = []

## The force actually applied this tick, after smoothing.
var force: Vector3 = Vector3.ZERO


func _ready() -> void:
	_collect_behaviours()


## Cache the child behaviours once rather than walking the child list every
## physics frame. Call again if behaviours are added at run time.
func _collect_behaviours() -> void:
	behaviours.clear()
	for child in get_children():
		if child is SteeringBehaviour:
			behaviours.append(child)


# --- Force accumulation (Mae's implementation) ----------------------------

## Combine the child behaviours into one steering force using WTPRS:
## Weighted Truncated Running Sum with Prioritisation.
##
## Duggan's algorithm, behaviors/boid.gd:141-158. Four parts to it:
##   Weighted        multiply each behaviour's force by its own weight
##   Running Sum     accumulate as you go, testing after every single addition
##   Truncated       clamp the accumulator to max_force when it exceeds it
##   Prioritisation  break out of the loop at that point, so behaviours later
##                   in the child order contribute nothing at all this tick
##
## Steps:
##   1. Start an accumulator at Vector3.ZERO.
##   2. For each behaviour in `behaviours`, skip it unless `enabled`.
##   3. Multiply `behaviour.calculate()` by `behaviour.weight`.
##   4. Guard against NaN: a behaviour that divides by a zero-length vector
##      poisons the sum permanently, since NaN plus anything is NaN. Zero the
##      offending force instead.
##   5. Add it to the accumulator.
##   6. If the accumulator now exceeds `max_force`, clamp it with
##      `limit_length(max_force)` and break.
##   7. Return the accumulator.
func calculate_force() -> Vector3:
	# TODO(human): implement WTPRS per the steps above.
	return Vector3.ZERO


# --- Integration (fixed-timestep plumbing) --------------------------------

func _physics_process(delta: float) -> void:
	var new_force: Vector3 = calculate_force()
	new_force.y = 0.0

	# Low-pass filter the applied force so it chases the newly computed force
	# rather than snapping to it. Removes jitter when a behaviour switches on
	# or off. Duggan, behaviors/boid.gd:178.
	force = force.lerp(new_force, delta)

	var acceleration: Vector3 = force / mass
	velocity += acceleration * delta
	velocity.y = 0.0

	# Clamp first, then damp. The clamp is a hard ceiling; damping is
	# continuous decay that also acts below the ceiling.
	velocity = velocity.limit_length(max_speed)
	velocity -= velocity * delta * damping

	move_and_slide()

	if velocity.length() > 0.01:
		_face_direction_of_travel(acceleration, delta)

	if draw_gizmos:
		DebugDraw3D.draw_arrow(
			global_position, global_position + force, Color.YELLOW, 0.1
		)
		DebugDraw3D.draw_arrow(
			global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1
		)


## Point the hull along the velocity and roll it into turns.
##
## [method Node3D.look_at] aims the node's -Z at the point given, but this
## codebase treats +Z as forward, following Duggan. Passing a point *behind*
## the unit aims -Z backwards, which leaves +Z along the velocity.
func _face_direction_of_travel(acceleration: Vector3, delta: float) -> void:
	var banked_up: Vector3 = Vector3.UP + acceleration * banking
	var smoothed_up: Vector3 = global_basis.y.lerp(banked_up, delta * 5.0)

	# look_at() errors when the up-vector is parallel to the look direction.
	if absf(smoothed_up.normalized().dot(velocity.normalized())) > 0.999:
		return
	look_at(global_position - velocity, smoothed_up)


## Reduce health and free the unit when it runs out.
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		died.emit(self)
		queue_free()
```

- [ ] **Step 2: Verify it parses**

Run: `godot --headless --path godot --check-only --script res://scripts/agents/swarm_unit.gd`
Expected: exits 0.

- [ ] **Step 3: Hand `calculate_force()` to Mae**

Present the Learn by Doing request. Do not implement it. Wait.

- [ ] **Step 4: Commit once her implementation is in**

```bash
git add godot/scripts/agents/swarm_unit.gd
git commit -m "feat: add SwarmUnit agent with WTPRS force accumulation"
```

---

### Task 5: Concrete steering behaviours

Three behaviours: enough for a unit to hold formation on a moving leader.

**Files:**
- Create: `godot/scripts/steering/seek_behaviour.gd`
- Create: `godot/scripts/steering/arrive_behaviour.gd`
- Create: `godot/scripts/steering/offset_pursue_behaviour.gd`

**Interfaces:**
- Consumes: `SteeringBehaviour.seek_towards()`, `.arrive_towards()`, `.agent`.
- Produces: `SeekBehaviour`, `ArriveBehaviour`, `OffsetPursueBehaviour`, each with `@export var target: Node3D` (the last named `leader`).

- [ ] **Step 1: Write seek**

Create `godot/scripts/steering/seek_behaviour.gd`:

```gdscript
## Steer flat out towards a target node.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/seek.gd.
class_name SeekBehaviour
extends SteeringBehaviour

## The node to steer towards. When null the behaviour contributes nothing.
@export var target: Node3D


func calculate() -> Vector3:
	if target == null:
		return Vector3.ZERO
	return seek_towards(target.global_position)


func on_draw_gizmos() -> void:
	if target != null:
		DebugDraw3D.draw_line(
			agent.global_position, target.global_position, Color.AQUA
		)
```

- [ ] **Step 2: Write arrive**

Create `godot/scripts/steering/arrive_behaviour.gd`:

```gdscript
## Steer towards a target node, braking inside the slowing radius.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/arrive.gd.
class_name ArriveBehaviour
extends SteeringBehaviour

## The node to settle at. When null the behaviour contributes nothing.
@export var target: Node3D

## Distance at which the unit begins to brake. Duggan's default is 20 against
## a max speed of 10.
@export var slowing_radius: float = 20.0


func calculate() -> Vector3:
	if target == null:
		return Vector3.ZERO
	return arrive_towards(target.global_position, slowing_radius)


func on_draw_gizmos() -> void:
	if target != null:
		DebugDraw3D.draw_sphere(
			target.global_position, slowing_radius, Color.AQUAMARINE
		)
```

- [ ] **Step 3: Write offset pursue**

Create `godot/scripts/steering/offset_pursue_behaviour.gd`:

```gdscript
## Hold a fixed slot in the leader's local frame, leading the leader's motion.
##
## This is what makes a swarm read as a formation rather than a crowd. The slot
## is not authored: [method _capture_offset] measures where the unit was placed
## relative to the leader and keeps that as its station for the run.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/offset_pursue.gd.
## Two departures: the slowing distance is exported rather than hardcoded at
## 30, and the offset is flattened onto the XZ plane for this 2.5D game.
class_name OffsetPursueBehaviour
extends SteeringBehaviour

## The agent to fly formation on.
@export var leader: CharacterBody3D

## Distance at which the unit brakes into its slot rather than overshooting.
@export var slowing_radius: float = 30.0

## The formation slot, in the leader's local frame. Captured on ready.
var leader_offset: Vector3 = Vector3.ZERO

## The world-space point the unit is currently steering for.
var projected: Vector3 = Vector3.ZERO


func _ready() -> void:
	super()
	# Deferred because the leader's global transform may not be settled during
	# _ready(). Duggan uses call_deferred here for the same reason.
	call_deferred("_capture_offset")


## Measure the unit's starting position relative to the leader and keep it.
##
## [code]Vector3 * Basis[/code] is the transposed product, which for an
## orthonormal basis is the inverse rotation -- so this converts a world-space
## offset into the leader's local frame. [method calculate] applies the full
## transform to convert it back, which is why the formation rotates with the
## leader for free.
func _capture_offset() -> void:
	if leader == null:
		return
	var world_offset: Vector3 = agent.global_position - leader.global_position
	world_offset.y = 0.0
	leader_offset = world_offset * leader.global_transform.basis


func calculate() -> Vector3:
	if leader == null:
		return Vector3.ZERO
	var world_target: Vector3 = leader.global_transform * leader_offset
	var dist: float = agent.global_position.distance_to(world_target)
	var lead_time: float = dist / agent.max_speed
	projected = world_target + leader.velocity * lead_time
	projected.y = agent.global_position.y
	return arrive_towards(projected, slowing_radius)


func on_draw_gizmos() -> void:
	if leader != null:
		DebugDraw3D.draw_line(agent.global_position, projected, Color.ORANGE)
```

- [ ] **Step 4: Verify all three parse**

```bash
for f in seek_behaviour arrive_behaviour offset_pursue_behaviour; do
  godot --headless --path godot --check-only --script "res://scripts/steering/$f.gd" || echo "FAILED: $f"
done
```

Expected: no `FAILED` lines.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/steering/
git commit -m "feat: add seek, arrive and offset pursue behaviours"
```

---

### Task 6: The commander ship

**Files:**
- Create: `godot/scripts/agents/ship.gd`
- Create: `godot/scripts/steering/player_steering_behaviour.gd`

**Interfaces:**
- Consumes: `SteeringBehaviour`.
- Produces: `Ship extends CharacterBody3D` exposing `max_speed`, `velocity`, `allegiance`; `PlayerSteeringBehaviour extends SteeringBehaviour`.

- [ ] **Step 1: Write the player steering behaviour**

Create `godot/scripts/steering/player_steering_behaviour.gd`:

```gdscript
## Turn keyboard input into a thrust force in the agent's local frame.
##
## Unlike every other behaviour this returns a raw thrust vector rather than
## [code]desired - velocity[/code]. That is what makes it feel like flying a
## ship rather than commanding a destination; its magnitude comes entirely from
## [member SteeringBehaviour.weight].
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/player_steering.gd.
## The vertical axis is dropped because movement is constrained to XZ.
class_name PlayerSteeringBehaviour
extends SteeringBehaviour

## Thrust applied along the agent's forward axis.
@export var thrust: float = 30.0

## Turning force applied along the agent's right axis.
@export var turn_force: float = 20.0


func calculate() -> Vector3:
	# basis.x flattened onto XZ. When the hull is banked into a turn its local
	# right-vector tilts, which would otherwise inject a vertical component.
	var projected_right: Vector3 = agent.global_transform.basis.x
	projected_right.y = 0.0
	projected_right = projected_right.normalized()

	var move: float = Input.get_axis("move_back", "move_forward")
	var turn: float = Input.get_axis("turn_left", "turn_right")

	# basis.z is the forward push: +Z is forward in this codebase.
	var force := Vector3.ZERO
	force += move * agent.global_transform.basis.z * thrust
	force += turn * projected_right * turn_force
	force.y = 0.0
	return force
```

- [ ] **Step 2: Write the ship**

Create `godot/scripts/agents/ship.gd`:

```gdscript
## A commander vessel: the player's ship, and the enemy's identical mirror.
##
## Shares the swarm unit's integration model but keeps its own tuning, because
## a capital ship should feel heavier and turn more lazily than a creature.
## The class carries no input handling -- [PlayerSteeringBehaviour] or the
## enemy's controller drives it, so the ship never knows which is at the helm.
class_name Ship
extends CharacterBody3D

## Emitted when the ship is destroyed. The match ends on this.
signal destroyed(ship: Ship)

## Which side this ship commands. Player is 0, enemy is 1.
@export var allegiance: int = 0

@export var mass: float = 4.0
@export var max_speed: float = 18.0
@export var max_force: float = 40.0
@export var banking: float = 0.25
@export var damping: float = 0.6

@export_group("Combat")

@export var health: float = 500.0

@export_group("Debug")

@export var draw_gizmos: bool = true

var behaviours: Array[SteeringBehaviour] = []
var force: Vector3 = Vector3.ZERO


func _ready() -> void:
	for child in get_children():
		if child is SteeringBehaviour:
			behaviours.append(child)


## Weighted truncated sum of the child behaviours.
##
## The ship uses the plain weighted sum rather than the units' WTPRS: with only
## player steering attached there is nothing to prioritise, and truncating the
## running sum would make the controls feel like they were fighting back.
func calculate_force() -> Vector3:
	var total := Vector3.ZERO
	for behaviour in behaviours:
		if behaviour.enabled:
			total += behaviour.calculate() * behaviour.weight
	return total.limit_length(max_force)


func _physics_process(delta: float) -> void:
	var new_force: Vector3 = calculate_force()
	new_force.y = 0.0
	force = force.lerp(new_force, delta * 4.0)

	var acceleration: Vector3 = force / mass
	velocity += acceleration * delta
	velocity.y = 0.0
	velocity = velocity.limit_length(max_speed)
	velocity -= velocity * delta * damping

	move_and_slide()

	if velocity.length() > 0.01:
		var banked_up: Vector3 = Vector3.UP + acceleration * banking
		var smoothed_up: Vector3 = global_basis.y.lerp(banked_up, delta * 5.0)
		if absf(smoothed_up.normalized().dot(velocity.normalized())) < 0.999:
			look_at(global_position - velocity, smoothed_up)

	if draw_gizmos:
		DebugDraw3D.draw_arrow(
			global_position, global_position + force, Color.RED, 0.15
		)


## Reduce health and end the match when it runs out.
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		destroyed.emit(self)
```

- [ ] **Step 3: Verify both parse**

```bash
godot --headless --path godot --check-only --script res://scripts/steering/player_steering_behaviour.gd
godot --headless --path godot --check-only --script res://scripts/agents/ship.gd
```

Expected: both exit 0.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/agents/ship.gd godot/scripts/steering/player_steering_behaviour.gd
git commit -m "feat: add commander ship with planar player steering"
```

---

### Task 7: The follow camera

**Files:**
- Create: `godot/scripts/control/follow_camera.gd`

**Interfaces:**
- Consumes: a `Node3D` target.
- Produces: `FollowCamera extends Camera3D` with `@export var target: Node3D`, `height`, `distance`, `smoothing`.

- [ ] **Step 1: Write the camera**

Create `godot/scripts/control/follow_camera.gd`:

```gdscript
## A tilted camera that trails the player's ship, giving the 2.5D read.
##
## The camera holds a fixed world-space offset rather than orbiting behind the
## ship's heading. A trailing camera would swing the whole battlefield around
## every time the player turned, which in a top-down strategy game costs the
## player their mental map of where everything is. Keeping the offset in world
## space means north stays north.
class_name FollowCamera
extends Camera3D

## The node to follow.
@export var target: Node3D

## Height above the movement plane.
@export var height: float = 34.0

## How far back along world -Z the camera sits, which sets the tilt angle.
## With the default height this is roughly 60 degrees from vertical.
@export var distance: float = 20.0

## How quickly the camera catches up. Higher is snappier.
@export var smoothing: float = 4.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = target.global_position + Vector3(0.0, height, distance)
	global_position = global_position.lerp(desired, delta * smoothing)
	look_at(target.global_position, Vector3.UP)
```

- [ ] **Step 2: Verify it parses**

Run: `godot --headless --path godot --check-only --script res://scripts/control/follow_camera.gd`
Expected: exits 0.

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/control/follow_camera.gd
git commit -m "feat: add tilted follow camera for the 2.5D view"
```

---

### Task 8: Assemble and play

**Files:**
- Create: `godot/scenes/units/swarm_unit.tscn`
- Create: `godot/scenes/ships/commander_ship.tscn`
- Replace: `godot/scenes/main.tscn`

**Interfaces:**
- Consumes: every class from Tasks 2-7.
- Produces: a running game.

- [ ] **Step 1: Build the swarm unit scene**

Assemble in the editor (`godot-dev editor`) rather than by hand-writing `.tscn`, because node paths and sub-resource ids are error-prone to author blind:

```
SwarmUnit            (CharacterBody3D, swarm_unit.gd)
├── Hull             (WireframeHull, hull_shape POD, colour cyan)
├── CollisionShape3D (SphereShape3D, radius 0.7)
└── OffsetPursue     (OffsetPursueBehaviour, weight 1.0)
```

Set `motion_mode` on the `CharacterBody3D` to **Floating**. The default Grounded mode adds floor snapping and up-axis velocity clamping, which are built for a walking character and fight a steered agent.

- [ ] **Step 2: Build the ship scene**

```
CommanderShip        (CharacterBody3D, ship.gd)
├── Hull             (WireframeHull, hull_shape DART, colour cyan, scale 2.0)
├── CollisionShape3D (BoxShape3D, 2.4 x 0.6 x 4)
└── PlayerSteering   (PlayerSteeringBehaviour, weight 1.0)
```

`motion_mode` Floating here too.

- [ ] **Step 3: Build the main scene**

```
Main                    (Node3D)
├── WorldEnvironment    (glow enabled, background colour 0.02 0.02 0.04)
├── CommanderShip       (instance, at origin)
├── Units               (Node3D)
│   ├── SwarmUnit  ... five instances, placed BEHIND the ship
│   └── ...             each OffsetPursue.leader = CommanderShip
└── Camera3D            (FollowCamera, target = CommanderShip)
```

Place the five units at roughly `(-6, 0, -6)`, `(-3, 0, -9)`, `(0, 0, -11)`, `(3, 0, -9)`, `(6, 0, -6)` — a trailing V. **Negative Z is behind**, because +Z is forward in this codebase. Getting the sign wrong builds a formation that flies ahead of its own leader.

Each unit's `OffsetPursue` captures its slot from exactly where it was placed, so the V in the editor is the V in play.

- [ ] **Step 4: Run it**

Run: `cd godot && godot-dev run`

Expected: a dark field, a cyan wireframe dart, five cyan pods trailing it in a V. W and S thrust, A and D turn. The pods hold station, lag on hard turns, and settle back without oscillating. Yellow force arrows and blue velocity arrows on every agent.

- [ ] **Step 5: Verify it boots clean headless**

Run: `godot --headless --path godot --quit-after 180`
Expected: exits 0 with no script errors in the output.

- [ ] **Step 6: Commit**

```bash
git add godot/scenes/
git commit -m "feat: assemble MVP scene with ship and five formation units"
```

---

## What this MVP deliberately leaves out

Named here so the omissions read as decisions rather than gaps, and so Saturday's plan knows where to start:

- **Flocking.** Separation, alignment and cohesion, plus the `Swarm` spatial hash. Phase 2.
- **The FSM.** Units have no states yet; they only ever hold formation. Phase 2.
- **The economy.** Asteroids, feasting, alloy, the factory. Phase 3.
- **The enemy.** `CommanderAI` and the mirror faction. Phase 4.
- **Weapons.** The `fire` action is mapped but unbound.
- **Sound.** Phase 4.
