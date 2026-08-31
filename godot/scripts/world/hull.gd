## A ship or asteroid hull, drawn either flat-shaded solid or as wireframe.
##
## [constant RenderStyle.SOLID] builds a non-indexed [constant
## Mesh.PRIMITIVE_TRIANGLES] mesh from a hand-authored vertex and face list,
## in the style of Frontier: Elite II (1993). Each triangle gets its own copy
## of its vertices rather than sharing them through an index array, which is
## what lets the fragment shader derive a genuine per-face normal and keep
## the facets hard-edged instead of smoothed.
##
## [constant RenderStyle.WIREFRAME] keeps the original Elite (1984) look: an
## [constant Mesh.PRIMITIVE_LINES] mesh built from the same vertex list plus
## a separate edge list. Line primitives are used rather than a barycentric
## wireframe shader because Godot's primitive and CSG meshes carry no
## barycentric attribute, so a derivative-based shader would require custom
## unindexed meshes regardless. Drawing the edges directly is simpler and
## stays crisp at any zoom.
class_name Hull
extends MeshInstance3D

## Which hull to build. Each is a hand-authored vertex, face and edge list.
enum HullShape {
	## The commander ship: an elongated dart.
	DART,
	## A swarm unit: a small octahedral pod.
	POD,
	## An asteroid: an irregular lump.
	ROCK,
	## The Matriarch: a flat octagon-derived hull, nose-first.
	MATRIARCH,
}

## Which visual style to render the hull in.
enum RenderStyle {
	## Flat-shaded solid polygons (Frontier: Elite II, 1993).
	SOLID,
	## Line-drawn wireframe (Elite, 1984).
	WIREFRAME,
}

@export var hull_shape: HullShape = HullShape.POD

## Which visual style to build the mesh in.
@export var render_style: RenderStyle = RenderStyle.SOLID

## Hull colour. Player cyan, enemy amber, asteroids a dull green.
@export var hull_colour: Color = Color(0.2, 0.9, 1.0)

## Take the colour from the owning agent's allegiance instead.
##
## The player and the rival fly the SAME scenes -- one commander_ship.tscn, one
## drone.tscn, instanced twice -- so a colour set in the scene file would paint
## both sides identically. Deriving it from allegiance is what lets one scene
## serve both hives, which is also the reason the fiction works: they are the
## same species.
##
## Anything with no allegiance in its ancestry keeps its own colour, so
## Barnacles and asteroids are unaffected without needing to opt out.
@export var use_faction_colour: bool = true

## Caustic green: the player's hive.
@export var player_colour: Color = Color(0.435, 0.812, 0.353)

## Amber gold: the rival hive. Both are Thargoid, so the palette stays inside
## the same biotech range and splits by hue rather than by unrelated colours.
@export var rival_colour: Color = Color(0.851, 0.643, 0.255)

## Uniform scale applied to the authored vertex list.
@export var hull_scale: float = 1.0


func _ready() -> void:
	if use_faction_colour:
		_apply_faction_colour()
	match render_style:
		RenderStyle.WIREFRAME:
			mesh = _build_wireframe_mesh()
			material_override = _build_wireframe_material()
		_:
			mesh = _build_solid_mesh()
			material_override = _build_solid_material()


## Colour this hull by the allegiance of whatever owns it.
##
## Walks UP the tree rather than reading the immediate parent: a Hull can sit
## directly on a Drone, or under a Projectile, or a level deeper inside an
## imported model. Anything with no allegiance anywhere above it -- a Barnacle,
## an asteroid -- keeps the colour it was given.
func _apply_faction_colour() -> void:
	var node: Node = get_parent()
	while node != null:
		if "allegiance" in node:
			hull_colour = rival_colour if node.allegiance == 1 else player_colour
			return
		node = node.get_parent()


## Assemble the flat-shaded solid mesh for [member hull_shape].
##
## Non-indexed: every triangle gets its own three vertices, so no vertex is
## shared between faces. That is what forces each face to carry its own
## normal in the shader instead of an averaged, smoothed one.
func _build_solid_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = _vertices_for(hull_shape)
	var faces: PackedInt32Array = _faces_for(hull_shape)

	var points := PackedVector3Array()
	var colours := PackedColorArray()
	for i in faces.size():
		points.append(vertices[faces[i]] * hull_scale)
		# Integer division: the three vertices of one triangle share a face
		# index, so they share a shade and the facet stays flat.
		var shade: float = _facet_shade(i / 3)
		colours.append(Color(
			hull_colour.r * shade,
			hull_colour.g * shade,
			hull_colour.b * shade,
			hull_colour.a
		))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colours

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh


