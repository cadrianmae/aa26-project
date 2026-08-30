## Applies the flat-shaded hull look to an imported glTF model.
##
## [Hull] builds its geometry in code and sets its own material. A modelled
## mesh arrives from Blender already built, carrying Godot's default white
## material, so it needs the same shader put on it from outside. This is that
## adapter -- put it on a node whose children are imported meshes.
##
## [member tint] is why modelled meshes do not need vertex colours at all.
## Blender exports white when a mesh carries no colour attribute, and the
## shader multiplies vertex colour by the tint, so white times tint IS the
## tint. Colour becomes an Inspector property of the thing in the world rather
## than data baked into the geometry, which also lets one mesh serve both
## hives.
class_name ModelledHull
extends Node3D

## Multiplied with the mesh's own vertex colours. White leaves a painted mesh
## exactly as painted; any other colour recolours an unpainted one.
@export var tint: Color = Color(1.0, 1.0, 1.0)

## Applied to every mesh found beneath this node, so a glTF scene with several
## parts is handled without naming any of them.
@export var apply_to_children: bool = true


func _ready() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/flat_hull.gdshader")
	material.set_shader_parameter("tint", tint)
	_apply(self, material)


## Walk the subtree and put [param material] on every MeshInstance3D.
##
## Recursive because the glTF importer nests meshes under a scene root, and
## that structure is decided by Blender rather than here -- a single-level
## search would silently miss anything the modeller grouped.
func _apply(node: Node, material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	if not apply_to_children:
		return
	for child in node.get_children():
		_apply(child, material)
