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
@export var harvest_radius: float = 14.0

@export_group("Debug")

## Draw the harvest radius and remaining reserve.
@export var draw_gizmos: bool = true


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


func _process(_delta: float) -> void:
	if not draw_gizmos:
		return
	# Green while it holds alloys, fading toward grey as it empties, so a
	# glance at the belt says which rocks are still worth visiting.
	var colour: Color = Color(0.42, 0.39, 0.34).lerp(
		Color(0.62, 0.82, 0.23), fullness()
	)
	DebugDraw3D.draw_sphere(global_position, harvest_radius, colour)
