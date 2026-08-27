## Turn keyboard input into a thrust force in the agent's local frame.
##
## Unlike every other behaviour this returns a raw thrust vector rather than
## [code]desired - velocity[/code]. That is what makes it feel like flying a
## ship rather than commanding a destination; its magnitude comes entirely from
## [member SteeringBehaviour.weight].
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/player_steering.gd.
## The vertical axis is dropped because movement is constrained to XZ.
class_name PlayerSteeringBehaviour
extends SteeringBehaviour

## Thrust applied along the agent's forward axis.
@export var thrust: float = 30.0

## Turning force applied along the agent's right axis.
@export var turn_force: float = 20.0

## The thrust force computed last [method calculate], kept for the gizmo.
var last_force: Vector3 = Vector3.ZERO


func calculate() -> Vector3:
	# basis.x flattened onto XZ. When the hull is banked into a turn its local
	# right-vector tilts, which would otherwise inject a vertical component.
	var projected_right: Vector3 = agent.global_transform.basis.x
	projected_right.y = 0.0
	projected_right = projected_right.normalized()

	var move: float = Input.get_axis("move_back", "move_forward")
	var turn: float = Input.get_axis("turn_left", "turn_right")

	# basis.z is the forward push: +Z is forward in this codebase.
	var force := Vector3.ZERO
	force += move * agent.global_transform.basis.z * thrust
	force += turn * projected_right * turn_force
	force.y = 0.0
	last_force = force
	return force


func on_draw_gizmos() -> void:
	DebugDraw3D.draw_arrow(
		agent.global_position, agent.global_position + last_force, Color.GREEN, 0.1
	)
