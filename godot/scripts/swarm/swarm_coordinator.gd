## Turns player input into swarm orders.
##
## Issues orders only; [SwarmIntentState] decides what an intent means, per
## unit.
class_name SwarmCoordinator
extends Node

## The swarm being commanded. Found by group on ready when left unset.
@export var swarm: Swarm

## Which side this coordinator commands.
@export var allegiance: int = 0

## Where RALLY sends the swarm when the player gives no aim point.
@export var default_rally_distance: float = 25.0

## The player's ship, used as the origin for a rally point and as the fallback
## the swarm returns to on HOLD.
var ship: Node3D

## The marker showing the current rally point.
var marker: RallyMarker

## Maps each input action to the intent it issues.
const INTENT_ACTIONS: Dictionary = {
	"order_hold": Swarm.Intent.HOLD,
	"order_rally": Swarm.Intent.RALLY,
	"order_patrol": Swarm.Intent.PATROL,
	"order_harvest": Swarm.Intent.HARVEST,
}


func _ready() -> void:
	ship = get_parent() as Node3D


## Find the swarm and marker, if they exist yet.
##
## Resolved on demand: at _ready() time the swarm and marker have not joined
## their groups yet.
func _resolve_targets() -> void:
	if swarm == null:
		var found: Array = get_tree().get_nodes_in_group("swarm_" + str(allegiance))
		if not found.is_empty():
			swarm = found[0] as Swarm
	if marker == null:
		marker = RallyMarker.for_swarm(get_tree(), allegiance)


## Keep the standing harvest order pointed at whatever the player has locked.
func _process(_delta: float) -> void:
	_resolve_targets()
	if swarm == null or swarm.intent != Swarm.Intent.HARVEST:
		return
	var locked: Barnacle = targeted_barnacle()
	if locked != null and locked != swarm.harvest_target:
		swarm.harvest_target = locked


func _unhandled_input(event: InputEvent) -> void:
	_resolve_targets()
	if swarm == null:
		return
	for action in INTENT_ACTIONS:
		if not event.is_action_pressed(action):
			continue
		var intent: Swarm.Intent = INTENT_ACTIONS[action]
		if intent == Swarm.Intent.HARVEST:
			swarm.harvest_target = designated_barnacle()
		swarm.order(intent, rally_point())
		if intent == Swarm.Intent.RALLY and marker != null:
			marker.place_at(swarm.rally_point)
		get_viewport().set_input_as_handled()
		return


## Which Barnacle a HARVEST order designates.
##
## Explicit lock first, then nearest to the aim point, then nearest to the
## ship.
func designated_barnacle() -> Barnacle:
	var locked: Barnacle = targeted_barnacle()
	if locked != null:
		return locked

	var point: Vector3 = rally_point()
	var chosen: Barnacle = Barnacle.nearest_to(get_tree(), point)
	if chosen != null:
		return chosen
	if ship == null:
		return null
	return Barnacle.nearest_to(get_tree(), ship.global_position)


## The Barnacle the player currently has targeted, or null.
func targeted_barnacle() -> Barnacle:
	if ship == null:
		return null
	var targeting: Node = ship.get_node_or_null("Targeting")
	if targeting == null:
		return null
	var chosen: Node = targeting.current
	if chosen == null or not is_instance_valid(chosen):
		return null
	var barnacle: Barnacle = chosen as Barnacle
	if barnacle == null or barnacle.is_spent():
		return null
	return barnacle


## Where a RALLY order should send the swarm.
##
## The mouse aim point, or a spot ahead of the ship when there is none.
func rally_point() -> Vector3:
	var steering: Node = ship.get_node_or_null("PlayerSteering") if ship else null
	if steering != null and steering.has_method("aim_point"):
		var aimed: Vector3 = steering.aim_point()
		if aimed.is_finite():
			return aimed
	if ship == null:
		return Vector3.ZERO
	# +Z, not -Z: this codebase follows Duggan's convention that the model's
	# front is +Z, which is why the agents call look_at() with a point BEHIND
	# them. Godot's engine constant Vector3.FORWARD is -Z and would aim the
	# rally point out of the ship's back.
	return ship.global_position + ship.global_transform.basis.z * default_rally_distance
