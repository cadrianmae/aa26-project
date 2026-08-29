## Steer away from near neighbours so units do not overlap.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/separation.gd:16-22.
##
## The falloff is INVERSE distance, 1/d, not inverse-square. The expression
## away.normalized() / away.length() is away / |away| squared, whose MAGNITUDE
## is 1/|away|. It reads as inverse-square because of the squared denominator;
## it is not. Closer neighbours dominate, and deliberately so.
##
## The sum is neither normalised nor divided by the neighbour count, unlike
## cohesion. A unit in a tight cluster gets a genuinely larger escape force,
## which is the point. Truncation is left to the agent's WTPRS max_force clamp.
class_name SeparationBehaviour
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

	var force: Vector3 = Vector3.ZERO
	for other in unit.neighbours:
		if not is_instance_valid(other):
			continue
		var away: Vector3 = unit.global_position - other.global_position
		var distance: float = away.length()
		# Guard the division: two units at the same position give a
		# zero-length vector, and away.normalized() / 0.0 poisons the whole
		# WTPRS sum with infinity or NaN.
		if distance > 0.001:
			force += away.normalized() / distance
	force.y = 0.0
	return force


func on_draw_gizmos() -> void:
	var unit: SwarmUnit = agent as SwarmUnit
	if unit == null:
		return
	for other in unit.neighbours:
		if is_instance_valid(other):
			DebugDraw3D.draw_line(
				unit.global_position, other.global_position, Color.ORANGE_RED
			)
