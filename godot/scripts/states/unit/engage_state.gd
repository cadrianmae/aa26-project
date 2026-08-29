## Hunting a designated target.
##
## Phase 4 fills this in: pursue the target with lead, keeping separation from
## the rest of the swarm, then transition to Detonate within strike distance.
class_name EngageState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
