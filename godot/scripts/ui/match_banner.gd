## The end-of-match announcement.
##
## Listens for [signal MatchState.finished] and draws the result across the
## screen. Until this existed the match simply stopped: the losing Matriarch
## exploded, the music changed to VICTORY or DEFEAT, and nothing said which had
## happened -- so the two most important seconds in the game were the two least
## legible.
##
## Drawn rather than composed from Label nodes, like the rest of this HUD, so
## it sits in the same 640x360 space as the radar and needs no font asset.
##
## The animation is deliberately slow to arrive. A result that snaps up the
## instant the hull pops competes with the explosion for attention; letting the
## blast land first and the text follow gives each its own moment.
class_name MatchBanner
extends Control

## Which side the player commands, so the result reads as won or lost.
@export var player_allegiance: int = 0

@export_group("Timing")

## Seconds to wait after the match resolves before the text appears.
##
## Long enough for the explosion to read as the cause. Shorter than about half
## a second and the banner and the blast arrive together and fight.
@export var delay_seconds: float = 0.9

## Seconds the text takes to settle once it starts.
@export var rise_seconds: float = 0.6

## How far above its resting place the text starts, in pixels.
##
## It falls INTO position rather than rising out of one: downward motion
## settling reads as conclusive, where upward motion reads as something
## beginning.
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
@export var victory_colour: Color = Color(0.435, 0.812, 0.353)
@export var defeat_colour: Color = Color(1.0, 0.42, 0.30)

## The winning side, or -1 while the match is still running.
var winner: int = -1

var _age: float = 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	# Nothing to draw until the match ends, and no reason to redraw either.
	set_process(false)
	# Deferred for the reason everything else here is: MatchState may not have
	# joined the tree yet when this Control is ready.
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

	# Held back until the explosion has had its moment.
	var elapsed: float = _age - delay_seconds
	if elapsed <= 0.0:
		return

	# Eased so it decelerates into place: linear motion stopping dead reads as
	# a jump cut, where easing out reads as settling.
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

	# The subtitle trails the title by a beat, so the eye reads them in order
	# instead of taking both at once.
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
