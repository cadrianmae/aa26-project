## Hold station near the commander, flocking with the rest of the swarm.
##
## The default state. Steering is the flocking triple plus offset pursue: the
## slot keeps the formation legible, the flocking keeps it from being rigid.
class_name FollowState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	# The flee reflex is checked from every state, so it lives in the global
	# state rather than being repeated here. See SwarmIntentState.
	pass
