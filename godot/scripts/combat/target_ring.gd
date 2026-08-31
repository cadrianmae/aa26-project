## A ring drawn in the world around whatever the player has targeted.
##
## The HUD panel says WHAT is targeted; this says WHERE. Without it the player
## has to infer the selection from a schematic in the corner, which is exactly
## the kind of indirection that makes a target lock feel unreliable.
##
## A real mesh rather than a debug draw. The gizmo layer is off by default and
## is meant to be switched off for recordings, and a target lock is part of the
## game rather than part of its instrumentation -- it has to survive with the
## gizmos hidden.
##
## Unshaded and always-on-top so it reads at 640x360 against a dark belt, where
## a lit ring would disappear whenever the sun was behind it.
class_name TargetRing
extends MeshInstance3D

## Ring size for each kind of contact, in world units.
##
## A swarm's ring is much larger because it encircles a whole flock rather
## than an object -- and being visibly bigger than any ship is what tells the
## player at a glance that they have locked a cloud, not a hull.
@export var ship_radius: float = 9.0
@export var barnacle_radius: float = 6.0
@export var swarm_radius: float = 18.0

## Turns per second. Slow: motion is what separates a live lock from painted
## scenery, but a fast spin reads as an alarm.
@export var spin_speed: float = 0.35

## How far the ring pulses either side of its radius, as a fraction.
@export_range(0.0, 0.5) var pulse_depth: float = 0.06

## Pulses per second.
@export var pulse_hz: float = 1.1

@export var player_colour: Color = Color(0.435, 0.812, 0.353)
@export var rival_colour: Color = Color(0.851, 0.643, 0.255)
@export var barnacle_colour: Color = Color(0.62, 0.82, 0.23)

var _targeting: Targeting
var _material: StandardMaterial3D
var _torus: TorusMesh
var _age: float = 0.0


func _ready() -> void:
	# World space, not the ship's: the ring sits on the target, and inheriting
	# the ship's transform would drag it around as the player turned.
	top_level = true

	_torus = TorusMesh.new()
	_torus.rings = 24
	_torus.ring_segments = 6
	mesh = _torus

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Drawn over everything: a lock the player cannot see because a rock is in
	# the way is worse than no lock at all.
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
	# Breathing, so a stationary lock on a stationary rock still looks live.
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
