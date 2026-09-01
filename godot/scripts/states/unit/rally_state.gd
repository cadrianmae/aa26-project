## Move to the swarm's rally point and hold there.
##
class_name RallyState
extends State

## Name of the ArriveBehaviour node on the unit that this state drives.
@export var arrive_behaviour_name: String = "Arrive"

## The behaviours this state runs.
const ACTIVE_BEHAVIOURS: Array = ["Avoid", "Arrive", "Separation", "Alignment"]


func _enter() -> void:
	_point_arrive_at_marker()
	use_only(ACTIVE_BEHAVIOURS)


## Aim the unit's ArriveBehaviour at the rally marker.
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
