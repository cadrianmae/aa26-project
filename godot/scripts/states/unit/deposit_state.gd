## Carry a full load of Meta-Alloys home and hand them to the hatchery.
##
class_name DepositState
extends State

## The ArriveBehaviour this state points at the hatchery.
@export var arrive_behaviour_name: String = "ArriveHive"

## Where to go once the load is handed over.
@export var next_state_name: String = "Harvest"

## Meta-Alloys handed over per second.
@export var transfer_rate: float = 6.0

## Behaviours this state runs.
const ACTIVE_BEHAVIOURS: Array = ["Avoid", "ArriveHive", "Separation", "Alignment"]

var _hatchery: Hatchery


func _enter() -> void:
	_hatchery = Hatchery.for_allegiance(get_tree(), unit.allegiance)
	_point_arrive_at_hatchery()
	use_only(ACTIVE_BEHAVIOURS)


## Aim the unit's ArriveBehaviour at its own hatchery.
func _point_arrive_at_hatchery() -> void:
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
	arrive.target = _hatchery


func _think() -> void:
	if unit == null or machine == null:
		return

	# A drone that arrives carrying nothing has nothing to do here: this
	# happens after a flee interrupts a delivery.
	if unit.payload <= 0.0:
		_leave()
		return

	if _hatchery == null:
		_hatchery = Hatchery.for_allegiance(get_tree(), unit.allegiance)
		if _hatchery == null:
			return
		_point_arrive_at_hatchery()

	if not _hatchery.can_deposit_from(unit.global_position):
		return

	var slice: float = minf(
		transfer_rate * get_process_delta_time(), unit.payload
	)
	unit.payload -= slice
	_hatchery.deposit(slice)

	if unit.payload <= 0.0:
		unit.payload = 0.0
		_leave()


## Move on to the next state, if it exists.
func _leave() -> void:
	var next: State = machine.state_named(next_state_name)
	if next == null:
		return
	machine.change_state(next)
