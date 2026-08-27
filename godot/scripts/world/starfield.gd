## A procedural, three-layer parallax starfield backdrop, plus camera-speed
## motion-dust streaks.
##
## Builds a single large quad and feeds the camera's world position into
## [code]starfield.gdshader[/code] every frame, which hashes stars directly
## in the fragment shader rather than sampling a texture, so no starfield
## asset ships with the project. The quad follows the camera's position and
## orientation, positioned just inside the camera's far plane and scaled from
## the camera's fov and aspect so it always exactly fills the view -- see the
## shader file's header comment for why the quad relies on ordinary depth
## testing (rather than depth_test_disabled) to stay behind gameplay geometry
## and the DebugDraw3D gizmos, and why a quad was chosen over a Sky.
##
## Motion dust reuses this same quad and shader rather than a separate
## particle system: the quad already fills the screen every frame, so a
## streak layer added to the shader gets "everywhere on screen" for free, and
## it keeps the dust visually and technically co-located with the stars it
## belongs next to. This script's job for that layer is just differencing the
## camera's world position frame to frame -- FollowCamera lerps toward its
## target and carries no velocity of its own -- and handing the shader that
## velocity projected into the camera's local right/up axes.
class_name Starfield
extends MeshInstance3D

## The camera whose world position drives the parallax and motion dust, and
## which the quad trails to stay filling the view.
@export var camera: Camera3D

## Fraction of the camera's far plane the quad sits at. Kept short of 1.0 so
## the quad is comfortably inside the far clip plane rather than exactly on
## it, where it could be culled by floating point error.
@export_range(0.5, 0.999) var far_plane_fraction: float = 0.95

## Render priority handed to the material. No longer load-bearing for draw
## order now that the quad relies on real depth testing (see the shader's
## header comment), but harmless to keep low.
const _RENDER_PRIORITY: int = -128

var _material: ShaderMaterial
var _quad: QuadMesh
var _has_previous_position: bool = false
var _previous_camera_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_quad = QuadMesh.new()
	mesh = _quad

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/starfield.gdshader")
	_material.render_priority = _RENDER_PRIORITY
	material_override = _material

	_follow_camera(0.0)


func _process(delta: float) -> void:
	_follow_camera(delta)


## Positions the quad just inside the camera's far plane, facing it and sized
## to exactly cover the frustum at that distance, and pushes the camera's
## current world position and frame-to-frame velocity into the shader.
func _follow_camera(delta: float) -> void:
	if camera == null:
		return

	var distance: float = camera.far * far_plane_fraction
	global_transform.basis = camera.global_transform.basis
	global_position = camera.global_position - camera.global_transform.basis.z * distance

	# Size the quad from the camera's vertical fov and viewport aspect so it
	# covers the frustum exactly at this distance, regardless of far plane or
	# window size. Godot's Camera3D.fov is the vertical fov in degrees.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = 1.0
	if viewport_size.y > 0.0:
		aspect = viewport_size.x / viewport_size.y
	var half_height: float = distance * tan(deg_to_rad(camera.fov) * 0.5)
	var half_width: float = half_height * aspect
	# A small safety margin so camera jitter or FollowCamera's own lerp lag
	# never exposes the quad's edge for a frame.
	_quad.size = Vector2(half_width, half_height) * 2.2

	if _material == null:
		return
	_material.set_shader_parameter("camera_world_position", camera.global_position)

	var camera_velocity: Vector3 = Vector3.ZERO
	if _has_previous_position and delta > 0.0:
		camera_velocity = (camera.global_position - _previous_camera_position) / delta
	_previous_camera_position = camera.global_position
	_has_previous_position = true

	# Project world-space velocity into the camera's own local right/up axes
	# so a streak's on-screen direction always matches how the view actually
	# moves, regardless of which way the camera faces. basis.transposed() is
	# the inverse of an orthonormal basis, so this recovers local components
	# from the world-space vector.
	var local_velocity: Vector3 = camera.global_transform.basis.transposed() * camera_velocity
	var velocity_screen: Vector2 = Vector2(local_velocity.x, local_velocity.y)
	_material.set_shader_parameter("camera_velocity_local", velocity_screen)
	_material.set_shader_parameter("camera_speed", camera_velocity.length())
