## Runs one current state plus an always-on global state for a unit.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/state_machine.gd. The
## two-tier shape is his: current_state._think() runs, then global_state
## ._think(), every frame. The global tier is where swarm-wide intent lives, so
## a unit can be told what the swarm wants while its own state still decides
## what it actually does.
##
## States stay children of the machine for their whole life.
class_name StateMachine
extends Node

## Emitted after a transition, for gizmos and audio to react to.
signal state_changed(from: State, to: State)

## The state to start in. Must be a child of this machine.
@export var initial_state: NodePath

## Optional always-on state, run after the current one every frame.
@export var global_state: NodePath

## The state currently driving the unit.
var current_state: State

## The state run every frame regardless of the current one.
var global: State

## The unit this machine drives.
var unit: Drone


func _ready() -> void:
	unit = get_parent() as Drone
	if unit == null:
		push_error("%s must be a child of a Drone." % name)
		return

	for child in get_children():
		if child is State:
			child.machine = self
			child.unit = unit

	if not initial_state.is_empty():
		current_state = get_node_or_null(initial_state) as State
		if current_state == null:
			push_error("%s: initial_state %s did not resolve to a State." % [name, initial_state])
		# Deferred because sibling behaviours may not have run _ready yet, and
		# a state's _enter reaches into unit.behaviours.
		if current_state != null:
			current_state.call_deferred("_enter")

	if not global_state.is_empty():
		global = get_node_or_null(global_state) as State
		if global == null:
			push_error("%s: global_state %s did not resolve to a State." % [name, global_state])
		if global != null:
			global.call_deferred("_enter")


func _process(_delta: float) -> void:
	if current_state != null:
		current_state._think()
	if global != null:
		global._think()

	# Mirrors Duggan's own FSM readout (state_machine.gd:37).
	if unit != null:
		DebugDraw2D.set_text("SM: " + unit.name, current_state.name if current_state else "-")


## Leave the current state and enter [param new_state].
##
## Ignores a transition to the state already running, so a _think that fires
## its condition every frame does not restart the state 60 times a second.
func change_state(new_state: State) -> void:
	if new_state == null:
		push_error("%s: change_state() called with null for unit %s." % [name, unit])
		return
	if new_state == current_state:
		return
	var previous: State = current_state
	if current_state != null:
		current_state._exit()
	current_state = new_state
	current_state._enter()
	state_changed.emit(previous, current_state)


## Find a sibling state by node name. States transition by name rather than by
## instantiating a new object, so each state exists exactly once per unit and
## can hold its own data across visits.
func state_named(state_name: String) -> State:
	return get_node_or_null(NodePath(state_name)) as State


## Change to the state with this name, if it exists.
##
## Exists so a caller can defer a transition by name. call_deferred cannot
## carry a State object that has not been resolved yet, and the Hatchery needs
## exactly that: it must put a new drone into Launch AFTER the machine has
## entered its own initial state, or the initial state overwrites it.
func change_state_named(state_name: String) -> void:
	var state: State = state_named(state_name)
	if state == null:
		push_warning("%s: no state named '%s'." % [name, state_name])
		return
	change_state(state)
