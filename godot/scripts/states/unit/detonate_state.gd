## Terminal state: close on the target, then blow up on it.
##
## A Thargon's last resort, and the swarm's only answer to something too tough
## to shoot down. Structurally it is also the clearest demonstration of the
## emergent-membership argument: the unit simply stops existing, its
## neighbours re-query the spatial hash on the next frame, and the flock
## re-coheres around the gap with nothing told to do so.
##
## Deliberately not reachable from an intent. Detonating is a decision a unit
## makes about itself -- when it is nearly dead and something worth killing is
## close -- so the swarm cannot be ordered to spend itself. That keeps the
## sacrifice emergent rather than commanded.
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

## Separation and obstacle avoidance only: the unit is committed, and cohesion
## pulling it back toward the flock would fight the run-in. Avoid stays because
## a unit that flies into a rock on the way to its target has wasted itself.
const ACTIVE_BEHAVIOURS: Array = ["Avoid", "Engage", "Separation"]

## What it is diving at.
var target: Node3D

var _fuse: float = 0.0


func _enter() -> void:
	_fuse = 0.0
	_acquire()
	use_only(ACTIVE_BEHAVIOURS)


## Nearest enemy, ship or drone. Unweighted, unlike [EngageState]: a unit
## about to die should spend itself on whatever it can actually reach.
func _acquire() -> void:
	if unit == null:
		return
	var enemy: int = 1 - unit.allegiance
	var closest: Node3D = null
	var closest_distance: float = INF

	for node in get_tree().get_nodes_in_group("swarm_" + str(enemy)):
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		for drone in swarm.units:
			if drone == null:
				continue
			var distance: float = unit.global_position.distance_to(drone.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest = drone

	for node in get_tree().get_nodes_in_group("commander_" + str(enemy)):
		var ship: Node3D = node as Node3D
		if ship == null:
			continue
		var distance: float = unit.global_position.distance_to(ship.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = ship

	target = closest
	var seek: SeekBehaviour = unit.get_node_or_null(
		NodePath(seek_behaviour_name)
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

	for node in get_tree().get_nodes_in_group("swarm_" + str(enemy)):
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

	for node in get_tree().get_nodes_in_group("commander_" + str(enemy)):
		var ship: Node3D = node as Node3D
		if ship == null or not ship.has_method("take_damage"):
			continue
		if centre.distance_to(ship.global_position) <= blast_radius:
			ship.take_damage(blast_damage)

	DebugDraw3D.draw_sphere(centre, blast_radius, Color(1.0, 0.6, 0.2), 0.4)
	unit.take_damage(unit.health)
