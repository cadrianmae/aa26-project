## Owns the single music track for the whole game, chosen by phase.
class_name MusicDirector
extends AudioStreamPlayer

## The phases the game can be in.
enum Phase { LAUNCH, HARVEST, COMBAT, PATROL, FLEE, VICTORY, DEFEAT }

## Track for the launch phase.
@export var launch_theme: AudioStream

## Track for the harvest phase.
@export var harvest_theme: AudioStream

## Track for the combat phase.
@export var combat_theme: AudioStream

## Track for the patrol phase.
@export var patrol_theme: AudioStream

## Track for the flee phase.
@export var flee_theme: AudioStream

## Track for the victory phase.
@export var victory_theme: AudioStream

## Track for the defeat phase.
@export var defeat_theme: AudioStream

## How long a cross-fade between tracks takes, in seconds.
@export var fade_seconds: float = 1.5

## The phase currently playing (or fading toward), readable from outside.
var current_phase: Phase = Phase.LAUNCH

## The node's configured full volume, captured on ready.
var _full_volume_db: float = 0.0

## The silence floor used for fade-out. volume_db is logarithmic, so 0.0 is
## full volume and this is "as good as silent", not the bottom of the scale.
const _SILENCE_DB: float = -60.0

## The tween currently driving volume_db; killed before a new fade starts.
var _fade_tween: Tween

## Seconds since the track last changed, for the minimum hold.
var _since_change: float = 999.0

## Seconds since the last heartbeat line.
var _since_log: float = 0.0

@export_group("Situation")

## Which swarm's situation the score follows.
@export var watched_allegiance: int = 0

## How often the swarm is sampled, in seconds.
@export var sample_interval: float = 0.5

## Least time a track must play before another may replace it, in seconds.
##
## Must exceed [member fade_seconds], or a new fade can start before the
## previous one finishes.
@export var minimum_hold_seconds: float = 10.0

@export_group("Debug")

## Print every phase decision and every fade to the console.
@export var log_music: bool = false

## Seconds between status lines while nothing is changing.
##
## 0 turns the heartbeat off and leaves only the event lines.
@export var log_interval_seconds: float = 2.0

## Show the director's state on screen through DebugDraw2D.
@export var draw_gizmos: bool = true

## Fraction of the swarm that must be fleeing before the score panics.
@export_range(0.0, 1.0) var flee_fraction: float = 0.2

## The player's ship. Resolved on first sample alongside the swarm.
@export var ship: Ship

## Fraction of its starting health the ship must fall below before the score
## treats the player personally as the situation.
@export_range(0.0, 1.0) var ship_hurt_fraction: float = 0.4

## Which phase each unit state contributes to. States absent from this map
## contribute nothing.
const STATE_PHASES: Dictionary = {
	"Flee": Phase.FLEE,
	"Engage": Phase.COMBAT,
	"Harvest": Phase.HARVEST,
	"Deposit": Phase.HARVEST,
	"Patrol": Phase.PATROL,
}

## Phases that win on presence rather than on majority, most urgent first.
const URGENT_PHASES: Array = [Phase.FLEE, Phase.COMBAT]

## The swarm being watched. Resolved on first sample, not in _ready(): Godot
## readies siblings in scene order, so it may not have joined its group yet.
var _swarm: Swarm

## Seconds since the last sample.
var _since_sample: float = 0.0

## The ship's health when first seen.
var _ship_full_health: float = 0.0


func _ready() -> void:
	_full_volume_db = volume_db
	play_phase(Phase.LAUNCH)


func _process(delta: float) -> void:
	_since_sample += delta
	_since_change += delta
	_since_log += delta

	if draw_gizmos:
		_draw_gizmos()

	if log_music and log_interval_seconds > 0.0 and _since_log >= log_interval_seconds:
		_since_log = 0.0
		_log_status()

	if _since_sample < sample_interval:
		return
	_since_sample = 0.0
	var wanted: Phase = situation()

	if wanted != current_phase and _since_change < minimum_hold_seconds:
		return

	if log_music and wanted != current_phase:
		print("[Music] %6.1fs  %s -> %s" % [
			Time.get_ticks_msec() / 1000.0,
			Phase.keys()[current_phase], Phase.keys()[wanted]
		])
	play_phase(wanted)


## The phase the player's own circumstances demand, or null if the ship has
## nothing urgent to say and the swarm should decide.
func _ship_situation() -> Variant:
	if ship == null:
		# "commander_", not "ship_": that is the group Ship._ready() joins.
		ship = get_tree().get_first_node_in_group(
			"commander_" + str(watched_allegiance)
		) as Ship
	if ship == null:
		return null
	if _ship_full_health <= 0.0:
		_ship_full_health = ship.health

	var threat: Threat = Threat.nearest_to(get_tree(), ship.global_position)
	if threat != null:
		if ship.global_position.distance_to(threat.global_position) <= threat.danger_radius:
			return Phase.COMBAT

	if _ship_full_health > 0.0 and ship.health / _ship_full_health < ship_hurt_fraction:
		return Phase.FLEE

	return null


