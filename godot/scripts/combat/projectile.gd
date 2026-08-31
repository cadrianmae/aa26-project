## A single shot: travels forward, damages the first enemy it reaches, dies.
##
## Deliberately not a physics body. Combat here is dozens of small fast shots
## between agents that are already doing steering every frame, and adding that
## many rigid bodies would cost more than the game can spare at forty drones a
## side. Instead each shot steps forward and tests distance against the units
## it could plausibly hit -- which for a game with a swarm register is a short
## list, not a broad-phase query.
##
## Frees itself on hit or on timeout. A shot that missed and flew on forever
## would accumulate until the frame budget went with it.
class_name Projectile
extends Node3D

## Emitted when the shot connects, before it frees itself.
signal hit(target: Node3D, amount: float)

## Which side fired this. A shot never damages its own side, so a swarm firing
## through itself is harmless rather than a friendly-fire disaster the player
## cannot avoid.
@export var allegiance: int = 0

## Damage dealt on contact.
@export var damage: float = 8.0

## Units per second.
@export var speed: float = 180.0

## Seconds before the shot gives up and frees itself.
@export var lifetime: float = 2.5

## How close counts as a hit. Generous, because the shot moves far in one
## frame: at 90 units per second a 60 Hz frame is 1.5 units, so a tight radius
## would let shots tunnel straight through a drone between frames.
@export var hit_radius: float = 2.2

## Core colour of the bolt: orange-red, the hottest part of the shot.
@export var core_colour: Color = Color(1.0, 0.30, 0.10)

## The caustic green the bolt glows with.
##
## The two colours do different jobs. Green is the emission, so it blooms
## OUTWARD past the geometry and is what carries the shot at 640x360 against a
## near-black belt. Orange-red is the albedo, so it stays tight in the middle
## -- and it only reads as heat because there is green around it.
@export var glow_colour: Color = Color(0.42, 1.0, 0.22)

## How hard the bolt blooms. The scene Environment has glow enabled, so an
## emission above 1.0 spills light past the geometry and a shot two pixels wide
## still reads as a bolt rather than a dot.
@export var glow_energy: float = 4.0

var _age: float = 0.0

## The ribbon left behind the bolt.
var _trail: TrailRibbon


## Replace the hull's lit material with a self-lit one.
##
## The hull shader modulates by the angle to the sun, which is right for a
## ship and wrong for a bolt: a projectile spinning past the camera would
## flicker as its facets turned. A shot emits its own light, so it should not
## be lit at all.
##
## Runs in _ready on the parent, which Godot calls AFTER its children, so this
## reliably overwrites the material Hull assigns to itself.
func _ready() -> void:
	var hull: MeshInstance3D = get_node_or_null("Hull") as MeshInstance3D
	if hull == null:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = core_colour
	material.emission_enabled = true
	material.emission = glow_colour
	material.emission_energy_multiplier = glow_energy
	# Drawn over the belt rather than depth-sorted against it: a bolt passing
	# behind a rock should still be visible as tracer fire.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = material

	_build_trail()
	_build_glow()


## A tight ribbon behind the bolt.
##
## Narrower and much shorter than a Thruster's. An engine exhaust should
## billow; a bolt is a few pixels wide at 640x360, and a wide ribbon would
## swallow the shot inside its own trail. Few points and a thin width keeps it
## a line the eye can follow back to whoever fired.
func _build_trail() -> void:
	_trail = TrailRibbon.new()
	_trail.name = "Trail"
	_trail.points = 10
	_trail.width = 0.16
	_trail.minimum_step = 0.6
	_trail.head_colour = core_colour
	_trail.tail_colour = Color(glow_colour.r, glow_colour.g, glow_colour.b, 0.0)
	add_child(_trail)


## A small light travelling with the bolt, so it lights what it passes.
func _build_glow() -> void:
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = core_colour
	light.light_energy = 2.0
	# Small. A wide light on a fast-moving shot sweeps the whole belt and
	# reads as the scene flickering rather than as a bolt going past.
	light.omni_range = 5.0
	add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# +Z is forward in this codebase, following Duggan. Vector3.FORWARD is -Z
	# and would send every shot out of the back of the ship that fired it.
	var step: Vector3 = global_transform.basis.z.normalized() * speed * delta
	global_position += step

	if _trail != null:
		_trail.advance(global_position, true)

	var target: Node3D = _first_hit()
	if target == null:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage)
	hit.emit(target, damage)
	queue_free()


## The nearest enemy within [member hit_radius], or null.
##
## Checks the swarm registers and the commander groups rather than the whole
## tree: those are the only things that can be shot, and both are already
## maintained for other reasons.
func _first_hit() -> Node3D:
	var closest: Node3D = null
	var closest_distance: float = hit_radius

	for side in [0, 1]:
		if side == allegiance:
			continue

		for node in get_tree().get_nodes_in_group("swarm_" + str(side)):
			var swarm: Swarm = node as Swarm
			if swarm == null:
				continue
			for drone in swarm.units:
				if drone == null:
					continue
				var distance: float = global_position.distance_to(drone.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest = drone

		for node in get_tree().get_nodes_in_group("commander_" + str(side)):
			var ship: Node3D = node as Node3D
			if ship == null:
				continue
			# A capital ship is far larger than a drone, so it needs a bigger
			# catch radius or shots pass visibly through the hull.
			var distance: float = global_position.distance_to(ship.global_position)
			if distance < maxf(closest_distance, hit_radius * 4.0):
				closest_distance = distance
				closest = ship

	return closest
