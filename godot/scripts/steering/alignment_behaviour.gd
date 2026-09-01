## Match the average heading of nearby neighbours, so the flock moves as one.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/alignment.gd:13-21.
##
## Averages basis.z: +Z is forward in this codebase, not Godot's default -Z.
class_name AlignmentBehaviour
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
	var desired: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if is_instance_valid(other):
			desired += other.global_transform.basis.z
			valid += 1

	if valid == 0:
		return Vector3.ZERO

	desired /= float(valid)
	var force: Vector3 = desired - unit.global_transform.basis.z
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var unit: Drone = agent as Drone
	if unit == null or unit.neighbours.is_empty():
		return
	DebugDraw3D.draw_arrow(
		unit.global_position,
		unit.global_position + unit.global_transform.basis.z * 4.0,
		Color.SPRING_GREEN,
		0.1
	)
