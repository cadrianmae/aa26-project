## A faction's swarm: the spatial index that answers "who is near this unit".
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/school.gd:29-58, with
## three corrections documented at their sites. Unlike his School this does NOT
## spawn its units: Phase 3's factory owns spawning, and units register
## themselves on ready. Separating "who creates units" from "who indexes them"
## is what lets a unit spawned at run time join the flock with no special case.
##
## The grid is a uniform spatial hash re-binned every frame. Binning is O(n)
## with no tree to rebuild, which is the right trade for a few hundred agents
## that all move every frame. The naive alternative is O(n squared): at 100
## units that is 9,900 distance checks per frame, at 1,000 it is 999,000.
class_name Swarm
extends Node

## Which side this swarm belongs to. Units only ever see neighbours whose
## allegiance matches their own.
@export var allegiance: int = 0

## How far a unit can see a neighbour, in world units.
@export var neighbour_distance: float = 20.0

## Most neighbours any one unit considers. Caps the cost of a dense cluster.
@export var max_neighbours: int = 10

## Width of one hash cell.
##
## DEFECT 1 in Duggan's school.gd:9,14 -- he ships cell_size = 10 against
## neighbour_distance = 20. The 27-cell scan samples the boid's own cell plus
## the 26 around it, so the GUARANTEED reach in any direction is only one
## cell_size (the unit can sit hard against a cell face), up to two at best.
## With his numbers a genuine neighbour 16 to 20 units away is silently missed.
## The flock still looks passable because a missed neighbour at the edge of the
## perception sphere contributes almost nothing under 1/d separation, but it is
## a correctness bug, not a tuning choice. Fixed by requiring
## cell_size >= neighbour_distance, enforced in _ready().
@export var cell_size: float = 20.0

## Spread of the hash key space per axis. Large enough that distinct cells
## never collide onto one key for any position this game reaches.
@export var grid_size: int = 10000

## When false, falls back to the naive O(n squared) scan. Kept as a runtime
## A/B against the partitioned path, which is what the optimisation claim in
## the write-up rests on.
@export var partition: bool = true

@export_group("Debug")

## Draw the occupied cells and each unit's perception radius.
@export var draw_gizmos: bool = false

## Every living unit on this side.
var units: Array[SwarmUnit] = []

## Hash key to the units currently binned in that cell. Rebuilt every frame.
var _cells: Dictionary = {}


func _ready() -> void:
	# Enforcing the fix rather than trusting the Inspector: a cell smaller than
	# the perception radius reintroduces DEFECT 1 silently.
	if cell_size < neighbour_distance:
		push_warning(
			"Swarm cell_size (%.1f) is below neighbour_distance (%.1f); "
			% [cell_size, neighbour_distance]
			+ "raising it, because a smaller cell makes the 27-cell scan "
			+ "miss genuine neighbours."
		)
		cell_size = neighbour_distance

	# Register this swarm in a group keyed by allegiance. This is how spawned
	# units locate their swarm when no export reference is set; runtime spawned
	# units in Phase 3 depend on this.
	add_to_group("swarm_" + str(allegiance))


## Add a unit to this swarm. Called by the unit itself on ready, so units
## created at run time join without the swarm knowing they exist beforehand.
func register(unit: SwarmUnit) -> void:
	if not units.has(unit):
		units.append(unit)


## Remove a unit, on death or despawn.
func deregister(unit: SwarmUnit) -> void:
	units.erase(unit)


func _process(_delta: float) -> void:
	if partition:
		_rebuild_cells()
	if draw_gizmos:
		_draw_gizmos()


## Hash a world position to a single integer cell key.
##
## The +10000 shift kills negative coordinates before flooring. Without it
## floor(-0.5) is -1 and floor(0.5) is 0, so positions either side of an axis
## collapse onto neighbouring keys and the grid corrupts near the origin.
## Duggan, school.gd:29-34.
func position_to_cell(p: Vector3) -> int:
	var shifted: Vector3 = p + Vector3(10000.0, 10000.0, 10000.0)
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
## DEFECT 2 in Duggan's boid.gd:65-66 -- he returns the moment the neighbour
## count hits the cap, so the units kept are the first ones the cell iteration
## happened to reach, NOT the nearest. In a dense cluster that is a meaningful
## bias, and scanning the centre cell first only mitigates it. Fixed here by
## collecting every candidate inside the radius, sorting by distance, and
## keeping the closest max_neighbours.
func neighbours_of(unit: SwarmUnit) -> Array[SwarmUnit]:
	var found: Array[SwarmUnit] = []
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

	# Nearest-first, then truncate. This is the correction to DEFECT 2.
	var origin: Vector3 = unit.global_position
	found.sort_custom(
		func(a: SwarmUnit, b: SwarmUnit) -> bool:
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
## Offsetting the POSITION by exactly cell_size always shifts the cell index by
## exactly one, so the 27 keys are distinct and nothing is double-counted.
## Note 3x3x3 = 27 is the 3D figure; the familiar "own cell plus 8 neighbours"
## is the 2D form and is wrong here. Duggan, boid.gd:44-49.
func _candidates_for(unit: SwarmUnit) -> Array:
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
