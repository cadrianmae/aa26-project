## An autonomous swarm creature, steered by its child [SteeringBehaviour] nodes.
##
## The unit owns movement and nothing else: mass, limits, banking, and the
## integration step. It never names a concrete behaviour, so adding seek, flee
## or flocking means adding a file and a node -- this script does not change.
##
## Each physics tick:
## [codeblock]
## force        = WTPRS sum of enabled behaviours
## acceleration = force / mass
## velocity    += acceleration * delta
## [/codeblock]
##
## Movement is constrained to the XZ plane: the Y component of both force and
## velocity is zeroed, because this is a 2.5D game.
class_name SwarmUnit
extends CharacterBody3D

## Emitted when health reaches zero, before the node is freed.
signal died(unit: SwarmUnit)

## Which side this unit fights for. Player is 0, enemy is 1.
@export var allegiance: int = 0

## Higher mass means the same force produces less acceleration, so the unit
## turns more sluggishly and feels heavier. Never set this to zero.
@export var mass: float = 1.0

## Speed ceiling in units per second. Behaviours read this to size the
## velocity they ask for, so it is an input, not a readout.
@export var max_speed: float = 12.0

## Ceiling on the summed steering force. Without it, several behaviours pulling
## the same way produce unbounded acceleration and the motion reads as robotic.
@export var max_force: float = 20.0

## How far the unit rolls into a turn. 0 keeps it upright.
@export var banking: float = 0.1

## Continuous velocity decay, applied on top of the speed clamp. This is what
## makes the unit coast to rest when the forces vanish.
@export var damping: float = 0.1

@export_group("Combat")

## Current health. Corrosion and enemy fire reduce it.
@export var health: float = 100.0

@export_group("Debug")

## Draw the accumulated force and the velocity through DebugDraw3D.
@export var draw_gizmos: bool = true

## Behaviours found among this unit's children, in scene-tree order.
## That order IS priority order -- see [method calculate_force].
var behaviours: Array[SteeringBehaviour] = []

## The force actually applied this tick, after smoothing.
var force: Vector3 = Vector3.ZERO


func _ready() -> void:
	_collect_behaviours()


## Cache the child behaviours once rather than walking the child list every
## physics frame. Call again if behaviours are added at run time.
func _collect_behaviours() -> void:
	behaviours.clear()
	for child in get_children():
		if child is SteeringBehaviour:
			behaviours.append(child)


# --- Force accumulation (Mae's implementation) ----------------------------

## Combine the child behaviours into one steering force using WTPRS:
## Weighted Truncated Running Sum with Prioritisation.
##
## Duggan's algorithm, behaviors/boid.gd:141-158. Four parts to it:
##   Weighted        multiply each behaviour's force by its own weight
##   Running Sum     accumulate as you go, testing after every single addition
##   Truncated       clamp the accumulator to max_force when it exceeds it
##   Prioritisation  break out of the loop at that point, so behaviours later
##                   in the child order contribute nothing at all this tick
##
## Steps:
##   1. Start an accumulator at Vector3.ZERO.
##   2. For each behaviour in `behaviours`, skip it unless `enabled`.
##   3. Multiply `behaviour.calculate()` by `behaviour.weight`.
##   4. Guard against NaN: a behaviour that divides by a zero-length vector
##      poisons the sum permanently, since NaN plus anything is NaN. Zero the
##      offending force instead.
##   5. Add it to the accumulator.
##   6. If the accumulator now exceeds `max_force`, clamp it with
##      `limit_length(max_force)` and break.
##   7. Return the accumulator.
func calculate_force() -> Vector3:
	# TODO(human): implement WTPRS per the steps above.
	return Vector3.ZERO


# --- Integration (fixed-timestep plumbing) --------------------------------

func _physics_process(delta: float) -> void:
	var new_force: Vector3 = calculate_force()
	new_force.y = 0.0

	# Low-pass filter the applied force so it chases the newly computed force
	# rather than snapping to it. Removes jitter when a behaviour switches on
	# or off. Duggan, behaviors/boid.gd:178.
	# The 4.0 multiplier sets the smoothing time constant (matches ship.gd).
	force = force.lerp(new_force, delta * 4.0)

	var acceleration: Vector3 = force / mass
	velocity += acceleration * delta
	velocity.y = 0.0

	# Clamp first, then damp. The clamp is a hard ceiling; damping is
	# continuous decay that also acts below the ceiling.
	velocity = velocity.limit_length(max_speed)
	velocity -= velocity * delta * damping

	move_and_slide()

	if velocity.length() > 0.01:
		_face_direction_of_travel(acceleration, delta)

	if draw_gizmos:
		DebugDraw3D.draw_arrow(
			global_position, global_position + force, Color.YELLOW, 0.1
		)
		DebugDraw3D.draw_arrow(
			global_position, global_position + velocity, Color.CORNFLOWER_BLUE, 0.1
		)


## Point the hull along the velocity and roll it into turns.
##
## [method Node3D.look_at] aims the node's -Z at the point given, but this
## codebase treats +Z as forward, following Duggan. Passing a point *behind*
## the unit aims -Z backwards, which leaves +Z along the velocity.
func _face_direction_of_travel(acceleration: Vector3, delta: float) -> void:
	var banked_up: Vector3 = Vector3.UP + acceleration * banking
	var smoothed_up: Vector3 = global_basis.y.lerp(banked_up, delta * 5.0)

	# look_at() errors when the up-vector is parallel to the look direction.
	if absf(smoothed_up.normalized().dot(velocity.normalized())) > 0.999:
		return
	look_at(global_position - velocity, smoothed_up)


## Reduce health and free the unit when it runs out.
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		died.emit(self)
		queue_free()
