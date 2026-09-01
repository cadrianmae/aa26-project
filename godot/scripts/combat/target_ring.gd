## An unshaded, always-on-top torus drawn at the player's current target.
## Sized and tinted by [member Targeting.kind]; hidden when nothing is locked.
class_name TargetRing
extends MeshInstance3D

## Ring size for each kind of contact, in world units.
@export var ship_radius: float = 9.0
@export var barnacle_radius: float = 6.0
@export var swarm_radius: float = 18.0

## Turns per second.
@export var spin_speed: float = 0.35

## How far the ring pulses either side of its radius, as a fraction.
@export_range(0.0, 0.5) var pulse_depth: float = 0.06

## Pulses per second.
@export var pulse_hz: float = 1.1

@export var rival_colour: Color = Palette.RIVAL
@export var barnacle_colour: Color = Palette.BARNACLE

var _targeting: Targeting
var _material: StandardMaterial3D
var _torus: TorusMesh
var _age: float = 0.0


func _ready() -> void:
	# top_level so the ring holds a world position, not the ship's.
	top_level = true

	_torus = TorusMesh.new()
	_torus.rings = 24
	_torus.ring_segments = 6
	mesh = _torus

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Drawn over the world geometry rather than depth-sorted against it.
	_material.no_depth_test = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _material

	visible = false


func _process(delta: float) -> void:
	if _targeting == null:
		var ship: Ship = get_parent() as Ship
		if ship == null or ship.allegiance != 0:
			set_process(false)
			return
		_targeting = ship.get_node_or_null("Targeting") as Targeting
		if _targeting == null:
			set_process(false)
			return

	var target: Node3D = _targeting.current
	if target == null or not is_instance_valid(target):
		visible = false
		return

	visible = true
	_age += delta

	var radius: float = _radius_for(_targeting.kind)
	radius *= 1.0 + sin(_age * TAU * pulse_hz) * pulse_depth

	_torus.inner_radius = radius - 0.35
	_torus.outer_radius = radius

	global_position = target.global_position
	# Flat on the movement plane, then spun about the vertical.
	global_rotation = Vector3(0.0, _age * TAU * spin_speed, 0.0)

	var tint: Color = _colour_for(_targeting.kind)
	_material.albedo_color = tint
	_material.emission_enabled = true
	_material.emission = tint
	_material.emission_energy_multiplier = 1.6


func _radius_for(kind: Targeting.Kind) -> float:
	match kind:
		Targeting.Kind.SWARM:
			return swarm_radius
		Targeting.Kind.BARNACLE:
			return barnacle_radius
	return ship_radius


func _colour_for(kind: Targeting.Kind) -> Color:
	match kind:
		Targeting.Kind.BARNACLE:
			return barnacle_colour
		Targeting.Kind.SWARM:
			return rival_colour
	return rival_colour
