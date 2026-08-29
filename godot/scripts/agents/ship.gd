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
@export var max_speed: float = 18.0
@export var max_force: float = 40.0
@export var banking: float = 0.25
@export var damping: float = 0.6

@export_group("Combat")

@export var health: float = 500.0

@export_group("Debug")

@export var draw_gizmos: bool = true

var behaviours: Array[SteeringBehaviour] = []
var force: Vector3 = Vector3.ZERO

## Optional facing override, set by [PlayerSteeringBehaviour] in AIMED mode.
## Ignored unless [member use_face_target] is true.
var face_target: Vector3 = Vector3.ZERO

## When true, orient towards [member face_target] instead of velocity.
var use_face_target: bool = false


func _ready() -> void:
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
	force = force.lerp(new_force, delta * 4.0)

	var acceleration: Vector3 = force / mass
	velocity += acceleration * delta
	velocity.y = 0.0
	velocity = velocity.limit_length(max_speed)
	velocity -= velocity * delta * damping

	move_and_slide()

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
	if health <= 0.0:
		destroyed.emit(self)
