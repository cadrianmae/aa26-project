## Sweep the area around the commander, watching for enemies.
##
## Each unit arrives at a slowly rotating point, offset by its own phase around
## the circle.
class_name PatrolState
extends State

## The ArriveBehaviour steered at this unit's patrol point.
@export var arrive_behaviour_name: String = "Arrive"

## Where to go when an enemy comes within reach.
@export var engage_state_name: String = "Engage"

## Radius of the patrol circle around the commander.
@export var patrol_radius: float = 60.0

## How fast the circle turns, in radians per second.
@export var orbit_speed: float = 0.35

## How far to look for something to fight. Shorter than EngageState's acquire
## range.
@export var contact_range: float = 90.0

const ACTIVE_BEHAVIOURS: Array = ["Avoid", "Arrive", "Separation", "Alignment"]

## A node that carries this unit's patrol point. An ArriveBehaviour steers at
## a Node3D, so the moving point needs to BE one.
var point: Node3D

## Where the circle is centred: the commander, or the swarm's rally point.
var centre: Node3D

## This unit's own angle around the circle, so the swarm spreads out.
var _phase: float = 0.0


func _enter() -> void:
	centre = get_tree().get_first_node_in_group(
		Ship.GROUP_PREFIX + str(unit.allegiance)
	) as Node3D

	if point == null:
		point = Node3D.new()
		point.name = "PatrolPoint"
		# top_level so it holds a world position rather than being dragged
		# around by the unit it belongs to.
		point.top_level = true
		unit.add_child(point)

	# The unit's own place on the circle, derived from its instance id.
	_phase = float(unit.get_instance_id() % 360) * TAU / 360.0

	var arrive: ArriveBehaviour = behaviour_named(
		arrive_behaviour_name
	) as ArriveBehaviour
	if arrive != null:
		arrive.target = point

	use_only(ACTIVE_BEHAVIOURS)


func _exit() -> void:
	if point != null:
		point.queue_free()
		point = null


func _think() -> void:
	if unit == null or machine == null:
		return

	_advance_point()

	var enemy: Node3D = _nearest_enemy()
	if enemy == null:
		return
	var engage: State = machine.state_named(engage_state_name)
	if engage != null:
		machine.change_state(engage)


## Move this unit's patrol point around the circle.
func _advance_point() -> void:
	if point == null:
		return
	var origin: Vector3 = centre.global_position if centre != null else Vector3.ZERO
	_phase += orbit_speed * get_process_delta_time()
	point.global_position = origin + Vector3(
		cos(_phase) * patrol_radius, 0.0, sin(_phase) * patrol_radius
	)


## Nearest hostile unit within [member contact_range], or null.
func _nearest_enemy() -> Node3D:
	return Swarm.nearest_hostile(
		get_tree(), unit.global_position, 1 - unit.allegiance, contact_range
	)
