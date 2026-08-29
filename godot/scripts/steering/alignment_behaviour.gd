## Match the average heading of nearby neighbours, so the flock moves as one.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/alignment.gd:13-21.
##
## This averages neighbours' HEADINGS (basis.z), not their velocities, which
## has two consequences worth knowing. It is speed-independent: a fast and a
## slow neighbour pointing the same way contribute identically. And it is only
## correct because +Z is forward in this codebase; averaging basis.z under
## Godot's default -Z-forward would align the flock backwards.
##
## DEFECT 3 in Duggan's alignment.gd:17-20 -- his `force` is a member written
## only inside the `neighbors.size() > 0` guard, so a unit that loses all its
## neighbours keeps applying its LAST alignment force indefinitely. A lone unit
## latches on a stale heading forever. Fixed here by returning Vector3.ZERO
## when there are no neighbours, so the behaviour contributes nothing rather
## than something stale.
class_name AlignmentBehaviour
extends SteeringBehaviour


func _ready() -> void:
	super()
	var unit: SwarmUnit = agent as SwarmUnit
	if unit != null:
		unit.count_neighbours = true


func calculate() -> Vector3:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null:
		return Vector3.ZERO

	var valid: int = 0
	var desired: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if is_instance_valid(other):
			desired += other.global_transform.basis.z
			valid += 1

	# The correction to DEFECT 3: no neighbours means no force, not the
	# previous frame's force.
	if valid == 0:
		return Vector3.ZERO

	desired /= float(valid)
	var force: Vector3 = desired - unit.global_transform.basis.z
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null or unit.neighbours.is_empty():
		return
	DebugDraw3D.draw_arrow(
		unit.global_position,
		unit.global_position + unit.global_transform.basis.z * 4.0,
		Color.SPRING_GREEN,
		0.1
	)
