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
	_apply(self, material)


## Walk the subtree and put [param material] on every MeshInstance3D.
func _apply(node: Node, material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	if not apply_to_children:
		return
	for child in node.get_children():
		_apply(child, material)
