## Hold a fixed slot in the leader's local frame, leading the leader's motion.
##
## This is what makes a swarm read as a formation rather than a crowd. The slot
## is not authored: [method _capture_offset] measures where the unit was placed
## relative to the leader and keeps that as its station for the run.
##
## Adapted from Duggan, miniature-rotary-phone/behaviors/offset_pursue.gd.
## Two departures: the slowing distance is exported rather than hardcoded at
## 30, and the offset is flattened onto the XZ plane for this 2.5D game.
class_name OffsetPursueBehaviour
extends SteeringBehaviour

## The agent to fly formation on.
@export var leader: CharacterBody3D

## Distance at which the unit brakes into its slot rather than overshooting.
@export var slowing_radius: float = 30.0

## The formation slot, in the leader's local frame. Captured on ready.
var leader_offset: Vector3 = Vector3.ZERO

## The world-space point the unit is currently steering for.
var projected: Vector3 = Vector3.ZERO


func _ready() -> void:
	super()
	# [member leader] is an optional editor override, kept so the Inspector
	# still works and the wiring is visible while debugging. It cannot be
	# relied on: overrides patched into an instanced sub-scene are keyed on
	# child index and get silently pruned when the scene is re-saved in the
	# editor, and a unit spawned at run time by a factory has no scene-authored
	# reference at all. So when it is unset, resolve it from the per-faction
	# "commander_<allegiance>" group that [Ship] joins on ready -- this works
	# identically whether the unit came from the scene file or was spawned.
	if leader == null:
		var unit: SwarmUnit = agent as SwarmUnit
		if unit != null:
			leader = get_tree().get_first_node_in_group(
				"commander_" + str(unit.allegiance)
			)
	# Deferred because the leader's global transform may not be settled during
	# _ready(). Duggan uses call_deferred here for the same reason. Resolving
	# leader above, before this call is queued, ensures _capture_offset() sees
	# the resolved leader rather than running before it exists.
	call_deferred("_capture_offset")


## Measure the unit's starting position relative to the leader and keep it.
##
## [code]Vector3 * Basis[/code] is the transposed product, which for an
## orthonormal basis is the inverse rotation -- so this converts a world-space
## offset into the leader's local frame. [method calculate] applies the full
## transform to convert it back, which is why the formation rotates with the
## leader for free.
func _capture_offset() -> void:
	if leader == null:
		return
	var world_offset: Vector3 = agent.global_position - leader.global_position
	world_offset.y = 0.0
	leader_offset = world_offset * leader.global_transform.basis
	# Avoid a first-frame gizmo line to the world origin before calculate() runs.
	projected = agent.global_position


func calculate() -> Vector3:
	if leader == null:
		return Vector3.ZERO
	var world_target: Vector3 = leader.global_transform * leader_offset
	var dist: float = agent.global_position.distance_to(world_target)
	var lead_time: float = dist / agent.max_speed
	projected = world_target + leader.velocity * lead_time
	projected.y = agent.global_position.y
	return arrive_towards(projected, slowing_radius)


func on_draw_gizmos() -> void:
	if leader != null:
		DebugDraw3D.draw_line(agent.global_position, projected, Color.ORANGE)
