## Renders the game at roughly 640x360 and upscales it with nearest-neighbour.
##
## The pixel treatment is the strongest single signal of the 1993 era, and it
## earns its place mechanically as well as decoratively: at this resolution
## facet edges get genuine stair-stepping, so low-poly geometry reads as
## deliberate rather than as cheap.
##
## 640x360 specifically. 320x180 is a stronger statement but puts a drone at
## about three pixels, losing the hull shapes entirely; 960x540 is barely
## distinguishable from a slightly soft image. At 640x360 a drone is about six
## pixels and the Matriarch about twenty-eight, so silhouettes survive.
##
## Inside this viewport, everything pixelates: the world, the HUD, and the 3D
## debug gizmos. Outside it, the 2D debug readout stays native.
##
## The gizmos are not a choice. DebugDraw3D projects through a camera, so it
## must draw into the viewport holding that camera or its arrows will not line
## up with the ships they describe. Only 2D overlays can sit above the upscale.
class_name PixelView
extends SubViewportContainer

## How many screen pixels each rendered pixel becomes. The SubViewport's size
## is the container's size divided by this. The project's logical canvas is
## 1280x720 (see project.godot [display]), so a shrink of 2 renders at exactly
## 640x360 whatever window the player actually has.
##
## Set through stretch_shrink rather than by assigning SubViewport.size: with
## stretch enabled the container owns the size, and writing to it directly is
## refused with "Can't change the size of a SubViewport with a
## SubViewportContainer parent that has stretch enabled".
@export_range(1, 8) var pixel_scale: int = 2

## Route the debug overlay: 3D gizmos inside the pixel viewport, 2D text
## outside it.
##
## The two halves need opposite treatment and have separate properties, which
## is the only reason both are possible at once.
##
## DebugDrawManager.custom_viewport decides which viewport the gizmos project
## through. They HAVE to go inside: they are spatially registered, so drawing
## them anywhere but the camera's own viewport puts the arrows somewhere other
## than the ships they describe. They pixelate as a consequence, and there is
## no way around that short of a second mirrored camera.
##
## DebugDraw2D.custom_canvas decides where the text draws. Pointing it at a
## CanvasItem OUTSIDE the container keeps the state readout sharp -- without
## it, the text follows the manager into the viewport and pixelates with
## everything else.
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
	# TEXTURE_FILTER_NEAREST, not the default. Linear filtering smooths the
	# upscale back into the soft image the low resolution exists to avoid --
	# the whole effect lives in this one property.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Input has to reach the world inside. Without this the SubViewport
	# swallows the mouse and the aim point never moves.
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


## The resolution actually being rendered, for probes and for the write-up.
func render_size() -> Vector2i:
	if _viewport == null:
		return Vector2i.ZERO
	return _viewport.size
