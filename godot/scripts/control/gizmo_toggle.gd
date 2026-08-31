## Turn every debug overlay on and off with one key.
##
## The steering gizmos are the whole point of the project on screen -- they are
## how a viewer sees that the forces exist -- but they cover the ships, so a
## screenshot or a recording of the SHIPS needs them gone for a moment. This is
## that switch.
##
## An autoload rather than a node in main.tscn for two reasons. It works in any
## scene, including scratch test scenes with no main.tscn in sight. And the
## Godot editor has twice pruned instance-override properties in this project's
## scene files; a switch that lives only in project.godot cannot be lost that
## way.
##
## [DebugDrawManager] is the master switch, above [DebugDraw3D] and
## [DebugDraw2D]: it takes out the 3D force arrows AND the 2D state readout in
## the corner together. Toggling only DebugDraw3D would leave the state list
## sitting over the top-left of every screenshot.
extends Node

## Whether the overlays are on when the game starts.
##
## Off. Every gizmo in the project defaults to true individually, which is
## right -- each one should draw when debug drawing is on at all -- but the
## sum of them is roughly one wire sphere per behaviour per agent, which at
## forty drones buries the ships completely. Starting from off means the
## default view is the game, and the forces are one keypress away when the
## question is what the steering is doing.
@export var enabled_at_start: bool = false


func _ready() -> void:
	# Process input even while the tree is paused, so the toggle still works
	# if a later phase adds a pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DebugDrawManager.debug_enabled = enabled_at_start


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_gizmos"):
		return
	DebugDrawManager.debug_enabled = not DebugDrawManager.debug_enabled
	# Mark it handled so a future UI cannot end up double-toggling.
	get_viewport().set_input_as_handled()
