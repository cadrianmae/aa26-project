## A continuous ribbon trailing whatever it is attached to.
##
## Godot has no trail node, so this keeps a short history of where its parent
## has been and rebuilds a triangle strip through those points every frame.
##
## A ribbon rather than a particle system, and the difference is not cosmetic:
## particles are individually simulated points that happen to be near each
## other, so a fast mover leaves visible GAPS between them and a turn scatters
## them. A ribbon is one connected surface through the actual path travelled,
## so it stays unbroken at any speed and a hard turn draws a clean curve. At
## 640x360 that continuity is most of what makes a trail read as a trail.
##
## The ribbon lies FLAT ON THE XZ PLANE rather than billboarding to the camera.
## This is a 2.5D game viewed from a fixed overhead angle, so a flat ribbon
## always presents its face; billboarding would cost a camera lookup per frame
## per trail and look no different.
class_name TrailRibbon
extends MeshInstance3D

## How many past positions the ribbon spans.
##
## Length in points rather than seconds, so a fast mover leaves a long trail
## and a slow one a short trail without anything having to scale it.
@export var points: int = 18

## Least distance the parent must travel before a new point is recorded.
##
## Without a minimum, a stationary object records the same position repeatedly
## and the ribbon collapses into a degenerate sliver at its own origin.
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
	# inherit the parent's transform and be dragged along with it.
	#
	# The identity reset is not optional. top_level PRESERVES the node's
	# current global transform rather than clearing it, so the ribbon froze at
	# whatever position its parent occupied on the frame it was readied. Its
	# vertices are already world coordinates, so they were then offset a second
	# time by that frozen transform and the whole trail drew twice as far from
	# the origin as it should -- almost always off screen entirely.
	top_level = true
	global_transform = Transform3D.IDENTITY

	# Procedural geometry far from the node's own origin gets frustum-culled on
	# the frame it moves outside the previous AABB. A generous margin costs
	# nothing here and stops the ribbon flickering at the screen edge.
	extra_cull_margin = 256.0
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	material_override = _build_material()


func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Additive, so overlapping trails brighten instead of occluding, and so the
	# ribbon glows against the near-black belt.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Depth read but not written: the ribbon is hidden by rocks in front of it,
	# but never occludes another ribbon crossing it.
	material.no_depth_test = false
	material.disable_receive_shadows = true
	return material


## Record a point and redraw. Called by whatever owns the trail.
##
## Driven by the owner rather than by this node's own _process, so a thruster
## can stop feeding it the moment the engine cuts and the ribbon decays
## naturally instead of being frozen mid-air.
func advance(at: Vector3, emitting: bool) -> void:
	if emitting:
		if _history.is_empty() or _history[_history.size() - 1].distance_to(at) >= minimum_step:
			_history.append(at)
	elif not _history.is_empty():
		# Not emitting: let the tail run out rather than vanishing at once, so
		# an engine cutting reads as the exhaust dissipating.
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

		# Direction along the ribbon, from the neighbouring points. Taken from
		# both sides where possible so the strip stays smooth around a corner
		# rather than kinking at every recorded point.
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
