## A tilted camera that trails the player's ship, giving the 2.5D read.
class_name FollowCamera
extends Camera3D

## The node to follow.
@export var target: Node3D

## Height above the movement plane.
@export var height: float = 34.0

## How far back along the yawed -Z the camera sits, which sets the tilt.
@export var distance: float = 20.0

## How quickly the camera catches up. Higher is snappier.
@export var smoothing: float = 4.0

## The zoom steps, as multipliers on [member height] and [member distance]
## together. Scaling both preserves the tilt angle.
@export var zoom_levels: Array[float] = [0.6, 1.0, 1.6, 2.4]

## Which entry of [member zoom_levels] the view is settling towards.
@export var zoom_index: int = 1

## How quickly the view closes on the selected zoom step, per second.
@export var zoom_speed: float = 6.0

## The multiplier actually applied this frame, easing towards the step.
var zoom: float = 1.0

## Current rotation of the camera's offset about Vector3.UP, in radians.
@export var yaw: float = 0.0

## How far one press of camera_left or camera_right turns the view, in
## degrees.
@export var yaw_step_degrees: float = 45.0

## How quickly [member yaw] closes on [member target_yaw], per second.
@export var yaw_speed: float = 6.0

## The orientation the view is turning towards. Steps by
## [member yaw_step_degrees] on each press.
var target_yaw: float = 0.0


func _ready() -> void:
	zoom = _selected_zoom()
	target_yaw = yaw


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_left"):
		target_yaw += deg_to_rad(yaw_step_degrees)
	elif event.is_action_pressed("camera_right"):
		target_yaw -= deg_to_rad(yaw_step_degrees)
	elif event.is_action_pressed("zoom_in"):
		_step_zoom(-1)
	elif event.is_action_pressed("zoom_out"):
		_step_zoom(1)
	elif event.is_action_pressed("zoom_cycle"):
		zoom_index = (zoom_index + 1) % zoom_levels.size()


## Move [member zoom_index] by [param step], clamped to the ends.
func _step_zoom(step: int) -> void:
	zoom_index = clampi(zoom_index + step, 0, zoom_levels.size() - 1)


## The multiplier for the currently selected step, or 1.0 if the levels array
## has been emptied in the Inspector.
func _selected_zoom() -> float:
	if zoom_levels.is_empty():
		return 1.0
	return zoom_levels[clampi(zoom_index, 0, zoom_levels.size() - 1)]


func _physics_process(delta: float) -> void:
	if target == null:
		return
	# lerp_angle rather than lerp: it takes the shorter way round.
	yaw = lerp_angle(yaw, target_yaw, minf(delta * yaw_speed, 1.0))
	zoom = lerpf(zoom, _selected_zoom(), minf(delta * zoom_speed, 1.0))

	var offset: Vector3 = Vector3(
		0.0, height * zoom, -distance * zoom
	).rotated(Vector3.UP, yaw)
	var desired: Vector3 = target.global_position + offset
	global_position = global_position.lerp(desired, delta * smoothing)
	var to_target: Vector3 = target.global_position - global_position
	if to_target.length() == 0.0:
		return
	# Vector3.UP fails as the up-hint when the camera looks straight down, so
	# fall back to a horizontal up-vector for a true overhead view.
	var up_hint: Vector3 = Vector3.UP
	if absf(to_target.normalized().dot(Vector3.UP)) > 0.999:
		up_hint = Vector3.FORWARD
	look_at(target.global_position, up_hint)
