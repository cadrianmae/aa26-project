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
	var arrive: ArriveBehaviour = behaviour_named(
		arrive_behaviour_name
	) as ArriveBehaviour
	if arrive != null:
		arrive.target = RallyMarker.for_swarm(get_tree(), unit.allegiance)
