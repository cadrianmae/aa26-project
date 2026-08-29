# Phase 2: Flocking and FSM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn five units that hold a rigid formation into a swarm that flocks, reacts, and reads as alive: neighbour-aware steering over a spatial hash, a per-unit finite state machine, and a flee reflex that overrides orders for survival.

**Architecture:** A `Swarm` node owns a uniform spatial-hash grid and answers "who is near this unit, on its side". Units register with it on ready and query it once per frame, caching the result so the three flocking behaviours share one search. Each unit also owns a `StateMachine` whose states are child nodes following Duggan's `_enter` / `_exit` / `_think` contract; a state changes nothing about movement code, it only re-weights which steering behaviours are enabled.

**Tech Stack:** Godot 4.7 (project targets 4.6 features), GDScript, `debug_draw_3d` for gizmos.

**Spec:** `docs/superpowers/specs/2026-08-27-swarm-command-rts-design.md`

## Global Constraints

- **Engine:** Godot 4.6 feature level under 4.7.1. Binary is `godot`; `godot-dev run` runs the project.
- **Parse check:** `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`. Empty output means every script parses. NEVER use `--check-only --script`: it does not load the global class cache and reports misleading "Could not find type" errors.
- **File and folder names:** `snake_case`. **Node names in scenes:** `PascalCase`.
- **GDScript member order:** doc comment FIRST at the very top of the file above `class_name`, then `class_name`, `extends`, signals, enums, constants, `@export`, vars, `@onready`, then methods.
- **Type annotations:** explicit `var x: Vector3 = ...` preferred over `:=`, matching `aa-26-refactored`.
- **Indentation:** tabs. **Line length:** under 100 characters. **Quotes:** double.
- **Forward axis is +Z**, following Duggan. Negative Z is behind. Alignment averages `basis.z` headings, which is only correct under this convention.
- **Movement plane:** XZ. Y is held constant; zero the Y component of every steering force.
- **Attribution:** every file adapted from Duggan carries a comment naming the source file and line range.
- **Language:** British and Irish English. No emoji, no non-ASCII symbols anywhere.
- **Commit messages are ONE LINE**, Conventional Commits `type(scope): message` or `type: message`. No body, no trailers, no `Co-Authored-By`. Never pass a second `-m`.
- **Mae authors** `FleeState._think()`. It arrives as a `TODO(human)` and must NOT be implemented.
- **Scene edits:** add nodes as normal children. NEVER as overrides into instanced sub-scenes — the editor silently prunes those in this project.

---

## File structure

| File | Responsibility |
|---|---|
| `scripts/swarm/swarm.gd` | Uniform spatial hash. Registration, re-binning, neighbour queries. |
| `scripts/steering/separation_behaviour.gd` | Steer away from near neighbours, 1/d falloff. |
| `scripts/steering/alignment_behaviour.gd` | Match neighbours' average heading. |
| `scripts/steering/cohesion_behaviour.gd` | Seek the neighbours' centre of mass. |
| `scripts/states/state.gd` | Base state: `_enter` / `_exit` / `_think`. |
| `scripts/states/state_machine.gd` | Current state plus global state, transitions. |
| `scripts/states/unit/*.gd` | Eight unit states. FOLLOW live, FLEE is Mae's, six stubs. |
| `scripts/world/threat.gd` | A marker units flee from, so FLEE is testable before combat exists. |
| `scripts/agents/swarm_unit.gd` | Modified: swarm registration, neighbour cache, death. |

---

### Task 1: The Swarm spatial hash

**Files:**
- Create: `godot/scripts/swarm/swarm.gd`

**Interfaces:**
- Consumes: `SwarmUnit` (class exists, has `allegiance: int`, `global_position`).
- Produces: `Swarm extends Node` with `@export var neighbour_distance: float`, `@export var max_neighbours: int`, `@export var cell_size: float`, `@export var partition: bool`, `@export var draw_gizmos: bool`; methods `register(unit: SwarmUnit) -> void`, `deregister(unit: SwarmUnit) -> void`, `neighbours_of(unit: SwarmUnit) -> Array[SwarmUnit]`, `position_to_cell(p: Vector3) -> int`.

This is the task that fixes two defects in Duggan's `school.gd`. Each fix carries a comment naming the defect, because the assignment's Complexity band rewards demonstrated understanding over transcription.

- [ ] **Step 1: Write the file**

Create `godot/scripts/swarm/swarm.gd`:

