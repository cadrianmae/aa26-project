## The always-on tier: swarm intent, and the reflex that overrides it.
##
## Runs after the current state every frame. Duggan's FireAtTargetGlobalState
## is the same shape -- a concern that applies in every state, kept in one
## place rather than copied into all of them.
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
##
## A unit this hurt is unlikely to survive the fight it is in, so the question
## stops being "how do I get out" and becomes "what can I take with me".
@export_range(0.0, 1.0) var detonate_health_fraction: float = 0.3

## How close an enemy must be for detonation to be worth it.
##
## Deliberately short. A dying unit that charges across the map to detonate
## reads as scripted; one that blows up on the thing already killing it reads
## as a decision. It also has to be reachable before the unit dies on the way.
@export var detonate_radius: float = 20.0

## Starting health, captured on first think so "nearly dead" is a proportion
## rather than a hard-coded number.
var _full_health: float = 0.0

## Which state each swarm intent asks a unit to enter.
##
## A lookup rather than a match statement, so adding an order is one entry
## here and one state node -- no branching to extend. Keys are
## [enum Swarm.Intent] values; values are state node names.
const INTENT_STATES: Dictionary = {
	Swarm.Intent.HOLD: "Follow",
	Swarm.Intent.RALLY: "Rally",
	Swarm.Intent.PATROL: "Patrol",
	Swarm.Intent.HARVEST: "Harvest",
	Swarm.Intent.ENGAGE: "Engage",
}

## Which states each intent will LEAVE ALONE.
##
## The table above says where an order sends a unit. This one says where an
## order is willing to let a unit stay, and the two are not the same thing:
##
##   - HARVEST names a CYCLE. A drone alternates Harvest and Deposit, and
##     without this the router would drag it out of Deposit on the next frame
##     and it would never reach the hatchery.
##   - Every intent tolerates Launch, a TRANSIENT. A drone the factory just
##     built needs a moment to clear the hatchery whatever the swarm was ordered
##     to do.
##   - ENGAGE and PATROL tolerate Detonate, a unit-level DECISION. A drone
##     spends itself on its own judgement; no order commands it, and no order
##     should cancel it either.
##
## So the rule is: re-assert the order only when the unit is doing something
## the order does not cover. That keeps the every-frame self-healing -- a unit
## returning from Flee still gets pulled back to its standing order -- without
## the router overriding states that are part of carrying that order out.
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

	# Checked BEFORE the flee reflex, and that ordering is the whole design.
	# Fleeing is what a unit does when it can still be saved; a unit this hurt
	# with an enemy already on top of it cannot be, and running only means
	# dying a few seconds later having achieved nothing. Detonation is not an
	# order -- the swarm cannot be told to spend itself -- so it belongs here,
	# in the tier a unit reasons about ITSELF in.
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
	# Without this the router re-asserts the order every frame and overrides
	# Deposit, Launch and Detonate -- states that ARE the order being carried
	# out, not a departure from it.
	var permitted: Array = INTENT_PERMITS.get(intent, [])
	if machine.current_state != null and permitted.has(str(machine.current_state.name)):
		return

	# A HARVEST order with nothing left to harvest becomes a follow order.
	#
	# Decided HERE rather than by permitting Follow under HARVEST. Permitting
	# it stopped the per-frame thrash between Harvest and Follow, but it also
	# meant the router would leave a drone in Follow forever -- so one that
	# briefly failed to find a rock never went back to work. Asking the world
	# whether any rock exists answers the question once, for the whole swarm,
	# and a drone returns to harvesting the moment one is available again.
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

	return


## Whether this unit should spend itself now.
##
## Two conditions, both required: nearly dead, and an enemy close enough to be
## worth the trade. Either alone is wrong -- a healthy unit beside an enemy
## should fight it, and a dying unit alone should run.
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
