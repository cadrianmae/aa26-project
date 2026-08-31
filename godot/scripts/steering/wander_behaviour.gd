## A slow, smoothly-varying push in no particular direction.
##
## Without it a swarm SETTLES. Every other behaviour here is a converging one
## -- arrive brakes, separation balances against cohesion, offset pursue holds
## a slot -- so once the forces cancel, fifty drones sit perfectly still in a
## lattice. Correct, and completely wrong: a swarm that has stopped moving
## stops reading as alive.
##
## Reynolds calls this wander, and solves it by walking a target point around
## a circle projected ahead of the agent. This uses value noise instead, for
## two reasons: the noise field is continuous, so the force never jumps the way
## a randomly re-rolled target does, and sampling it at a per-unit offset gives
## every drone its own independent drift from one shared field.
##
## Adapted in spirit from Reynolds, "Steering Behaviors For Autonomous
## Characters", the Wander behaviour.
class_name WanderBehaviour
extends SteeringBehaviour

## How hard the drift pushes, before [member weight] is applied.
@export var strength: float = 1.0

@export_group("Distance gating")

## Drift is scaled DOWN when the unit is far from what it is heading for, and
## up when it arrives. Thargon swarms in Elite Dangerous do exactly this:
## beyond a few kilometres they hold formation and run straight, and only
## inside that range do they slow and start swaying about.
##
## The contrast is what carries the information. A swarm that jitters
## constantly just looks noisy; one that snaps out of formation as it closes
## reads as deciding to attack.
@export var gate_by_distance: bool = true

## Inside this distance from its objective, the unit drifts at full strength.
@export var close_range: float = 30.0

## Beyond this, it holds formation and runs almost straight.
@export var far_range: float = 120.0

## How much drift survives at long range, as a fraction.
@export_range(0.0, 1.0) var far_strength: float = 0.12

## How quickly the direction changes, in noise units per second.
##
## Low. This is a drift, not a twitch: at high rates the noise decorrelates
## between frames and the behaviour becomes white noise, which cancels itself
## out over any two frames and just wastes force budget.
@export var drift_speed: float = 0.35

## Noise frequency. Larger makes the field vary faster in space, which here
## means faster in TIME, since the sample walks along one axis.
@export var noise_frequency: float = 0.5

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
		_field.frequency = noise_frequency
	# Derived from the instance id, like the patrol and queue phases: any
	# stable per-unit number works, and a shared counter would collide when
	# units are freed and rebuilt.
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
## state name, so a new state gets the behaviour for free and none of them
## needs to know this exists.
func distance_gain() -> float:
	if not gate_by_distance:
		return 1.0

	var objective: Vector3 = _objective()
	if objective == Vector3.INF:
		# Nothing to be far FROM -- a unit holding station is at its
		# objective by definition, so it drifts freely.
		return 1.0

	var distance: float = agent.global_position.distance_to(objective)
	var t: float = clampf(
		inverse_lerp(close_range, far_range, distance), 0.0, 1.0
	)
	return lerpf(1.0, far_strength, t)


## Where this unit is currently heading, or Vector3.INF when nothing says.
##
## Takes it from the enabled steering behaviours themselves: whichever arrive
## or seek is switched on names the objective, so this stays correct as states
## are added without any of them reporting anything.
func _objective() -> Vector3:
	for behaviour in agent.behaviours:
		if not behaviour.enabled:
			continue
		if not ("target" in behaviour):
			continue
		# Validity checked BEFORE the cast, not after. `as` on a freed object
		# throws "Trying to cast a freed object" in its own right, so a check
		# on the result never runs -- the crash happens on the way to it. A
		# behaviour holds its target as a plain reference, and the target can
		# be freed at any time: shot down, or detonated.
		var held: Variant = behaviour.target
		if held == null or not is_instance_valid(held):
			continue
		var target: Node3D = held as Node3D
		if target != null:
			return target.global_position
	return Vector3.INF
