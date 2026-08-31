## A commander vessel: the player's ship, and the enemy's identical mirror.
##
## Shares the swarm unit's integration model but keeps its own tuning, because
## a capital ship should feel heavier and turn more lazily than a creature.
## The class carries no input handling -- [PlayerSteeringBehaviour] or the
## enemy's controller drives it, so the ship never knows which is at the helm.
class_name Ship
extends CharacterBody3D

## Emitted when the ship is destroyed. The match ends on this.
signal destroyed(ship: Ship)

## Which side this ship commands. Player is 0, enemy is 1.
@export var allegiance: int = 0

@export var mass: float = 4.0
@export var max_speed: float = 36.0
@export var max_force: float = 80.0
@export var banking: float = 0.25
@export var damping: float = 0.6

## Widest angle, in degrees, between the ship's nose and the thrust it may
## apply. 180 removes the limit.
##
## 135, not the drones' 90. A Matriarch is a gunship and the player needs
## enough lateral authority to strafe and to keep a target in the firing arc;
## what 135 removes is the instant about-face -- flipping from full ahead to
## full astern in a single frame, which read as the ship teleporting its
## momentum rather than flying.
##
## The wider angle is the whole difference in handling between the two: a drone
## must commit to an arc, the Matriarch can slide but not reverse on the spot.
@export_range(10.0, 180.0) var max_steer_angle: float = 135.0

@export_group("Combat")

@export var health: float = 2000.0

## Hull repaired per second, up to [member max_health].
##
## A commander that heals cannot be worn down by chip damage, so a duel
## between the two ships is unwinnable on its own -- the only way through a
## regenerating hull is more damage per second than it repairs, which means a
## swarm. That is the point: it pushes both sides into the economy rather than
## letting the match be decided by two ships shooting at each other.
@export var regen_per_second: float = 12.0

## Seconds after taking damage before repair resumes.
##
## Without the delay, regen would tick during a fight and blunt every hit. The
## pause is what makes damage feel like it landed, and what lets a sustained
## attack out-pace the repair while a few stray shots cannot.
@export var regen_delay: float = 6.0

## Health at spawn, for anything that needs to report damage as a fraction.
##
## The HUD used to divide by a hard-coded 100, which is a Drone's health, not a
## Ship's -- so a rival commander read as untouched until it was below a fifth.
var max_health: float = 0.0

@export_group("Debug")

@export var draw_gizmos: bool = true

var behaviours: Array[SteeringBehaviour] = []
var force: Vector3 = Vector3.ZERO

## Seconds since this ship was last hit, for the regen delay.
var _since_damage: float = 999.0

## Optional facing override, set by [PlayerSteeringBehaviour] in AIMED mode.
## Ignored unless [member use_face_target] is true.
var face_target: Vector3 = Vector3.ZERO

## When true, orient towards [member face_target] instead of velocity.
var use_face_target: bool = false


func _ready() -> void:
	# Recorded before anything can damage it, so every readout has an honest
	# denominator. Captured rather than exported so it cannot drift out of
	# step with `health` when that is tuned.
	max_health = health
	_collect_behaviours()
	# Join a per-faction group so swarm units can find their commander at run
	# time rather than through a scene-authored NodePath. Editor overrides
	# patched into instanced sub-scenes get pruned on re-save, and units
	# spawned at run time by a factory never have a scene-authored reference
	# at all, so group lookup is the only wiring that works in both cases.
	add_to_group("commander_" + str(allegiance))


## Cache the child behaviours once rather than walking the child list every
## physics frame. Call again if behaviours are added at run time.
func _collect_behaviours() -> void:
	behaviours.clear()
	for child in get_children():
		if child is SteeringBehaviour:
			behaviours.append(child)


## Weighted truncated sum of the child behaviours.
##
## The ship uses the plain weighted sum rather than the units' WTPRS: with only
## player steering attached there is nothing to prioritise, and truncating the
## running sum would make the controls feel like they were fighting back.
func calculate_force() -> Vector3:
	var total := Vector3.ZERO
	for behaviour in behaviours:
		if behaviour.enabled:
			total += behaviour.calculate() * behaviour.weight
	return total.limit_length(max_force)


