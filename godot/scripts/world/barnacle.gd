## A Thargoid Barnacle: a finite reserve of Meta-Alloys growing on an asteroid.
class_name Barnacle
extends Node3D

## Emitted when the reserve reaches zero.
signal depleted(barnacle: Barnacle)

## Emitted whenever alloys are taken, for gizmos and audio to react to.
signal extracted(amount: float, remaining: float)

## Every Barnacle joins this group.
const GROUP: String = "barnacles"

## How many Meta-Alloys are left in this Barnacle.
@export var reserve: float = 120.0

## The reserve it started with, captured in [method _ready].
var _initial_reserve: float = 0.0

## How close a drone must be to draw from it.
@export var harvest_radius: float = 6.0

## How long a claim survives without being renewed, in seconds.
##
## A claim is a lease: it expires unless the holder renews it on each draw.
@export var claim_timeout: float = 1.5

## The drone currently working this Barnacle, or null when it is free.
var occupant: Drone

## Seconds left on the current claim.
var _lease: float = 0.0

@export_group("Debug")

## Draw the harvest radius and remaining reserve.
@export var draw_gizmos: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_initial_reserve = reserve


## Take up to [param amount] alloys, returning how much was actually taken.
##
## Returns LESS than asked when the Barnacle is nearly spent, and 0.0 when it
## is empty.
func extract(amount: float) -> float:
	if amount <= 0.0 or reserve <= 0.0:
		return 0.0
	var taken: float = minf(amount, reserve)
	reserve -= taken
	extracted.emit(taken, reserve)
	if reserve <= 0.0:
		reserve = 0.0
		depleted.emit(self)
	return taken


## Whether anything is left to take.
func is_spent() -> bool:
	return reserve <= 0.0


## Whether no drone currently holds this Barnacle.
func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)


## Try to take this Barnacle. Returns whether [param drone] now holds it.
##
## Re-claiming as the current occupant succeeds and renews the lease.
func claim(drone: Drone) -> bool:
	if drone == null:
		return false
	if not is_free() and occupant != drone:
		return false
	occupant = drone
	_lease = claim_timeout
	return true


## Give up the claim, if [param drone] is the one holding it.
func release(drone: Drone) -> void:
	if occupant == drone:
		occupant = null
		_lease = 0.0


## How full this Barnacle is, from 0.0 to 1.0.
func fullness() -> float:
	if _initial_reserve <= 0.0:
		return 0.0
	return clampf(reserve / _initial_reserve, 0.0, 1.0)


## The nearest Barnacle with alloys left, or null when the belt is stripped.
static func nearest_to(tree: SceneTree, point: Vector3) -> Barnacle:
	var best: Barnacle = null
	var best_distance: float = INF
	for node in tree.get_nodes_in_group(GROUP):
		var barnacle: Barnacle = node as Barnacle
		if barnacle == null or barnacle.is_spent():
			continue
		var distance: float = point.distance_squared_to(barnacle.global_position)
		if distance < best_distance:
			best_distance = distance
			best = barnacle
	return best


func _process(delta: float) -> void:
	_expire_claim(delta)

	if not draw_gizmos:
		return
	var colour: Color = Color(0.42, 0.39, 0.34).lerp(
		Color(0.62, 0.82, 0.23), fullness()
	)
	DebugDraw3D.draw_sphere(global_position, harvest_radius, colour)
	if not is_free():
		DebugDraw3D.draw_line(
			global_position, occupant.global_position, Color(0.62, 0.82, 0.23)
		)


## Count the lease down and drop the claim when it runs out.
func _expire_claim(delta: float) -> void:
	if occupant == null:
		return
	if not is_instance_valid(occupant):
		occupant = null
		_lease = 0.0
		return
	_lease -= delta
	if _lease <= 0.0:
		occupant = null
