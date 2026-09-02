## The hive's Meta-Alloy count, and what it can afford.
##
## Draws the raw total and a segmented bar of progress toward the next drone.
class_name ResourceReadout
extends Control

## Which side's economy to report.
@export var allegiance: int = 0

@export_group("Colours")
@export var background_colour: Color = Color(Palette.PANEL_BACKING, 0.6)
@export var frame_colour: Color = Color(Palette.PLAYER, 0.6)
@export var text_colour: Color = Palette.PLAYER
@export var alloy_colour: Color = Palette.BARNACLE
@export var bar_empty_colour: Color = Color(Palette.PLAYER, 0.22)

## Segments in the "next drone" bar.
@export var segments: int = 10

var _hatchery: Hatchery
var _swarm: Swarm
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


## Resolved on first draw, never in _ready(): Godot readies siblings in scene
## order, and this Control can be ready before the ship carrying the hatchery.
func _resolve() -> void:
	if _hatchery == null:
		_hatchery = Hatchery.for_allegiance(get_tree(), allegiance)
	if _swarm == null:
		var found: Array = get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(allegiance))
		if not found.is_empty():
			_swarm = found[0] as Swarm


func _draw() -> void:
	_resolve()

	draw_rect(Rect2(Vector2.ZERO, size), background_colour, true)
	draw_rect(Rect2(Vector2.ZERO, size), frame_colour, false, 1.0)

	if _hatchery == null:
		return

	var alloys: float = _hatchery.alloys
	var cost: float = maxf(_hatchery.drone_cost, 0.001)

	draw_string(
		_font, Vector2(6.0, 12.0), Strings.ALLOY, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		text_colour
	)
	var total: String = "%d" % floori(alloys)
	var total_width: float = _font.get_string_size(
		total, HORIZONTAL_ALIGNMENT_LEFT, -1, 14
	).x
	draw_string(
		_font, Vector2(size.x - total_width - 6.0, 14.0), total,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, alloy_colour
	)

	# Progress toward the next drone, as segments.
	var fraction: float = clampf(fposmod(alloys, cost) / cost, 0.0, 1.0)
	# At the drone cap the bar reads full, not empty.
	if _swarm != null and _swarm.units.size() >= _hatchery.max_drones:
		fraction = 1.0
	var lit: int = int(round(fraction * segments))

	var bar_top: float = size.y - 12.0
	var bar_width: float = size.x - 12.0
	var segment_width: float = bar_width / float(segments)
	for i in segments:
		var x: float = 6.0 + segment_width * float(i)
		draw_rect(
			Rect2(x, bar_top, segment_width - 1.5, 4.0),
			alloy_colour if i < lit else bar_empty_colour,
			true
		)

	var swarm_size: int = _swarm.units.size() if _swarm else 0
	draw_string(
		_font, Vector2(6.0, bar_top - 3.0),
		"%s %d/%d" % [Strings.SWARM, swarm_size, _hatchery.max_drones],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_colour
	)
