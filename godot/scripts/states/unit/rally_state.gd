## Move to the swarm's rally point and hold there.
##
## The first order that is genuinely disobeyable. A unit told to rally still
## separates from its neighbours, so fifty units sent to one point spread into
## a cloud around it rather than stacking on a single coordinate -- the order
## says where, the steering works out how, and the result is a formation nobody
## specified.
##
## Arrive rather than seek: seek runs at full speed until it overshoots, then
## turns around and overshoots again, so the swarm oscillates around the point
## forever. Arrive brakes inside the slowing radius and settles.
class_name RallyState
extends State

## Name of the ArriveBehaviour node on the unit that this state drives.
@export var arrive_behaviour_name: String = "Arrive"

## The behaviours this state runs. Arrive supplies the order; the flocking pair
## keeps the swarm from collapsing into one point on arrival.
const ACTIVE_BEHAVIOURS: Array = ["Arrive", "Separation", "Alignment"]


func _enter() -> void:
	_point_arrive_at_marker()
	use_only(ACTIVE_BEHAVIOURS)


## Aim the unit's ArriveBehaviour at the rally marker.
##
## The marker is found through a group rather than an exported NodePath. The
## Godot editor has twice pruned instance-override properties from this
## project's scenes, silently unwiring every unit; a group lookup cannot be
## pruned that way because nothing about it lives in the unit's scene.
func _point_arrive_at_marker() -> void:
	if unit == null:
		return
	var arrive: ArriveBehaviour = unit.get_node_or_null(
		NodePath(arrive_behaviour_name)
	) as ArriveBehaviour
	if arrive == null:
		push_error(
			"%s: no ArriveBehaviour named '%s' on %s."
			% [name, arrive_behaviour_name, unit.name]
		)
		return
	arrive.target = RallyMarker.for_swarm(get_tree(), unit.allegiance)