```gdscript
## A faction's swarm: the spatial index that answers "who is near this unit".
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/school.gd:29-58, with
## two corrections documented at their sites. Unlike his School this does NOT
## spawn its units: Phase 3's factory owns spawning, and units register
## themselves on ready. Separating "who creates units" from "who indexes them"
## is what lets a unit spawned at run time join the flock with no special case.
##
## The grid is a uniform spatial hash re-binned every frame. Binning is O(n)
## with no tree to rebuild, which is the right trade for a few hundred agents
## that all move every frame. The naive alternative is O(n squared): at 100
## units that is 9,900 distance checks per frame, at 1,000 it is 999,000.
class_name Swarm
extends Node

## Which side this swarm belongs to. Units only ever see neighbours whose
## allegiance matches their own.
@export var allegiance: int = 0

## How far a unit can see a neighbour, in world units.
@export var neighbour_distance: float = 20.0

## Most neighbours any one unit considers. Caps the cost of a dense cluster.
@export var max_neighbours: int = 10

## Width of one hash cell.
##
## DEFECT 1 in Duggan's school.gd:9,14 -- he ships cell_size = 10 against
## neighbour_distance = 20. The 27-cell scan samples the boid's own cell plus
## the 26 around it, so the GUARANTEED reach in any direction is only one
## cell_size (the unit can sit hard against a cell face), up to two at best.
## With his numbers a genuine neighbour 16 to 20 units away is silently missed.
## The flock still looks passable because a missed neighbour at the edge of the
## perception sphere contributes almost nothing under 1/d separation, but it is
## a correctness bug, not a tuning choice. Fixed by requiring
## cell_size >= neighbour_distance, enforced in _ready().
@export var cell_size: float = 20.0

## Spread of the hash key space per axis. Large enough that distinct cells
## never collide onto one key for any position this game reaches.
@export var grid_size: int = 10000

## When false, falls back to the naive O(n squared) scan. Kept as a runtime
## A/B against the partitioned path, which is what the optimisation claim in
## the write-up rests on.
@export var partition: bool = true

@export_group("Debug")

## Draw the occupied cells and each unit's perception radius.
@export var draw_gizmos: bool = false

## Every living unit on this side.
var units: Array[SwarmUnit] = []

## Hash key to the units currently binned in that cell. Rebuilt every frame.
var _cells: Dictionary = {}


func _ready() -> void:
	# Enforcing the fix rather than trusting the Inspector: a cell smaller than
	# the perception radius reintroduces DEFECT 1 silently.
	if cell_size < neighbour_distance:
		push_warning(
			"Swarm cell_size (%.1f) is below neighbour_distance (%.1f); "
			% [cell_size, neighbour_distance]
			+ "raising it, because a smaller cell makes the 27-cell scan "
			+ "miss genuine neighbours."
		)
		cell_size = neighbour_distance


## Add a unit to this swarm. Called by the unit itself on ready, so units
## created at run time join without the swarm knowing they exist beforehand.
func register(unit: SwarmUnit) -> void:
	if not units.has(unit):
		units.append(unit)


## Remove a unit, on death or despawn.
func deregister(unit: SwarmUnit) -> void:
	units.erase(unit)


func _process(_delta: float) -> void:
	if partition:
		_rebuild_cells()
	if draw_gizmos:
		_draw_gizmos()


## Hash a world position to a single integer cell key.
##
## The +10000 shift kills negative coordinates before flooring. Without it
## floor(-0.5) is -1 and floor(0.5) is 0, so positions either side of an axis
## collapse onto neighbouring keys and the grid corrupts near the origin.
## Duggan, school.gd:29-34.
func position_to_cell(p: Vector3) -> int:
	var shifted: Vector3 = p + Vector3(10000.0, 10000.0, 10000.0)
	var x: int = int(floor(shifted.x / cell_size))
	var y: int = int(floor(shifted.y / cell_size))
	var z: int = int(floor(shifted.z / cell_size))
	return x + (y * grid_size) + (z * grid_size * grid_size)


## Re-bin every unit. O(n), once per rendered frame.
func _rebuild_cells() -> void:
	_cells.clear()
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var key: int = position_to_cell(unit.global_position)
		if not _cells.has(key):
			_cells[key] = []
		_cells[key].append(unit)


## Return the nearest units to [param unit] on the same side, within
## [member neighbour_distance], at most [member max_neighbours] of them.
##
## DEFECT 2 in Duggan's boid.gd:65-66 -- he returns the moment the neighbour
## count hits the cap, so the units kept are the first ones the cell iteration
## happened to reach, NOT the nearest. In a dense cluster that is a meaningful
## bias, and scanning the centre cell first only mitigates it. Fixed here by
## collecting every candidate inside the radius, sorting by distance, and
## keeping the closest max_neighbours.
func neighbours_of(unit: SwarmUnit) -> Array[SwarmUnit]:
	var found: Array[SwarmUnit] = []
	var candidates: Array = _candidates_for(unit)
	var radius_squared: float = neighbour_distance * neighbour_distance

	for other in candidates:
		if other == unit or not is_instance_valid(other):
			continue
		if other.allegiance != unit.allegiance:
			continue
		var offset: Vector3 = other.global_position - unit.global_position
		if offset.length_squared() <= radius_squared:
			found.append(other)

	# Nearest-first, then truncate. This is the correction to DEFECT 2.
	var origin: Vector3 = unit.global_position
	found.sort_custom(
		func(a: SwarmUnit, b: SwarmUnit) -> bool:
			return (
				a.global_position.distance_squared_to(origin)
				< b.global_position.distance_squared_to(origin)
			)
	)
	if found.size() > max_neighbours:
		found.resize(max_neighbours)
	return found


## The units worth distance-testing: the 27 cells around this one when
## partitioning, or everything when not.
##
## Offsetting the POSITION by exactly cell_size always shifts the cell index by
## exactly one, so the 27 keys are distinct and nothing is double-counted.
## Note 3x3x3 = 27 is the 3D figure; the familiar "own cell plus 8 neighbours"
## is the 2D form and is wrong here. Duggan, boid.gd:44-49.
func _candidates_for(unit: SwarmUnit) -> Array:
	if not partition:
		return units

	var gathered: Array = []
	var origin: Vector3 = unit.global_position
	for slice in [0, -1, 1]:
		for row in [0, -1, 1]:
			for col in [0, -1, 1]:
				var sample: Vector3 = origin + Vector3(
					float(col) * cell_size,
					float(row) * cell_size,
					float(slice) * cell_size
				)
				var key: int = position_to_cell(sample)
				if _cells.has(key):
					gathered.append_array(_cells[key])
	return gathered


func _draw_gizmos() -> void:
	for unit in units:
		if is_instance_valid(unit):
			DebugDraw3D.draw_sphere(
				unit.global_position, neighbour_distance, Color.WEB_PURPLE
			)
```

