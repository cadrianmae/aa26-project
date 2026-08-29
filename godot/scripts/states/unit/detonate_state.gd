## Terminal state: trigger the blast and leave the flock.
##
## Phase 4 fills this in: apply blast damage, emit the effect, then remove the
## unit. Its neighbours re-query the grid and re-cohere on the next frame,
## which is the whole of the "leave" case in the emergent-membership model.
class_name DetonateState
extends State


func _enter() -> void:
	use_only([])


func _think() -> void:
	pass
