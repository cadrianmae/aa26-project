## Applies the flat-shaded hull look to an imported glTF model.
##
## Blender exports white vertex colours when a mesh carries none, and the
## shader multiplies vertex colour by tint -- so white times tint IS the tint.
class_name ModelledHull
extends Node3D

## Multiplied with the mesh's own vertex colours. White leaves a painted mesh
## exactly as painted; any other colour recolours an unpainted one.
@export var tint: Color = Color(1.0, 1.0, 1.0)

## Apply to every MeshInstance3D beneath this node, not just this one.
@export var apply_to_children: bool = true


func _ready() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/flat_hull.gdshader")
	material.set_shader_parameter("tint", tint)
	paint_subtree(self, material, apply_to_children)


## Put [param material] on [param node], and on every MeshInstance3D beneath it
## when [param recurse] is true.
static func paint_subtree(
	node: Node, material: ShaderMaterial, recurse: bool = true
) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	if not recurse:
		return
	for child in node.get_children():
		paint_subtree(child, material, recurse)
