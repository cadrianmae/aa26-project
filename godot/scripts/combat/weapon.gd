## Fires projectiles at a target, on a cooldown.
##
## Knows nothing about who to shoot: the caller supplies the target.
class_name Weapon
extends Node3D

## Emitted when a shot leaves the barrel, for audio and gizmos.
signal fired(at: Node3D)

## The shot to spawn. Unset, the weapon is inert rather than an error: a hull
## can carry a mount with nothing loaded.
@export var projectile_scene: PackedScene

## Seconds between shots, or between bursts when [member burst_count] is > 1.
@export var cooldown: float = 0.55

## How many shots leave the mount per trigger pull.
##
## 1 is a single shot. Above that the weapon fires a BURST: that many rounds
## spaced by [member burst_interval], then the full cooldown before the next
## burst is allowed.
@export_range(1, 10) var burst_count: int = 1

## Seconds between the rounds WITHIN a burst.
@export var burst_interval: float = 0.09

## Damage per shot, passed to the projectile.
@export var damage: float = 8.0

## Furthest the weapon will fire. [EngageState] closes to this before asking.
@export var range: float = 55.0

## How far ahead of the mount a shot appears, so it does not spawn inside the
## hull that fired it and immediately register a hit on its own ship.
@export var muzzle_offset: float = 2.5

## Fire along the agent's nose rather than at the target.
##
## The commander's weapon leaves this off; it is constrained by
## [PlayerGunner]'s own firing arc instead.
@export var fixed_mount: bool = false

## Half-angle the nose must be within for a fixed mount to fire, in degrees.
@export_range(1.0, 90.0) var mount_arc_degrees: float = 18.0

@export_group("Debug")

## Draw a line to the current target when firing.
@export var draw_gizmos: bool = true

## The agent carrying this weapon, for allegiance and position.
var agent: Node3D

## Seconds until the next shot is allowed.
var _cooldown_left: float = 0.0

## Rounds still owed on the burst in progress.
var _burst_left: int = 0

## The target the burst was started against.
var _burst_target: Node3D

## Kept only so the gizmo can draw what was last shot at.
var _last_target: Node3D


func _ready() -> void:
	agent = get_parent() as Node3D
	if agent == null:
		push_error("%s must be a child of a Node3D agent." % name)


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_continue_burst()
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
## Aimed at where the target IS, not where it will be: no lead.
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

	if fixed_mount:
		# +Z is the model's nose in this codebase, not Vector3.FORWARD.
		var nose: Vector3 = agent.global_basis.z
		nose.y = 0.0
		if nose.length_squared() < 0.0001:
			return false
		nose = nose.normalized()
		# Refuse the shot unless the hull is already pointed at the target.
		if rad_to_deg(nose.angle_to(direction)) > mount_arc_degrees:
			return false
		# Fire down the nose: a fixed gun cannot lead or correct.
		direction = nose

	# Added to the scene root rather than to the firing agent: a shot parented
	# to its shooter would inherit the shooter's motion and drag along behind
	# it instead of flying straight.
	get_tree().get_root().add_child(projectile)
	projectile.global_position = global_position + direction * muzzle_offset
	# look_at aims -Z, and this codebase's forward is +Z, so aim at a point
	# BEHIND the shot to point it forward. Same inversion as Drone and Ship.
	projectile.look_at(projectile.global_position - direction, Vector3.UP)

	# A burst spends its short interval between rounds and only pays the full
	# cooldown once the last round has left.
	if _burst_left > 0:
		_burst_left -= 1
		_cooldown_left = burst_interval if _burst_left > 0 else cooldown
	else:
		_burst_left = maxi(burst_count - 1, 0)
		_burst_target = target
		_cooldown_left = burst_interval if _burst_left > 0 else cooldown

	_last_target = target
	fired.emit(target)
	return true


## Continue a burst already in progress, without the caller having to ask.
func _continue_burst() -> void:
	if _burst_left <= 0 or _cooldown_left > 0.0:
		return
	if _burst_target == null or not is_instance_valid(_burst_target):
		# The target died mid-burst. Stop rather than firing at nothing, and
		# pay the full cooldown so a dead target is not a free reload.
		_burst_left = 0
		_cooldown_left = cooldown
		return
	fire_at(_burst_target)
