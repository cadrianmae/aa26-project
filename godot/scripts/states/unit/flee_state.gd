## Scatter from a threat, overriding whatever the swarm was told to do.
##
## This is the reflex that makes the swarm read as alive rather than obedient:
## a unit abandons its orders to survive, then rejoins when the danger passes.
## It is reachable from EVERY other state, which is what distinguishes a reflex
## from an ordinary transition.
class_name FleeState
extends State

## How far outside the threat's danger radius the unit must get before it is
## willing to go back to what it was doing. The gap between fleeing and
## returning is deliberate: without it a unit sitting exactly on the boundary
## flips between states every frame.
@export var safe_margin: float = 6.0

## The state to return to once safe.
@export var return_state_name: String = "Follow"

var return_state: State = null

func _enter() -> void:
	return_state = machine.state_named(return_state_name)
	use_only(["Avoid", "Flee", "Separation"])


## Return to [member return_state_name] once the threat is far enough away.
##
## Two separate reasons count as safe: the threat is gone entirely, or it is
## still there but out of reach. They share a body today, but they are
## different questions and a later phase may want to answer them differently.
##
## The threshold is deliberately NOT the same one that triggered the flee.
## [SwarmIntentState] enters this state at the threat's bare danger_radius;
## leaving needs that radius plus [member safe_margin]. Without the gap, a unit
## sitting exactly on the boundary satisfies both conditions on alternating
## frames and shudders in place instead of fleeing or returning.
func _think() -> void:
	var unit_position: Vector3 = unit.global_position
	var threat: Threat = Threat.nearest_to(get_tree(), unit_position)

	if threat == null:
		machine.change_state(return_state)
		return

	var distance_to_threat: float = unit_position.distance_to(threat.global_position)

	if distance_to_threat > threat.danger_radius + safe_margin:
		machine.change_state(return_state)
		return