func _physics_process(delta: float) -> void:
	var new_force: Vector3 = calculate_force()
	new_force.y = 0.0
	new_force = _limit_to_steering_arc(new_force)
	force = force.lerp(new_force, delta * 4.0)

	var acceleration: Vector3 = force / mass
	velocity += acceleration * delta
	velocity.y = 0.0
	velocity = velocity.limit_length(max_speed)
	velocity -= velocity * delta * damping

	move_and_slide()

	# Pinned to the plane AFTER the move, not just before it. Zeroing the
	# force and the velocity keeps the ship from steering off the plane, but
	# move_and_slide resolves collisions by pushing along the contact normal --
	# and a sphere collider on a rock has a normal with a Y component, so
	# clipping an asteroid lifted the ship off the plane with no velocity in Y
	# at all. Nothing then brought it back, because nothing was wrong with its
	# velocity.
	global_position.y = 0.0

	if velocity.length() > 0.01:
		var banked_up: Vector3 = Vector3.UP + acceleration * banking
		var smoothed_up: Vector3 = global_basis.y.lerp(banked_up, delta * 5.0)
		if use_face_target:
			# +Z is the model's front in this codebase. look_at's third
			# argument aims +Z at the target directly, which reads clearer
			# here than negating a "look away" vector.
			var to_face: Vector3 = face_target - global_position
			if absf(smoothed_up.normalized().dot(to_face.normalized())) < 0.999:
				look_at(face_target, smoothed_up, true)
		elif absf(smoothed_up.normalized().dot(velocity.normalized())) < 0.999:
			look_at(global_position - velocity, smoothed_up)

	_regenerate(delta)

	if draw_gizmos:
		DebugDraw3D.draw_arrow(
			global_position, global_position + force, Color.YELLOW, 0.1
		)
		DebugDraw3D.draw_arrow(
			global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1
		)


## Reduce health and end the match when it runs out.
func take_damage(amount: float) -> void:
	health -= amount
	_since_damage = 0.0
	if health <= 0.0:
		# Far bigger than a drone's, because it is far bigger. The match ends
		# on this, so it is the last thing the player sees.
		Explosion.burst(get_tree(), global_position, 4.0)
		destroyed.emit(self)


## Repair the hull once the ship has been left alone long enough.
func _regenerate(delta: float) -> void:
	_since_damage += delta
	if health <= 0.0 or max_health <= 0.0:
		return
	if _since_damage < regen_delay or health >= max_health:
		return
	health = minf(health + regen_per_second * delta, max_health)


## Clamp a thrust into the cone the ship can steer through.
##
## Rotated onto the cone's edge rather than projected onto it, so a thrust at
## the limit keeps its full magnitude and becomes the hardest turn available
## instead of collapsing to nothing.
##
## BRAKING IS EXEMPT: a thrust opposing the ship's own velocity is shedding
## speed, not dodging a turn, and a ship that cannot slow down cannot stop.
func _limit_to_steering_arc(desired: Vector3) -> Vector3:
	if max_steer_angle >= 180.0 or desired.length_squared() < 0.0001:
		return desired

	# +Z is the nose in this codebase, not Vector3.FORWARD.
	var nose: Vector3 = global_basis.z
	nose.y = 0.0
	if nose.length_squared() < 0.0001:
		return desired
	nose = nose.normalized()

	var direction: Vector3 = desired.normalized()
	var limit: float = deg_to_rad(max_steer_angle)
	var offset: float = nose.signed_angle_to(direction, Vector3.UP)
	if absf(offset) <= limit:
		return desired

	if velocity.length_squared() > 0.01 and desired.dot(velocity) < 0.0:
		return desired

	return nose.rotated(Vector3.UP, clampf(offset, -limit, limit)) * desired.length()