## How much darker the darkest facet gets, as a fraction of [member
## hull_colour]. 0.0 makes every facet the base colour.
@export_range(0.0, 0.6) var facet_shade_spread: float = 0.2


## A brightness multiplier for the facet at [param face_index], somewhere in
## the range 1.0 - [member facet_shade_spread] .. 1.0.
##
## Lighting alone does not separate adjacent facets on a cone, because their
## normals are nearly identical. Varying the base colour per face does.
func _facet_shade(face_index: int) -> float:
	# TODO(human)
	return 1.0


## Assemble the line mesh for [member hull_shape].
func _build_wireframe_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = _vertices_for(hull_shape)
	var edges: PackedInt32Array = _edges_for(hull_shape)

	var points := PackedVector3Array()
	var colours := PackedColorArray()
	for i in edges.size():
		points.append(vertices[edges[i]] * hull_scale)
		colours.append(hull_colour)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colours

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return array_mesh


## Build the flat-shading material that lights the solid hull.
func _build_solid_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/flat_hull.gdshader")
	return material


## Build the unlit material that draws the wireframe lines.
func _build_wireframe_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/wireframe.gdshader")
	return material


## Corner positions for a hull, in model space with +Z as forward.
func _vertices_for(shape: HullShape) -> PackedVector3Array:
	match shape:
		HullShape.DART:
			return PackedVector3Array([
				Vector3(0.0, 0.0, 2.0),      # 0 nose
				Vector3(-1.2, 0.0, -1.0),    # 1 port wingtip
				Vector3(1.2, 0.0, -1.0),     # 2 starboard wingtip
				Vector3(0.0, 0.5, -0.6),     # 3 dorsal fin
				Vector3(0.0, 0.0, -1.4),     # 4 tail
			])
		HullShape.MATRIARCH:
			# Octagonal head-on, like an Interceptor: the octagon lives in the
			# XY plane and the hull runs along Z through it. Three stations
			# down the length --
			#
			#   1. a small octagonal nose face at the front (the flat),
			#   2. the full-width octagon behind it (the widest ring),
			#   3. a single point at the tail (the sharp back).
			#
			# The angled front faces are the band between stations 1 and 2:
			# eight facets sweeping back and outward from the small nose to
			# the wide ring, which is what "angled and pushed back" means
			# geometrically.
			#
			# Both octagons use corners at 22.5 + 45k degrees, which puts the
			# FACETS on the cardinals -- flat top, flat bottom, flat sides --
			# rather than a corner pointing straight up. The flats catch the
			# light as broad panels, which is the Frontier look; corner-up
			# would read as a spinning top.
			#
			# The nose centre sits slightly proud of its ring so the cap is a
			# shallow eight-sided pyramid rather than one flat disc. A flat
			# disc would shade as a single colour and kill the faceting on
			# the part of the hull the player looks at most.
			return PackedVector3Array([
				Vector3(0.0, 0.0, 1.85),      # 0 nose centre, slightly proud
				# 1..8 nose ring, radius 0.5 at z = 1.7.
				Vector3(0.462, 0.191, 1.7),   # 1
				Vector3(0.191, 0.462, 1.7),   # 2
				Vector3(-0.191, 0.462, 1.7),  # 3
				Vector3(-0.462, 0.191, 1.7),  # 4
				Vector3(-0.462, -0.191, 1.7), # 5
				Vector3(-0.191, -0.462, 1.7), # 6
				Vector3(0.191, -0.462, 1.7),  # 7
				Vector3(0.462, -0.191, 1.7),  # 8
				# 9..16 main ring, radius 1.2 at z = 0.3: the widest point.
				Vector3(1.109, 0.459, 0.3),   # 9
				Vector3(0.459, 1.109, 0.3),   # 10
				Vector3(-0.459, 1.109, 0.3),  # 11
				Vector3(-1.109, 0.459, 0.3),  # 12
				Vector3(-1.109, -0.459, 0.3), # 13
				Vector3(-0.459, -1.109, 0.3), # 14
				Vector3(0.459, -1.109, 0.3),  # 15
				Vector3(1.109, -0.459, 0.3),  # 16
				Vector3(0.0, 0.0, -2.2),      # 17 tail point
			])
		HullShape.ROCK:
			return PackedVector3Array([
				Vector3(0.0, 1.3, 0.0),
				Vector3(1.1, 0.3, 0.4),
				Vector3(0.2, 0.4, 1.2),
				Vector3(-1.0, 0.2, 0.5),
				Vector3(-0.6, 0.1, -1.0),
				Vector3(0.8, 0.3, -0.9),
				Vector3(0.0, -1.1, 0.0),
			])
		_:
			# POD: an octahedron.
			return PackedVector3Array([
				Vector3(0.0, 0.0, 1.0),
				Vector3(0.7, 0.0, 0.0),
				Vector3(0.0, 0.0, -1.0),
				Vector3(-0.7, 0.0, 0.0),
				Vector3(0.0, 0.6, 0.0),
				Vector3(0.0, -0.6, 0.0),
			])