- [ ] **Step 2: Parse check**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/swarm/swarm.gd
git commit -m "feat(swarm): add spatial hash correcting two defects in Duggan's School"
```

---

### Task 2: Wire units into the swarm

**Files:**
- Modify: `godot/scripts/agents/swarm_unit.gd`

**Interfaces:**
- Consumes: `Swarm.register()`, `Swarm.deregister()`, `Swarm.neighbours_of()`.
- Produces: on `SwarmUnit` — `@export var swarm: Swarm`, `var neighbours: Array[SwarmUnit]`, `var count_neighbours: bool`.

One neighbour search per unit per frame, shared by all three flocking behaviours. A behaviour opts the unit into searching by setting `count_neighbours = true` in its `_ready()`, exactly as Duggan's do; a unit with no flocking behaviour pays nothing.

- [ ] **Step 1: Add the members**

In `godot/scripts/agents/swarm_unit.gd`, after the existing `@export var draw_gizmos: bool = true` and its `@export_group("Debug")`, add a new group and members. Insert before `var behaviours: Array[SteeringBehaviour] = []`:

```gdscript
@export_group("Flocking")

## The swarm this unit belongs to. Assigned in the scene, or by the factory
## when the unit is spawned at run time.
@export var swarm: Swarm
```

Then alongside the existing `var behaviours` and `var force` declarations, add:

```gdscript
## Units near this one on the same side, refreshed once per frame. Shared by
## every flocking behaviour so the search runs once rather than three times.
var neighbours: Array[SwarmUnit] = []

## Set true by any behaviour that needs neighbours. A unit with no flocking
## behaviour never pays for the search.
var count_neighbours: bool = false
```

- [ ] **Step 2: Register on ready and refresh per frame**

Change `_ready()` from its current body to:

```gdscript
func _ready() -> void:
	_collect_behaviours()
	if swarm != null:
		swarm.register(self)
```

Add a `_process` (the unit currently has none — neighbour search belongs at render rate, not physics rate, so an expensive query runs at most once per drawn frame):

```gdscript
func _process(_delta: float) -> void:
	if swarm != null and count_neighbours:
		neighbours = swarm.neighbours_of(self)
```

- [ ] **Step 3: Deregister on death**

Change `take_damage()` from its current body to:

```gdscript
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		if swarm != null:
			swarm.deregister(self)
		died.emit(self)
		queue_free()
```

- [ ] **Step 4: Parse check**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/agents/swarm_unit.gd
git commit -m "feat(agents): register swarm units and cache neighbour queries"
```

---

### Task 3: The flocking triple

**Files:**
- Create: `godot/scripts/steering/separation_behaviour.gd`
- Create: `godot/scripts/steering/alignment_behaviour.gd`
- Create: `godot/scripts/steering/cohesion_behaviour.gd`

**Interfaces:**
- Consumes: `SteeringBehaviour` (`agent`, `calculate()`, `on_draw_gizmos()`, `seek_towards()`), `SwarmUnit.neighbours`, `SwarmUnit.count_neighbours`.
- Produces: `SeparationBehaviour`, `AlignmentBehaviour`, `CohesionBehaviour`.

- [ ] **Step 1: Separation**

Create `godot/scripts/steering/separation_behaviour.gd`:

