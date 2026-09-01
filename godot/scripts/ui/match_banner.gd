## The end-of-match announcement.
##
## Listens for [signal MatchState.finished] and draws the result across the
## screen.
class_name MatchBanner
extends Control

## Which side the player commands, so the result reads as won or lost.
@export var player_allegiance: int = 0

@export_group("Timing")

## Seconds to wait after the match resolves before the text appears.
@export var delay_seconds: float = 0.9

## Seconds the text takes to settle once it starts.
@export var rise_seconds: float = 0.6

## How far above its resting place the text starts, in pixels.
@export var rise_distance: float = 14.0

@export_group("Text")

@export var victory_text: String = "SWARM ASCENDANT"
@export var defeat_text: String = "HIVE COLLAPSED"

## The smaller line under the result.
@export var victory_subtitle: String = "the belt is yours"
@export var defeat_subtitle: String = "the Matriarch is lost"

@export var title_size: int = 28
@export var subtitle_size: int = 10

@export_group("Colours")
@export var victory_colour: Color = Palette.PLAYER
@export var defeat_colour: Color = Color(1.0, 0.42, 0.30)

## The winning side, or -1 while the match is still running.
var winner: int = -1

var _age: float = 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	# Nothing to draw until the match ends, and no reason to redraw either.
	set_process(false)
	# Deferred: MatchState may not be in the tree yet.
	call_deferred("_connect_to_match")


func _connect_to_match() -> void:
	var match_state: MatchState = get_tree().get_root().find_child(
		"MatchState", true, false
	) as MatchState
	if match_state == null:
		push_warning("%s: no MatchState found; the result will not be shown." % name)
		return
	match_state.finished.connect(_on_finished)


func _on_finished(winner_allegiance: int) -> void:
	winner = winner_allegiance
	_age = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	if winner < 0:
		return

	# Held back by delay_seconds.
	var elapsed: float = _age - delay_seconds
	if elapsed <= 0.0:
		return

	# Cubic ease-out.
	var t: float = clampf(elapsed / maxf(rise_seconds, 0.001), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)

	var won: bool = winner == player_allegiance
	var tint: Color = victory_colour if won else defeat_colour
	var title: String = victory_text if won else defeat_text
	var subtitle: String = victory_subtitle if won else defeat_subtitle

	# Alpha and position share the same curve, so the text fades in as it falls
	# rather than appearing and then moving.
	tint.a = eased
	var drop: float = (1.0 - eased) * -rise_distance

	var centre_y: float = size.y * 0.38
	draw_string(
		_font, Vector2(0.0, centre_y + drop), title,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, title_size, tint
	)

	# Subtitle starts half a rise_seconds after the title.
	var sub_t: float = clampf((elapsed - rise_seconds * 0.5) / maxf(rise_seconds, 0.001), 0.0, 1.0)
	if sub_t <= 0.0:
		return
	var sub_eased: float = 1.0 - pow(1.0 - sub_t, 3.0)
	var sub_tint: Color = tint
	sub_tint.a = sub_eased * 0.75
	draw_string(
		_font, Vector2(0.0, centre_y + 18.0 + (1.0 - sub_eased) * -rise_distance * 0.5),
		subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, subtitle_size, sub_tint
	)
