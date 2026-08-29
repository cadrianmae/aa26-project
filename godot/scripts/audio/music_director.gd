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


func _ready() -> void:
	_full_volume_db = volume_db
	play_phase(Phase.LAUNCH)


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
	if _fade_tween != null:
		_fade_tween.kill()
	if next_stream == null:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "volume_db", _SILENCE_DB, fade_seconds)
		_fade_tween.tween_callback(stop)
		return
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