```gdscript
## Steer away from near neighbours so units do not overlap.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/separation.gd:16-22.
##
## The falloff is INVERSE distance, 1/d, not inverse-square. The expression
## away.normalized() / away.length() is away / |away| squared, whose MAGNITUDE
## is 1/|away|. It reads as inverse-square because of the squared denominator;
## it is not. Closer neighbours dominate, and deliberately so.
##
## The sum is neither normalised nor divided by the neighbour count, unlike
## cohesion. A unit in a tight cluster gets a genuinely larger escape force,
## which is the point. Truncation is left to the agent's WTPRS max_force clamp.
class_name SeparationBehaviour
extends SteeringBehaviour


func _ready() -> void:
	super()
	var unit: SwarmUnit = agent as SwarmUnit
	if unit != null:
		unit.count_neighbours = true


func calculate() -> Vector3:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null:
		return Vector3.ZERO

	var force: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if not is_instance_valid(other):
			continue
		var away: Vector3 = unit.global_position - other.global_position
		var distance: float = away.length()
		# Guard the division: two units at the same position give a
		# zero-length vector, and away.normalized() / 0.0 poisons the whole
		# WTPRS sum with infinity or NaN.
		if distance > 0.001:
			force += away.normalized() / distance
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null:
		return
	for other in unit.neighbours:
		if is_instance_valid(other):
			DebugDraw3D.draw_line(
				unit.global_position, other.global_position, Color.ORANGE_RED
			)
```

- [ ] **Step 2: Alignment**

Create `godot/scripts/steering/alignment_behaviour.gd`:

```gdscript
## Match the average heading of nearby neighbours, so the flock moves as one.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/alignment.gd:13-21.
##
## This averages neighbours' HEADINGS (basis.z), not their velocities, which
## has two consequences worth knowing. It is speed-independent: a fast and a
## slow neighbour pointing the same way contribute identically. And it is only
## correct because +Z is forward in this codebase; averaging basis.z under
## Godot's default -Z-forward would align the flock backwards.
##
## DEFECT 3 in Duggan's alignment.gd:17-20 -- his `force` is a member written
## only inside the `neighbors.size() > 0` guard, so a unit that loses all its
## neighbours keeps applying its LAST alignment force indefinitely. A lone unit
## latches on a stale heading forever. Fixed here by returning Vector3.ZERO
## when there are no neighbours, so the behaviour contributes nothing rather
## than something stale.
class_name AlignmentBehaviour
extends SteeringBehaviour


func _ready() -> void:
	super()
	var unit: SwarmUnit = agent as SwarmUnit
	if unit != null:
		unit.count_neighbours = true


func calculate() -> Vector3:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null:
		return Vector3.ZERO

	var valid: int = 0
	var desired: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if is_instance_valid(other):
			desired += other.global_transform.basis.z
			valid += 1

	# The correction to DEFECT 3: no neighbours means no force, not the
	# previous frame's force.
	if valid == 0:
		return Vector3.ZERO

	desired /= float(valid)
	var force: Vector3 = desired - unit.global_transform.basis.z
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null or unit.neighbours.is_empty():
		return
	DebugDraw3D.draw_arrow(
		unit.global_position,
		unit.global_position + unit.global_transform.basis.z * 4.0,
		Color.SPRING_GREEN,
		0.1
	)
```

- [ ] **Step 3: Cohesion**

Create `godot/scripts/steering/cohesion_behaviour.gd`:

```gdscript
## Steer toward the average position of nearby neighbours, so units do not get
## left behind.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/cohesion.gd:14-24.
##
## Cohesion is the cleanest example of a behaviour composed out of seek: the
## whole force is "average the neighbours' positions, then seek that point".
##
## The trailing normalisation matters. Cohesion contributes a UNIT-LENGTH
## direction only, discarding magnitude, so distance sets direction and nothing
## else; relative strength is left entirely to weight in the WTPRS sum.
## Separation deliberately keeps its magnitude, cohesion deliberately discards
## it. That asymmetry is what stops the flock collapsing in on itself.
class_name CohesionBehaviour
extends SteeringBehaviour


func _ready() -> void:
	super()
	var unit: SwarmUnit = agent as SwarmUnit
	if unit != null:
		unit.count_neighbours = true


func calculate() -> Vector3:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null:
		return Vector3.ZERO

	var valid: int = 0
	var centre_of_mass: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if is_instance_valid(other):
			centre_of_mass += other.global_position
			valid += 1

	if valid == 0:
		return Vector3.ZERO

	centre_of_mass /= float(valid)
	var force: Vector3 = seek_towards(centre_of_mass).normalized()
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null or unit.neighbours.is_empty():
		return
	var centre: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if is_instance_valid(other):
			centre += other.global_position
	centre /= float(unit.neighbours.size())
	DebugDraw3D.draw_line(unit.global_position, centre, Color.CORNFLOWER_BLUE)
```

