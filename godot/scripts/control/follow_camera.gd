## A tilted camera that trails the player's ship, giving the 2.5D read.
##
## The camera holds a player-controlled orientation rather than following the
## ship's heading: [member yaw] only changes when the player turns it with
## camera_left/camera_right. A trailing camera that swung to match the ship's
## heading would rotate the whole battlefield every time the player turned,
## costing them their mental map of where everything is. Here the mental map
## is preserved by the player being in control of the frame, not by the frame
## being fixed -- the offset still rotates, just on the player's own input.
class_name FollowCamera
extends Camera3D

## The node to follow.
@export var target: Node3D

## Height above the movement plane.
@export var height: float = 34.0

## How far back along the yawed -Z the camera sits, which sets the tilt angle.
## With the default height this is roughly 30 degrees from vertical, which is
## roughly 60 degrees above the horizontal.
@export var distance: float = 20.0

## How quickly the camera catches up. Higher is snappier.
@export var smoothing: float = 4.0

## The zoom steps, as multipliers on [member height] and [member distance]
## together. Scaling both preserves the tilt angle, so zooming changes how
## much of the belt is visible without changing how the scene is framed --
## which matters, because the tilt is what makes the game read as 2.5D rather
## than flat.
##
## Discrete rather than continuous for the same reason the yaw is: the player
## can return to a known framing instead of hunting for it.
@export var zoom_levels: Array[float] = [0.6, 1.0, 1.6, 2.4]

## Which entry of [member zoom_levels] the view is settling towards.
@export var zoom_index: int = 1

## How quickly the view closes on the selected zoom step, per second.
@export var zoom_speed: float = 6.0

## The multiplier actually applied this frame, easing towards the step.
var zoom: float = 1.0

## Current rotation of the camera's offset about Vector3.UP, in radians.
## Player-controlled via camera_left/camera_right; never follows the ship.
@export var yaw: float = 0.0

## How far one press of camera_left or camera_right turns the view, in
## degrees. Rotation is stepped rather than continuous: eight presses take the
## view all the way round, so the player always lands on one of eight fixed
## orientations and can return to a known one by counting. A continuously
## swivelling camera makes that impossible, and in a top-down game the player's
## sense of where things are is most of what the camera is for.
@export var yaw_step_degrees: float = 45.0

## How quickly [member yaw] closes on [member target_yaw], per second. The
## steps are discrete but the motion between them is not -- snapping instantly
## costs the player track of which way the field just turned.
@export var yaw_speed: float = 6.0

## The orientation the view is turning towards. Steps by
## [member yaw_step_degrees] on each press.
var target_yaw: float = 0.0


func _ready() -> void:
	zoom = _selected_zoom()


func _unhandled_input(event: InputEvent) -> void:
	# Stepped on the press rather than held, so a key that is down for two
	# frames still turns the view exactly one step.
	if event.is_action_pressed("camera_left"):
		target_yaw += deg_to_rad(yaw_step_degrees)
	elif event.is_action_pressed("camera_right"):
		target_yaw -= deg_to_rad(yaw_step_degrees)
	elif event.is_action_pressed("zoom_in"):
		_step_zoom(-1)
	elif event.is_action_pressed("zoom_out"):
		_step_zoom(1)
	elif event.is_action_pressed("zoom_cycle"):
		# Wraps rather than clamping. A single button has no direction, so
		# cycling is the only way it can reach every step.
		zoom_index = (zoom_index + 1) % zoom_levels.size()


## Move [member zoom_index] by [param step], clamped to the ends.
##
## Clamped rather than wrapped, unlike the cycle button: scrolling past the
## closest step and landing on the furthest would be disorienting, and the
## scroll wheel has a direction so it does not need to wrap to be complete.
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
	# lerp_angle rather than lerp: it takes the shorter way round and does not
	# unwind through a full turn when target_yaw crosses PI.
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
