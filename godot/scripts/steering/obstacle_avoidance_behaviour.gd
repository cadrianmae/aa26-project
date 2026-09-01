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
## Short, because it only has to cover the slow case. An earlier version set
## this to 24 -- long enough to see past the belt's largest rocks from a
## standstill -- which made a drifting unit trail a probe several times its own
## length. That job now belongs to the contact escape above, which reacts to
## collisions Godot has already computed rather than trying to predict them
## from a standstill, so the floor here can be small enough to read as a
## sensor rather than a searchlight.
@export var minimum_look_ahead: float = 9.0

## How hard the sideways push is, relative to the agent's top speed.
##
## Low, because it is only the STARTING push -- see [member pressure_gain].
@export var avoid_strength: float = 0.55

## Extra push added per second while an obstacle stays in front of the agent.
##
## A single fixed strength has to be wrong one way or the other: strong enough
## to escape a rock it is grinding against will fling it sideways every time it
## passes one, and gentle enough to pass cleanly will not free it. Building the
## force while the obstacle PERSISTS separates those cases -- brushing past
## something costs almost nothing, and only a probe that keeps seeing the same
## rock escalates, which is exactly the situation that needs escalating.
@export var pressure_gain: float = 1.4

## Ceiling on the accumulated push, so a cornered agent cannot be flung.
@export var pressure_max: float = 2.5

## Seconds of clear space before the accumulated push resets to nothing.
##
## Not instant: a feeler sweeping past the edge of a rock flickers between hit
## and miss, and resetting on the first clear frame would drop the pressure
## exactly when the agent is still working its way around. Long enough to ride
## out the flicker, short enough that open space genuinely clears it.
@export var pressure_reset_seconds: float = 0.7

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

## Every feeler cast this frame, hit or not, for the gizmo.
##
## Each entry is {from, to, hit}. Rebuilt in [method calculate] rather than
## recast when drawing: the rays are already paid for, and casting a second set
## for the display would let what is drawn drift from what actually steered.
var _drawn_feelers: Array = []

## Colour of a feeler that found nothing.
@export var clear_colour: Color = Color(0.35, 0.75, 0.45, 0.35)

## Colour of a feeler that hit something.
@export var blocked_colour: Color = Color(1.0, 0.35, 0.15)

func _ready() -> void:
	super()
	# Never on the PLAYER's own ship.
	#
	# Avoidance is autonomy, and the player is not autonomous -- a hull that
	# steers itself away from rocks is one that argues with the stick. Flying
	# into an asteroid should be the player's mistake to make and their
	# correction to perform; the rival gets it precisely because nobody is
	# holding its stick.
	#
	# Drones keep it whichever side they belong to, so the test is for a Ship
	# on allegiance 0 rather than for allegiance alone. Both hives instance the
	# same scene, which is why this has to be decided here rather than by
	# leaving the node out.
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

	# Already touching something: push off it, before any probing.
	#
	# The feelers answer "what am I about to hit", which is the wrong question
	# for an agent that has already hit it. A unit pressed against a rock has
	# almost no velocity, so its heading is unreliable and its feelers can miss
	# entirely along the surface -- and meanwhile ArriveBarnacle is producing
	# well over a thousand units of force against a budget of forty, so it
	# saturates WTPRS and holds the unit against the rock indefinitely. That is
	# the stuck case: not a failure to see the obstacle, but a failure to stop
	# pushing into one already found.
	#
	# Godot's own collision normals are the reliable signal here, and they are
	# free -- move_and_slide has already computed them this frame.
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

	# Recorded for the gizmo, whether or not anything is found. Drawing only the
	# feelers that HIT shows nothing most of the time, which makes the
	# behaviour look inert when it is working perfectly well -- the useful
	# thing to see is the probe sweeping ahead and lengthening with speed.
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