- [ ] **Step 4: Parse check**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/steering/separation_behaviour.gd godot/scripts/steering/alignment_behaviour.gd godot/scripts/steering/cohesion_behaviour.gd
git commit -m "feat(steering): add separation, alignment and cohesion"
```

---

### Task 4: FSM core

**Files:**
- Create: `godot/scripts/states/state.gd`
- Create: `godot/scripts/states/state_machine.gd`

**Interfaces:**
- Consumes: `SwarmUnit`.
- Produces: `State extends Node` with `var machine: StateMachine`, `var unit: SwarmUnit`, `func _enter() -> void`, `func _exit() -> void`, `func _think() -> void`; `StateMachine extends Node` with `@export var initial_state: NodePath`, `@export var global_state: NodePath`, `var current_state: State`, `func change_state(new_state: State) -> void`.

- [ ] **Step 1: The state base**

Create `godot/scripts/states/state.gd`:

```gdscript
## One state a unit can be in. States change no movement code: each simply
## re-weights which steering behaviours are enabled on entry.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/state.gd. The contract
## is his: _enter on arrival, _exit on departure, _think every frame while
## current.
class_name State
extends Node

## The machine running this state.
var machine: StateMachine

## The unit being driven. Convenience for machine.unit, which every state uses.
var unit: SwarmUnit


## Called once when this state becomes current. Set up behaviour weights here.
func _enter() -> void:
	pass


## Called once when leaving. Undo anything _enter turned on.
func _exit() -> void:
	pass


## Called every frame while current. Decide whether to transition.
func _think() -> void:
	pass


## Enable exactly the named behaviours on the unit and disable the rest.
##
## Shared helper because every state's _enter is otherwise the same five lines.
## Matching is by node name, so the scene tree stays the single place that says
## which behaviours a unit has.
func use_only(behaviour_names: Array) -> void:
	if unit == null:
		return
	for behaviour in unit.behaviours:
		behaviour.enabled = behaviour_names.has(behaviour.name)
```

- [ ] **Step 2: The machine**

Create `godot/scripts/states/state_machine.gd`:

```gdscript
## Runs one current state plus an always-on global state for a unit.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/state_machine.gd. The
## two-tier shape is his: current_state._think() runs, then global_state
## ._think(), every frame. The global tier is where swarm-wide intent lives, so
## a unit can be told what the swarm wants while its own state still decides
## what it actually does.
##
## DEFECT 4 in Duggan's state_machine.gd:14-31 -- his change_state() reparents
## the new state onto the boid, but _ready() does NOT do the same for
## initial_state. The first state therefore lives at a different place in the
## tree from every state after it, so anything resolving relative node paths
## behaves differently on the first state than on all the others. Fixed here by
## not reparenting at all: states stay children of the machine for their whole
## life, which is simpler and uniform.
class_name StateMachine
extends Node

## Emitted after a transition, for gizmos and audio to react to.
signal state_changed(from: State, to: State)

## The state to start in. Must be a child of this machine.
@export var initial_state: NodePath

## Optional always-on state, run after the current one every frame.
@export var global_state: NodePath

## The state currently driving the unit.
var current_state: State

## The state run every frame regardless of the current one.
var global: State

## The unit this machine drives.
var unit: SwarmUnit


func _ready() -> void:
	unit = get_parent() as SwarmUnit
	if unit == null:
		push_error("%s must be a child of a SwarmUnit." % name)
		return

	for child in get_children():
		if child is State:
			child.machine = self
			child.unit = unit

	if not initial_state.is_empty():
		current_state = get_node(initial_state) as State
		# Deferred because sibling behaviours may not have run _ready yet, and
		# a state's _enter reaches into unit.behaviours.
		if current_state != null:
			current_state.call_deferred("_enter")

	if not global_state.is_empty():
		global = get_node(global_state) as State
		if global != null:
			global.call_deferred("_enter")


func _process(_delta: float) -> void:
	if current_state != null:
		current_state._think()
	if global != null:
		global._think()


## Leave the current state and enter [param new_state].
##
## Ignores a transition to the state already running, so a _think that fires
## its condition every frame does not restart the state 60 times a second.
func change_state(new_state: State) -> void:
	if new_state == null or new_state == current_state:
		return
	var previous: State = current_state
	if current_state != null:
		current_state._exit()
	current_state = new_state
	current_state._enter()
	state_changed.emit(previous, current_state)


## Find a sibling state by node name. States transition by name rather than by
## instantiating a new object, so each state exists exactly once per unit and
## can hold its own data across visits.
func state_named(state_name: String) -> State:
	return get_node_or_null(NodePath(state_name)) as State
```

- [ ] **Step 3: Parse check**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/states/state.gd godot/scripts/states/state_machine.gd
git commit -m "feat(states): add FSM core with a uniform initial-state fix"
```

---

### Task 5: The threat marker

**Files:**
- Create: `godot/scripts/world/threat.gd`

**Interfaces:**
- Produces: `Threat extends Node3D` with `@export var danger_radius: float`; joins group `"threat"`.

FLEE needs something to flee from, and combat does not exist until Phase 4. A threat marker makes the reflex testable and demonstrable now, and Phase 4's enemy fire simply joins the same group.

