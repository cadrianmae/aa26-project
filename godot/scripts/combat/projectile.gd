## A single shot: travels forward, damages the first enemy it reaches, dies.
##
## Frees itself on hit or on timeout.
class_name Projectile
extends Node3D

## Emitted when the shot connects, before it frees itself.
signal hit(target: Node3D, amount: float)

## Which side fired this; a shot never damages its own side.
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

## The caustic green the bolt glows with: the emission, not the albedo.
@export var glow_colour: Color = Color(0.42, 1.0, 0.22)

## Emission multiplier. Needs glow enabled on the scene Environment.
@export var glow_energy: float = 4.0

var _age: float = 0.0

## The ribbon left behind the bolt.
var _trail: TrailRibbon


## Replace the hull's lit material with a self-lit one.
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
	# Drawn over the belt rather than depth-sorted against it.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = material

	_build_trail()
	_build_glow()


## A tight ribbon behind the bolt.
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
func _first_hit() -> Node3D:
	var closest: Node3D = null
	var closest_distance: float = hit_radius

	for side in [0, 1]:
		if side == allegiance:
			continue

		for node in get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(side)):
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

		for node in get_tree().get_nodes_in_group(Ship.GROUP_PREFIX + str(side)):
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
