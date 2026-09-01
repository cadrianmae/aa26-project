## Steer around obstacles using three ray feelers fanned along the direction of
## travel. The push is lateral, never backwards, and the probe length scales
## with the agent's speed.
##
## Reynolds, Steering Behaviors For Autonomous Characters, "obstacle avoidance".
##
## Belongs high in the scene-tree child order, just under Flee -- WTPRS spends
## the force budget in that order.
class_name ObstacleAvoidanceBehaviour
extends SteeringBehaviour

## Physics layers treated as solid. Layer 1 is the world: rocks and the wreck.
@export_flags_3d_physics var obstacle_mask: int = 1

## Seconds of travel to look ahead. The probe lengthens with the agent's speed.
@export var look_ahead_seconds: float = 1.6

## Shortest the probe is ever allowed to be, for an agent moving too slowly to
## have a useful direction of travel.
@export var minimum_look_ahead: float = 9.0

## Sideways push on first contact, relative to the agent's top speed. Grows
## from here by [member pressure_gain] for as long as the obstacle persists.
@export var avoid_strength: float = 0.55

## Extra push added per second while an obstacle stays in front of the agent.
@export var pressure_gain: float = 1.4

## Ceiling on the accumulated push.
@export var pressure_max: float = 2.5

## Seconds of clear space before the accumulated push resets to nothing. Not
## instant, so a feeler flickering along a rock's edge does not reset it.
@export var pressure_reset_seconds: float = 0.7

## Extra clearance demanded beyond the hit point, since the agent has width and
## the probe is a line.
@export var clearance: float = 4.0

## How far the side feelers splay from the centre one, in degrees.
@export_range(5.0, 80.0) var feeler_angle: float = 30.0

## How long the side feelers are, relative to the centre one.
@export_range(0.2, 1.0) var feeler_length_ratio: float = 0.65

## The chosen hit, for the gizmo.
var _hit_point: Vector3 = Vector3.INF
var _hit_normal: Vector3 = Vector3.ZERO

## Every feeler cast this frame as {from, to, hit}, for the gizmo. Recorded by
## [method calculate] so what is drawn is what actually steered.
var _drawn_feelers: Array = []

## Colour of a feeler that found nothing.
@export var clear_colour: Color = Color(0.35, 0.75, 0.45, 0.35)

## Colour of a feeler that hit something.
@export var blocked_colour: Color = Color(1.0, 0.35, 0.15)

func _ready() -> void:
	super()
	# Off on the player's own ship, on for every other agent. Both hives share
	# one scene, so this cannot be decided by leaving the node out.
	var ship: Ship = agent as Ship
	if ship != null and ship.allegiance == 0:
		enabled = false
		set_process(false)


## Accumulated push, built while blocked and released in open space.
var _pressure: float = 0.0

## Seconds since a feeler last found anything.
var _clear_for: float = 0.0


func calculate() -> Vector3:
	_hit_point = Vector3.INF
	if agent == null:
		return Vector3.ZERO

	# Already in contact: push off directly, before probing for what is ahead.
	var contact: Vector3 = _contact_escape()
	if contact != Vector3.ZERO:
		return contact

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

	# Recorded whether or not anything is found, so the gizmo can draw clear
	# feelers as well as blocked ones.
	_drawn_feelers.clear()

	for feeler in feelers:
		var from: Vector3 = agent.global_position
		var to: Vector3 = from + feeler[0] * feeler[1]
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = obstacle_mask
		# The agent is a body itself; without this a feeler can hit its own
		# collider on a frame it is already overlapping something.
		query.exclude = [agent.get_rid()]
		var hit: Dictionary = space.intersect_ray(query)
		_drawn_feelers.append({
			"from": from,
			"to": hit["position"] if not hit.is_empty() else to,
			"hit": not hit.is_empty(),
		})
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

	# Pressure released only after a spell of genuinely clear space, then built
	# again from the moment something is found. Tracked here rather than in
	# _process because it must advance in step with the probing that feeds it.
	var delta: float = get_physics_process_delta_time()
	if not found:
		_clear_for += delta
		if _clear_for >= pressure_reset_seconds:
			_pressure = 0.0
		return Vector3.ZERO

	_clear_for = 0.0
	_pressure = minf(_pressure + pressure_gain * delta, pressure_max)

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

	# Base strength plus whatever has accumulated. At first contact this is the
	# base alone -- a nudge -- and it grows only for as long as the obstacle
	# refuses to go away.
	return lateral * agent.max_speed * (avoid_strength + _pressure) * urgency


func on_draw_gizmos() -> void:
	if agent == null:
		return

	# All three feelers, always, not just the ones that found something. A probe
	# drawn only on contact is invisible for most of a match, which reads as the
	# behaviour being switched off rather than as clear space ahead.
	for feeler in _drawn_feelers:
		DebugDraw3D.draw_line(
			feeler["from"], feeler["to"],
			blocked_colour if feeler["hit"] else clear_colour
		)

	# The chosen hit, marked separately: with three feelers it is not obvious
	# which one the steering actually acted on.
	if _hit_point.is_finite():
		DebugDraw3D.draw_sphere(_hit_point, 1.5, blocked_colour)


## A push directly off whatever the agent is in contact with.
##
## Returns ZERO when nothing is being touched, so this costs a single integer
## compare on the overwhelming majority of frames.
##
## Deliberately strong -- max_speed times the full avoid_strength, with no
## urgency taper. There is no "how close" to scale by: contact IS the closest
## an agent can be, and a gentle nudge loses to an arrive force thirty times
## larger.
func _contact_escape() -> Vector3:
	if not (agent is CharacterBody3D):
		return Vector3.ZERO
	var body: CharacterBody3D = agent as CharacterBody3D
	var count: int = body.get_slide_collision_count()
	if count == 0:
		return Vector3.ZERO

	# Summed across every contact, so a unit wedged in a crevice is pushed out
	# of the corner rather than along one wall into the other.
	var escape := Vector3.ZERO
	for i in count:
		var collision: KinematicCollision3D = body.get_slide_collision(i)
		if collision == null:
			continue
		escape += collision.get_normal()
	escape.y = 0.0
	if escape.length_squared() < 0.0001:
		return Vector3.ZERO

	_hit_point = body.global_position
	return escape.normalized() * agent.max_speed * avoid_strength
