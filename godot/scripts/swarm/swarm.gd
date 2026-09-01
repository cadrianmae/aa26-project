## A faction's swarm: the spatial index that answers "who is near this unit".
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/school.gd:29-58, with
## two corrections documented at their sites. Units register themselves on
## ready; this does not spawn them.
##
## The grid is a uniform spatial hash re-binned every frame.
class_name Swarm
extends Node

## Group each Swarm joins, suffixed with its allegiance.
const GROUP_PREFIX: String = "swarm_"

## What the swarm has been told to do. One order for the whole swarm, not per
## unit.
##
## Does not force a state: [SwarmIntentState] reads it, and the flee reflex
## overrides it.
enum Intent {
	## Hold formation on the commander. The default.
	HOLD,
	## Move to [member rally_point] and wait there.
	RALLY,
	## Sweep the area around the commander.
	PATROL,
	## Work the nearest Barnacle. Phase 3.
	HARVEST,
	## Attack the nearest enemy. Phase 4.
	ENGAGE,
}

## Emitted when [member intent] changes, so listeners react to the order rather
## than polling it. Carries both ends so a listener can tell what changed.
signal intent_changed(from: Intent, to: Intent)

## Which side this swarm belongs to. Units only ever see neighbours whose
## allegiance matches their own.
@export var allegiance: int = 0

## The standing order for this swarm. Set through [method order], never
## assigned directly, so the signal cannot be bypassed.
var intent: Intent = Intent.HOLD

## Where [constant Intent.RALLY] sends the swarm, in world space.
var rally_point: Vector3 = Vector3.ZERO

## The Barnacle the player has designated for [constant Intent.HARVEST].
var harvest_target: Barnacle

## How far a unit can see a neighbour, in world units.
@export var neighbour_distance: float = 20.0

## Most neighbours any one unit considers. Caps the cost of a dense cluster.
@export var max_neighbours: int = 10

## Width of one hash cell.
##
## Must be at least [member neighbour_distance]: the 27-cell scan reaches only
## one cell in the worst case, so a smaller cell silently misses neighbours.
## Enforced in _ready(). See docs.
@export var cell_size: float = 20.0

## Spread of the hash key space per axis. Large enough that distinct cells
## never collide onto one key for any position this game reaches.
@export var grid_size: int = 10000

## World-space offset applied before hashing, in world units, so every
## component is non-negative.
const ORIGIN_SHIFT: float = 10000.0

## When false, falls back to the naive O(n squared) scan.
@export var partition: bool = true

@export_group("Debug")

## Draw each unit's perception radius.
@export var draw_gizmos: bool = false

## Every living unit on this side.
var units: Array[Drone] = []

## Hash key to the units currently binned in that cell. Rebuilt every frame.
var _cells: Dictionary = {}


func _ready() -> void:
	if cell_size < neighbour_distance:
		push_warning(
			"Swarm cell_size (%.1f) is below neighbour_distance (%.1f); "
			% [cell_size, neighbour_distance]
			+ "raising it, because a smaller cell makes the 27-cell scan "
			+ "miss genuine neighbours."
		)
		cell_size = neighbour_distance

	# Group lookup is how spawned units find their swarm.
	add_to_group(Swarm.GROUP_PREFIX + str(allegiance))


## Add a unit to this swarm. Called by the unit itself on ready, so units
## created at run time join without the swarm knowing they exist beforehand.
func register(unit: Drone) -> void:
	if not units.has(unit):
		units.append(unit)


## Give the swarm a new standing order.
##
## The only way [member intent] changes; assigning it directly skips the
## signal. Re-issuing the order already in force is a no-op.
func order(new_intent: Intent, point: Vector3 = Vector3.ZERO) -> void:
	# The rally point is set before the early-out, so re-issuing RALLY at a new
	# location moves the swarm rather than being swallowed as a duplicate.
	if new_intent == Intent.RALLY:
		rally_point = point
	if new_intent == intent:
		return
	var previous: Intent = intent
	intent = new_intent
	intent_changed.emit(previous, intent)


## Remove a unit, on death or despawn.
func deregister(unit: Drone) -> void:
	units.erase(unit)


func _process(_delta: float) -> void:
	if partition:
		_rebuild_cells()
	if draw_gizmos:
		_draw_gizmos()