## Triangle index triples that close a hull's vertex list into a solid.
##
## Winding order does not matter here: the shader derives each face's normal
## from screen-space derivatives and flips it toward the viewer, so any
## consistent closure of the hull lights correctly either way.
func _faces_for(shape: HullShape) -> PackedInt32Array:
	match shape:
		HullShape.DART:
			# Nose(0), port wingtip(1), starboard wingtip(2), fin(3), tail(4).
			# 0, 1, 4, 2 are coplanar (y = 0) and form a convex kite: that
			# plane is the flat underside, split into two base triangles.
			# The fin (3) sits above it and is the apex of a four-sided
			# pyramid roofing the same kite. 2 base + 4 roof = 6 triangles,
			# closing the hull with no gaps.
			return PackedInt32Array([
				# Underside (flat base, y = 0).
				0, 1, 4,
				0, 4, 2,
				# Roof (pyramid up to the dorsal fin).
				0, 1, 3,
				1, 4, 3,
				4, 2, 3,
				2, 0, 3,
			])
		HullShape.MATRIARCH:
			# Three closures, one per section of the hull: a fan over the
			# nose, a band of quads between the two octagons, and a cone from
			# the wide ring down to the tail point. 8 + 16 + 8 = 32
			# triangles, closing the hull with no gaps.
			return PackedInt32Array([
				# Nose cap: fan from the proud centre(0) round the nose ring.
				0, 1, 2,
				0, 2, 3,
				0, 3, 4,
				0, 4, 5,
				0, 5, 6,
				0, 6, 7,
				0, 7, 8,
				0, 8, 1,
				# Angled front: each nose edge sweeps back and out to the
				# matching main-ring edge, two triangles per quad.
				1, 2, 9,
				2, 10, 9,
				2, 3, 10,
				3, 11, 10,
				3, 4, 11,
				4, 12, 11,
				4, 5, 12,
				5, 13, 12,
				5, 6, 13,
				6, 14, 13,
				6, 7, 14,
				7, 15, 14,
				7, 8, 15,
				8, 16, 15,
				8, 1, 16,
				1, 9, 16,
				# Rear cone: the whole main ring closes on the tail point(17).
				9, 10, 17,
				10, 11, 17,
				11, 12, 17,
				12, 13, 17,
				13, 14, 17,
				14, 15, 17,
				15, 16, 17,
				16, 9, 17,
			])
		HullShape.ROCK:
			# Top vertex(0), ring of five(1..5), bottom vertex(6).
			return PackedInt32Array([
				0, 1, 2,
				0, 2, 3,
				0, 3, 4,
				0, 4, 5,
				0, 5, 1,
				6, 2, 1,
				6, 3, 2,
				6, 4, 3,
				6, 5, 4,
				6, 1, 5,
			])
		_:
			# POD: an octahedron. Top apex(4) and bottom apex(5) over the
			# equator ring (0, 1, 2, 3).
			return PackedInt32Array([
				4, 0, 1,
				4, 1, 2,
				4, 2, 3,
				4, 3, 0,
				5, 1, 0,
				5, 2, 1,
				5, 3, 2,
				5, 0, 3,
			])


## Vertex-index pairs, two per line segment.
func _edges_for(shape: HullShape) -> PackedInt32Array:
	match shape:
		HullShape.DART:
			return PackedInt32Array([
				0, 1, 0, 2, 1, 4, 2, 4, 1, 2, 0, 3, 3, 4,
			])
		HullShape.MATRIARCH:
			return PackedInt32Array([
				# Nose cap spokes.
				0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8,
				# Nose ring.
				1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 1,
				# Longitudinals along the angled front.
				1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15, 8, 16,
				# Main ring.
				9, 10, 10, 11, 11, 12, 12, 13,
				13, 14, 14, 15, 15, 16, 16, 9,
				# Tail spokes.
				9, 17, 10, 17, 11, 17, 12, 17,
				13, 17, 14, 17, 15, 17, 16, 17,
			])
		HullShape.ROCK:
			return PackedInt32Array([
				0, 1, 0, 2, 0, 3, 0, 4, 0, 5,
				1, 2, 2, 3, 3, 4, 4, 5, 5, 1,
				6, 1, 6, 2, 6, 3, 6, 4, 6, 5,
			])
		_:
			return PackedInt32Array([
				0, 1, 1, 2, 2, 3, 3, 0,
				4, 0, 4, 1, 4, 2, 4, 3,
				5, 0, 5, 1, 5, 2, 5, 3,
			])
