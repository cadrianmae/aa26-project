## A tilted camera that trails the player's ship, giving the 2.5D read.
##
## The camera holds a fixed world-space offset rather than orbiting behind the
## ship's heading. A trailing camera would swing the whole battlefield around
## every time the player turned, which in a top-down strategy game costs the
## player their mental map of where everything is. Keeping the offset in world
## space means north stays north.
class_name FollowCamera
extends Camera3D

## The node to follow.
@export var target: Node3D

## Height above the movement plane.
@export var height: float = 34.0

## How far back along world -Z the camera sits, which sets the tilt angle.
## With the default height this is roughly 60 degrees from vertical.
@export var distance: float = 20.0

## How quickly the camera catches up. Higher is snappier.
@export var smoothing: float = 4.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = target.global_position + Vector3(0.0, height, distance)
	global_position = global_position.lerp(desired, delta * smoothing)
	look_at(target.global_position, Vector3.UP)
