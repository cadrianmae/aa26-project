## Owns the single music track for the whole game, chosen by phase.
##
## This exists as one node rather than an AudioStreamPlayer per phase because
## the game's music changes as the phase changes, not because several tracks
## should ever play together. A single owner makes "only one track audible"
## structurally true; scattered players each need their own discipline about
## stopping the others, and that discipline always eventually lapses,
## producing overlapping music. Centralising the swap here removes the chance
## of that bug rather than relying on every caller to avoid it.
##
## PATROL, FLEE, VICTORY, and DEFEAT exist ahead of the game logic that will
## trigger them, so all seven placeholder tracks have a phase to audition
## through in the editor before that logic is written.
class_name MusicDirector
extends AudioStreamPlayer

## The phases the game can be in. More will be added as the game grows.
enum Phase { LAUNCH, HARVEST, COMBAT, PATROL, FLEE, VICTORY, DEFEAT }

## Track for the launch phase.
@export var launch_theme: AudioStream

## Track for the harvest phase. Left unassigned until that phase exists.
@export var harvest_theme: AudioStream

## Track for the combat phase. Left unassigned until that phase exists.
@export var combat_theme: AudioStream

## Track for the patrol phase. Left unassigned until that phase exists.
@export var patrol_theme: AudioStream

## Track for the flee phase. Left unassigned until that phase exists.
@export var flee_theme: AudioStream

## Track for the victory phase. Left unassigned until that phase exists.
@export var victory_theme: AudioStream

## Track for the defeat phase. Left unassigned until that phase exists.
@export var defeat_theme: AudioStream

## How long a cross-fade between tracks takes, in seconds.
@export var fade_seconds: float = 1.5

## The phase currently playing (or fading toward), readable from outside.
var current_phase: Phase = Phase.LAUNCH

## The node's configured full volume, captured on ready so fade-in has a
## target that is not just an assumed 0.0 dB.
var _full_volume_db: float = 0.0

## The silence floor used for fade-out. volume_db is logarithmic, so 0.0 is
## full volume and this is "as good as silent", not the bottom of the scale.
const _SILENCE_DB: float = -60.0

## The tween currently driving volume_db, kept so a new fade can kill any
## fade still in flight rather than fighting it for control of volume_db.
var _fade_tween: Tween

## Seconds since the track last changed, for the minimum hold.
var _since_change: float = 999.0

## Seconds since the last heartbeat line.
var _since_log: float = 0.0

@export_group("Situation")

## Which swarm's situation the score follows.
@export var watched_allegiance: int = 0

## How often the swarm is sampled, in seconds. The score reacts to the
## situation, not to the frame: sampling at 60 Hz would let one unit briefly
## entering Flee flip the track and flip it back, which reads as a glitch.
@export var sample_interval: float = 0.5

## Least time a track must play before another may replace it, in seconds.
##
## The phase is read from what the swarm is DOING, and that changes constantly
## -- a single drone entering Flee for one second was enough to swing the whole
## soundtrack and swing it straight back. Logged phase changes at 1.7s, 2.2s,
## 4.2s: music that re-decides every two seconds is not scoring the game, it is
## reporting noise.
##
## Longer than the cross-fade, necessarily: a hold shorter than a fade means a
## new change can begin before the previous one has finished arriving, which is
## how the director ended up cross-fading FROM a track it had never started.
@export var minimum_hold_seconds: float = 10.0

@export_group("Debug")

## Print every phase decision and every fade to the console.
##
## The music is driven by what the swarm is DOING, which changes constantly, so
## when it misbehaves the question is never "is the fade broken" but "what did
## the director think was happening". This answers that.
@export var log_music: bool = false

## Seconds between status lines while nothing is changing.
##
## The event lines only fire when something happens, which leaves long silences
## in the log during exactly the stretches worth understanding -- a track
## holding for ten seconds prints nothing, so the log cannot distinguish
## "holding correctly" from "stopped working". A heartbeat fills that in.
##
## 0 turns the heartbeat off and leaves only the event lines.
@export var log_interval_seconds: float = 2.0

## Show the director's state on screen through DebugDraw2D.
##
## The console log answers what happened AFTER the fact; this answers what is
## happening now, which is the question while playing. It reports the phase the
## swarm is asking for alongside the one actually playing -- and those two
## differing is the normal, correct case during a hold, not a fault.
@export var draw_gizmos: bool = true

## Fraction of the swarm that must be fleeing before the score panics.
##
## Deliberately low. One unit running is noise, but a fifth of the swarm
## running is the player's cue that something is wrong -- and the music
## should tell them before they have counted.
@export_range(0.0, 1.0) var flee_fraction: float = 0.2

