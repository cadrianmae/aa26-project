## Steer toward the average position of nearby neighbours, so units do not get
## left behind.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/cohesion.gd:14-24.
##
## Cohesion is the cleanest example of a behaviour composed out of seek: the
## whole force is "average the neighbours' positions, then seek that point".
##
## The trailing normalisation matters. Cohesion contributes a UNIT-LENGTH
## direction only, discarding magnitude, so distance sets direction and nothing
## else; relative strength is left entirely to weight in the WTPRS sum.
## Separation deliberately keeps its magnitude, cohesion deliberately discards
## it. That asymmetry is what stops the flock collapsing in on itself.
class_name CohesionBehaviour
extends SteeringBehaviour

## How loose the swarm gets when its commander is nearly dead, as a fraction
## of full cohesion.
##
## Taken from how Thargon swarms behave in Elite Dangerous: as the Interceptor
## controlling them loses hearts, its swarm visibly moves with LESS cohesion.
## The swarm's tightness reports the mothership's health, so a player reads
## how a fight is going by looking at the enemy's drones rather than at a bar.
##
## Emergent rather than scripted: nothing tells the drones to spread out. One
## weight falls, the separation force that was always there stops being
## balanced, and the formation opens up on its own.
@export_range(0.0, 1.0) var wounded_cohesion: float = 0.2

## The commander this unit's cohesion depends on. Resolved on first use, never
## in _ready(): Godot readies siblings in scene order, and a drone can be ready
## before the ship it belongs to.
var _commander: Ship

## The commander's health when first seen, so "hurt" is a proportion rather
## than a number hard-coded here.
var _commander_full_health: float = 0.0


func _ready() -> void:
	super()
	var unit: Drone = agent as Drone
	if unit != null:
		unit.count_neighbours = true


## How tightly this unit should flock right now, from wounded_cohesion to 1.0.
func cohesion_scale() -> float:
	var unit: Drone = agent as Drone
	if unit == null:
		return 1.0
	if _commander == null:
		_commander = get_tree().get_first_node_in_group(
			"commander_" + str(unit.allegiance)
		) as Ship
		if _commander == null:
			return 1.0
		_commander_full_health = _commander.health
	if not is_instance_valid(_commander) or _commander_full_health <= 0.0:
		return wounded_cohesion
	var health: float = clampf(_commander.health / _commander_full_health, 0.0, 1.0)
	return lerpf(wounded_cohesion, 1.0, health)


func calculate() -> Vector3:
	var unit: Drone = agent as Drone
	if unit == null:
		return Vector3.ZERO

	var valid: int = 0
	var centre_of_mass: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if is_instance_valid(other):
			centre_of_mass += other.global_position
			valid += 1

	if valid == 0:
		return Vector3.ZERO

	centre_of_mass /= float(valid)
	var force: Vector3 = seek_towards(centre_of_mass).normalized()
	force.y = 0.0
	# Scaled here rather than by writing to `weight`, so the Inspector value
	# keeps meaning "how cohesive is this swarm at full health" instead of
	# being silently overwritten every frame.
	return force * cohesion_scale()


func on_draw_gizmos() -> void:
	var unit: Drone = agent as Drone
	if unit == null or unit.neighbours.is_empty():
		return
	var centre: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if is_instance_valid(other):
			centre += other.global_position
	centre /= float(unit.neighbours.size())
	DebugDraw3D.draw_line(unit.global_position, centre, Color.CORNFLOWER_BLUE)
