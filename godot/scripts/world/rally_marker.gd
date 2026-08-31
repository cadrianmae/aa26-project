## The place a swarm has been told to gather, as a node in the world.
##
## The rally point is a [Vector3] on the [Swarm], so why does a node exist for
## it? Two reasons, and both are about reuse rather than data.
##
## [ArriveBehaviour] steers at a [Node3D], not a coordinate. Giving the point a
## node means RALLY reuses the existing behaviour unchanged instead of needing
## a near-duplicate that reads a vector -- the same reason Duggan's behaviours
## all target nodes.
##
## And a node can be seen. The marker draws itself, so during a demo the order
## is visible on screen: the player presses a key, a ring appears, and fifty
## units converge on it. An intent that only exists as a number in a variable
## is invisible in a recording.
class_name RallyMarker
extends Node3D

## Group naming convention, matching Swarm's own "swarm_<allegiance>" groups.
## One marker per side, so the enemy hatchery can rally independently.
const GROUP_PREFIX: String = "rally_marker_"

## Which side this marker belongs to.
@export var allegiance: int = 0

## Radius of the ring, in world units.
@export var gizmo_radius: float = 4.0

## Colour of the ring.
@export var gizmo_colour: Color = Color(0.4, 1.0, 0.6)

## How fast the ring turns, in radians per second. Rotation is what separates
## a placed order from scenery: a static ring on an asteroid field reads as
## part of the terrain, a turning one reads as an instrument.
@export var spin_speed: float = 0.6

## How far the ring pulses either side of its radius, as a fraction. Small on
## purpose -- enough to catch the eye at the edge of the screen, not enough to
## misreport where the swarm is actually going.
@export_range(0.0, 0.5) var pulse_amount: float = 0.06

## Pulses per second.
@export var pulse_speed: float = 1.5

## Whether the marker is currently showing an active order.
var active: bool = false

## The ring itself. Real geometry rather than a DebugDraw3D call, because
## DebugDraw3D output disappears with the rest of the gizmos on F1 -- and the
## marker is the one thing a clean screenshot most needs to show. A debug
## overlay is for the developer; this is for the player.
var _ring: MeshInstance3D

## Seconds since the marker was placed, driving the spin and the pulse.
var _age: float = 0.0


func _ready() -> void:
	add_to_group(GROUP_PREFIX + str(allegiance))
	_build_ring()
	_ring.visible = false


## Build the ring mesh and its material.
##
## An eight-segment torus, matching the octagonal geometry of the ships: at
## this segment count the ring reads as a faceted ring rather than a smooth
## one, which is the Frontier look and costs nothing to ask for.
##
## Unshaded, because the ring is an instrument rather than an object in the
## world. A lit ring would go dark when it faced away from the light, which
## for a marker means "disappears at exactly the angle you needed it".
func _build_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = gizmo_radius * 0.92
	torus.outer_radius = gizmo_radius
	torus.rings = 8
	torus.ring_segments = 4

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = gizmo_colour
	# Drawn through whatever is in front of it. A marker the player cannot see
	# because an asteroid is in the way has failed at the only thing it does.
	material.no_depth_test = true
	material.render_priority = 1

	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.material_override = material
	# TorusMesh is built lying in the XZ plane already, which is the movement
	# plane, so the ring reads as sitting ON the battlefield rather than
	# standing up out of it.
	add_child(_ring)


## Find the marker belonging to [param allegiance], or null if none exists.
##
## Static so callers reach it without holding a reference, which is what lets
## a unit spawned at run time find the marker with no wiring.
static func for_swarm(tree: SceneTree, allegiance_id: int) -> RallyMarker:
	var found: Array = tree.get_nodes_in_group(GROUP_PREFIX + str(allegiance_id))
	if found.is_empty():
		return null
	return found[0] as RallyMarker


## Place the marker and show it.
##
## Resets [member _age] so every new order restarts the pulse. Re-issuing a
## rally then reads as a fresh command rather than as the ring quietly sliding
## to a new position mid-cycle.
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
	# The perception radius stays a gizmo: it is a developer's readout, not
	# part of the game's presentation, so it belongs behind F1 with the rest.
	if OS.is_debug_build():
		DebugDraw3D.draw_sphere(global_position, gizmo_radius, gizmo_colour)
