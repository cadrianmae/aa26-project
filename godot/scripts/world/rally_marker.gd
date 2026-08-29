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
## One marker per side, so the enemy hive can rally independently.
const GROUP_PREFIX: String = "rally_marker_"

## Which side this marker belongs to.
@export var allegiance: int = 0

## Radius of the drawn ring, in world units.
@export var gizmo_radius: float = 4.0

## Colour of the drawn ring.
@export var gizmo_colour: Color = Color(0.4, 1.0, 0.6)

## Whether the marker is currently showing an active order.
var active: bool = false


func _ready() -> void:
	add_to_group(GROUP_PREFIX + str(allegiance))


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
func place_at(point: Vector3) -> void:
	global_position = point
	active = true


func _process(_delta: float) -> void:
	if not active:
		return
	DebugDraw3D.draw_sphere(global_position, gizmo_radius, gizmo_colour)
