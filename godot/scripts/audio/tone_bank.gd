## Renders sine partials into a seamlessly looping audio stream.
##
## Both engine sounds are built the same way -- sum a measured set of partials,
## normalise, wrap in a looping stream -- so the rendering lives here once
## rather than in each of them.
##
## The rendering happens ONCE, at load. An earlier version synthesised every
## sample live in _process, which cost around 300 000 sin() calls per frame
## between the two players and dropped the game to 3 FPS. Worse, it fed back:
## a slower frame left a larger gap in the audio buffer, which took longer to
## fill, which slowed the next frame further.
##
## The buffer is exactly one second long, and that is what makes the loop
## join free. A tone at a whole number of Hz completes a whole number of
## cycles in one second, so it returns to its starting phase at the loop point
## and the seam is inaudible. The price is rounding each measured frequency to
## the nearest Hz: 562.5 becomes 562, which is a shift of 0.09 percent and far
## below what anyone can hear.
##
## Modulation slower than about 1 Hz cannot be baked in -- it does not fit in
## a one-second loop. Those run per frame instead, from the players
## themselves, where the cost is one sine per frame.
class_name ToneBank
extends RefCounted


## An empty one-second mix buffer at the given rate.
static func buffer(rate: int) -> PackedFloat32Array:
	var mix: PackedFloat32Array = PackedFloat32Array()
	mix.resize(rate)
	return mix


## Sum one sine wave into the mix.
##
## The frequency is rounded to a whole number of Hz so the tone closes cleanly
## at the loop point.
static func add_tone(
	mix: PackedFloat32Array, rate: int, hz: float, amplitude: float
) -> void:
	var step: float = TAU * roundf(hz) / float(rate)
	for i in mix.size():
		mix[i] += sin(step * float(i)) * amplitude


## Multiply the mix by an amplitude modulation at the given rate.
##
## Also rounded to a whole number of Hz, for the same reason: a modulation
## that did not close would click at the loop point.
static func modulate(
	mix: PackedFloat32Array, rate: int, hz: float, depth: float
) -> void:
	if depth <= 0.0:
		return
	var step: float = TAU * roundf(hz) / float(rate)
	for i in mix.size():
		mix[i] *= 1.0 - depth * (0.5 + 0.5 * sin(step * float(i)))


## Normalise the mix and wrap it in a looping 16-bit mono stream.
static func to_stream(mix: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	# Normalised rather than scaled by a guessed constant. Summed partials
	# peak at whatever their phases happen to produce, so the only safe
	# headroom is a measured one.
	var peak: float = 0.0
	for value in mix:
		peak = maxf(peak, absf(value))
	var scale: float = 0.92 / maxf(peak, 0.0001)

	var data: PackedByteArray = PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		data.encode_s16(i * 2, int(clampf(mix[i] * scale, -1.0, 1.0) * 32767.0))

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = mix.size()
	wav.data = data
	return wav
