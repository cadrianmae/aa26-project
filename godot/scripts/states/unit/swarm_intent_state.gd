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


func _think() -> void:
	if unit == null or machine == null:
		return
	if machine.current_state != null and machine.current_state.name == flee_state_name:
		return

	var threat: Threat = Threat.nearest_to(get_tree(), unit.global_position)
	if threat == null:
		return
	var distance: float = threat.global_position.distance_to(unit.global_position)
	if distance <= threat.danger_radius:
		machine.change_state(machine.state_named(flee_state_name))
