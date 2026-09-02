## What the swarm has been ordered to do, and what its drones are actually
## doing about it.
##
## The order is one value from the commander; the states beneath it are chosen
## per drone, so the two lines rarely agree exactly. That gap is the point:
## a HARVEST order shows drones split across Harvest, Deposit and Launch.
class_name SwarmPanel
extends Control

## Which hive to report on.
@export var allegiance: int = 0

## Longest state tally drawn, so a large swarm cannot overflow the panel.
@export var max_states_listed: int = 3

@export_group("Colours")
@export var background_colour: Color = Color(Palette.PANEL_BACKING, 0.6)
@export var frame_colour: Color = Color(Palette.PLAYER, 0.6)
@export var text_colour: Color = Palette.PLAYER
@export var intent_colour: Color = Palette.BARNACLE
@export var dim_colour: Color = Color(Palette.PLAYER, 0.55)

var _swarm: Swarm
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


## Resolved on first draw, never in _ready(): Godot readies siblings in scene
## order, and this Control can be ready before the swarm it reports on.
func _resolve() -> void:
	if _swarm != null and not is_instance_valid(_swarm):
		_swarm = null
	if _swarm != null:
		return
	var found: Array = get_tree().get_nodes_in_group(
		Swarm.GROUP_PREFIX + str(allegiance)
	)
	if not found.is_empty():
		_swarm = found[0] as Swarm


func _draw() -> void:
	_resolve()

	draw_rect(Rect2(Vector2.ZERO, size), background_colour, true)
	draw_rect(Rect2(Vector2.ZERO, size), frame_colour, false, 1.0)

	if _swarm == null:
		return

	draw_string(
		_font, Vector2(6.0, 12.0), Strings.SWARM,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_colour
	)

	# The order, right-aligned against the heading.
	var order: String = Swarm.Intent.keys()[_swarm.intent]
	var order_width: float = _font.get_string_size(
		order, HORIZONTAL_ALIGNMENT_LEFT, -1, 10
	).x
	draw_string(
		_font, Vector2(size.x - order_width - 6.0, 12.0), order,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, intent_colour
	)

	if _swarm.units.is_empty():
		draw_string(
			_font, Vector2(6.0, 26.0), Strings.SWARM_EMPTY,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dim_colour
		)
		return

	_draw_state_tally(_state_counts(), 26.0)


## How many drones are in each state, highest first.
##
## Returns an Array of [name, count] pairs rather than a Dictionary, because
## the draw order matters and Dictionary order does not survive sorting.
func _state_counts() -> Array:
	var counts: Dictionary = {}
	for unit in _swarm.units:
		if not is_instance_valid(unit):
			continue
		var machine: StateMachine = unit.get_node_or_null(
			"StateMachine"
		) as StateMachine
		if machine == null or machine.current_state == null:
			continue
		var state: String = str(machine.current_state.name)
		counts[state] = counts.get(state, 0) + 1

	var pairs: Array = []
	for state in counts:
		pairs.append([state, counts[state]])
	pairs.sort_custom(func(a, b): return a[1] > b[1])
	return pairs


## One line per state, "COUNT NAME", truncated to [member max_states_listed].
func _draw_state_tally(pairs: Array, top: float) -> void:
	var listed: int = mini(pairs.size(), max_states_listed)
	for i in listed:
		var pair: Array = pairs[i]
		draw_string(
			_font, Vector2(6.0, top + float(i) * 10.0),
			"%d %s" % [pair[1], str(pair[0]).to_upper()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_colour
		)

	# Whatever did not fit, summed, so the counts still add up to the swarm.
	if pairs.size() <= listed:
		return
	var remainder: int = 0
	for i in range(listed, pairs.size()):
		remainder += pairs[i][1]
	draw_string(
		_font, Vector2(6.0, top + float(listed) * 10.0),
		"%d other" % remainder,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, dim_colour
	)
