## Steer towards a target node, braking inside the slowing radius.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/arrive.gd.
class_name ArriveBehaviour
extends SteeringBehaviour

## The node to settle at. When null the behaviour contributes nothing.
@export var target: Node3D

## Distance at which the unit begins to brake, when [member auto_slowing] is
## off.
@export var slowing_radius: float = 20.0

## Derive the slowing radius from the agent's speed instead of the fixed value
## above.
@export var auto_slowing: bool = true

## Multiplies the derived radius. Below 1 brakes late and arrives hard; above
## 1 drifts in gently.
@export_range(0.1, 3.0) var slowing_scale: float = 1.0


func calculate() -> Vector3:
	# is_instance_valid as well as null: a freed node is NOT null, and reading
	# global_position off one throws.
	if target == null or not is_instance_valid(target):
		return Vector3.ZERO
	return arrive_towards(target.global_position, effective_radius())


## The radius actually used this frame.
##
## Never smaller than the authored [member slowing_radius].
func effective_radius() -> float:
	if not auto_slowing:
		return slowing_radius
	return maxf(slowing_radius, braking_distance(slowing_scale))


func on_draw_gizmos() -> void:
	if target != null:
		DebugDraw3D.draw_sphere(
			target.global_position, effective_radius(), Color.AQUAMARINE
		)
