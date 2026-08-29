## Turn keyboard/mouse input into a camera-relative thrust force, plus facing.
##
## Unlike every other behaviour this returns a raw thrust vector rather than
## [code]desired - velocity[/code]. That is what makes it feel like flying a
## ship rather than commanding a destination; its magnitude comes entirely from
## [member SteeringBehaviour.weight].
##
## Movement is always relative to the camera, never the ship's own basis --
## W means "camera forward" regardless of which way the hull is pointing. Two
## control schemes share that movement and differ only in facing:
## [constant ControlMode.DIRECTIONAL] faces the hull along its velocity (set on
## [Ship] itself); [constant ControlMode.AIMED] faces the hull at the mouse
## cursor, for weapons that point where the player is looking rather than
## where the ship happens to be drifting.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/player_steering.gd.
## The vertical axis is dropped because movement is constrained to XZ.
class_name PlayerSteeringBehaviour
extends SteeringBehaviour

## Which facing scheme is active. Toggled by the toggle_aim action.
enum ControlMode { DIRECTIONAL, AIMED }

## Thrust applied along the camera-relative forward/right axes.
@export var thrust: float = 30.0

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
	if camera == null:
		# The editor silently prunes instance-override properties on nodes
		# inside an instanced sub-scene (this node lives inside
		# commander_ship.tscn), so wiring `camera` from main.tscn does not
		# survive a re-save. Resolving it at run time instead needs no scene
		# wiring at all, matching how the swarm and its leader are resolved.
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


func calculate() -> Vector3:
	var move: float = Input.get_axis("move_back", "move_forward")
	var strafe: float = Input.get_axis("move_left", "move_right")

	var force := Vector3.ZERO
	force += move * camera_forward() * thrust
	force += strafe * camera_right() * thrust
	force.y = 0.0
	last_force = force
	return force


func on_draw_gizmos() -> void:
	DebugDraw3D.draw_arrow(
		agent.global_position, agent.global_position + last_force, Color.GREEN, 0.1
	)
