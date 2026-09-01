## Turn every debug overlay on and off with one key.
extends Node

## Whether the overlays are on when the game starts.
@export var enabled_at_start: bool = false


func _ready() -> void:
	# Processes input even while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DebugDrawManager.debug_enabled = enabled_at_start


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_gizmos"):
		return
	DebugDrawManager.debug_enabled = not DebugDrawManager.debug_enabled
	# Mark it handled so a future UI cannot end up double-toggling.
	get_viewport().set_input_as_handled()
