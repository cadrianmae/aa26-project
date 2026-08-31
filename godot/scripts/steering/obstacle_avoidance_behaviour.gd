## Steer around whatever the agent is about to fly into.
##
## Reynolds' obstacle avoidance by FEELERS: three probes fanned along the
## direction of travel -- one straight ahead and one to each side -- and a
## lateral push away from whichever finds something first. Lateral, not
## backwards: braking stops a unit in front of the thing it was avoiding, where
## steering takes it past.
##
## Three feelers rather than one, because a single forward ray is blind to
## anything it does not point exactly at. A rock the agent is about to clip
## with its shoulder returns nothing at all, so the agent flies on and hits it.
## The side feelers are what let it notice an obstacle it is passing rather
## than only one it is aiming at, and they are what make the avoidance start
## turning EARLY instead of at the last moment.
##
## Adapted from Reynolds, Steering Behaviors For Autonomous Characters, the
## "obstacle avoidance" section, and sitting in the same WTPRS priority scheme
## as the rest of this project's behaviours.
##
## The probe length scales with SPEED, not with a constant. A unit travelling
## twice as fast needs to begin turning twice as early, and the same fixed
## look-ahead that works when crawling is useless at full speed -- which is
## exactly how the commander ended up pinned against an asteroid: it only
## noticed the rock at the moment it hit it.
##
## Placed high in the child order, just under Flee. Avoiding a rock and fleeing
## a threat are both survival, and both need their share of the force budget
## before anything about formation or destination gets a say.
class_name ObstacleAvoidanceBehaviour
extends SteeringBehaviour

## Physics layers treated as solid. Layer 1 is the world: rocks and the wreck.
@export_flags_3d_physics var obstacle_mask: int = 1

## Seconds of travel to look ahead.
##
## In time rather than distance, so the probe automatically lengthens as the
## agent speeds up. Roughly the time it takes to notice, turn, and clear.
@export var look_ahead_seconds: float = 1.6

## Shortest the probe is ever allowed to be.
##
## A stationary agent has no direction of travel and so no probe at all, which
## would leave a unit that had already stopped against a rock with no force to
## get it off again.
##
## Generous, because the belt's rocks scale up to a 21-unit radius. A probe
## shorter than the obstacle is wide finds nothing until the agent is already
## inside it -- the first version reached 22 units at a rock whose surface was
## 23 away, and reported no obstacle at all while flying straight into it.
@export var minimum_look_ahead: float = 24.0

## How hard the sideways push is, relative to the agent's top speed.
@export var avoid_strength: float = 1.6

## Extra clearance demanded beyond the hit point.
##
## Aiming exactly at the tangent means clipping the rock, because the agent has
## width and the probe is a line.
@export var clearance: float = 4.0

## How far the side feelers splay from the centre one, in degrees.
@export_range(5.0, 80.0) var feeler_angle: float = 30.0

## How long the side feelers are, relative to the centre one.
##
## Shorter: they exist to catch obstacles the agent is about to pass close to,
## not to look far off to the side for things it will never reach.
@export_range(0.2, 1.0) var feeler_length_ratio: float = 0.65

## The last probe result, kept only so the gizmo can draw it.
var _hit_point: Vector3 = Vector3.INF
var _hit_normal: Vector3 = Vector3.ZERO


func calculate() -> Vector3:
	_hit_point = Vector3.INF
	if agent == null:
		return Vector3.ZERO

	# Along the direction of travel where there is one, otherwise along the
	# nose: a unit sitting still against a rock still needs to see it.
	var heading: Vector3 = agent.velocity
	heading.y = 0.0
	if heading.length_squared() < 0.01:
		heading = agent.global_basis.z
		heading.y = 0.0
	if heading.length_squared() < 0.0001:
		return Vector3.ZERO
	heading = heading.normalized()

	var reach: float = maxf(
		agent.velocity.length() * look_ahead_seconds, minimum_look_ahead
	)

	# The three feelers: centre at full reach, sides shorter and splayed.
	var feelers: Array = [
		[heading, reach],
		[heading.rotated(Vector3.UP, deg_to_rad(feeler_angle)), reach * feeler_length_ratio],
		[heading.rotated(Vector3.UP, deg_to_rad(-feeler_angle)), reach * feeler_length_ratio],
	]

	var space: PhysicsDirectSpaceState3D = agent.get_world_3d().direct_space_state
	var nearest: float = INF
	var found: bool = false
	var normal: Vector3 = Vector3.ZERO
	var point: Vector3 = Vector3.ZERO

	for feeler in feelers:
		var query := PhysicsRayQueryParameters3D.create(
			agent.global_position, agent.global_position + feeler[0] * feeler[1]
		)
		query.collision_mask = obstacle_mask
		# The agent is a body itself; without this a feeler can hit its own
		# collider on a frame it is already overlapping something.
		query.exclude = [agent.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		# The CLOSEST hit across all three wins. A side feeler finding a rock
		# nearer than the centre one means the agent is about to clip it, and
		# that is the more urgent problem.
		var d: float = agent.global_position.distance_to(hit["position"])
		if d < nearest:
			nearest = d
			normal = hit["normal"]
			point = hit["position"]
			found = true

	if not found:
		return Vector3.ZERO

	_hit_point = point
	_hit_normal = normal

	# Sideways, not backwards. The component of the surface normal that lies
	# across the direction of travel is the shortest way past the obstacle;
	# the component along it would only push the agent back the way it came.
	var lateral: Vector3 = _hit_normal - heading * _hit_normal.dot(heading)
	lateral.y = 0.0
	if lateral.length_squared() < 0.0001:
		# Dead-on: the normal points straight back down the feeler, so there is
		# no lateral component to use and the agent must be given a side to
		# turn to. Its own right, chosen from the heading so the choice is
		# stable frame to frame rather than flickering.
		lateral = Vector3(-heading.z, 0.0, heading.x)
	lateral = lateral.normalized()

	# Urgency rises as the obstacle gets closer: a rock at the far end of a
	# feeler barely registers, one about to be hit takes the whole budget.
	var urgency: float = clampf(
		1.0 - (nearest - clearance) / maxf(reach, 0.001), 0.0, 1.0
	)

	return lateral * agent.max_speed * avoid_strength * urgency


func on_draw_gizmos() -> void:
	if agent == null:
		return
	if _hit_point.is_finite():
		DebugDraw3D.draw_line(agent.global_position, _hit_point, Color.ORANGE_RED)
		DebugDraw3D.draw_sphere(_hit_point, 1.5, Color.ORANGE_RED)
