## A procedural, three-layer parallax starfield backdrop.
##
## Builds a large quad tracking the camera and feeds camera_world_position
## into res://shaders/starfield.gdshader, which hashes stars per fragment.
class_name Starfield
extends MeshInstance3D

## The camera whose world position drives the parallax, and which the quad
## trails to stay filling the view.
@export var camera: Camera3D

## Fraction of the camera's far plane the quad sits at. Kept short of 1.0 so
## floating point error cannot cull the quad against the far clip plane.
@export_range(0.5, 0.999) var far_plane_fraction: float = 0.95

## Render priority handed to the material.
const _RENDER_PRIORITY: int = -128

var _material: ShaderMaterial
var _quad: QuadMesh


func _ready() -> void:
	_quad = QuadMesh.new()
	mesh = _quad

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/starfield.gdshader")
	_material.render_priority = _RENDER_PRIORITY
	material_override = _material

	_follow_camera()


func _process(_delta: float) -> void:
	_follow_camera()


## Positions the quad just inside the camera's far plane, facing it and sized
## to exactly cover the frustum at that distance, and pushes the camera's
## current world position into the shader.
func _follow_camera() -> void:
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
	# A small margin so camera lag never exposes the quad's edge.
	_quad.size = Vector2(half_width, half_height) * 2.2

	if _material == null:
		return
	_material.set_shader_parameter("camera_world_position", camera.global_position)
