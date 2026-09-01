## Renders sine partials into a seamlessly looping audio stream.
##
## The buffer is exactly one second long, so a tone at a whole number of Hz
## completes a whole number of cycles and closes cleanly at the loop seam.
## Frequencies are rounded to the nearest Hz to guarantee that.
##
## Modulation slower than about 1 Hz does not fit in the loop; run it per frame.
class_name ToneBank
extends RefCounted

## Peak amplitude a rendered stream is normalised to, leaving clipping headroom.
const PEAK_TARGET: float = 0.92


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
## Rounded to whole Hz so the modulation closes at the loop point.
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
	var peak: float = 0.0
	for value in mix:
		peak = maxf(peak, absf(value))
	var scale: float = PEAK_TARGET / maxf(peak, 0.0001)

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
