## Steer towards a target node, braking inside the slowing radius.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/arrive.gd.
class_name ArriveBehaviour
extends SteeringBehaviour

## The node to settle at. When null the behaviour contributes nothing.
@export var target: Node3D

## Distance at which the unit begins to brake, when [member auto_slowing] is
## off. Duggan's default is 20 against a max speed of 10.
@export var slowing_radius: float = 20.0

## Derive the slowing radius from the agent's speed instead of the fixed value
## above.
##
## On by default. A fixed radius is only correct at the speed it was tuned at:
## when this project doubled every speed, every hand-set radius became too
## small at once and units sailed past what they were arriving at. Deriving it
## means the tuning survives any change to how fast things move.
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
## Floored at the authored [member slowing_radius] so a deliberately tight
## approach -- a drone settling onto a Barnacle's surface -- is never widened
## by the derived value, only ever tightened.
func effective_radius() -> float:
	if not auto_slowing:
		return slowing_radius
	return maxf(slowing_radius, braking_distance(slowing_scale))


func on_draw_gizmos() -> void:
	if target != null:
		DebugDraw3D.draw_sphere(
			target.global_position, effective_radius(), Color.AQUAMARINE
		)
