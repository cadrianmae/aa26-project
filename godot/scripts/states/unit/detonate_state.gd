## Terminal state: close on the target, then blow up on it.
##
## Not reachable from an intent.
class_name DetonateState
extends State

## The SeekBehaviour used to close on the target.
@export var seek_behaviour_name: String = "Engage"

## Damage dealt to everything inside the blast.
@export var blast_damage: float = 45.0

## How far the blast reaches.
@export var blast_radius: float = 12.0

## How close the unit must be before it triggers.
@export var trigger_radius: float = 5.0

## Seconds before it detonates regardless, so a unit that loses its target or
## cannot close does not sit armed forever.
@export var fuse_seconds: float = 6.0

## Behaviours this state runs.
const ACTIVE_BEHAVIOURS: Array = ["Avoid", "Engage", "Separation"]

## What it is diving at.
var target: Node3D

var _fuse: float = 0.0


func _enter() -> void:
	_fuse = 0.0
	_acquire()
	use_only(ACTIVE_BEHAVIOURS)


## Nearest enemy, ship or drone. Unweighted, unlike [EngageState].
func _acquire() -> void:
	if unit == null:
		return
	target = Swarm.nearest_hostile(
		get_tree(), unit.global_position, 1 - unit.allegiance
	)
	var seek: SeekBehaviour = behaviour_named(
		seek_behaviour_name
	) as SeekBehaviour
	if seek != null:
		seek.target = target


func _think() -> void:
	if unit == null:
		return

	_fuse += get_process_delta_time()

	var reached: bool = (
		target != null
		and is_instance_valid(target)
		and unit.global_position.distance_to(target.global_position) <= trigger_radius
	)
	if reached or _fuse >= fuse_seconds:
		detonate()


## Damage everything hostile in the blast, then destroy this unit.
##
## The unit takes its own health down rather than being freed directly, so it
## goes through [method Drone.take_damage] and its normal death path --
## deregistering from the swarm and emitting `died`. Freeing it here would
## leave a dangling entry in the swarm's register.
func detonate() -> void:
	var enemy: int = 1 - unit.allegiance
	var centre: Vector3 = unit.global_position

	for node in get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(enemy)):
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		# Copied before iterating: take_damage can free a drone, and mutating
		# the register mid-loop skips whatever shuffles into the gap.
		for drone in swarm.units.duplicate():
			if drone == null or not is_instance_valid(drone):
				continue
			if centre.distance_to(drone.global_position) <= blast_radius:
				drone.take_damage(blast_damage)

	for node in get_tree().get_nodes_in_group(Ship.GROUP_PREFIX + str(enemy)):
		var ship: Node3D = node as Node3D
		if ship == null or not ship.has_method("take_damage"):
			continue
		if centre.distance_to(ship.global_position) <= blast_radius:
			ship.take_damage(blast_damage)

	DebugDraw3D.draw_sphere(centre, blast_radius, Color(1.0, 0.6, 0.2), 0.4)
	unit.take_damage(unit.health)
