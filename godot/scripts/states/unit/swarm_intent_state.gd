## The always-on tier: swarm intent, and the reflex that overrides it.
##
## Runs after the current state every frame. Same shape as Duggan's
## FireAtTargetGlobalState.
##
## Putting the flee check here is what makes FLEE a genuine reflex: it is
## reachable from every state without any state knowing about it.
class_name SwarmIntentState
extends State

## The state to enter when a threat is in range.
@export var flee_state_name: String = "Flee"

## Where a HARVEST order sends units when the belt has nothing left in it.
@export var stripped_belt_state_name: String = "Follow"

## The state a dying unit enters to spend itself.
@export var detonate_state_name: String = "Detonate"

## Health fraction below which a unit will consider detonating.
@export_range(0.0, 1.0) var detonate_health_fraction: float = 0.3

## How close an enemy must be for detonation to be worth it. It has to be
## reachable before the unit dies on the way.
@export var detonate_radius: float = 20.0

## Starting health, captured on first think so "nearly dead" is a proportion
## rather than a hard-coded number.
var _full_health: float = 0.0

## Which state each swarm intent asks a unit to enter.
##
## Keys are [enum Swarm.Intent] values; values are state node names.
const INTENT_STATES: Dictionary = {
	Swarm.Intent.HOLD: "Follow",
	Swarm.Intent.RALLY: "Rally",
	Swarm.Intent.PATROL: "Patrol",
	Swarm.Intent.HARVEST: "Harvest",
	Swarm.Intent.ENGAGE: "Engage",
}

## Which states each intent will LEAVE ALONE.
##
##   - HARVEST names a CYCLE: a drone alternates Harvest and Deposit.
##   - Every intent tolerates Launch, a TRANSIENT.
##   - ENGAGE and PATROL tolerate Detonate, a unit-level DECISION no order
##     commands or cancels.
const INTENT_PERMITS: Dictionary = {
	Swarm.Intent.HOLD: ["Follow", "Launch"],
	Swarm.Intent.RALLY: ["Rally", "Launch"],
	Swarm.Intent.PATROL: ["Patrol", "Engage", "Detonate", "Launch"],
	Swarm.Intent.HARVEST: ["Harvest", "Deposit", "Launch"],
	Swarm.Intent.ENGAGE: ["Engage", "Detonate", "Launch"],
}

func _think() -> void:
	if unit == null or machine == null or unit.swarm == null:
		return

	if _full_health <= 0.0:
		_full_health = unit.health

	# Both terminal-ish: once committed, neither is reconsidered from here.
	if machine.current_state != null and (
		machine.current_state.name == flee_state_name
		or machine.current_state.name == detonate_state_name
	):
		return

	# Before the flee reflex: a unit this hurt cannot be saved by running.
	if _should_detonate():
		machine.change_state_named(detonate_state_name)
		return

	var next_state: State = null
	var threat: Threat = Threat.nearest_to(get_tree(), unit.global_position)

	if threat != null:
		var distance_to_threat: float = threat.global_position.distance_to(unit.global_position)

		if distance_to_threat <= threat.danger_radius:
			next_state = machine.state_named(flee_state_name)
			machine.change_state(next_state)
			return

	var intent: int = unit.swarm.intent

	# Leave the unit alone if what it is already doing carries out the order.
	var permitted: Array = INTENT_PERMITS.get(intent, [])
	if machine.current_state != null and permitted.has(str(machine.current_state.name)):
		return

	# A HARVEST order with nothing left to harvest becomes a follow order.
	# Decided here rather than by permitting Follow under HARVEST, so a drone
	# returns to harvesting the moment a rock is available again.
	if intent == Swarm.Intent.HARVEST:
		if Barnacle.nearest_to(get_tree(), unit.global_position) == null:
			var idle: State = machine.state_named(stripped_belt_state_name)
			if idle != null and machine.current_state != idle:
				machine.change_state(idle)
			return

	var next_state_name: String = INTENT_STATES.get(intent, "")
	next_state = machine.state_named(next_state_name)

	if next_state == null:
		return

	machine.change_state(next_state)


## Whether this unit should spend itself now.
##
## Two conditions, both required: nearly dead, and an enemy close enough to be
## worth the trade.
func _should_detonate() -> bool:
	if unit == null or _full_health <= 0.0:
		return false
	if unit.health / _full_health > detonate_health_fraction:
		return false
	return _nearest_enemy_distance() <= detonate_radius


## Distance to the closest hostile, or INF when the field is clear.
func _nearest_enemy_distance() -> float:
	var enemy: int = 1 - unit.allegiance
	var closest: float = INF

	for node in get_tree().get_nodes_in_group("swarm_" + str(enemy)):
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		for drone in swarm.units:
			if drone == null or not is_instance_valid(drone):
				continue
			closest = minf(
				closest, unit.global_position.distance_to(drone.global_position)
			)

	for node in get_tree().get_nodes_in_group("commander_" + str(enemy)):
		var ship: Node3D = node as Node3D
		if ship == null or not is_instance_valid(ship):
			continue
		closest = minf(
			closest, unit.global_position.distance_to(ship.global_position)
		)

	return closest
