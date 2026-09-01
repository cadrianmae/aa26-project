## One side's alloy pool, and the factory that spends it.
##
## A child of the Matriarch, so moving the ship moves the drop-off point.
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
## The node is a child of the ship, so the offset rotates with it.
@export var deposit_radius: float = 7.0

@export_group("Factory")

## The drone to build. Left unset, the hatchery banks alloys and never spends.
@export var drone_scene: PackedScene

## What one drone costs.
@export var drone_cost: float = 25.0

## Ceiling on swarm size. A frame-budget limit, not a design one.
@export var max_drones: int = 40

## How far from the hatchery a new drone appears.
@export var spawn_spread: float = 12.0

## Seconds between build attempts.
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
	# Inherit the carrier ship's side rather than setting it in two places.
	var carrier: Node = get_parent()
	if carrier != null and "allegiance" in carrier:
		allegiance = carrier.allegiance
	add_to_group(GROUP_PREFIX + str(allegiance))


## The hatchery for [param allegiance_id], or null if that side has none.
##
## Mirrors [method RallyMarker.for_swarm].
static func for_allegiance(tree: SceneTree, allegiance_id: int) -> Hatchery:
	var found: Array = tree.get_nodes_in_group(GROUP_PREFIX + str(allegiance_id))
	if found.is_empty():
		return null
	return found[0] as Hatchery


## Add alloys to the pool.
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
func spawn_drone() -> Drone:
	if drone_scene == null:
		return null
	var drone: Drone = drone_scene.instantiate() as Drone
	if drone == null:
		push_error("%s: drone_scene is not a Drone." % name)
		return null

	# Allegiance and swarm are set BEFORE the node enters the tree, because
	# Drone._ready() registers itself using them.
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
## A SIBLING of the Matriarch, never a child: children inherit its
## transform and the whole swarm would move as one object.
func _drone_container() -> Node:
	var carrier: Node = get_parent()
	if carrier != null and carrier.get_parent() != null:
		return carrier.get_parent()
	return get_tree().current_scene


## Put a newly built drone into LaunchState.
##
## Deferred, because the drone's StateMachine enters its initial state in a
## deferred call -- changing state before that lands would be overwritten.
func _launch(drone: Drone) -> void:
	drone.get_node("StateMachine").call_deferred("change_state_named", "Launch")
