## Carry a full load of Meta-Alloys home and hand them to the hatchery.
##
## The return half of the economy. Built and tested BEFORE harvesting, by
## handing a drone a payload directly: otherwise neither half can be seen
## working until both are, and a fault in one looks exactly like a fault in
## the other.
##
## Arrive rather than seek, for the same reason [RallyState] uses it -- seek
## runs at full speed until it overshoots, turns round, and overshoots again,
## so a drone would orbit its own hatchery forever instead of settling.
class_name DepositState
extends State

## The ArriveBehaviour this state points at the hatchery.
@export var arrive_behaviour_name: String = "ArriveHive"

## Where to go once the load is handed over. Back out to work, not home to
## the commander: a drone that deposited and then idled would need the player
## to re-issue the harvest order after every single trip.
@export var next_state_name: String = "Harvest"

## Meta-Alloys handed over per second.
##
## A transfer, not an instant. Dumping the whole load the moment a drone
## crossed the radius made delivery invisible: the drone arrived and turned
## round in the same frame. At 6/s a full 10-unit load takes a second and a
## half, so the drone visibly holds station off the Matriarch's tail while it
## unloads -- which is what makes the supply line read as a supply line.
@export var transfer_rate: float = 6.0

## Behaviours this state runs. Separation and Alignment stay on so a dozen
## drones converging on one hatchery spread into a queue rather than stacking on
## a single point.
const ACTIVE_BEHAVIOURS: Array = ["ArriveHive", "Separation", "Alignment"]

var _hatchery: Hatchery


func _enter() -> void:
	_hatchery = Hatchery.for_allegiance(get_tree(), unit.allegiance)
	_point_arrive_at_hatchery()
	use_only(ACTIVE_BEHAVIOURS)


## Aim the unit's ArriveBehaviour at its own hatchery.
##
## Found through the group rather than an exported NodePath: the Godot editor
## has pruned instance-override properties from this project's scenes twice,
## and a group lookup cannot be lost that way.
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

	# A drone that arrives carrying nothing has nothing to do here. This
	# happens after a flee interrupts a delivery, and without the check the
	# unit would sit at the hatchery depositing zeroes.
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

	# Hand over a slice at a time rather than the whole load at once, so the
	# drone stays on station long enough to be seen delivering.
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
