## The place a swarm has been told to gather, as a node in the world.
class_name RallyMarker
extends Node3D

## Group naming convention, matching Swarm's "swarm_<allegiance>" groups.
const GROUP_PREFIX: String = "rally_marker_"

## Which side this marker belongs to.
@export var allegiance: int = 0

## Radius of the ring, in world units.
@export var gizmo_radius: float = 4.0

## Colour of the ring.
@export var gizmo_colour: Color = Color(0.4, 1.0, 0.6)

## How fast the ring turns, in radians per second.
@export var spin_speed: float = 0.6

## How far the ring pulses either side of its radius, as a fraction.
@export_range(0.0, 0.5) var pulse_amount: float = 0.06

## Pulses per second.
@export var pulse_speed: float = 1.5

## Whether the marker is currently showing an active order.
var active: bool = false

## The ring itself.
var _ring: MeshInstance3D

## Seconds since the marker was placed, driving the spin and the pulse.
var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP_PREFIX + str(allegiance))
	_build_ring()
	_ring.visible = false


## Build the ring mesh and its material.
func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = gizmo_radius * 0.92
	torus.outer_radius = gizmo_radius
	torus.rings = 8
	torus.ring_segments = 4

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = gizmo_colour
	# Drawn through whatever is in front of it.
	material.no_depth_test = true
	material.render_priority = 1

	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.material_override = material
	# TorusMesh already lies in the XZ plane, which is the movement plane.
	add_child(_ring)


## Find the marker belonging to [param allegiance], or null if none exists.
static func for_swarm(tree: SceneTree, allegiance_id: int) -> RallyMarker:
	var found: Array = tree.get_nodes_in_group(GROUP_PREFIX + str(allegiance_id))
	if found.is_empty():
		return null
	return found[0] as RallyMarker


## Place the marker and show it.
##
## Resets [member _age], so a re-issued rally restarts the pulse.
func place_at(point: Vector3) -> void:
	global_position = point
	active = true
	_age = 0.0
	if _ring != null:
		_ring.visible = true


func _process(delta: float) -> void:
	if not active or _ring == null:
		return
	_age += delta
	_ring.rotate_y(spin_speed * delta)
	var pulse: float = 1.0 + sin(_age * pulse_speed * TAU) * pulse_amount
	_ring.scale = Vector3.ONE * pulse
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(global_position, gizmo_radius, gizmo_colour)
