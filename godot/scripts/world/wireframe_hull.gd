## A wireframe hull drawn as line primitives, in the style of Elite (1984).
##
## Builds an [ArrayMesh] of [constant Mesh.PRIMITIVE_LINES] on ready. Line
## primitives are used rather than a barycentric wireframe shader because
## Godot's primitive and CSG meshes carry no barycentric attribute, so a
## derivative-based shader would require custom unindexed meshes regardless.
## Drawing the edges directly is simpler and stays crisp at any zoom.
class_name WireframeHull
extends MeshInstance3D

## Which hull to build. Each is a hand-authored vertex and edge list.
enum HullShape {
	## The commander ship: an elongated dart.
	DART,
	## A swarm unit: a small octahedral pod.
	POD,
	## An asteroid: an irregular lump.
	ROCK,
}

@export var hull_shape: HullShape = HullShape.POD

## Line colour. Player cyan, enemy amber, asteroids a dull green.
@export var hull_colour: Color = Color(0.2, 0.9, 1.0)

## Uniform scale applied to the authored vertex list.
@export var hull_scale: float = 1.0


func _ready() -> void:
	mesh = _build_mesh()
	material_override = _build_material()


## Assemble the line mesh for [member hull_shape].
func _build_mesh() -> ArrayMesh:
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


## Build the unlit material that draws the lines.
func _build_material() -> ShaderMaterial:
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
