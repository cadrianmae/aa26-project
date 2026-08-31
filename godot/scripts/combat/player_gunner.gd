## Fires the player's [Weapon] while the fire action is held.
##
## The weapon itself knows nothing about who to shoot -- that is deliberate, and
## it is why the same component works for a drone and for a commander. This is
## the player's half of that split: it chooses a target and asks. [EngageState]
## is the drone's half, and it asks the same way.
##
## Held rather than tapped. The weapon has its own cooldown, so holding fire
## produces an even rate rather than a burst as fast as the player can press,
## and there is nothing to gain from mashing.
##
## Only the player's own commander mounts this. Both hives instance the SAME
## commander_ship.tscn, so anything added there is added to the rival too --
## the mistake that had the rival flying on the player's keyboard. The
## allegiance guard in [method _ready] is what stops this becoming the same
## bug with a trigger.
class_name PlayerGunner
extends Node

## Furthest a target can be from where the ship is pointing, in degrees, and
## still be shot at.
##
## Wide, because the ship faces its direction of travel in DIRECTIONAL mode and
## the player is often strafing. Narrow enough that firing still expresses
## intent rather than auto-killing whatever happens to be nearest.
@export_range(5.0, 180.0) var firing_arc_degrees: float = 75.0

## The ship carrying the weapon.
var ship: Ship

## The weapon being fired. Resolved from the parent, never wired in the scene.
var weapon: Weapon


func _ready() -> void:
	ship = get_parent() as Ship
	if ship == null:
		push_error("%s must be a child of a Ship." % name)
		set_physics_process(false)
		return
	if ship.allegiance != 0:
		# The rival fires through its own states, not through a keyboard.
		set_physics_process(false)
		return
	weapon = ship.get_node_or_null("Weapon") as Weapon


func _physics_process(_delta: float) -> void:
	if weapon == null or not Input.is_action_pressed("fire"):
		return
	var target: Node3D = choose_target()
	if target != null:
		weapon.fire_at(target)


## The enemy this shot should go to, or null when nothing is worth shooting.
##
## Nearest hostile inside the weapon's range AND inside the firing arc. Range
## is the weapon's own business, so it is asked rather than duplicated here.
func choose_target() -> Node3D:
	if ship == null or weapon == null:
		return null

	var best: Node3D = null
	var best_distance: float = INF
	for candidate in hostiles():
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not weapon.in_range(candidate):
			continue
		if not _within_arc(candidate):
			continue
		var distance: float = ship.global_position.distance_to(
			candidate.global_position
		)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


## Everything the player is allowed to shoot: the rival commander and every
## drone it has in the field.
##
## Drones are reached through the enemy [Swarm] rather than a group, because
## they never join one -- the swarm owns its units and is the only thing that
## knows the whole list.
func hostiles() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var enemy: int = 1 - ship.allegiance

	for node in get_tree().get_nodes_in_group("commander_" + str(enemy)):
		var other: Node3D = node as Node3D
		if other != null:
			found.append(other)

	for node in get_tree().get_nodes_in_group("swarm_" + str(enemy)):
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		for unit in swarm.units:
			var drone: Node3D = unit as Node3D
			if drone != null and is_instance_valid(drone):
				found.append(drone)

	return found


## Whether the ship is pointing near enough at [param target] to fire.
##
## Measured on the XZ plane only. The game is played on a plane, so a Y
## component in the comparison would only ever be floating-point noise.
func _within_arc(target: Node3D) -> bool:
	var to_target: Vector3 = target.global_position - ship.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return true
	# +Z is the model's front throughout this codebase, not Vector3.FORWARD.
	var facing: Vector3 = ship.global_basis.z
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		return true
	var angle: float = rad_to_deg(
		facing.normalized().angle_to(to_target.normalized())
	)
	return angle <= firing_arc_degrees
