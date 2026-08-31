## The Matriarch's voice, synthesised from the Thargoid's measured resonances.
##
## Not a sample. The partials below are the average spectrum of 1278 loud
## frames across a compilation of isolated Thargoid recordings -- see
## docs/audio/analysis.md. Averaging over many separate clips is what makes
## the set trustworthy: whatever a single clip happens to contain averages
## down, and only what the Thargoid resonates at EVERY time it makes a noise
## survives.
##
## The ratios between those resonances decide everything:
##
##      93.8 Hz   1.00       -1.2 dB
##     175.8 Hz   1.87       -5.6 dB
##     246.1 Hz   2.62        0.0 dB   the loudest
##     269.5 Hz   2.87       -0.2 dB   and its neighbour, 23 Hz away
##     310.5 Hz   3.31       -5.1 dB
##     421.9 Hz   4.50       -6.1 dB
##     468.8 Hz   5.00       -5.2 dB
##     738.3 Hz   7.87       -8.8 dB
##
## 1 : 1.87 : 2.62 : 2.87 : 3.31 : 4.50 : 5.00 is NOT a harmonic series. A
## series would be 1 : 2 : 3 : 4. This is the signature of a resonating shell
## -- a bell, not an engine -- and it is the whole character of the sound. A
## Thargoid ship is grown rather than built, so it has no cylinders, no firing
## rate, and nothing in it should imply combustion.
##
## The nearest everyday approximation is the whine a bus transmission makes
## slowing down -- a clear tone that GLIDES continuously with speed, over very
## little low end. Not the referent, but a good check: if it sounds like an
## engine idling rather than a gearbox gliding, it is wrong.
##
## That is why there is no tremolo here and no detuning. An earlier version had
## both, over a 46.9 Hz tone beating against 87.9 Hz, which is structurally
## what a diesel at idle sounds like -- two close low tones plus a slow swell.
## Worse, 46.9 Hz is not Thargoid at all: it was the human ship sharing the
## frame in the recording that measurement came from, and it appears nowhere in
## the clean source.
##
## What replaces them is glide. The pitch tracks speed across a wide range and
## nothing else modulates, so the sound rises and falls with the ship rather
## than pulsing on its own.
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
##
## The Thargoid's two lowest resonances are genuinely there in the source, but
## at full strength they read as an idling engine rather than a gliding one.
## Held well down so the tone carries the sound and the low end only anchors
## it. A deliberate departure from the measurement, and the only one.
@export_range(0.0, 1.0) var low_weight: float = 0.25

## Frequency below which [member low_weight] applies, in Hz.
@export var low_knee: float = 200.0

@export_group("Response")

## How far the pitch glides between rest and full speed.
##
## Wide, and this is the single most important number in the file. A gearbox
## whine is recognisable because its pitch tracks speed continuously across a
## broad range; a narrow range reads as a motor holding a note instead.
@export_range(0.0, 2.0) var pitch_range: float = 0.85

## Output level.
@export_range(0.0, 1.0) var master: float = 0.16

## Throttle below which the drive is silent, as a fraction of full speed.
##
## There is no idle. A Thargoid drive is either running or it is not, so below
## this the sound stops completely rather than settling to a hum.
@export_range(0.0, 1.0) var cutoff_throttle: float = 0.08

## How much of the throttle range above the cutoff is spent fading in.
##
## Small but not zero: a hard gate clicks when the ship hovers on the
## threshold, and this is narrow enough to still read as switching on.
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

## Sample rate of the rendered loop. Half the usual 44.1 kHz: nothing here
## exceeds 1.2 kHz, so 22 050 is far above what the content needs and halves
## both the render time and the memory.
@export var loop_rate: int = 22050

func _ready() -> void:
	_build_partials()
	# Rendered ONCE, then looped. The first version synthesised every sample in
	# _process, which cost 200 000 sin() calls per frame and dropped the game
	# to 3 FPS -- and got worse as it slowed, because a longer frame meant more
	# samples to fill. Baking the loop moves all of that to load time and
	# leaves per-frame cost at two property writes.
	#
	# The trade is that timbre can no longer change with throttle, only pitch
	# and level. For a sound whose character IS its glide, that is the part
	# worth keeping.
	stream = _render_loop()


## The Thargoid's resonances, as measured across the whole clean source.
##
## Every frequency and level is a row from that average. Nothing is rounded to
## a harmonic series, because the inharmonic spacing is the character.
func _build_partials() -> void:
	partials = [
		# The low anchors. Held down by low_weight -- see there for why.
		Partial.at(93.8, -1.2),
		Partial.at(175.8, -5.6),
		# The core. These two are the loudest things the Thargoid produces and
		# they sit 23 Hz apart, so they beat against each other on their own.
		# That beat is the sound's texture; nothing needs to be added for it.
		Partial.at(246.1, 0.0),
		Partial.at(269.5, -0.2),
		Partial.at(310.5, -5.1),
		# The upper resonances, at 4.5x and 5x the lowest. These carry the
		# whine, and they are what the glide is most audible on.
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
##
## The 1.46 Hz swell is NOT baked in: it does not fit in a one-second loop.
## It runs per frame instead, in _process.
func _render_loop() -> AudioStreamWAV:
	var mix: PackedFloat32Array = ToneBank.buffer(loop_rate)

	for partial in partials:
		var amplitude: float = db_to_linear(partial.db)
		if partial.hz < low_knee:
			amplitude *= low_weight
		ToneBank.add_tone(mix, loop_rate, partial.hz, amplitude)

	return ToneBank.to_stream(mix, loop_rate)


## Per frame the sound costs a gate test and two property writes. All of the
## synthesis happened once, at load.
func _process(delta: float) -> void:
	_track_ship(delta)

	var gate: float = clampf(
		(throttle - cutoff_throttle) / cutoff_fade, 0.0, 1.0
	)
	# Stopped outright below the cutoff rather than left playing at zero
	# volume, so a parked Matriarch costs nothing at all.
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
			"commander_" + str(allegiance)
		) as Ship
	var target: float = 0.0
	if ship != null and ship.max_speed > 0.0:
		target = clampf(ship.velocity.length() / ship.max_speed, 0.0, 1.0)
	throttle = lerpf(throttle, target, minf(delta * response_speed, 1.0))