## The player's ship. Resolved on first sample alongside the swarm.
@export var ship: Ship

## Fraction of its starting health the ship must fall below before the score
## treats the player personally as the situation.
@export_range(0.0, 1.0) var ship_hurt_fraction: float = 0.4

## Which phase each unit state contributes to. States absent from this map
## contribute nothing, which is what lets the six stub states stay silent
## until they do something worth scoring.
const STATE_PHASES: Dictionary = {
	"Flee": Phase.FLEE,
	"Engage": Phase.COMBAT,
	"Harvest": Phase.HARVEST,
	"Deposit": Phase.HARVEST,
	"Patrol": Phase.PATROL,
}

## Phases that win on presence rather than on majority, most urgent first.
## Danger is not a democracy: a swarm that is mostly harvesting while being
## shot at is in combat, whatever the majority is doing.
const URGENT_PHASES: Array = [Phase.FLEE, Phase.COMBAT]

## The swarm being watched. Resolved on first sample, not in _ready(), because
## Godot readies siblings in scene order and the swarm may not have joined its
## group yet. Same reason as SwarmCoordinator._resolve_targets().
var _swarm: Swarm

## Seconds since the last sample.
var _since_sample: float = 0.0

## The ship's health when first seen, so "hurt" is measured against how much
## it started with rather than against a number hard-coded here.
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

	# Held. The phase itself still tracks the swarm honestly -- it is only the
	# AUDIO that refuses to be dragged around by a transient.
	# Not logged here. This fires twice a second for the whole hold, and the
	# heartbeat already reports what is wanted and how long is left -- printing
	# both buried the useful line under twenty identical ones.
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
##
## The ship has no state machine -- it is flown by the player, so there is no
## state name to read. Its situation has to be inferred from its circumstances
## instead: whether something dangerous is on top of it, and whether it is
## badly hurt.
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

	# Danger to the commander is combat whatever the drones are doing.
	var threat: Threat = Threat.nearest_to(get_tree(), ship.global_position)
	if threat != null:
		if ship.global_position.distance_to(threat.global_position) <= threat.danger_radius:
			return Phase.COMBAT

	# A badly hurt commander is the situation, even with no threat in reach:
	# the player has just survived something and should still hear it.
	if _ship_full_health > 0.0 and ship.health / _ship_full_health < ship_hurt_fraction:
		return Phase.FLEE

	return null


## Work out what phase the swarm's behaviour amounts to right now.
##
## Reads the units' actual states rather than the swarm's intent. An order is
## what the player asked for; a state is what a unit decided to do about it,
## and the second is what the player should hear. A swarm ordered to harvest
## while a threat scatters it is not harvesting, whatever the order says.
##
## Falls back to the phase already playing when the swarm is empty or missing,
## so an unresolved reference holds the current track rather than snapping the
## score back to LAUNCH.
func situation() -> Phase:
	if _swarm == null:
		var found: Array = get_tree().get_nodes_in_group(
			"swarm_" + str(watched_allegiance)
		)
		if found.is_empty():
			return current_phase
		_swarm = found[0] as Swarm

	# The player's own circumstances outrank the swarm's. A commander being
	# shot at while the drones calmly harvest is not a harvesting scene, and
	# the swarm's states alone would never say so -- the drones cannot see
	# what is happening to the ship.
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

	# Fleeing is scored by fraction, so a scattering minority still panics
	# the music. The other urgent phase only needs one unit in it.
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

	# Nothing to cross-fade TO if it is already playing. Several phases share
	# a track -- HARVEST and PATROL are the same piece, as are COMBAT and
	# FLEE -- so a swarm drifting between two of them changed phase without
	# changing music, and the director dutifully faded the track out and back
	# in to itself. From the player's side that read as the loop fading every
	# few seconds for no reason.
	#
	# Compared by stream, not by phase: the phase genuinely did change, and
	# current_phase above is updated to say so. It is the AUDIO that has no
	# reason to move.
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
##
## Drawn every frame rather than on the sample interval, so the hold countdown
## runs smoothly instead of stepping twice a second.
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

	# What the swarm is asking for RIGHT NOW, which is only sampled twice a
	# second for the decision but can be read continuously for the display.
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
##
## Printed on an interval rather than on change, so a long hold is visibly a
## hold rather than an absence of output. The "wants" column is the useful one:
## it differing from the playing phase is the normal state during a hold, and
## seeing the countdown run down is how a held track is distinguished from a
## stuck one.
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
