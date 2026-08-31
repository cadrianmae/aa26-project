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

	if machine.current_state != null and machine.current_state.name == flee_state_name:
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

	var next_state_name: String = INTENT_STATES.get(intent, "")
	next_state = machine.state_named(next_state_name)

	if next_state == null:
		return

	machine.change_state(next_state)

	return
