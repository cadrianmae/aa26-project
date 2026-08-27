## A procedural, three-layer parallax starfield backdrop.
##
## Builds a single large quad and feeds the camera's world position into
## [code]starfield.gdshader[/code] every frame, which hashes stars directly
## in the fragment shader rather than sampling a texture, so no starfield
## asset ships with the project. The quad follows the camera's position and
## orientation at a fixed distance, and the shader's own render_mode
## (depth_draw_never, depth_test_disabled) plus a low render_priority set
## here keep it drawing behind every piece of gameplay geometry -- see the
## shader file's header comment for why a quad was chosen over a Sky.
class_name Starfield
extends MeshInstance3D

## The camera whose world position drives the parallax and which the quad
## trails to stay filling the view.
@export var camera: Camera3D

## How far in front of the camera the quad sits.
@export var distance: float = 150.0

## Edge length of the quad. Large enough to fill the view at [member distance]
## given the camera's field of view and the follow camera's typical range.
@export var quad_size: float = 500.0

## Render priority handed to the material, pushed very low so the renderer
## draws this backdrop before any opaque gameplay geometry.
const _RENDER_PRIORITY: int = -128

var _material: ShaderMaterial


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(quad_size, quad_size)
	mesh = quad

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/starfield.gdshader")
	_material.render_priority = _RENDER_PRIORITY
	material_override = _material

	_follow_camera()


func _process(_delta: float) -> void:
	_follow_camera()


## Positions the quad in front of the camera, facing it, and pushes the
## camera's current world position into the shader so the three star layers
## can scroll at their different parallax rates.
func _follow_camera() -> void:
	if camera == null:
		return
	global_transform.basis = camera.global_transform.basis
	global_position = camera.global_position - camera.global_transform.basis.z * distance
	if _material != null:
		_material.set_shader_parameter("camera_world_position", camera.global_position)
