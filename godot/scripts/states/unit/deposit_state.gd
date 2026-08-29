## Carrying alloy back to the commander to add it to the faction's pool.
##
## Phase 3 fills this in: arrive at the ship, transfer the carried alloy, then
## return to Harvest or Follow.
class_name DepositState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
