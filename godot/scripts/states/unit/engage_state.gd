## Hunt the nearest enemy and shoot it.
##
## Target selection is per drone, not issued by the swarm. The player orders
## ENGAGE and each unit picks whatever is nearest to itself, so the swarm
## spreads naturally across a fight instead of fifty drones queueing behind
## one target -- an emergent focus-fire that nothing coordinates.
##
## Retargets only when the current target dies or drifts out of reach.
## Re-choosing every frame makes drones oscillate between two enemies at
## similar range and never actually close on either.
class_name EngageState
extends State

## The SeekBehaviour this state points at the target.
##
## Seek, not the formation behaviour: OffsetPursue holds a slot beside the
## commander, which is the opposite of chasing something.
@export var seek_behaviour_name: String = "Engage"

## Where to go when there is nothing left to fight.
@export var idle_state_name: String = "Follow"

## Distance at which an attack run breaks off and the drone extends away.
##
## Thargons do not brawl. They make a pass, overshoot, run out, turn and come
## back -- so a drone commits to the target until it is this close, then stops
## steering at it entirely. Without a break-off the whole swarm converges on
## one point and sits there grinding, which reads as a bug even when it is
## working exactly as written.
@export var break_off_distance: float = 14.0

## How far out to run before turning back for the next pass.
##
## Well beyond weapon range, so the extend is a real disengagement rather than
## a wobble. This is what gives the fight its rhythm: waves arriving and
## clearing rather than one continuous scrum.
@export var extend_distance: float = 85.0

## How far to one side the run-out is angled, as a fraction of extend_distance.
##
## Without this a drone reverses straight back down its own approach and the
## two legs overlay each other. Angling the exit turns the pattern into a loop,
## which is both what a real attack run looks like and what stops outbound
## drones colliding with inbound ones.
@export_range(0.0, 1.5) var extend_sweep: float = 0.65

## How far to look for a target.
@export var acquire_range: float = 140.0

## Behaviours this state runs. Separation matters more here than anywhere
## else: without it a swarm converging on one enemy collapses into a single
## point and stops reading as many units.
const ACTIVE_BEHAVIOURS: Array = ["Engage", "Separation", "Alignment"]

## Which leg of the attack pattern this drone is on.
enum Phase { RUN, EXTEND }

## The enemy being hunted.
var target: Node3D

## RUN steers at the enemy; EXTEND steers at a point away from it.
var phase: Phase = Phase.RUN

var _weapon: Weapon

## Carries the run-out point, because SeekBehaviour targets a node rather than
## a position. One per drone, so each picks its own exit.
var _extend_marker: Node3D


func _enter() -> void:
	_weapon = unit.get_node_or_null("Weapon") as Weapon
	if _extend_marker == null:
		_extend_marker = Node3D.new()
		_extend_marker.name = "ExtendPoint"
		_extend_marker.top_level = true
		add_child(_extend_marker)
	phase = Phase.RUN
	acquire()
	use_only(ACTIVE_BEHAVIOURS)


## Point the seek behaviour at [member target].
func _point_seek_at_target() -> void:
	_point_seek_at(target)


## Point the seek behaviour at any node.
##
## The attack pattern swings the same behaviour between the enemy and a
## run-out marker, so the seek is aimed rather than re-created: one behaviour,
## two destinations, and the WTPRS budget never changes shape mid-fight.
func _point_seek_at(destination: Node3D) -> void:
	if unit == null:
		return
	var seek: SeekBehaviour = unit.get_node_or_null(
		NodePath(seek_behaviour_name)
	) as SeekBehaviour
	if seek == null:
		push_error(
			"%s: no SeekBehaviour named '%s' on %s."
			% [name, seek_behaviour_name, unit.name]
		)
		return
	seek.target = destination


