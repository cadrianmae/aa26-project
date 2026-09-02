## Base class for every steering behaviour a [Drone] or [Ship] can run.
##
## A behaviour is a [Node] child of the agent it steers. The agent collects its
## behaviours at run time and never names a concrete one, so adding a behaviour
## is a new file plus a node in the scene.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/steering_behavior.gd.
## Two deliberate departures from that original:
##   1. [method calculate] is declared here and returns [constant Vector3.ZERO],
##      rather than being discovered by duck typing.
##   2. [member agent] is typed [CharacterBody3D] rather than the agent class,
##      because two scripts whose [code]class_name[/code]s reference each other
##      are a cyclic dependency that GDScript rejects at parse time.
##      However, this class reads [code]agent.max_speed[/code], which no base
##      [CharacterBody3D] provides. That coupling is by convention, not enforced
##      by the type: the parent must be an agent script that defines it, or this
##      fails at run time with [code]Invalid get index 'max_speed'[/code].
class_name SteeringBehaviour
extends Node

## Speed above which braking escapes the steering arc, in world units per
## second. See [method limit_to_arc].
const BRAKING_EXEMPT_SPEED: float = 6.0

## When false the agent skips this behaviour entirely. Toggle in the Inspector
## to isolate one behaviour while debugging.
@export var enabled: bool = true

## Multiplier applied before the agent sums this force with the others.
## Weights are absolute, not normalised, because the agent truncates the
## running sum at its own max_force.
@export var weight: float = 1.0

## Draw this behaviour's own gizmos through DebugDraw3D.
@export var draw_gizmos: bool = true

## The agent being steered. Set from the parent on ready.
var agent: CharacterBody3D


func _ready() -> void:
	agent = get_parent() as CharacterBody3D
	if agent == null:
		push_error("%s must be a child of a CharacterBody3D agent." % name)


func _process(_delta: float) -> void:
	if draw_gizmos and enabled and agent != null:
		on_draw_gizmos()


## Return the steering force this behaviour wants, in world space.
## Override in a subclass. The base contributes nothing.
func calculate() -> Vector3:
	return Vector3.ZERO


## Draw this behaviour's debug visualisation. Override in a subclass.
func on_draw_gizmos() -> void:
	pass


## Steer flat out towards [param destination]: Reynolds seek.
func seek_towards(destination: Vector3) -> Vector3:
	var to_target: Vector3 = destination - agent.global_position
	var desired: Vector3 = to_target.normalized() * agent.max_speed
	return desired - agent.velocity


## The distance this agent needs in order to stop from full speed.
##
## Braking distance from the constant-acceleration result, v^2 / 2a, where the
## agent's acceleration is its force ceiling over its mass. Both terms come
## from the agent itself, so the radius tracks whatever the agent is tuned to.
##
## [param scale] is per-behaviour taste -- below 1 brakes late and arrives
## hard, above 1 drifts in gently.
func braking_distance(scale: float = 1.0) -> float:
	if agent == null:
		return 0.0
	var speed: float = agent.max_speed if "max_speed" in agent else 0.0
	var force: float = agent.max_force if "max_force" in agent else 0.0
	var mass: float = agent.mass if "mass" in agent else 1.0
	if force <= 0.0 or mass <= 0.0:
		return 0.0
	var acceleration: float = force / mass
	return (speed * speed) / (2.0 * acceleration) * scale


## Steer towards [param destination], braking inside [param slowing_radius].
##
## The [code]dist < 2.0[/code] dead zone is a numerical-stability guard: the
## line below it divides by [code]dist[/code], which blows up at the target and
## makes the agent jitter or emit NaN. It also gives a clean stop condition.
## Adapted from Duggan, behaviors/boid.gd:106-116.
func arrive_towards(destination: Vector3, slowing_radius: float) -> Vector3:
	var to_target: Vector3 = destination - agent.global_position
	var dist: float = to_target.length()
	if dist < 2.0:
		return Vector3.ZERO
	var ramped: float = (dist / slowing_radius) * agent.max_speed
	var clamped: float = minf(agent.max_speed, ramped)
	var desired: Vector3 = (to_target * clamped) / dist
	return desired - agent.velocity


## Every SteeringBehaviour that is a direct child of [param node].
static func children_of(node: Node) -> Array[SteeringBehaviour]:
	var found: Array[SteeringBehaviour] = []
	for child in node.get_children():
		if child is SteeringBehaviour:
			found.append(child)
	return found


## Clamp [param desired] into an arc of [param max_steer_angle] degrees either
## side of the agent's nose, leaving it untouched when already inside the arc.
##
## [param basis] is the agent's global basis; +Z is the nose in this codebase,
## not Vector3.FORWARD.
##
## Braking is exempt above [constant BRAKING_EXEMPT_SPEED]: thrust opposing
## [param velocity] is returned unclamped, so an agent can always kill real
## speed. Below that the exemption does not apply, or an agent barely drifting
## would be allowed to thrust anywhere it liked.
static func limit_to_arc(
	desired: Vector3,
	basis: Basis,
	velocity: Vector3,
	max_steer_angle: float
) -> Vector3:
	if max_steer_angle >= 180.0 or desired.length_squared() < 0.0001:
		return desired

	var nose: Vector3 = basis.z
	nose.y = 0.0
	if nose.length_squared() < 0.0001:
		return desired
	nose = nose.normalized()

	var direction: Vector3 = desired.normalized()
	var limit: float = deg_to_rad(max_steer_angle)
	var offset: float = nose.signed_angle_to(direction, Vector3.UP)
	if absf(offset) <= limit:
		return desired

	var speed: float = velocity.length()
	if speed > BRAKING_EXEMPT_SPEED and desired.dot(velocity) < 0.0:
		return desired

	return nose.rotated(Vector3.UP, clampf(offset, -limit, limit)) * desired.length()
