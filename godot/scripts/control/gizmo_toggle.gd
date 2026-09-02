## Turn the debug overlays on and off, and choose which of them are drawn.
##
## F1 toggles every overlay at once. F2 cycles the category that stays visible,
## so one system can be shown on its own.
extends Node

## The groups F2 steps through, in order.
enum Category { ALL, STEERING, AGENTS, AI, COMBAT, WORLD }

## Which classes each category owns. A node is in a category when it is one of
## these types and carries a draw_gizmos property.
const CATEGORY_TYPES: Dictionary = {
	Category.STEERING: ["SteeringBehaviour"],
	Category.AGENTS: ["Ship", "Drone", "Swarm"],
	Category.AI: ["CommanderAI", "MusicDirector"],
	Category.COMBAT: ["Weapon"],
	Category.WORLD: ["Barnacle", "Threat", "Hatchery"],
}

## Whether the overlays are on when the game starts.
@export var enabled_at_start: bool = false

## How long the category name stays on screen after F2, in seconds.
@export var label_seconds: float = 2.0

var _category: Category = Category.ALL
var _label_left: float = 0.0


func _ready() -> void:
	# Processes input even while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DebugDrawManager.debug_enabled = enabled_at_start


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_gizmos"):
		DebugDrawManager.debug_enabled = not DebugDrawManager.debug_enabled
		# Mark it handled so a future UI cannot end up double-toggling.
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("cycle_gizmos"):
		_advance_category()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _label_left <= 0.0:
		return
	_label_left -= delta
	if _label_left <= 0.0:
		DebugDraw2D.set_text("Gizmos", "")
		return
	DebugDraw2D.set_text("Gizmos", Category.keys()[_category])


## Step to the next category and apply it.
func _advance_category() -> void:
	_category = ((_category + 1) % Category.size()) as Category
	_label_left = label_seconds
	# Cycling implies wanting to see something.
	DebugDrawManager.debug_enabled = true
	_apply_category()


## Set draw_gizmos across the tree to match the current category.
func _apply_category() -> void:
	var wanted: Array = CATEGORY_TYPES.get(_category, [])
	_apply_to(get_tree().get_root(), wanted)


func _apply_to(node: Node, wanted: Array) -> void:
	if "draw_gizmos" in node:
		node.draw_gizmos = _category == Category.ALL or _matches(node, wanted)
	for child in node.get_children():
		_apply_to(child, wanted)


## Whether [param node] is one of the class names in [param wanted].
##
## Compared by script class name rather than `is`, so the table stays data and
## this file does not have to name every agent type in code.
func _matches(node: Node, wanted: Array) -> bool:
	var script: Script = node.get_script() as Script
	while script != null:
		if wanted.has(script.get_global_name()):
			return true
		script = script.get_base_script()
	return false
