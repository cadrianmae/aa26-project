## Freshly built by the factory, flying out to join the swarm.
##
## A new drone appears beside the hatchery, which is usually nowhere near the rest
## of the swarm. Dropping it straight into Follow makes it cross the map at
## full speed with cohesion yanking at it, and it arrives sideways. This gives
## it a moment to clear the hatchery under seek alone, then hands it over.
##
## Brief on purpose. It exists to stop new units looking wrong for their first
## second, not to be a behaviour the player ever thinks about.
class_name LaunchState
extends State

## Where to go once clear of the hatchery. Follow rather than the swarm's standing
## order: the global intent state re-asserts the real order on the next frame
## anyway, so this only has to be somewhere sane to land.
@export var next_state_name: String = "Follow"

## How far from the hatchery counts as clear.
@export var clear_distance: float = 22.0

## Seconds after which it joins regardless. A drone whose hatchery is destroyed
## mid-launch has nothing to measure distance from, and without this it would
## sit in Launch forever.
@export var timeout_seconds: float = 4.0

## Only separation and the formation pull: a new unit should spread away from
## the others leaving the hatchery at the same moment, but not yet try to hold a
## slot it is far too distant to reach.
const ACTIVE_BEHAVIOURS: Array = ["OffsetPursue", "Separation"]

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