- [ ] **Step 1: Write it**

Create `godot/scripts/world/threat.gd`:

```gdscript
## Something units flee from.
##
## Exists so the FLEE reflex is testable and demonstrable before combat is
## built. Phase 4's enemy fire and enemy units join the same "threat" group and
## the reflex works unchanged -- the units never learn what a threat actually
## is, which is what keeps the behaviour general.
class_name Threat
extends Node3D

## Units inside this radius flee. Beyond it the threat costs them nothing.
@export var danger_radius: float = 18.0

@export_group("Debug")

@export var draw_gizmos: bool = true


func _ready() -> void:
	add_to_group("threat")


func _process(_delta: float) -> void:
	if draw_gizmos:
		DebugDraw3D.draw_sphere(global_position, danger_radius, Color.CRIMSON)


## The nearest threat to [param point], or null when none is in range.
##
## Static so callers do not need a reference to any particular threat.
static func nearest_to(tree: SceneTree, point: Vector3) -> Threat:
	var best: Threat = null
	var best_distance: float = INF
	for node in tree.get_nodes_in_group("threat"):
		var threat: Threat = node as Threat
		if threat == null:
			continue
		var distance: float = threat.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = threat
	return best
```

- [ ] **Step 2: Parse check**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/world/threat.gd
git commit -m "feat(world): add a threat marker so the flee reflex is testable"
```

---

### Task 6: The eight unit states

**Files:**
- Create: `godot/scripts/states/unit/launch_state.gd`
- Create: `godot/scripts/states/unit/follow_state.gd`
- Create: `godot/scripts/states/unit/flee_state.gd`
- Create: `godot/scripts/states/unit/harvest_state.gd`
- Create: `godot/scripts/states/unit/deposit_state.gd`
- Create: `godot/scripts/states/unit/engage_state.gd`
- Create: `godot/scripts/states/unit/patrol_state.gd`
- Create: `godot/scripts/states/unit/detonate_state.gd`

**Interfaces:**
- Consumes: `State` (`machine`, `unit`, `use_only()`), `StateMachine.change_state()`, `StateMachine.state_named()`, `Threat.nearest_to()`.
- Produces: eight `State` subclasses named for their files.

FOLLOW is fully implemented. **FLEE carries a `TODO(human)` and MUST NOT be implemented** — Mae writes it. The remaining six are honest stubs that hold formation and document which phase fills them in.

- [ ] **Step 1: FOLLOW, the live state**

Create `godot/scripts/states/unit/follow_state.gd`:

```gdscript
## Hold station near the commander, flocking with the rest of the swarm.
##
## The default state. Steering is the flocking triple plus offset pursue: the
## slot keeps the formation legible, the flocking keeps it from being rigid.
class_name FollowState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	# The flee reflex is checked from every state, so it lives in the global
	# state rather than being repeated here. See SwarmIntentState.
	pass
```

- [ ] **Step 2: FLEE, Mae's**

Create `godot/scripts/states/unit/flee_state.gd`:

```gdscript
## Scatter from a threat, overriding whatever the swarm was told to do.
##
## This is the reflex that makes the swarm read as alive rather than obedient:
## a unit abandons its orders to survive, then rejoins when the danger passes.
## It is reachable from EVERY other state, which is what distinguishes a reflex
## from an ordinary transition.
class_name FleeState
extends State

## How far outside the threat's danger radius the unit must get before it is
## willing to go back to what it was doing. The gap between fleeing and
## returning is deliberate: without it a unit sitting exactly on the boundary
## flips between states every frame.
@export var safe_margin: float = 6.0

## The state to return to once safe.
@export var return_state_name: String = "Follow"


func _enter() -> void:
	use_only(["Flee", "Separation"])


## Decide whether this unit is safe enough to stop fleeing.
##
## Steps:
##   1. Find the nearest threat with Threat.nearest_to(get_tree(),
##      unit.global_position). It returns null when no threat exists.
##   2. If there is no threat at all, the unit is safe: transition back.
##   3. Otherwise measure the distance from the unit to that threat.
##   4. The unit is safe once that distance exceeds the threat's own
##      danger_radius PLUS safe_margin. The margin is the hysteresis: entering
##      flee uses danger_radius alone, leaving it needs danger_radius plus the
##      margin, so the two thresholds cannot chatter against each other.
##   5. To transition, ask the machine for the state by name and change to it:
##      machine.change_state(machine.state_named(return_state_name))
##      change_state ignores a transition to the state already running, so
##      calling it repeatedly is harmless.
func _think() -> void:
	# TODO(human): implement the safe-to-return check per the steps above.
	pass
