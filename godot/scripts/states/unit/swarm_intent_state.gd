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
	var next_state_name: String = INTENT_STATES.get(intent, "")	
	next_state = machine.state_named(next_state_name)

	if next_state == null:
		return

	machine.change_state(next_state)

	return
