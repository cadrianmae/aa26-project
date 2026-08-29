## Circling a designated point, watching for enemies.
##
## Phase 4 fills this in: follow a path around the designated point while the
## flocking triple keeps the group coherent.
class_name PatrolState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