```

- [ ] **Step 3: The six stubs**

Each stub holds formation and names the phase that fills it in. Create each file with exactly this shape, substituting the class name, the doc comment, and the phase note.

`godot/scripts/states/unit/launch_state.gd`:

```gdscript
## Freshly grown by the factory, flying out to join the swarm.
##
## Phase 3 fills this in: seek the commander, then transition to Follow on
## arrival. For now it behaves as Follow does, so a unit placed in the scene
## still holds station.
class_name LaunchState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
```

`godot/scripts/states/unit/harvest_state.gd`:

```gdscript
## Scraping a caustic asteroid for alloy, taking corrosion damage while it
## works.
##
## Phase 3 fills this in: arrive at the asteroid, drain alloy, take damage,
## then transition to Deposit when full or Flee when hurt.
class_name HarvestState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
```

`godot/scripts/states/unit/deposit_state.gd`:

```gdscript
## Carrying alloy back to the commander to add it to the faction's pool.
##
## Phase 3 fills this in: arrive at the ship, transfer the carried alloy, then
## return to Harvest or Follow.
class_name DepositState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
```

`godot/scripts/states/unit/engage_state.gd`:

```gdscript
## Hunting a designated target.
##
## Phase 4 fills this in: pursue the target with lead, keeping separation from
## the rest of the swarm, then transition to Detonate within strike distance.
class_name EngageState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
```

`godot/scripts/states/unit/patrol_state.gd`:

```gdscript
## Circling a designated point, watching for enemies.
##
## Phase 4 fills this in: follow a path around the designated point while the
## flocking triple keeps the group coherent.
class_name PatrolState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
```

`godot/scripts/states/unit/detonate_state.gd`:

```gdscript
## Terminal state: trigger the blast and leave the flock.
##
## Phase 4 fills this in: apply blast damage, emit the effect, then remove the
## unit. Its neighbours re-query the grid and re-cohere on the next frame,
## which is the whole of the "leave" case in the emergent-membership model.
class_name DetonateState
extends State


func _enter() -> void:
	use_only([])


func _think() -> void:
	pass
```

- [ ] **Step 4: The global intent state**

Create `godot/scripts/states/unit/swarm_intent_state.gd`. This runs every frame alongside whatever the unit is doing, and owns the flee reflex so it does not have to be repeated in all eight states:

```gdscript
## The always-on tier: swarm intent, and the reflex that overrides it.
##
## Runs after the current state every frame. Duggan's FireAtTargetGlobalState
## is the same shape -- a concern that applies in every state, kept in one
## place rather than copied into all of them.
##
## Putting the flee check here is what makes FLEE a genuine reflex: it is
## reachable from every state without any state knowing about it.
class_name SwarmIntentState
extends State

## The state to enter when a threat is in range.
@export var flee_state_name: String = "Flee"


func _think() -> void:
	if unit == null or machine == null:
		return
	if machine.current_state != null and machine.current_state.name == flee_state_name:
		return

	var threat: Threat = Threat.nearest_to(get_tree(), unit.global_position)
	if threat == null:
		return
	var distance: float = threat.global_position.distance_to(unit.global_position)
	if distance <= threat.danger_radius:
		machine.change_state(machine.state_named(flee_state_name))
```

- [ ] **Step 5: Parse check**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

- [ ] **Step 6: Confirm exactly one TODO(human)**

Run: `grep -rc "TODO(human)" godot/scripts/states/unit/flee_state.gd`
Expected: `1`

Run: `grep -rl "TODO(human)" godot/scripts/ | grep -v flee_state`
Expected: no output — no other file carries one.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/states/unit/
git commit -m "feat(states): add the unit state skeleton with a global flee reflex"
```

---

### Task 7: A flee behaviour

**Files:**
- Create: `godot/scripts/steering/flee_behaviour.gd`

**Interfaces:**
- Consumes: `SteeringBehaviour`, `Threat.nearest_to()`.
- Produces: `FleeBehaviour` with `@export var flee_range: float`.

- [ ] **Step 1: Write it**

Create `godot/scripts/steering/flee_behaviour.gd`:

```gdscript
## Steer directly away from the nearest threat.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/Flee.gd:19-24.
##
## The force is velocity - desired, the opposite sign to seek's
## desired - velocity. Range-gating it means a distant threat costs nothing,
## so this behaviour can sit enabled on a unit without dragging on the WTPRS
## budget when nothing is chasing it.
class_name FleeBehaviour
extends SteeringBehaviour

## Beyond this distance the behaviour contributes nothing.
@export var flee_range: float = 30.0


func calculate() -> Vector3:
	var threat: Threat = Threat.nearest_to(get_tree(), agent.global_position)
	if threat == null:
		return Vector3.ZERO

	var to_threat: Vector3 = threat.global_position - agent.global_position
	if to_threat.length() >= flee_range:
		return Vector3.ZERO

	var desired: Vector3 = to_threat.normalized() * agent.max_speed
	var force: Vector3 = agent.velocity - desired
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var threat: Threat = Threat.nearest_to(get_tree(), agent.global_position)
	if threat != null:
		DebugDraw3D.draw_line(
			agent.global_position, threat.global_position, Color.CRIMSON
		)
```

