## Steer directly away from the nearest threat.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/Flee.gd:19-24.
##
## Flee is seek with the DESIRED VELOCITY reversed -- not seek with the whole
## subtraction reversed. Both read as "the opposite of seek" and they are not
## the same expression; they differ by twice the agent's velocity.
##
##     seek:  desired_toward - velocity
##     flee:  desired_away   - velocity     where desired_away = -desired_toward
##
## An earlier version computed velocity - desired_toward, which is exactly
## -seek. That returns ZERO whenever velocity equals desired_toward -- that is,
## whenever the unit is already flying straight at the threat at full speed,
## which is precisely the case the reflex exists to catch. Flee sits first in
## the priority order at weight 40 so it is guaranteed its share of the WTPRS
## budget, and it was spending that guarantee on a zero.
##
## Range-gating means a distant threat costs nothing, so this can sit enabled
## on a unit without dragging on the budget when nothing is chasing it.
class_name FleeBehaviour
extends SteeringBehaviour

## Beyond this distance the behaviour contributes nothing.
@export var flee_range: float = 30.0


func calculate() -> Vector3:
	var threat: Threat = Threat.nearest_to(get_tree(), agent.global_position)
	if threat == null:
		return Vector3.ZERO

	var to_threat: Vector3 = threat.global_position - agent.global_position
	if to_threat.length() >= flee_range:
		return Vector3.ZERO

	# Away from the threat, not toward it. The minus sign here is the fix.
	var desired: Vector3 = -to_threat.normalized() * agent.max_speed
	var force: Vector3 = desired - agent.velocity
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var threat: Threat = Threat.nearest_to(get_tree(), agent.global_position)
	if threat != null:
		DebugDraw3D.draw_line(
			agent.global_position, threat.global_position, Color.CRIMSON
		)