## Choose the nearest enemy drone or capital ship within reach.
##
## Ships are weighted as if closer than they are, so a swarm that could shoot
## either will go for the ship. Destroying the commander ends the match;
## trading drones does not.
func acquire() -> Node3D:
	var enemy: int = 1 - unit.allegiance
	var closest: Node3D = null
	var closest_score: float = acquire_range

	for node in get_tree().get_nodes_in_group("swarm_" + str(enemy)):
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		for drone in swarm.units:
			if drone == null:
				continue
			var distance: float = unit.global_position.distance_to(drone.global_position)
			if distance < closest_score:
				closest_score = distance
				closest = drone

	for node in get_tree().get_nodes_in_group("commander_" + str(enemy)):
		var ship: Node3D = node as Node3D
		if ship == null:
			continue
		var distance: float = unit.global_position.distance_to(ship.global_position) * 0.6
		if distance < closest_score:
			closest_score = distance
			closest = ship

	# Nothing within acquire_range. Advance on the enemy commander anyway,
	# at whatever distance it sits.
	#
	# Without this, ENGAGE was silently a no-op whenever the enemy started
	# further away than acquire_range: the seek behaviour kept a null target
	# and contributed zero force, so a swarm ordered to attack drifted on
	# separation, alignment and wander alone -- moving, so it never looked
	# broken, but never arriving either. A swarm told to attack must always
	# have somewhere to go, and the commander is the one target that cannot
	# be out of reach, because reaching it IS the attack.
	if closest == null:
		closest = _enemy_commander(enemy)

	target = closest
	_point_seek_at_target()
	return target


## The enemy commander at any distance, or null if it is already dead.
func _enemy_commander(enemy: int) -> Node3D:
	var closest: Node3D = null
	var closest_distance: float = INF
	for node in get_tree().get_nodes_in_group("commander_" + str(enemy)):
		var ship: Node3D = node as Node3D
		if ship == null or not is_instance_valid(ship):
			continue
		var distance: float = unit.global_position.distance_to(ship.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = ship
	return closest


func _think() -> void:
	if unit == null or machine == null:
		return

	# A freed target leaves a stale reference, so validity is checked before
	# anything is read off it.
	var lost: bool = (
		target == null
		or not is_instance_valid(target)
		or unit.global_position.distance_to(target.global_position) > acquire_range
	)
	if lost and acquire() == null:
		var idle: State = machine.state_named(idle_state_name)
		if idle != null:
			machine.change_state(idle)
		return

	_update_phase()

	# Fired on both legs. A drone that only shot on the way in would waste the
	# overshoot, and weapons that keep bearing while extending are what make a
	# pass feel like a strafing run rather than a ram.
	if _weapon != null:
		_weapon.fire_at(target)


## Switch between closing and extending, and point the seek accordingly.
func _update_phase() -> void:
	var distance: float = unit.global_position.distance_to(target.global_position)

	match phase:
		Phase.RUN:
			if distance <= break_off_distance:
				phase = Phase.EXTEND
				_place_extend_point()
				_point_seek_at(_extend_marker)
		Phase.EXTEND:
			# Turn back once the drone is clear, whether it reached its exact
			# run-out point or simply got far enough while dodging.
			var clear: bool = distance >= extend_distance
			var arrived: bool = unit.global_position.distance_to(
				_extend_marker.global_position
			) <= break_off_distance
			if clear or arrived:
				phase = Phase.RUN
				_point_seek_at(target)


## Choose where this drone runs out to after a pass.
##
## Straight on through the target, then swung to one side. Carrying the
## approach direction through means the drone overshoots rather than reversing,
## and the side it swings to alternates per drone so a swarm fans out into a
## wheel instead of every unit tracing the same loop.
func _place_extend_point() -> void:
	var through: Vector3 = target.global_position - unit.global_position
	through.y = 0.0
	if through.length_squared() < 0.0001:
		through = unit.global_basis.z
	through = through.normalized()

	# Perpendicular on the plane. get_instance_id is stable per drone, so a
	# unit always breaks the same way and the pattern stays legible.
	var side: float = 1.0 if int(unit.get_instance_id()) % 2 == 0 else -1.0
	var across := Vector3(-through.z, 0.0, through.x) * side

	_extend_marker.global_position = (
		target.global_position
		+ through * extend_distance
		+ across * extend_distance * extend_sweep
	)
