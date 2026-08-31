## Work a Barnacle for Meta-Alloys until the drone is full.
##
## The outward half of the economy, and the state where the swarm's autonomy
## shows most plainly: the player orders HARVEST once, and fifty drones
## independently choose Barnacles, fill up, carry home, and come back out.
## Nothing coordinates them -- they each just answer "what is nearest that
## still has alloys in it".
##
## The pairing with [DepositState] is the whole loop. This one fills the
## payload and hands over when full; that one empties it and sends the drone
## back here.
class_name HarvestState
extends State

## The ArriveBehaviour this state points at the chosen Barnacle.
@export var arrive_behaviour_name: String = "ArriveBarnacle"

## Where to go when the payload is full.
@export var full_state_name: String = "Deposit"

## Where to go when there is nothing left in the belt to work.
@export var idle_state_name: String = "Follow"

## Meta-Alloys drawn per second while in range.
##
## Slow enough to WATCH. At 8/s a 10-capacity drone filled in 1.25 seconds,
## which read as arriving and instantly leaving -- the mining was over before
## the eye registered it had started. At 2.5/s a load takes four seconds, so
## a drone visibly sits against the rock and works.
##
## The cost is throughput, and it is paid deliberately: a Barnacle holding 120
## is twelve loads either way, but those twelve now take 48 seconds of
## drone-time rather than 15, so a swarm has a real reason to spread across
## several rocks instead of queueing at one.
@export var harvest_rate: float = 2.5

## How far out a waiting drone orbits while the Barnacle is busy.
##
## Outside the harvest radius on purpose: a queue that waits INSIDE the
## working range looks like several drones harvesting at once, which is
## exactly the impression the one-at-a-time rule exists to avoid.
##
## Roughly twice the harvest radius. Close enough that the queue reads as
## attending THIS rock rather than milling about near it, far enough that the
## working drone is visibly the only one on the surface.
@export var queue_radius: float = 13.0

## How fast the waiting ring turns, in radians per second.
@export var queue_orbit_speed: float = 0.8

## How far off the Barnacle's centre the working drone sits.
##
## Roughly the Barnacle's own radius. Steering at the centre parks the drone
## INSIDE the rock, which looks like a clipping bug rather than like mining;
## steering at the near surface puts it against the face it is working.
@export var surface_offset: float = 3.5

## Behaviours this state runs. The flocking pair stays on so drones working
## the same rock spread around it instead of stacking on one point.
const ACTIVE_BEHAVIOURS: Array = ["ArriveBarnacle", "Separation", "Alignment"]

## The Barnacle being worked. Chosen on entry and held, so a drone commits to
## one rock rather than re-deciding every frame and oscillating between two
## equidistant ones.
var barnacle: Barnacle

## The point this drone steers at: the Barnacle itself when it holds the
## claim, or a place on the waiting ring when another drone is working.
var _target_point: Node3D

## This drone's angle on the waiting ring, so a queue spreads out around the
## rock instead of stacking on one side of it.
var _queue_phase: float = 0.0


func _enter() -> void:
	barnacle = _designated()
	_ensure_target_point()
	# Derived from the instance id, like the patrol phase: any stable per-unit
	# number works, and a shared counter would collide after respawns.
	_queue_phase = float(unit.get_instance_id() % 360) * TAU / 360.0
	_point_arrive_at_barnacle()
	use_only(ACTIVE_BEHAVIOURS)


func _exit() -> void:
	# Release on the way out, so a drone that fills up, flees, or is ordered
	# elsewhere frees the rock immediately rather than making the next drone
	# wait out the lease.
	if barnacle != null and is_instance_valid(barnacle):
		barnacle.release(unit)
	if _target_point != null:
		_target_point.queue_free()
		_target_point = null


## Create the node the ArriveBehaviour steers at.
##
## A node rather than a coordinate because ArriveBehaviour targets a Node3D --
## the same reason the rally marker and the patrol point are nodes. top_level
## so it holds a world position instead of being dragged along by the drone.
func _ensure_target_point() -> void:
	if _target_point != null:
		return
	_target_point = Node3D.new()
	_target_point.name = "HarvestPoint"
	_target_point.top_level = true
	unit.add_child(_target_point)


## Aim the unit's ArriveBehaviour at [member barnacle].
##
## Called again whenever the target changes, so re-targeting is one call
## rather than something every caller has to remember to do.
func _point_arrive_at_barnacle() -> void:
	if unit == null:
		return
	var arrive: ArriveBehaviour = unit.get_node_or_null(
		NodePath(arrive_behaviour_name)
	) as ArriveBehaviour
	if arrive == null:
		push_error(
			"%s: no ArriveBehaviour named '%s' on %s."
			% [name, arrive_behaviour_name, unit.name]
		)
		return
	# Always the moving point, never the Barnacle itself: the point sits ON
	# the Barnacle while this drone holds the claim and out on the waiting
	# ring while it does not, so one target covers both cases.
	arrive.target = _target_point


