## Fires projectiles at a target, on a cooldown.
##
## A Node child of whatever carries it, like the steering behaviours, so a
## drone and a capital ship mount the same component with different numbers
## rather than each having its own firing code.
##
## Knows nothing about who to shoot. [EngageState] chooses the target and asks
## this to fire; the weapon only decides whether it is ready and where the
## shot goes. Keeping target selection out of here is what lets the player's
## ship and an autonomous drone share it.
class_name Weapon
extends Node3D

## Emitted when a shot leaves the barrel, for audio and gizmos.
signal fired(at: Node3D)

## The shot to spawn. Unset, the weapon is inert rather than an error: a hull
## can carry a mount with nothing loaded.
@export var projectile_scene: PackedScene

## Seconds between shots.
@export var cooldown: float = 0.55

## Damage per shot, passed to the projectile.
@export var damage: float = 8.0

## Furthest the weapon will fire. [EngageState] closes to this before asking.
@export var range: float = 55.0

## How far ahead of the mount a shot appears, so it does not spawn inside the
## hull that fired it and immediately register a hit on its own ship.
@export var muzzle_offset: float = 2.5

@export_group("Debug")

## Draw a line to the current target when firing.
@export var draw_gizmos: bool = true

## The agent carrying this weapon, for allegiance and position.
var agent: Node3D

## Seconds until the next shot is allowed.
var _cooldown_left: float = 0.0

## Kept only so the gizmo can draw what was last shot at.
var _last_target: Node3D


func _ready() -> void:
	agent = get_parent() as Node3D
	if agent == null:
		push_error("%s must be a child of a Node3D agent." % name)


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if draw_gizmos and _last_target != null and is_instance_valid(_last_target):
		DebugDraw3D.draw_line(
			global_position, _last_target.global_position, Color(1.0, 0.55, 0.25)
		)


## Whether the weapon could fire this instant.
func is_ready() -> bool:
	return _cooldown_left <= 0.0 and projectile_scene != null


## Whether [param target] is close enough to be worth shooting at.
func in_range(target: Node3D) -> bool:
	if target == null or agent == null:
		return false
	return agent.global_position.distance_to(target.global_position) <= range


## Fire at [param target] if ready and in range. Returns whether a shot left.
##
## Aimed at where the target IS, not where it will be. Lead would be more
## effective and less readable: shots that visibly converge on a moving drone
## look like the game cheating, where shots that trail behind read as a fight
## the player can follow.
func fire_at(target: Node3D) -> bool:
	if target == null or agent == null or not is_ready() or not in_range(target):
		return false

	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		push_error("%s: projectile_scene is not a Projectile." % name)
		return false

	projectile.allegiance = agent.allegiance if "allegiance" in agent else 0
	projectile.damage = damage

	var direction: Vector3 = (target.global_position - global_position)
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return false
	direction = direction.normalized()

	# Added to the scene root rather than to the firing agent: a shot parented
	# to its shooter would inherit the shooter's motion and drag along behind
	# it instead of flying straight.
	get_tree().get_root().add_child(projectile)
	projectile.global_position = global_position + direction * muzzle_offset
	# look_at aims -Z, and this codebase's forward is +Z, so aim at a point
	# BEHIND the shot to point it forward. Same inversion as Drone and Ship.
	projectile.look_at(projectile.global_position - direction, Vector3.UP)

	_cooldown_left = cooldown
	_last_target = target
	fired.emit(target)
	return true
