## Steer towards a target node, braking inside the slowing radius.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/arrive.gd.
class_name ArriveBehaviour
extends SteeringBehaviour

## The node to settle at. When null the behaviour contributes nothing.
@export var target: Node3D

## Distance at which the unit begins to brake. Duggan's default is 20 against
## a max speed of 10.
@export var slowing_radius: float = 20.0


func calculate() -> Vector3:
	# is_instance_valid as well as null: a freed node is NOT null, and reading
	# global_position off one throws.
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	return arrive_towards(target.global_position, slowing_radius)


func on_draw_gizmos() -> void:
	if target != null:
		DebugDraw3D.draw_sphere(
			target.global_position, slowing_radius, Color.AQUAMARINE
		)
