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

## Uniform scale applied to the authored vertex list.
@export var hull_scale: float = 1.0


func _ready() -> void:
	match render_style:
		RenderStyle.WIREFRAME:
			mesh = _build_wireframe_mesh()
			material_override = _build_wireframe_material()
		_:
			mesh = _build_solid_mesh()
			material_override = _build_solid_material()


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
		colours.append(hull_colour)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colours

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh


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
