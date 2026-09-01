## The Matriarch's voice, synthesised from the Thargoid's measured resonances.
##
## Partials are the average spectrum of 1278 loud frames across a compilation
## of isolated Thargoid recordings. See docs/audio/analysis.md.
class_name EngineHum
extends AudioStreamPlayer

## One measured partial.
class Partial extends RefCounted:
	var hz: float
	var db: float

	static func at(frequency: float, level_db: float) -> Partial:
		var made: Partial = Partial.new()
		made.hz = frequency
		made.db = level_db
		return made


## The measured partials.
var partials: Array = []

@export_group("Movement")

## How much of the low end to keep, below [member low_knee].
@export_range(0.0, 1.0) var low_weight: float = 0.25

## Frequency below which [member low_weight] applies, in Hz.
@export var low_knee: float = 200.0

@export_group("Response")

## How far the pitch glides between rest and full speed.
@export_range(0.0, 2.0) var pitch_range: float = 0.85

## Output level.
@export_range(0.0, 1.0) var master: float = 0.16

## Throttle below which the drive is silent, as a fraction of full speed.
@export_range(0.0, 1.0) var cutoff_throttle: float = 0.08

## How much of the throttle range above the cutoff is spent fading in.
@export_range(0.001, 0.5) var cutoff_fade: float = 0.06

## How quickly the sound follows the throttle.
@export var response_speed: float = 2.5

@export_group("Source")

## The ship whose speed drives the sound. Found by group when unset.
@export var ship: Ship

## Which side's commander to follow.
@export var allegiance: int = 0

## Smoothed throttle, 0 at rest and 1 at full speed.
var throttle: float = 0.0

## Sample rate of the rendered loop, in Hz. Content stops below 1.2 kHz.
@export var loop_rate: int = 22050

func _ready() -> void:
	_build_partials()
	stream = _render_loop()


## The Thargoid's resonances, as measured across the whole clean source.
func _build_partials() -> void:
	partials = [
		# Low anchors, attenuated by low_weight.
		Partial.at(93.8, -1.2),
		Partial.at(175.8, -5.6),
		# The two loudest partials, 23 Hz apart; they beat against each other.
		Partial.at(246.1, 0.0),
		Partial.at(269.5, -0.2),
		Partial.at(310.5, -5.1),
		# Upper resonances.
		Partial.at(386.7, -7.9),
		Partial.at(421.9, -6.1),
		Partial.at(468.8, -5.2),
		Partial.at(527.3, -13.4),
		Partial.at(615.2, -14.7),
		Partial.at(662.1, -15.7),
		Partial.at(703.1, -11.9),
		Partial.at(738.3, -8.8),
		Partial.at(820.3, -14.8),
		Partial.at(937.5, -16.3),
		Partial.at(978.5, -13.6),
		Partial.at(1048.8, -16.4),
	]


## Render one second of the engine into a seamless looping stream.
func _render_loop() -> AudioStreamWAV:
	var mix: PackedFloat32Array = ToneBank.buffer(loop_rate)

	for partial in partials:
		var amplitude: float = db_to_linear(partial.db)
		if partial.hz < low_knee:
			amplitude *= low_weight
		ToneBank.add_tone(mix, loop_rate, partial.hz, amplitude)

	return ToneBank.to_stream(mix, loop_rate)


## Gate the loop on throttle, then set pitch and level from it.
func _process(delta: float) -> void:
	_track_ship(delta)

	var gate: float = clampf(
		(throttle - cutoff_throttle) / cutoff_fade, 0.0, 1.0
	)
	if gate <= 0.0:
		if playing:
			stop()
		return
	if not playing:
		play()

	pitch_scale = 1.0 + throttle * pitch_range
	volume_db = linear_to_db(maxf(master * gate, 0.0001))


## Follow the ship's speed, smoothed.
func _track_ship(delta: float) -> void:
	if ship == null:
		ship = get_tree().get_first_node_in_group(
			Ship.GROUP_PREFIX + str(allegiance)
		) as Ship
	var target: float = 0.0
	if ship != null and ship.max_speed > 0.0:
		target = clampf(ship.velocity.length() / ship.max_speed, 0.0, 1.0)
	throttle = lerpf(throttle, target, minf(delta * response_speed, 1.0))
