## Freshly built by the factory, flying out to join the swarm.
##
## Gives a new drone a moment to clear the hatchery, then hands it to
## [member next_state_name].
class_name LaunchState
extends State

## Where to go once clear of the hatchery.
@export var next_state_name: String = "Follow"

## How far from the hatchery counts as clear.
@export var clear_distance: float = 22.0

## Seconds after which it joins regardless. A drone whose hatchery is destroyed
## mid-launch has nothing to measure distance from, and without this it would
## sit in Launch forever.
@export var timeout_seconds: float = 4.0

## Behaviours this state runs.
const ACTIVE_BEHAVIOURS: Array = ["Avoid", "OffsetPursue", "Separation", "Alignment"]

var _hatchery: Hatchery
var _age: float = 0.0


func _enter() -> void:
	_age = 0.0
	_hatchery = Hatchery.for_allegiance(get_tree(), unit.allegiance)
	use_only(ACTIVE_BEHAVIOURS)


func _think() -> void:
	if unit == null or machine == null:
		return

	_age += get_process_delta_time()

	var clear: bool = (
		_hatchery == null
		or unit.global_position.distance_to(_hatchery.global_position) >= clear_distance
	)
	if not clear and _age < timeout_seconds:
		return

	var next: State = machine.state_named(next_state_name)
	if next != null:
		machine.change_state(next)
