## Fires the player's [Weapon] while the fire action is held.
##
## Both hives instance the same commander_ship.tscn, so the allegiance guard in
## [method _ready] is what keeps this off the rival's ship.
class_name PlayerGunner
extends Node

## Furthest a target can be from where the ship is pointing, in degrees, and
## still be shot at.
@export_range(5.0, 180.0) var firing_arc_degrees: float = 75.0

## The ship carrying the weapon.
var ship: Ship

## The weapon being fired. Resolved from the parent, never wired in the scene.
var weapon: Weapon

## The player's target selection, when the ship carries one.
var targeting: Targeting


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
	targeting = ship.get_node_or_null("Targeting") as Targeting


func _physics_process(_delta: float) -> void:
	if weapon == null or not Input.is_action_pressed("fire"):
		return
	var target: Node3D = choose_target()
	if target != null:
		weapon.fire_at(target)


## The enemy this shot should go to, or null when nothing is worth shooting.
##
## A deliberate selection wins over proximity; falls back to nearest in arc.
func choose_target() -> Node3D:
	if ship == null or weapon == null:
		return null

	if targeting != null and targeting.current != null:
		var chosen: Node3D = targeting.current
		if weapon.in_range(chosen) and _within_arc(chosen):
			return chosen

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
## Drones are reached through the enemy [Swarm] rather than a group: they never
## join one, the swarm owns its units.
func hostiles() -> Array[Node3D]:
	return Swarm.hostiles_of(get_tree(), 1 - ship.allegiance)


## Whether the ship is pointing near enough at [param target] to fire.
##
## Measured on the XZ plane only.
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