- [ ] **Step 2: Parse check and commit**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

```bash
git add godot/scripts/steering/flee_behaviour.gd
git commit -m "feat(steering): add a range-gated flee behaviour"
```

---

### Task 8: Assemble and verify

**Files:**
- Modify: `godot/scenes/units/swarm_unit.tscn`
- Modify: `godot/scenes/main.tscn`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Extend the unit scene**

`godot/scenes/units/swarm_unit.tscn` currently has `Hull`, `CollisionShape3D` and `OffsetPursue`. Add, as direct children of the `SwarmUnit` root:

```
Separation   (SeparationBehaviour, weight 20.0)
Alignment    (AlignmentBehaviour,  weight 20.0)
Cohesion     (CohesionBehaviour,   weight 8.0)
Flee         (FleeBehaviour,       weight 40.0)
StateMachine (StateMachine)
├── Follow      (FollowState)
├── Flee        (FleeState)
├── Launch      (LaunchState)
├── Harvest       (HarvestState)
├── Deposit     (DepositState)
├── Engage      (EngageState)
├── Patrol      (PatrolState)
├── Detonate    (DetonateState)
└── SwarmIntent (SwarmIntentState)
```

Set `StateMachine.initial_state` to `NodePath("Follow")` and `StateMachine.global_state` to `NodePath("SwarmIntent")`.

**Behaviour node order is priority order.** WTPRS walks children in order and breaks once the force budget is spent, so `Flee` must come BEFORE the flocking behaviours for the reflex to win when it fires. Order the behaviour children: `Flee`, `Separation`, `Alignment`, `Cohesion`, `OffsetPursue`.

Weights follow Duggan's own scenes, where alignment is heaviest and cohesion lightest because cohesion is already normalised (`Fish1.tscn`: separation 10, alignment 20, cohesion 8).

Note the node named `Flee` appears twice at different levels — once as a behaviour child of the unit, once as a state child of the machine. That is intentional and unambiguous: `use_only()` matches behaviour names, `state_named()` resolves states relative to the machine.

- [ ] **Step 2: Add the Swarm and a Threat to main.tscn**

Add as direct children of `Main`:

```
PlayerSwarm (Node, Swarm)  allegiance 0, neighbour_distance 20, cell_size 20, max_neighbours 10
Threat      (Node3D, Threat) danger_radius 18, positioned at (0, 0, -40)
```

Then set every `SwarmUnit` instance's `swarm` export to the `PlayerSwarm` node.

**Do NOT author this as an instance override inside main.tscn.** The editor prunes those. Assign `swarm` on the unit instances the same way the previous phase resolved `leader`: if an override will not survive, add a runtime fallback in `SwarmUnit._ready()` that finds the swarm by group instead. Prefer the group fallback: have `Swarm._ready()` call `add_to_group("swarm_" + str(allegiance))`, and have `SwarmUnit._ready()` resolve `swarm` from that group when the export is null. That is also what Phase 3's spawned units will need.

- [ ] **Step 3: Verify parse and run**

Run: `godot --headless --path godot --editor --quit-after 2 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

Run: `timeout 60 godot --headless --path godot --quit-after 300 2>&1 | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: empty.

- [ ] **Step 4: Behavioural verification**

Write a throwaway GDScript, run it with `godot --headless --path godot --script res://<name>.gd`, and delete it before committing. It must load `res://scenes/main.tscn`, add it to the scene tree, step physics frames, and print:

1. That every unit resolved a non-null `swarm`.
2. Each unit's neighbour count after a few frames. With five units within 20 units of each other, each should see the other four.
3. That `neighbours_of()` returns them nearest-first: print the distances and confirm they ascend.
4. Each unit's `machine.current_state.name` — all should be `Follow`.
5. Then move the `Threat` to the swarm's centre, step more frames, and print each unit's `current_state.name` again. **Expect all five to remain `Follow`,** because `FleeState._think()` is Mae's unimplemented stub and cannot transition back — but the transition INTO Flee is the global state's job and should fire. Report exactly what happened; do not adjust the code to make a nicer result.

Paste the full output in the report.

- [ ] **Step 5: Commit**

```bash
git add godot/scenes/units/swarm_unit.tscn godot/scenes/main.tscn
git commit -m "feat(scenes): wire flocking, the state machine and a threat marker"
```

---

## What Phase 2 deliberately leaves out

- **Unit death has no trigger.** `take_damage()` and `died` exist and deregister correctly, but nothing calls them until asteroid corrosion (Phase 3) and combat (Phase 4).
- **Six states are stubs.** Named so, with the phase that fills each one.
- **Swarm intent is not yet broadcast.** `SwarmIntentState` owns the flee reflex only; `SwarmCoordinator` and the HARVEST/ATTACK/RECALL/PATROL intents arrive in Phase 3.
- **One faction.** The enemy `Swarm` is instantiated from the same class in Phase 4.
