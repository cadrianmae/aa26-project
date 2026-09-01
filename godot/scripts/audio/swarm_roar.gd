## The swarm's collective sound: one player for the whole swarm.
##
## Uses the same measured partials as [EngineHum], shifted up by
## [member size_pitch].
class_name SwarmRoar
extends AudioStreamPlayer

## One measured partial of the swarm's comb.
class Partial extends RefCounted:
	var hz: float
	var db: float

	static func at(frequency: float, level_db: float) -> Partial:
		var made: Partial = Partial.new()
		made.hz = frequency
		made.db = level_db
		return made


## The measured comb.
var partials: Array = []

@export_group("Texture")

## How many detuned copies of the whole comb to sum.
@export_range(1, 8) var voices: int = 3

## How far apart the copies are spread, in Hz.
@export var spread_hz: float = 3.4

@export_group("Flutter")

## The measured 35.2 Hz amplitude modulation.
@export var flutter_hz: float = 35.2

## Depth of the flutter, 0 to 1.
@export_range(0.0, 1.0) var flutter_depth: float = 0.16

@export_group("Response")

## Swarm size at which the roar is at full volume.
@export var full_swarm: int = 20

## How far away the swarm can be heard, in world units.
@export var audible_range: float = 220.0

## How much faster the drones run at full speed.
@export_range(0.0, 2.0) var pitch_range: float = 0.55

## Fixed pitch multiplier applied to the whole comb.
@export_range(1.0, 4.0) var size_pitch: float = 2.1

## Output level.
@export_range(0.0, 1.0) var master: float = 0.18

## How quickly the sound follows the swarm.
@export var response_speed: float = 1.6

@export_group("Source")

## Which swarm to listen to.
@export var allegiance: int = 0

## Smoothed loudness, 0 when far or dead, 1 when close and numerous.
var presence: float = 0.0

## Smoothed speed of the swarm, driving pitch.
var effort: float = 0.0

## Sample rate of the rendered loop, in Hz. Content stops below 1.1 kHz.
@export var loop_rate: int = 22050

var _swarm: Swarm
var _listener: Node3D


func _ready() -> void:
	_build_partials()
	stream = _render_loop()
	play()


## The measured peaks, in frequency order.
func _build_partials() -> void:
	partials = [
		Partial.at(310.5, -9.1),
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


## Render one second of the swarm into a seamless looping stream.
##
## The 35.2 Hz flutter is baked into the loop; it is the only modulation
## applied, and it is too fast to run per frame without aliasing against the
## frame rate.
func _render_loop() -> AudioStreamWAV:
	var mix: PackedFloat32Array = ToneBank.buffer(loop_rate)

	for partial in partials:
		var amplitude: float = db_to_linear(partial.db) / float(voices)
		for v in voices:
			var offset: float = (
				float(v) / float(maxi(voices - 1, 1)) - 0.5
			) * spread_hz
			ToneBank.add_tone(
				mix, loop_rate, partial.hz * size_pitch + offset, amplitude
			)

	ToneBank.modulate(mix, loop_rate, flutter_hz, flutter_depth)

	return ToneBank.to_stream(mix, loop_rate)


## Set pitch from the swarm's speed and level from its presence.
func _process(delta: float) -> void:
	_track_swarm(delta)
	pitch_scale = 1.0 + effort * pitch_range
	volume_db = linear_to_db(maxf(master * presence, 0.0001))


## Follow the swarm's size, distance and speed.
func _track_swarm(delta: float) -> void:
	if _swarm == null:
		var found: Array = get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(allegiance))
		if not found.is_empty():
			_swarm = found[0] as Swarm
	if _listener == null:
		_listener = get_tree().get_first_node_in_group(
			Ship.GROUP_PREFIX + str(allegiance)
		) as Node3D

	var target_presence: float = 0.0
	var target_effort: float = 0.0

	if _swarm != null and not _swarm.units.is_empty():
		var count: float = clampf(
			float(_swarm.units.size()) / float(maxi(full_swarm, 1)), 0.0, 1.0
		)
		var nearest: float = audible_range
		var speed_total: float = 0.0
		var alive: int = 0
		for drone in _swarm.units:
			if drone == null or not is_instance_valid(drone):
				continue
			alive += 1
			speed_total += drone.velocity.length() / maxf(drone.max_speed, 0.001)
			if _listener != null:
				nearest = minf(
					nearest,
					_listener.global_position.distance_to(drone.global_position)
				)

		var proximity: float = 1.0 - clampf(nearest / audible_range, 0.0, 1.0)
		target_presence = count * proximity * proximity
		if alive > 0:
			target_effort = clampf(speed_total / float(alive), 0.0, 1.0)

	presence = lerpf(presence, target_presence, minf(delta * response_speed, 1.0))
	effort = lerpf(effort, target_effort, minf(delta * response_speed, 1.0))
