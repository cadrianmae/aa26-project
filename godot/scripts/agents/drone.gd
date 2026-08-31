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
class_name Drone
extends CharacterBody3D

## Emitted when health reaches zero, before the node is freed.
signal died(unit: Drone)

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

@export_group("Harvesting")

## Most Meta-Alloy this unit can carry at once.
##
## The cap is what creates the round trip. Without it a drone would harvest a
## Barnacle dry in one visit and the economy would be a single journey rather
## than a rhythm the player can watch, interrupt and defend.
@export var payload_capacity: float = 10.0

## Meta-Alloy currently carried. Filled by [HarvestState], emptied by
## [DepositState].
var payload: float = 0.0

@export_group("Debug")

## Draw the accumulated force and the velocity through DebugDraw3D.
@export var draw_gizmos: bool = true

@export_group("Flocking")

## The swarm this unit belongs to. Assigned in the scene, or by the factory
## when the unit is spawned at run time.
@export var swarm: Swarm

## Behaviours found among this unit's children, in scene-tree order.
## That order IS priority order -- see [method calculate_force].
var behaviours: Array[SteeringBehaviour] = []

## The force actually applied this tick, after smoothing.
var force: Vector3 = Vector3.ZERO

## Units near this one on the same side, refreshed once per frame. Shared by
## every flocking behaviour so the search runs once rather than three times.
var neighbours: Array[Drone] = []

## Set true by any behaviour that needs neighbours. A unit with no flocking
## behaviour never pays for the search.
var count_neighbours: bool = false


func _ready() -> void:
	_collect_behaviours()
	if swarm == null:
		# The Godot editor can silently delete instance-override properties
		# from the main scene, leaving units without a swarm reference.
		# Phases 2+ also spawn units at run time with no scene reference.
		# Fall back to a group lookup so we can find our swarm either way.
		swarm = get_tree().get_first_node_in_group(
			"swarm_" + str(allegiance)
		) as Swarm
	if swarm != null:
		swarm.register(self)


## Cache the child behaviours once rather than walking the child list every
## physics frame. Call again if behaviours are added at run time.
func _collect_behaviours() -> void:
	behaviours.clear()
	for child in get_children():
		if child is SteeringBehaviour:
			behaviours.append(child)


func _process(_delta: float) -> void:
	if swarm != null and count_neighbours:
		neighbours = swarm.neighbours_of(self)


# --- Force accumulation ---------------------------------------------------

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
## The break is the part worth understanding. Priority is SCENE-TREE CHILD
## ORDER -- there is no priority property anywhere -- so reordering the
## behaviour nodes on a unit changes what it does. Flee sits first, which is
## why the survival reflex is guaranteed its share of the force budget before
## formation-keeping gets any.
##
## The [method @GlobalScope.is_finite] guard is not defensive padding. A
## behaviour that divides by a zero-length vector returns NaN or infinity, and
## NaN poisons a running sum permanently: every later comparison against
## max_force returns false, so the truncation silently stops truncating and the
## break never fires. Checking is_finite rather than is_nan also catches the
## infinity that a near-zero divisor produces first.
func calculate_force() -> Vector3:
	var total_force: Vector3 = Vector3.ZERO
	var weighted_force: Vector3 = Vector3.ZERO

	for behaviour in behaviours:
		if not behaviour.enabled:
			continue

		weighted_force = behaviour.calculate() * behaviour.weight

		if not weighted_force.is_finite():
			weighted_force = Vector3.ZERO

		total_force += weighted_force
		if total_force.length() > max_force:
			total_force = total_force.limit_length(max_force)
			break

	return total_force


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

	# Pinned to the plane after the move. Zeroed forces keep a drone from
	# steering off it, but move_and_slide pushes along a contact normal, and a
	# rock's sphere collider has one that points partly up -- so a collision
	# lifts the drone off the plane with no Y velocity to bring it back.
	global_position.y = 0.0

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
## Whether this unit is carrying as much as it can.
##
## A method rather than callers comparing the two fields themselves, so
## "full" is defined once. Harvesting and depositing both ask this, and a
## later phase that adds a carrying upgrade changes only this line.
func is_full() -> bool:
	return payload >= payload_capacity


## Add up to [param amount] to the payload, returning what was actually taken.
##
## Mirrors [method Barnacle.extract]: the caller learns from the return value
## that the drone filled up, without a separate check that could disagree.
func load_payload(amount: float) -> float:
	var space: float = maxf(payload_capacity - payload, 0.0)
	var taken: float = minf(amount, space)
	payload += taken
	return taken


## Hand over everything carried, returning how much that was.
func unload_payload() -> float:
	var carried: float = payload
	payload = 0.0
	return carried


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		if swarm != null:
			swarm.deregister(self)
		died.emit(self)
		queue_free()
