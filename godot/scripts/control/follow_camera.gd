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

## Current rotation of the camera's offset about Vector3.UP, in radians.
## Player-controlled via camera_left/camera_right; never follows the ship.
@export var yaw: float = 0.0

## How fast [member yaw] turns in response to input, in radians per second.
@export var yaw_speed: float = 2.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var turn: float = Input.get_axis("camera_left", "camera_right")
	yaw += turn * yaw_speed * delta

	var offset: Vector3 = Vector3(0.0, height, -distance).rotated(Vector3.UP, yaw)
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
