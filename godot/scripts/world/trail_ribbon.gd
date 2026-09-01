## A continuous ribbon trailing whatever it is attached to.
##
## Godot has no trail node, so this keeps a short history of where its parent
## has been and rebuilds a triangle strip through those points every frame.
##
## The ribbon lies flat on the XZ plane; it does not billboard.
class_name TrailRibbon
extends MeshInstance3D

## How many past positions the ribbon spans.
@export var points: int = 18

## Least distance the parent must travel before a new point is recorded.
## Without a minimum the ribbon collapses into a degenerate sliver.
@export var minimum_step: float = 0.25

## Half-width at the head, tapering to nothing at the tail.
@export var width: float = 0.35

## Colour at the head.
@export var head_colour: Color = Color(1.0, 0.30, 0.10)

## Colour at the tail. Alpha should reach zero so the ribbon fades out rather
## than ending on a hard edge.
@export var tail_colour: Color = Color(0.65, 0.12, 0.03, 0.0)

## Recorded world positions, newest last.
var _history: PackedVector3Array = PackedVector3Array()

var _mesh: ImmediateMesh


func _ready() -> void:
	# World space: the ribbon marks where the parent HAS BEEN, so it must not
	# inherit the parent's transform. top_level PRESERVES the current global
	# transform rather than clearing it, so the identity reset is required.
	top_level = true
	global_transform = Transform3D.IDENTITY

	# Procedural geometry far from the node's own origin gets frustum-culled on
	# the frame it moves outside the previous AABB.
	extra_cull_margin = 256.0
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	material_override = _build_material()


func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Additive, so overlapping trails brighten instead of occluding.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Depth tested, so rocks in front of the ribbon hide it.
	material.no_depth_test = false
	material.disable_receive_shadows = true
	return material


## Record a point and redraw. Called by whatever owns the trail.
func advance(at: Vector3, emitting: bool) -> void:
	if emitting:
		if _history.is_empty() or _history[_history.size() - 1].distance_to(at) >= minimum_step:
			_history.append(at)
	elif not _history.is_empty():
		# Not emitting: the tail runs out a point per call.
		_history.remove_at(0)

	while _history.size() > points:
		_history.remove_at(0)

	_rebuild()


## Clear the ribbon outright.
func reset() -> void:
	_history.clear()
	if _mesh != null:
		_mesh.clear_surfaces()


func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _history.size() < 2:
		return

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _history.size():
		var t: float = float(i) / float(_history.size() - 1)

		# Direction from both neighbours, so the strip does not kink at each point.
		var ahead: Vector3 = _history[mini(i + 1, _history.size() - 1)]
		var behind: Vector3 = _history[maxi(i - 1, 0)]
		var along: Vector3 = ahead - behind
		along.y = 0.0
		if along.length_squared() < 0.000001:
			along = Vector3(0.0, 0.0, 1.0)
		along = along.normalized()

		# Perpendicular on the plane, which is what gives the ribbon width.
		var across := Vector3(-along.z, 0.0, along.x) * width * t

		_mesh.surface_set_color(head_colour.lerp(tail_colour, 1.0 - t))
		_mesh.surface_add_vertex(_history[i] + across)
		_mesh.surface_set_color(head_colour.lerp(tail_colour, 1.0 - t))
		_mesh.surface_add_vertex(_history[i] - across)
	_mesh.surface_end()
