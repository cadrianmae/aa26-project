## A Thargoid Barnacle: a finite reserve of Meta-Alloys growing on an asteroid.
##
## The economy's source. It knows nothing about drones, harvesting, or who is
## taking from it -- it holds a quantity and hands some out when asked. That
## keeps the rule about how fast alloys come out in [HarvestState], where the
## unit doing the work lives, rather than split across both.
##
## Finite on purpose. A Barnacle that never ran dry would let a hive sit on
## one rock forever; running dry is what pushes the swarm outward and
## eventually into contact with the rival hive. The map's pressure comes from
## the resource, not from a timer.
class_name Barnacle
extends Node3D

## Emitted when the reserve reaches zero. The Barnacle stays in the world --
## a spent shell is still a landmark, and still cover.
signal depleted(barnacle: Barnacle)

## Emitted whenever alloys are taken, for gizmos and audio to react to.
signal extracted(amount: float, remaining: float)

## Every Barnacle joins this group. Neutral, so one group rather than one per
## allegiance: a Barnacle belongs to whoever reaches it.
const GROUP: String = "barnacles"

## How many Meta-Alloys are left in this Barnacle.
@export var reserve: float = 120.0

## The reserve it started with, so a gizmo can show a proportion rather than
## an absolute, and so a spent Barnacle can be told from a small one.
@export var initial_reserve: float = 120.0

## How close a drone must be to draw from it.
##
## Tight on purpose. The Barnacle's own hull is about 3.5 units across, so at
## 6 a drone has to sit against the rock to work it -- which is the point: the
## player should SEE a drone harvesting, not see it hovering vaguely nearby
## while a number goes up. A generous radius makes the mechanic invisible.
@export var harvest_radius: float = 6.0

## How long a claim survives without being renewed, in seconds.
##
## A claim is a LEASE, not a lock. A drone that dies mid-harvest, or is
## scattered by the flee reflex, never gets to release its claim -- and a
## Barnacle held by a drone that no longer exists would be locked out of the
## economy permanently. Renewing on every draw and expiring otherwise means a
## claim cleans itself up without the drone having to survive to do it.
@export var claim_timeout: float = 1.5

## The drone currently working this Barnacle, or null when it is free.
##
## One at a time, on purpose. A queue forms around a busy Barnacle with
## nothing coordinating it: each waiting drone simply cannot claim, so it
## holds station until the one in front leaves. That bottleneck is also what
## makes a bigger swarm spread ACROSS the belt rather than just harvesting one
## rock faster.
var occupant: Drone

## Seconds left on the current claim.
var _lease: float = 0.0

@export_group("Debug")

## Draw the harvest radius and remaining reserve.
##
## Off by default, unlike most gizmos in this project. There are nine
## Barnacles spread across the belt and each draws a sphere, so leaving them
## on fills the screen with wireframe circles that have nothing to do with
## whatever is being debugged at the time. Turn one on when working on
## harvesting.
@export var draw_gizmos: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	initial_reserve = reserve


## Take up to [param amount] alloys, returning how much was actually taken.
##
## Returns LESS than asked when the Barnacle is nearly spent, and 0.0 when it
## is empty. The caller has to look at the return value rather than assuming
## it got what it asked for -- which is what lets a drone notice a Barnacle
## has run dry without a separate query.
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
##
## A claim held by a freed drone counts as free: the lease will expire anyway,
## but checking validity here means the next drone does not have to wait out
## the timeout for a claimant that no longer exists.
func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)


## Try to take this Barnacle. Returns whether [param drone] now holds it.
##
## Re-claiming when already the occupant succeeds and renews the lease, so a
## working drone calls this every frame without special-casing the first one.
func claim(drone: Drone) -> bool:
	if drone == null:
		return false
	if not is_free() and occupant != drone:
		return false
	occupant = drone
	_lease = claim_timeout
	return true


## Give up the claim, if [param drone] is the one holding it.
##
## Checks the holder rather than clearing unconditionally: a drone that was
## queued behind another and gave up would otherwise evict the drone actually
## working the rock.
func release(drone: Drone) -> void:
	if occupant == drone:
		occupant = null
		_lease = 0.0


## How full this Barnacle is, from 0.0 to 1.0.
func fullness() -> float:
	if initial_reserve <= 0.0:
		return 0.0
	return clampf(reserve / initial_reserve, 0.0, 1.0)


## The nearest Barnacle with alloys left, or null when the belt is stripped.
##
## Skips spent Barnacles rather than returning the closest one regardless: a
## drone sent to an empty rock would sit there, and "nearest" is only useful
## to a harvester if it means "nearest one worth going to".
##
## Static, and searching by group, so a drone spawned at run time can find one
## with no wiring. Mirrors [method Threat.nearest_to].
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
	# Green while it holds alloys, fading toward grey as it empties, so a
	# glance at the belt says which rocks are still worth visiting.
	var colour: Color = Color(0.42, 0.39, 0.34).lerp(
		Color(0.62, 0.82, 0.23), fullness()
	)
	DebugDraw3D.draw_sphere(global_position, harvest_radius, colour)
	# A line to whoever is working it, so a queue is visible as a queue rather
	# than as a cluster of drones milling about.
	if not is_free():
		DebugDraw3D.draw_line(
			global_position, occupant.global_position, Color(0.62, 0.82, 0.23)
		)


## Count the lease down and drop the claim when it runs out.
##
## This is what a drone killed or scattered mid-harvest relies on: nothing
## releases its claim, so the Barnacle has to notice it stopped renewing.
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
