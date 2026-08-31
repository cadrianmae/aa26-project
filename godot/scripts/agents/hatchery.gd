## One side's alloy pool, and the factory that spends it.
##
## The economy's sink and its purpose. Drones deposit here; the pool buys more
## drones. That loop is the whole reason harvesting matters -- without it the
## alloy count is a score rather than a resource.
##
## Lives ON the Matriarch, as a child node, not as a structure somewhere in
## the belt. The capital ship IS the hatchery: it grows the drones and they bring
## their loads back to it. That follows the fiction, and it makes the
## commander's position a decision -- fly forward and the supply line follows,
## with every drone's round trip getting shorter or longer accordingly.
##
## One Hatchery per allegiance. The rival's is the same script under a different
## ship, not a special case: [CommanderAI] spends through the same API the
## player's harvesting fills, so both sides run identical economies and only
## their decisions differ.
##
## Spawning lives here rather than in [Swarm] because they answer different
## questions. The Swarm knows who is near whom; the Hatchery knows who exists and
## what they cost. Keeping them apart is what let the Swarm be written before
## anything could spawn.
class_name Hatchery
extends Node3D

## Emitted whenever the pool changes, so a HUD can react rather than poll.
signal alloys_changed(total: float)

## Emitted after a drone is built and registered.
signal drone_spawned(drone: Drone)

## Group naming, matching the Swarm's own "swarm_<allegiance>" convention.
const GROUP_PREFIX: String = "hatchery_"

## Which side this hatchery belongs to.
@export var allegiance: int = 0

## Meta-Alloys in the pool.
@export var alloys: float = 0.0

## How close a drone must be to deposit.
##
## Tight, and paired with the node sitting BEHIND the Matriarch rather than at
## its centre. The hull is about 8 units long, so a drone delivering to the
## ship's middle would be flying through it; delivering to a point off the
## tail makes the drones queue into the ship's wake, which reads as a supply
## line instead of as drones vanishing into the hull.
##
## Because the node is a child of the ship, the offset rotates with it -- turn
## the Matriarch and the drop-off swings round to stay astern, with nothing
## computing that.
@export var deposit_radius: float = 7.0

@export_group("Factory")

## The drone to build. Left unset, the hatchery banks alloys and never spends.
@export var drone_scene: PackedScene

## What one drone costs.
@export var drone_cost: float = 25.0

## Ceiling on swarm size. The spatial hash is O(n) per frame and the flocking
## behaviours are capped at ten neighbours each, so this is a frame-budget
## limit rather than a design one.
@export var max_drones: int = 40

## How far from the hatchery a new drone appears.
@export var spawn_spread: float = 12.0

## Seconds between build attempts. Not per frame: at 60 Hz a full pool would
## empty into forty drones inside a second, which reads as a glitch rather
## than as production.
@export var build_interval: float = 1.2

@export_group("Debug")

## Draw the deposit radius.
@export var draw_gizmos: bool = true

## The swarm new drones join. Resolved on first use, never in _ready(): Godot
## readies siblings in scene order, and this hatchery may be ready first.
var _swarm: Swarm

## Seconds since the last build attempt.
var _since_build: float = 0.0


func _ready() -> void:
	# Inherit the ship's side rather than being set twice. A hatchery on the
	# rival's Matriarch that was left at allegiance 0 would quietly bank the
	# enemy's alloys into the player's pool, which is the kind of fault that
	# looks like a balance problem rather than a bug.
	var carrier: Node = get_parent()
	if carrier != null and "allegiance" in carrier:
		allegiance = carrier.allegiance
	add_to_group(GROUP_PREFIX + str(allegiance))


## The hatchery for [param allegiance_id], or null if that side has none.
##
## Static and group-based so a drone spawned at run time can find its hatchery
## with no wiring. Mirrors [method RallyMarker.for_swarm].
static func for_allegiance(tree: SceneTree, allegiance_id: int) -> Hatchery:
	var found: Array = tree.get_nodes_in_group(GROUP_PREFIX + str(allegiance_id))
	if found.is_empty():
		return null
	return found[0] as Hatchery


## Add alloys to the pool.
##
## Takes what it is given without asking where from, so a drone depositing, a
## debug command and a future salvage mechanic all use one path.
func deposit(amount: float) -> void:
	if amount <= 0.0:
		return
	alloys += amount
	alloys_changed.emit(alloys)


## Whether a drone at [param point] is close enough to deposit.
func can_deposit_from(point: Vector3) -> bool:
	return global_position.distance_to(point) <= deposit_radius


func _resolve_swarm() -> void:
	if _swarm != null:
		return
	var found: Array = get_tree().get_nodes_in_group("swarm_" + str(allegiance))
	if not found.is_empty():
		_swarm = found[0] as Swarm


func _process(delta: float) -> void:
	if draw_gizmos:
		DebugDraw3D.draw_sphere(
			global_position, deposit_radius, Color(0.435, 0.812, 0.353)
		)

	_since_build += delta
	if _since_build < build_interval:
		return
	_since_build = 0.0
	_try_build()


## Spend one drone's worth of alloys, if there are alloys and room.
##
## One per interval rather than draining the pool in a loop: a hatchery that
## banked a hundred alloys while its drones were away should not answer with
## four ships at once. Production paced this way also gives the rival hatchery a
## visible build-up the player can read and respond to.
func _try_build() -> void:
	if drone_scene == null:
		return
	_resolve_swarm()
	if _swarm == null:
		return
	if alloys < drone_cost or _swarm.units.size() >= max_drones:
		return

	alloys -= drone_cost
	alloys_changed.emit(alloys)
	spawn_drone()


## Build one drone and put it in the world, regardless of cost.
##
## Separate from [method _try_build] so a test or a debug key can spawn
## without touching the pool, and so the affordability rule lives in exactly
## one place.
func spawn_drone() -> Drone:
	if drone_scene == null:
		return null
	var drone: Drone = drone_scene.instantiate() as Drone
	if drone == null:
		push_error("%s: drone_scene is not a Drone." % name)
		return null

	# Allegiance and swarm are set BEFORE the node enters the tree, because
	# Drone._ready() registers itself using them -- assigning afterwards
	# would leave the drone registered to the wrong swarm, or to none.
	drone.allegiance = allegiance
	_resolve_swarm()
	drone.swarm = _swarm

	var angle: float = randf() * TAU
	var distance: float = sqrt(randf()) * spawn_spread
	drone.position = global_position + Vector3(
		cos(angle) * distance, 0.0, sin(angle) * distance
	)

	_drone_container().add_child(drone)
	_launch(drone)
	drone_spawned.emit(drone)
	return drone


## Where new drones are parented.
##
## A SIBLING of the Matriarch, never a child of it. The hatchery rides on the
## ship, so parenting drones to the hatchery would make them children of the ship
## too -- and they would then inherit its transform, flying in rigid lockstep
## with it however hard their own steering pushed. The whole swarm would move
## as one object.
func _drone_container() -> Node:
	var carrier: Node = get_parent()
	if carrier != null and carrier.get_parent() != null:
		return carrier.get_parent()
	return get_tree().current_scene


## Put a newly built drone into LaunchState.
##
## Deferred, because the drone's StateMachine enters its initial state in a
## deferred call of its own -- changing state before that lands would be
## immediately overwritten by the scene's initial_state.
func _launch(drone: Drone) -> void:
	drone.get_node("StateMachine").call_deferred("change_state_named", "Launch")
