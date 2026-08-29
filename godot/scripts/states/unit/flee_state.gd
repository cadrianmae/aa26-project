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


func _enter() -> void:
	use_only(["Flee", "Separation"])


## Decide whether this unit is safe enough to stop fleeing.
##
## Steps:
##   1. Find the nearest threat with Threat.nearest_to(get_tree(),
##      unit.global_position). It returns null when no threat exists.
##   2. If there is no threat at all, the unit is safe: transition back.
##   3. Otherwise measure the distance from the unit to that threat.
##   4. The unit is safe once that distance exceeds the threat's own
##      danger_radius PLUS safe_margin. The margin is the hysteresis: entering
##      flee uses danger_radius alone, leaving it needs danger_radius plus the
##      margin, so the two thresholds cannot chatter against each other.
##   5. To transition, ask the machine for the state by name and change to it:
##      machine.change_state(machine.state_named(return_state_name))
##      change_state ignores a transition to the state already running, so
##      calling it repeatedly is harmless.
func _think() -> void:
	# TODO(human): implement the safe-to-return check per the steps above.
	pass
