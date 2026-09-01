## Steer directly away from the nearest threat.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/Flee.gd:19-24.
##
## Negates seek's desired velocity, not the whole subtraction.
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
