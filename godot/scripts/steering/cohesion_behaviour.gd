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


func _ready() -> void:
	super()
	var unit: Drone = agent as Drone
	if unit != null:
		unit.count_neighbours = true


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
	return force


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
