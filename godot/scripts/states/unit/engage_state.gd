## Hunt the nearest enemy and shoot it.
##
## Retargets only when the current target dies or drifts out of reach.
class_name EngageState
extends State

## The SeekBehaviour this state points at the target.
@export var seek_behaviour_name: String = "Engage"

## Where to go when there is nothing left to fight.
@export var idle_state_name: String = "Follow"

## Distance at which an attack run breaks off and the drone extends away.
@export var break_off_distance: float = 14.0

## How far out to run before turning back for the next pass.
@export var extend_distance: float = 85.0

## How far to one side the run-out is angled, as a fraction of extend_distance.
@export_range(0.0, 1.5) var extend_sweep: float = 0.65

## How far to look for a target.
@export var acquire_range: float = 140.0

## Behaviours this state runs.
const ACTIVE_BEHAVIOURS: Array = ["Avoid", "Engage", "Separation", "Alignment"]

## Which leg of the attack pattern this drone is on.
enum Phase { RUN, EXTEND }

## The enemy being hunted.
var target: Node3D

## RUN steers at the enemy; EXTEND steers at a point away from it.
var phase: Phase = Phase.RUN

var _weapon: Weapon

## Carries the run-out point, because SeekBehaviour targets a node rather than
## a position.
var _extend_marker: Node3D


func _enter() -> void:
	_weapon = unit.get_node_or_null("Weapon") as Weapon
	if _extend_marker == null:
		_extend_marker = Node3D.new()
		_extend_marker.name = "ExtendPoint"
		_extend_marker.top_level = true
		add_child(_extend_marker)
	phase = Phase.RUN
	acquire()
	use_only(ACTIVE_BEHAVIOURS)


## Point the seek behaviour at [member target].
func _point_seek_at_target() -> void:
	_point_seek_at(target)


## Point the seek behaviour at any node.
func _point_seek_at(destination: Node3D) -> void:
	var seek: SeekBehaviour = behaviour_named(
		seek_behaviour_name
	) as SeekBehaviour
	if seek != null:
		seek.target = destination


## Choose the nearest enemy drone or capital ship within reach.
##
## Ships are weighted as if closer than they are, so a swarm that could shoot
## either will go for the ship.
func acquire() -> Node3D:
	var enemy: int = 1 - unit.allegiance
	var closest: Node3D = null
	var closest_score: float = acquire_range

	for node in get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(enemy)):
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		for drone in swarm.units:
			if drone == null:
				continue
			var distance: float = unit.global_position.distance_to(drone.global_position)
			if distance < closest_score:
				closest_score = distance
				closest = drone

	for node in get_tree().get_nodes_in_group(Ship.GROUP_PREFIX + str(enemy)):
		var ship: Node3D = node as Node3D
		if ship == null:
			continue
		var distance: float = unit.global_position.distance_to(ship.global_position) * 0.6
		if distance < closest_score:
			closest_score = distance
			closest = ship

	# Nothing within acquire_range: fall back to the enemy commander at any
	# distance, so an ENGAGE order always has somewhere to go.
	if closest == null:
		closest = _enemy_commander(enemy)

	target = closest
	# A new target starts a new run: EXTEND's exit tests cannot come true
	# against one.
	phase = Phase.RUN
	_point_seek_at_target()
	return target


## The enemy commander, when it is within the drone's vision range of its own
## commander. Null when it is dead, or too far to be worth leaving home for.
func _enemy_commander(enemy: int) -> Node3D:
	var hostile: Node3D = Swarm.commander_of(get_tree(), enemy)
	if hostile == null:
		return null

	var home: Node3D = Swarm.commander_of(get_tree(), unit.allegiance)
	var from: Vector3 = (
		home.global_position if home != null else unit.global_position
	)
	if from.distance_to(hostile.global_position) > unit.vision_range:
		return null
	return hostile


func _think() -> void:
	if unit == null or machine == null:
		return

	# A freed target leaves a stale reference, so validity is checked before
	# anything is read off it.
	var lost: bool = (
		target == null
		or not is_instance_valid(target)
		or unit.global_position.distance_to(target.global_position) > acquire_range
	)
	if lost and acquire() == null:
		var idle: State = machine.state_named(idle_state_name)
		if idle != null:
			machine.change_state(idle)
		return

	_update_phase()

	# Fired on both legs.
	if _weapon != null:
		_weapon.fire_at(target)


## Switch between closing and extending, and point the seek accordingly.
func _update_phase() -> void:
	var distance: float = unit.global_position.distance_to(target.global_position)

	match phase:
		Phase.RUN:
			if distance <= break_off_distance:
				phase = Phase.EXTEND
				_place_extend_point()
				_point_seek_at(_extend_marker)
		Phase.EXTEND:
			# Turn back once the drone is clear, whether it reached its exact
			# run-out point or simply got far enough while dodging.
			var clear: bool = distance >= extend_distance
			var arrived: bool = unit.global_position.distance_to(
				_extend_marker.global_position
			) <= break_off_distance
			if clear or arrived:
				phase = Phase.RUN
				_point_seek_at(target)


## Choose where this drone runs out to after a pass.
##
## Straight on through the target, then swung to one side.
func _place_extend_point() -> void:
	var through: Vector3 = target.global_position - unit.global_position
	through.y = 0.0
	if through.length_squared() < 0.0001:
		through = unit.global_basis.z
	through = through.normalized()

	# Perpendicular on the plane. get_instance_id is stable per drone, so a
	# unit always breaks the same way.
	var side: float = 1.0 if int(unit.get_instance_id()) % 2 == 0 else -1.0
	var across := Vector3(-through.z, 0.0, through.x) * side

	_extend_marker.global_position = (
		target.global_position
		+ through * extend_distance
		+ across * extend_distance * extend_sweep
	)