## Hash a world position to a single integer cell key.
##
## [constant ORIGIN_SHIFT] is a world-space offset in world units, keeping every
## component non-negative so distinct cells cannot alias onto one key.
## [member grid_size] is the key stride per axis, in cells. They are unrelated
## quantities that happen to share a value. Duggan, school.gd:29-34.
func position_to_cell(p: Vector3) -> int:
	var shifted: Vector3 = p + Vector3(ORIGIN_SHIFT, ORIGIN_SHIFT, ORIGIN_SHIFT)
	var x: int = int(floor(shifted.x / cell_size))
	var y: int = int(floor(shifted.y / cell_size))
	var z: int = int(floor(shifted.z / cell_size))
	return x + (y * grid_size) + (z * grid_size * grid_size)


## Re-bin every unit. O(n), once per rendered frame.
func _rebuild_cells() -> void:
	_cells.clear()
	for unit in units:
		if not is_instance_valid(unit):
			continue
		var key: int = position_to_cell(unit.global_position)
		if not _cells.has(key):
			_cells[key] = []
		_cells[key].append(unit)


## Return the nearest units to [param unit] on the same side, within
## [member neighbour_distance], at most [member max_neighbours] of them.
##
## Every candidate inside the radius is collected and sorted before truncation,
## so the units kept are the nearest rather than the first found. See docs.
func neighbours_of(unit: Drone) -> Array[Drone]:
	var found: Array[Drone] = []
	var candidates: Array = _candidates_for(unit)
	var radius_squared: float = neighbour_distance * neighbour_distance

	for other in candidates:
		if other == unit or not is_instance_valid(other):
			continue
		if other.allegiance != unit.allegiance:
			continue
		var offset: Vector3 = other.global_position - unit.global_position
		if offset.length_squared() <= radius_squared:
			found.append(other)

	# Nearest-first, then truncate.
	var origin: Vector3 = unit.global_position
	found.sort_custom(
		func(a: Drone, b: Drone) -> bool:
			return (
				a.global_position.distance_squared_to(origin)
				< b.global_position.distance_squared_to(origin)
			)
	)
	if found.size() > max_neighbours:
		found.resize(max_neighbours)
	return found


## The units worth distance-testing: the 27 cells around this one when
## partitioning, or everything when not.
##
## Offsetting the position by exactly cell_size shifts the cell index by one,
## so the 27 keys are distinct. Duggan, boid.gd:44-49.
func _candidates_for(unit: Drone) -> Array:
	if not partition:
		return units

	var gathered: Array = []
	var origin: Vector3 = unit.global_position
	for slice in [0, -1, 1]:
		for row in [0, -1, 1]:
			for col in [0, -1, 1]:
				var sample: Vector3 = origin + Vector3(
					float(col) * cell_size,
					float(row) * cell_size,
					float(slice) * cell_size
				)
				var key: int = position_to_cell(sample)
				if _cells.has(key):
					gathered.append_array(_cells[key])
	return gathered


func _draw_gizmos() -> void:
	for unit in units:
		if is_instance_valid(unit):
			DebugDraw3D.draw_sphere(
				unit.global_position, neighbour_distance, Color.WEB_PURPLE
			)


## Every live commander and drone belonging to [param enemy_allegiance].
##
## Drones are reached through their Swarm rather than a group: they never join
## one, the Swarm owns its units.
## is_instance_valid comes BEFORE every cast: casting a freed object throws,
## so a check afterwards never runs.
static func hostiles_of(tree: SceneTree, enemy_allegiance: int) -> Array[Node3D]:
	var found: Array[Node3D] = []

	for node in tree.get_nodes_in_group(Ship.GROUP_PREFIX + str(enemy_allegiance)):
		if not is_instance_valid(node):
			continue
		var ship: Node3D = node as Node3D
		if ship != null:
			found.append(ship)

	for node in tree.get_nodes_in_group(GROUP_PREFIX + str(enemy_allegiance)):
		if not is_instance_valid(node):
			continue
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		for unit in swarm.units:
			if not is_instance_valid(unit):
				continue
			var drone: Node3D = unit as Node3D
			if drone != null:
				found.append(drone)

	return found


## The closest hostile to [param from] within [param max_distance], or null.
static func nearest_hostile(
	tree: SceneTree,
	from: Vector3,
	enemy_allegiance: int,
	max_distance: float = INF
) -> Node3D:
	var closest: Node3D = null
	var closest_distance: float = max_distance
	for hostile in hostiles_of(tree, enemy_allegiance):
		var distance: float = from.distance_to(hostile.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = hostile
	return closest


## Distance to the closest hostile, or INF when the field is clear.
static func nearest_hostile_distance(
	tree: SceneTree, from: Vector3, enemy_allegiance: int
) -> float:
	var closest: Node3D = nearest_hostile(tree, from, enemy_allegiance)
	if closest == null:
		return INF
	return from.distance_to(closest.global_position)
