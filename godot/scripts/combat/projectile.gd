## A single shot: travels forward, damages the first enemy it reaches, dies.
##
## Deliberately not a physics body. Combat here is dozens of small fast shots
## between agents that are already doing steering every frame, and adding that
## many rigid bodies would cost more than the game can spare at forty drones a
## side. Instead each shot steps forward and tests distance against the units
## it could plausibly hit -- which for a game with a swarm register is a short
## list, not a broad-phase query.
##
## Frees itself on hit or on timeout. A shot that missed and flew on forever
## would accumulate until the frame budget went with it.
class_name Projectile
extends Node3D

## Emitted when the shot connects, before it frees itself.
signal hit(target: Node3D, amount: float)

## Which side fired this. A shot never damages its own side, so a swarm firing
## through itself is harmless rather than a friendly-fire disaster the player
## cannot avoid.
@export var allegiance: int = 0

## Damage dealt on contact.
@export var damage: float = 8.0

## Units per second.
@export var speed: float = 90.0

## Seconds before the shot gives up and frees itself.
@export var lifetime: float = 2.5

## How close counts as a hit. Generous, because the shot moves far in one
## frame: at 90 units per second a 60 Hz frame is 1.5 units, so a tight radius
## would let shots tunnel straight through a drone between frames.
@export var hit_radius: float = 2.2

var _age: float = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# +Z is forward in this codebase, following Duggan. Vector3.FORWARD is -Z
	# and would send every shot out of the back of the ship that fired it.
	var step: Vector3 = global_transform.basis.z.normalized() * speed * delta
	global_position += step

	var target: Node3D = _first_hit()
	if target == null:
		return

	if target.has_method("take_damage"):
		target.take_damage(damage)
	hit.emit(target, damage)
	queue_free()


## The nearest enemy within [member hit_radius], or null.
##
## Checks the swarm registers and the commander groups rather than the whole
## tree: those are the only things that can be shot, and both are already
## maintained for other reasons.
func _first_hit() -> Node3D:
	var closest: Node3D = null
	var closest_distance: float = hit_radius

	for side in [0, 1]:
		if side == allegiance:
			continue

		for node in get_tree().get_nodes_in_group("swarm_" + str(side)):
			var swarm: Swarm = node as Swarm
			if swarm == null:
				continue
			for drone in swarm.units:
				if drone == null:
					continue
				var distance: float = global_position.distance_to(drone.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest = drone

		for node in get_tree().get_nodes_in_group("commander_" + str(side)):
			var ship: Node3D = node as Node3D
			if ship == null:
				continue
			# A capital ship is far larger than a drone, so it needs a bigger
			# catch radius or shots pass visibly through the hull.
			var distance: float = global_position.distance_to(ship.global_position)
			if distance < maxf(closest_distance, hit_radius * 4.0):
				closest_distance = distance
				closest = ship

	return closest