## Whether this drone currently holds the Barnacle.
func has_claim() -> bool:
	return barnacle != null and barnacle.occupant == unit


## Try to take the Barnacle, renewing the claim if already held.
##
## Returns false when another drone is working it, which is the signal to
## wait rather than an error.
func try_claim() -> bool:
	if barnacle == null or unit == null:
		return false
	return barnacle.claim(unit)


## Put the steering target where this drone should be right now.
##
## On the Barnacle when it holds the claim; out on the waiting ring, at its
## own phase, when it does not. Called every frame, so a drone slides from
## the queue onto the rock the moment the one in front leaves.
func update_target_point(delta: float) -> void:
	if _target_point == null or barnacle == null:
		return

	if has_claim():
		# The near surface, not the centre: whichever side the drone
		# approached from becomes the face it works, so it settles against the
		# rock instead of burrowing into it.
		var approach: Vector3 = unit.global_position - barnacle.global_position
		approach.y = 0.0
		if approach.length_squared() < 0.01:
			approach = Vector3.FORWARD
		_target_point.global_position = (
			barnacle.global_position + approach.normalized() * surface_offset
		)
		return

	_queue_phase += queue_orbit_speed * delta
	_target_point.global_position = barnacle.global_position + Vector3(
		cos(_queue_phase) * queue_radius, 0.0, sin(_queue_phase) * queue_radius
	)


## Pick the nearest Barnacle that still has alloys and steer at it.
##
## Returns false when the belt is stripped and there is nothing left to work.
func retarget() -> bool:
	# Let go of the old rock first, or a drone that moves on leaves the
	# previous Barnacle claimed until its lease runs out.
	if barnacle != null and is_instance_valid(barnacle):
		barnacle.release(unit)
	barnacle = _designated()
	return barnacle != null


## The Barnacle this drone should be working.
##
## The player's designation when there is one; the nearest with alloys left
## otherwise. The fallback matters for drones the factory builds mid-order and
## for a designated rock that runs dry -- the swarm keeps working rather than
## stopping to wait for a new instruction.
func _designated() -> Barnacle:
	if unit != null and unit.swarm != null:
		var chosen: Barnacle = unit.swarm.harvest_target
		if chosen != null and is_instance_valid(chosen) and not chosen.is_spent():
			return chosen
	return Barnacle.nearest_to(get_tree(), unit.global_position)


## Whether the drone is close enough to draw from [member barnacle].
func in_range() -> bool:
	if barnacle == null or unit == null:
		return false
	return unit.global_position.distance_to(barnacle.global_position) <= barnacle.harvest_radius


## Take one frame's worth of alloys, returning how much was actually loaded.
##
## Two caps apply and either can bite: the Barnacle may have less left than
## asked for, and the drone may have less space than the Barnacle offers.
## Whatever the Barnacle gives but the drone cannot hold is put back, so
## alloys are never destroyed in transit.
func draw_alloys(delta: float) -> float:
	if barnacle == null or unit == null:
		return 0.0
	var offered: float = barnacle.extract(harvest_rate * delta)
	if offered <= 0.0:
		return 0.0
	var loaded: float = unit.load_payload(offered)
	if loaded < offered:
		barnacle.reserve += offered - loaded
	return loaded


func _think() -> void:
	if unit == null or machine == null:
		return

	var delta: float = get_process_delta_time()

	if barnacle == null or not is_instance_valid(barnacle) or barnacle.is_spent():
		if not retarget():
			# The belt is stripped. Go idle rather than to Deposit: an empty
			# drone sent to Deposit is bounced straight back here, finds no
			# rock, and is bounced again -- every frame, for the rest of the
			# match.
			machine.change_state_named(idle_state_name)
			return

	# Above every guard. The target point has to move whether this drone is
	# working or queueing, or a waiting drone flies to one fixed spot and the
	# ring stops turning.
	update_target_point(delta)

	# Also above the guards. try_claim() both TAKES and RENEWS, and the claim
	# is a lease -- so a drone that stops asking loses the rock, including one
	# that already holds it and is still flying in.
	if not try_claim():
		# Another drone is working it. Hold the ring and ask again next frame.
		return

	if not in_range():
		return

	draw_alloys(delta)

	if unit.is_full():
		machine.change_state_named(full_state_name)