## Work out what phase the swarm's behaviour amounts to right now.
##
## Falls back to the phase already playing when the swarm is empty or missing.
func situation() -> Phase:
	if _swarm == null:
		var found: Array = get_tree().get_nodes_in_group(
			"swarm_" + str(watched_allegiance)
		)
		if found.is_empty():
			return current_phase
		_swarm = found[0] as Swarm

	var ship_phase: Variant = _ship_situation()
	if ship_phase != null:
		return ship_phase

	var total: int = _swarm.units.size()
	if total == 0:
		return current_phase

	var counts: Dictionary = {}
	for unit in _swarm.units:
		var machine: StateMachine = unit.get_node_or_null("StateMachine") as StateMachine
		if machine == null or machine.current_state == null:
			continue
		var phase: Variant = STATE_PHASES.get(str(machine.current_state.name))
		if phase == null:
			continue
		counts[phase] = counts.get(phase, 0) + 1

	if counts.get(Phase.FLEE, 0) >= maxi(1, ceili(total * flee_fraction)):
		return Phase.FLEE
	for phase in URGENT_PHASES:
		if counts.get(phase, 0) > 0:
			return phase

	# Otherwise whichever ordinary activity most of the swarm is engaged in.
	var best_phase: Phase = Phase.LAUNCH
	var best_count: int = 0
	for phase in counts:
		if counts[phase] > best_count:
			best_count = counts[phase]
			best_phase = phase
	return best_phase


## Switches the music to the given phase, cross-fading between tracks.
##
## Re-requesting the current phase is a no-op so callers can call this freely
## on every phase check without restarting the track. A phase with no stream
## assigned fades out and stops rather than erroring or leaving stale audio.
func play_phase(phase: Phase) -> void:
	if phase == current_phase and playing:
		return
	current_phase = phase
	var next_stream: AudioStream = _stream_for_phase(phase)

	# Compared by stream, not by phase: several phases share a track.
	if next_stream != null and next_stream == stream and playing:
		if log_music:
			print("[Music]         same track, no fade (%s)" % [
				stream.resource_path.get_file()
			])
		return

	if _fade_tween != null:
		_fade_tween.kill()
	if next_stream == null:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "volume_db", _SILENCE_DB, fade_seconds)
		_fade_tween.tween_callback(stop)
		return
	if log_music:
		print("[Music]         CROSS-FADE %s -> %s  (playing=%s, vol %.1f)" % [
			stream.resource_path.get_file() if stream != null else "silence",
			next_stream.resource_path.get_file(), playing, volume_db
		])
	_since_change = 0.0
	_fade_tween = create_tween()
	if playing:
		_fade_tween.tween_property(self, "volume_db", _SILENCE_DB, fade_seconds)
	_fade_tween.tween_callback(_start_stream.bind(next_stream))
	_fade_tween.tween_property(self, "volume_db", _full_volume_db, fade_seconds)


## Returns the exported stream for the given phase.
func _stream_for_phase(phase: Phase) -> AudioStream:
	match phase:
		Phase.LAUNCH:
			return launch_theme
		Phase.HARVEST:
			return harvest_theme
		Phase.COMBAT:
			return combat_theme
		Phase.PATROL:
			return patrol_theme
		Phase.FLEE:
			return flee_theme
		Phase.VICTORY:
			return victory_theme
		Phase.DEFEAT:
			return defeat_theme
	return null


## Swaps in the given stream, loops it, and starts playback at silence so the
## following tween can fade it in.
func _start_stream(next_stream: AudioStream) -> void:
	if "loop" in next_stream:
		next_stream.loop = true
	stream = next_stream
	volume_db = _SILENCE_DB
	play()


## Report the director's state through the 2D debug overlay.
func _draw_gizmos() -> void:
	var track: String = "silence"
	if stream != null:
		track = stream.resource_path.get_file()

	DebugDraw2D.set_text("Music phase", Phase.keys()[current_phase])
	DebugDraw2D.set_text("Music track", track)
	DebugDraw2D.set_text(
		"Music level",
		"%.1f dB%s" % [volume_db, "  (fading)" if _fade_tween != null and _fade_tween.is_running() else ""]
	)

	var wanted: Phase = situation()
	if wanted == current_phase:
		DebugDraw2D.set_text("Music wants", "-")
	else:
		var remaining: float = maxf(minimum_hold_seconds - _since_change, 0.0)
		DebugDraw2D.set_text(
			"Music wants",
			"%s in %.1fs" % [Phase.keys()[wanted], remaining]
		)


## One line describing everything the director is doing.
func _log_status() -> void:
	var track: String = "silence"
	if stream != null:
		track = stream.resource_path.get_file()

	var wanted: Phase = situation()
	var note: String = "steady"
	if _fade_tween != null and _fade_tween.is_running():
		note = "FADING"
	elif wanted != current_phase:
		note = "wants %s in %.1fs" % [
			Phase.keys()[wanted], maxf(minimum_hold_seconds - _since_change, 0.0)
		]

	print("[Music] %6.1fs  %-8s  %-24s %6.1f dB  %s" % [
		Time.get_ticks_msec() / 1000.0,
		Phase.keys()[current_phase], track, volume_db, note
	])
