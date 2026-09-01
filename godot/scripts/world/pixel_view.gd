## Renders the game at roughly 640x360 and upscales it with nearest-neighbour.
##
## Everything inside the viewport pixelates, including the 3D debug gizmos;
## the 2D debug readout stays native outside it.
class_name PixelView
extends SubViewportContainer

## How many screen pixels each rendered pixel becomes. The project's logical
## canvas is 1280x720, so a shrink of 2 renders at 640x360.
##
## Set through stretch_shrink, not by assigning SubViewport.size: with stretch
## enabled the container owns the size and a direct write is refused.
@export_range(1, 8) var pixel_scale: int = 2

## Route the debug overlay: 3D gizmos inside the pixel viewport, 2D text
## outside it.
##
## DebugDrawManager.custom_viewport must be the camera's own viewport or the
## arrows miss their ships; DebugDraw2D.custom_canvas points outside so the
## text stays sharp.
@export var capture_debug_draw: bool = true

## A CanvasItem outside this container, for the 2D debug text to draw on.
@export var native_debug_canvas: NodePath

var _viewport: SubViewport


func _ready() -> void:
	_viewport = get_node_or_null("SubViewport") as SubViewport
	if _viewport == null:
		push_error("%s expects a SubViewport child." % name)
		return

	stretch = true
	stretch_shrink = pixel_scale
	# Nearest, not the default linear: linear filtering undoes the upscale.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Without this the SubViewport swallows the mouse and the aim point never moves.
	_viewport.handle_input_locally = false

	if capture_debug_draw:
		_route_debug_draw()


## Send the gizmos inside and keep the text outside.
##
## Deferred: DebugDrawManager is an autoload singleton and the node this
## points at may not be ready yet on the frame the container is.
func _route_debug_draw() -> void:
	await get_tree().process_frame

	if Engine.has_singleton("DebugDrawManager"):
		Engine.get_singleton("DebugDrawManager").custom_viewport = _viewport

	if native_debug_canvas.is_empty() or not Engine.has_singleton("DebugDraw2D"):
		return
	var canvas: Node = get_node_or_null(native_debug_canvas)
	if canvas == null:
		push_warning(
			"%s: native_debug_canvas did not resolve; the 2D debug text will "
			% name + "pixelate with the world."
		)
		return
	Engine.get_singleton("DebugDraw2D").custom_canvas = canvas


## The resolution actually being rendered.
func render_size() -> Vector2i:
	if _viewport == null:
		return Vector2i.ZERO
	return _viewport.size
