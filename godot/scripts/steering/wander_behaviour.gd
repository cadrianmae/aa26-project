## A slow, smoothly-varying push in no particular direction.
##
## Samples a shared value-noise field at a per-unit offset.
##
## Adapted in spirit from Reynolds, "Steering Behaviors For Autonomous
## Characters", the Wander behaviour.
class_name WanderBehaviour
extends SteeringBehaviour

## How hard the drift pushes, before [member weight] is applied.
@export var strength: float = 1.0

@export_group("Distance gating")

## Scale drift down when far from the objective, up as the unit closes.
@export var gate_by_distance: bool = true

## Inside this distance from its objective, the unit drifts at full strength.
@export var close_range: float = 30.0

## Beyond this, it holds formation and runs almost straight.
@export var far_range: float = 120.0

## How much drift survives at long range, as a fraction.
@export_range(0.0, 1.0) var far_strength: float = 0.12

## How quickly the direction changes, in noise units per second.
##
## Low: at high rates the noise decorrelates between frames and cancels itself
## out.
@export var drift_speed: float = 0.35

## Noise frequency. Larger makes the field vary faster in space, which here
## means faster in TIME, since the sample walks along one axis.
const NOISE_FREQUENCY: float = 0.5

## Each drone samples the same field at its own offset, so no two drift alike
## without needing a noise object each.
var _offset: float = 0.0

## Shared by every wandering unit: one field, sampled in different places.
static var _field: FastNoiseLite


func _ready() -> void:
	super()
	if _field == null:
		_field = FastNoiseLite.new()
		_field.noise_type = FastNoiseLite.TYPE_PERLIN
		_field.frequency = NOISE_FREQUENCY
	# Derived from the instance id: a stable per-unit number.
	_offset = float(agent.get_instance_id() % 9973) * 0.37


func calculate() -> Vector3:
	if agent == null or _field == null:
		return Vector3.ZERO

	var t: float = float(Time.get_ticks_msec()) * 0.001 * drift_speed

	# Two samples far apart in the field, so x and z drift independently.
	# Sampling one axis for both would give a force locked to the diagonal.
	var x: float = _field.get_noise_2d(_offset, t)
	var z: float = _field.get_noise_2d(_offset + 500.0, t)

	var drift := Vector3(x, 0.0, z)
	if drift.length() > 1.0:
		drift = drift.normalized()
	return drift * strength * distance_gain() * agent.max_speed


## How much drift applies right now, from [member far_strength] to 1.0.
##
## Read off whatever the unit is currently steering AT rather than off its
## state name.
func distance_gain() -> float:
	if not gate_by_distance:
		return 1.0

	var objective: Vector3 = _objective()
	if objective == Vector3.INF:
		# Nothing to be far FROM: drift freely.
		return 1.0

	var distance: float = agent.global_position.distance_to(objective)
	var t: float = clampf(
		inverse_lerp(close_range, far_range, distance), 0.0, 1.0
	)
	return lerpf(1.0, far_strength, t)


## Where this unit is currently heading, or Vector3.INF when nothing says.
##
func _objective() -> Vector3:
	for behaviour in agent.behaviours:
		if not behaviour.enabled:
			continue
		if not ("target" in behaviour):
			continue
		# Validity checked BEFORE the cast, not after. `as` on a freed object
		# throws "Trying to cast a freed object" in its own right, so a check
		# on the result never runs.
		var held: Variant = behaviour.target
		if held == null or not is_instance_valid(held):
			continue
		var target: Node3D = held as Node3D
		if target != null:
			return target.global_position
	return Vector3.INF
