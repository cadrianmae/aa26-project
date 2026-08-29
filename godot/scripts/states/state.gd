## One state a unit can be in. States change no movement code: each simply
## re-weights which steering behaviours are enabled on entry.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/state.gd. The contract
## is his: _enter on arrival, _exit on departure, _think every frame while
## current.
class_name State
extends Node

## The machine running this state.
var machine: StateMachine

## The unit being driven. Convenience for machine.unit, which every state uses.
var unit: SwarmUnit


## Called once when this state becomes current. Set up behaviour weights here.
func _enter() -> void:
	pass


## Called once when leaving. Undo anything _enter turned on.
func _exit() -> void:
	pass


## Called every frame while current. Decide whether to transition.
func _think() -> void:
	pass


## Enable exactly the named behaviours on the unit and disable the rest.
##
## Shared helper because every state's _enter is otherwise the same five lines.
## Matching is by node name, so the scene tree stays the single place that says
## which behaviours a unit has.
func use_only(behaviour_names: Array) -> void:
	if unit == null:
		return
	for behaviour in unit.behaviours:
		behaviour.enabled = behaviour_names.has(behaviour.name)
