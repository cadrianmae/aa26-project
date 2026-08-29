## Freshly grown by the factory, flying out to join the swarm.
##
## Phase 3 fills this in: seek the commander, then transition to Follow on
## arrival. For now it behaves as Follow does, so a unit placed in the scene
## still holds station.
class_name LaunchState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
