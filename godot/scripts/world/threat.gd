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
