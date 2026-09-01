## Steer flat out towards a target node.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/seek.gd.
class_name SeekBehaviour
extends SteeringBehaviour

## The node to steer towards. When null the behaviour contributes nothing.
@export var target: Node3D


func calculate() -> Vector3:
	# is_instance_valid as well as null: a freed node is NOT null, and reading
	# global_position off one throws.
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	return seek_towards(target.global_position)


func on_draw_gizmos() -> void:
	if target != null:
		DebugDraw3D.draw_line(
			agent.global_position, target.global_position, Color.AQUA
		)
