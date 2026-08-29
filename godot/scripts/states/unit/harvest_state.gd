## Scraping a caustic asteroid for alloy, taking corrosion damage while it
## works.
##
## Phase 3 fills this in: arrive at the asteroid, drain alloy, take damage,
## then transition to Deposit when full or Flee when hurt.
class_name HarvestState
extends State


func _enter() -> void:
	use_only(["OffsetPursue", "Separation", "Alignment", "Cohesion"])


func _think() -> void:
	pass
