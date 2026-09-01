## Turn keyboard/mouse/gamepad input into a camera-relative thrust force, plus
## facing.
##
## Unlike every other behaviour this returns a raw thrust vector rather than
## [code]desired - velocity[/code]; its magnitude comes entirely from
## [member SteeringBehaviour.weight].
##
## Movement is always relative to the camera, never the ship's own basis --
## W means "camera forward" regardless of which way the hull is pointing. Two
## control schemes share that movement and differ only in facing:
## [constant ControlMode.DIRECTIONAL] faces the hull along its velocity (set on
## [Ship] itself); [constant ControlMode.AIMED] faces the hull at the mouse
## cursor, or the right stick when a gamepad is deflecting it, for weapons
## that point where the player is looking rather than where the ship happens
## to be drifting.
##
## Gamepad: left stick moves, right stick aims, shoulder buttons rotate the
## camera.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/player_steering.gd.
## The vertical axis is dropped because movement is constrained to XZ.
class_name PlayerSteeringBehaviour
extends SteeringBehaviour

## Which facing scheme is active. Toggled by the toggle_aim action.
enum ControlMode { DIRECTIONAL, AIMED }

## Below this length the right stick is treated as at rest, in
## [method aim_stick_direction], so small analog noise does not fight the
## mouse for control of AIMED-mode facing.
const AIM_STICK_DEADZONE: float = 0.001

## How far out along [method aim_stick_direction] to project the stick's
## facing target, since [member Ship.face_target] is a position, not a
## direction.
const AIM_STICK_PROJECTION_DISTANCE: float = 10.0

## Thrust applied along the camera-relative forward/right axes.
##
## This, not [member Ship.max_speed], sets how fast the player actually goes:
## cruising speed is thrust / (mass * damping). `max_speed` is only a ceiling,
## and the ship settles well below it.
@export var thrust: float = 60.0

## The camera that movement and aiming are relative to. Falls back to the
## viewport's active camera in [method _ready] if left unset -- see that
## method for why this must not be wired as a scene override.
@export var camera: Camera3D

## Current facing scheme. DIRECTIONAL faces velocity; AIMED faces the mouse.
var control_mode: ControlMode = ControlMode.DIRECTIONAL

## The thrust force computed last [method calculate], kept for the gizmo.
var last_force: Vector3 = Vector3.ZERO


func _ready() -> void:
	super()

	# Both hives share commander_ship.tscn, so guard: only allegiance 0 reads
	# input.
	var ship: Ship = get_parent() as Ship
	if ship != null and ship.allegiance != 0:
		enabled = false
		set_process(false)
		return

	if camera == null:
		# Scene-authored overrides on nodes inside an instanced sub-scene do not
		# survive a re-save; resolve at run time.
		camera = get_viewport().get_camera_3d()


func _process(delta: float) -> void:
	super(delta)
	if Input.is_action_just_pressed("toggle_aim"):
		if control_mode == ControlMode.DIRECTIONAL:
			control_mode = ControlMode.AIMED
		else:
			control_mode = ControlMode.DIRECTIONAL

	var ship: Ship = agent as Ship
	if ship == null:
		return
	if control_mode == ControlMode.AIMED:
		# Prefer the stick when it is deflected, since a controller player's
		# mouse is untouched and would otherwise fight the stick for facing.
		# A mouse player never touches the stick, so aim_point() always wins.
		var stick: Vector3 = aim_stick_direction()
		if stick != Vector3.ZERO:
			ship.face_target = agent.global_position + stick * AIM_STICK_PROJECTION_DISTANCE
		else:
			ship.face_target = aim_point()
		ship.use_face_target = true
	else:
		ship.use_face_target = false


## The camera's forward direction, flattened onto the XZ plane.
func camera_forward() -> Vector3:
	if camera == null:
		return Vector3.BACK
	# Camera3D looks down its own -Z, so the world-space forward direction is
	# the negation of its basis.z. Getting this backwards inverts W and S.
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() == 0.0:
		return Vector3.BACK
	return forward.normalized()


## The camera's right direction, flattened onto the XZ plane.
func camera_right() -> Vector3:
	if camera == null:
		return Vector3.RIGHT
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0.0
	if right.length() == 0.0:
		return Vector3.RIGHT
	return right.normalized()


## Where the mouse points, projected onto the agent's movement plane.
func aim_point() -> Vector3:
	if camera == null:
		return agent.global_position + camera_forward()
	var mouse_pos: Vector2 = agent.get_viewport().get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var normal: Vector3 = camera.project_ray_normal(mouse_pos)
	var plane := Plane(Vector3.UP, agent.global_position.y)
	var hit = plane.intersects_ray(origin, normal)
	if hit == null:
		# Ray parallel to the plane: keep the current heading rather than
		# snapping to an undefined point.
		return agent.global_position + agent.global_transform.basis.z
	return hit


## The right stick's aim direction on the XZ plane, camera-relative, or
## Vector3.ZERO when the stick is at rest.
func aim_stick_direction() -> Vector3:
	var strafe: float = Input.get_axis("aim_left", "aim_right")
	# aim_down is the positive action, so pushing the stick up (the direction
	# that should aim along camera_forward()) reads as negative. Negate it so
	# "up" maps to +camera_forward(), matching how W maps to +camera_forward()
	# in calculate() above.
	var advance: float = -Input.get_axis("aim_up", "aim_down")

	var direction := Vector3.ZERO
	direction += advance * camera_forward()
	direction += strafe * camera_right()
	direction.y = 0.0
	if direction.length() < AIM_STICK_DEADZONE:
		return Vector3.ZERO
	return direction.normalized()


func calculate() -> Vector3:
	var move: float = Input.get_axis("move_back", "move_forward")
	var strafe: float = Input.get_axis("move_left", "move_right")

	var force := Vector3.ZERO
	force += move * camera_forward()
	force += strafe * camera_right()
	force.y = 0.0

	# Normalise BEFORE applying thrust, or holding two directions at once
	# gives a force of length sqrt(2) and the ship travels 41% faster on the
	# diagonals than along the axes. Clamped rather than normalised outright,
	# so a gamepad stick pushed half way still gives half thrust -- normalising
	# unconditionally would turn every analogue input into full throttle.
	if force.length() > 1.0:
		force = force.normalized()
	force *= thrust

	last_force = force
	return force


func on_draw_gizmos() -> void:
	DebugDraw3D.draw_arrow(
		agent.global_position, agent.global_position + last_force, Color.GREEN, 0.1
	)
