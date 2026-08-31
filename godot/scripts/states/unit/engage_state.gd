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

## Stop closing at this distance so the drone circles rather than colliding.
@export var standoff: float = 22.0

## How far to look for a target.
@export var acquire_range: float = 140.0

## Behaviours this state runs. Separation matters more here than anywhere
## else: without it a swarm converging on one enemy collapses into a single
## point and stops reading as many units.
const ACTIVE_BEHAVIOURS: Array = ["Engage", "Separation", "Alignment"]

## The enemy being hunted.
var target: Node3D

var _weapon: Weapon


func _enter() -> void:
	_weapon = unit.get_node_or_null("Weapon") as Weapon
	acquire()
	use_only(ACTIVE_BEHAVIOURS)


## Point the seek behaviour at [member target].
func _point_seek_at_target() -> void:
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
	seek.target = target


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

	if _weapon != null:
		_weapon.fire_at(target)
