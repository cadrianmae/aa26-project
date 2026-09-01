## A commander vessel: the player's ship, and the enemy's identical mirror.
##
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
@export_range(10.0, 180.0) var max_steer_angle: float = 135.0

@export_group("Combat")

@export var health: float = 2000.0

## Hull repaired per second, up to [member max_health].
@export var regen_per_second: float = 12.0

## Seconds after taking damage before repair resumes.
@export var regen_delay: float = 6.0

## How long the wreck lingers before it is removed, in seconds.
@export var death_fade_seconds: float = 1.2

## Health at spawn, for anything that needs to report damage as a fraction.
var max_health: float = 0.0

@export_group("Debug")

@export var draw_gizmos: bool = true

var behaviours: Array[SteeringBehaviour] = []
var force: Vector3 = Vector3.ZERO

## Seconds since this ship was last hit, for the regen delay.
var _since_damage: float = 999.0

## Latched once the hull is destroyed, so death resolves exactly once.
var _destroyed: bool = false

## Optional facing override, set by [PlayerSteeringBehaviour] in AIMED mode.
## Ignored unless [member use_face_target] is true.
var face_target: Vector3 = Vector3.ZERO

## When true, orient towards [member face_target] instead of velocity.
var use_face_target: bool = false


func _ready() -> void:
	max_health = health
	_collect_behaviours()
	# Group lookup, not a scene NodePath: run-time-spawned units and re-saved
	# instance overrides both lose scene-authored references.
	add_to_group("commander_" + str(allegiance))


## Cache the child behaviours once rather than walking the child list every
## physics frame. Call again if behaviours are added at run time.
func _collect_behaviours() -> void:
	behaviours.clear()
	for child in get_children():
		if child is SteeringBehaviour:
			behaviours.append(child)


## Weighted truncated sum of the child behaviours.
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

	# Pinned AFTER the move: move_and_slide resolves collisions along a contact
	# normal, and a rock's sphere collider has one with a Y component.
	global_position.y = 0.0

	if velocity.length() > 0.01:
		var banked_up: Vector3 = Vector3.UP + acceleration * banking
		var smoothed_up: Vector3 = global_basis.y.lerp(banked_up, delta * 5.0)
		if use_face_target:
			# +Z is the model's front here; look_at's third argument aims +Z directly.
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
		if allegiance == 0:
			_report_orientation()


## Put the ship's own position and heading on the debug overlay.
func _report_orientation() -> void:
	var nose: Vector3 = global_basis.z
	nose.y = 0.0
	if nose.length_squared() < 0.0001:
		return
	nose = nose.normalized()

	# 0 at north, increasing clockwise through east. North is -Z and east is
	# +X, matching the radar's cardinal labels.
	var bearing: float = fposmod(rad_to_deg(atan2(nose.x, -nose.z)), 360.0)

	DebugDraw2D.set_text("Ship X / Z", "%.0f, %.0f" % [global_position.x, global_position.z])
	DebugDraw2D.set_text("Ship facing", "%.0f deg  %s" % [bearing, _compass(bearing)])
	DebugDraw2D.set_text("Ship axis", _nearest_axis(nose))
	DebugDraw2D.set_text("Ship nose", "%+.2f X  %+.2f Z" % [nose.x, nose.z])


## A bearing in degrees as a compass point.
func _compass(bearing: float) -> String:
	var names: Array = [
		"N", "NE", "E", "SE", "S", "SW", "W", "NW"
	]
	return names[int(round(bearing / 45.0)) % 8]


## The signed world axis a flattened direction most nearly points along.
func _nearest_axis(flat: Vector3) -> String:
	if absf(flat.x) >= absf(flat.z):
		return "+X (east)" if flat.x > 0.0 else "-X (west)"
	return "+Z (south)" if flat.z > 0.0 else "-Z (north)"


## Reduce health and end the match when it runs out.
func take_damage(amount: float) -> void:
	if _destroyed:
		return
	health -= amount
	_since_damage = 0.0
	if health > 0.0:
		return

	# Latched: later hits must not emit destroyed a second time.
	_destroyed = true
	health = 0.0

	Explosion.burst(get_tree(), global_position, 4.0)
	destroyed.emit(self)
	_die()


## Take the hull out of the game.
##
## Leaves the group immediately: everything that hunts a commander resolves
## through it, so a wreck must not stay findable during the fade.
func _die() -> void:
	remove_from_group("commander_" + str(allegiance))
	set_physics_process(false)
	velocity = Vector3.ZERO

	for child in get_children():
		if child is SteeringBehaviour:
			child.enabled = false
		if child is Thruster:
			child.queue_free()

	var timer: SceneTreeTimer = get_tree().create_timer(death_fade_seconds)
	timer.timeout.connect(queue_free)


## Repair the hull once the ship has been left alone long enough.
func _regenerate(delta: float) -> void:
	_since_damage += delta
	if _destroyed or health <= 0.0 or max_health <= 0.0:
		return
	if _since_damage < regen_delay or health >= max_health:
		return
	health = minf(health + regen_per_second * delta, max_health)


## Clamp a thrust into the cone the ship can steer through.
##
## Braking is exempt: thrust opposing velocity is not a dodged turn.
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
