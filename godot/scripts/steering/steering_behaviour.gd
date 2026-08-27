## Base class for every steering behaviour a [SwarmUnit] or [Ship] can run.
##
## A behaviour is a [Node] child of the agent it steers. The agent collects its
## behaviours at run time and never names a concrete one, so adding a behaviour
## is a new file plus a node in the scene -- the Open/Closed principle made
## concrete.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/steering_behavior.gd.
## Two deliberate departures from that original:
##   1. [method calculate] is declared here and returns [constant Vector3.ZERO],
##      rather than being discovered by duck typing. A typo in a subclass then
##      fails loudly instead of silently never being collected.
##   2. [member agent] is typed [CharacterBody3D] rather than the agent class,
##      because two scripts whose [code]class_name[/code]s reference each other
##      are a cyclic dependency that GDScript rejects at parse time.
##      However, this class reads [code]agent.max_speed[/code], which no base
##      [CharacterBody3D] provides. That coupling is by convention, not enforced
##      by the type: the parent must be an agent script that defines it, or this
##      fails at run time with [code]Invalid get index 'max_speed'[/code].
class_name SteeringBehaviour
extends Node

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
	if draw_gizmos and enabled:
		on_draw_gizmos()


## Return the steering force this behaviour wants, in world space.
## Override in a subclass. The base contributes nothing.
func calculate() -> Vector3:
	return Vector3.ZERO


## Draw this behaviour's debug visualisation. Override in a subclass.
func on_draw_gizmos() -> void:
	pass


## Steer flat out towards [param destination]: Reynolds seek.
##
## Shared helper rather than a behaviour of its own, because cohesion, path
## following and pursuit are all "seek, at a point I worked out first".
func seek_towards(destination: Vector3) -> Vector3:
	var to_target: Vector3 = destination - agent.global_position
	var desired: Vector3 = to_target.normalized() * agent.max_speed
	return desired - agent.velocity


## Steer towards [param destination], braking inside [param slowing_distance].
##
## The [code]dist < 2.0[/code] dead zone is a numerical-stability guard: the
## line below it divides by [code]dist[/code], which blows up at the target and
## makes the agent jitter or emit NaN. It also gives a clean stop condition.
## Adapted from Duggan, behaviors/boid.gd:106-116.
func arrive_towards(destination: Vector3, slowing_distance: float) -> Vector3:
	var to_target: Vector3 = destination - agent.global_position
	var dist: float = to_target.length()
	if dist < 2.0:
		return Vector3.ZERO
	var ramped: float = (dist / slowing_distance) * agent.max_speed
	var clamped: float = minf(agent.max_speed, ramped)
	var desired: Vector3 = (to_target * clamped) / dist
	return desired - agent.velocity
