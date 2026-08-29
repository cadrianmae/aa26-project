## Turns player input into swarm orders.
##
## The player's second verb. Flying the Matriarch is direct control; this is
## indirect -- the player states an intent and fifty autonomous units interpret
## it. Keeping the two apart matters: [PlayerSteeringBehaviour] moves one ship
## and knows nothing about the swarm, this issues orders and moves nothing.
##
## Deliberately thin. It reads keys, works out a rally point, and calls
## [method Swarm.order]. It does not know what any intent means -- that is
## [SwarmIntentState]'s job, per unit. A coordinator that decided behaviour
## would be a central controller, and the swarm would stop being autonomous.
class_name SwarmCoordinator
extends Node

## The swarm being commanded. Found by group on ready when left unset, because
## the Godot editor has pruned exported NodePaths from this project's scenes
## before.
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

## Maps each input action to the intent it issues. Data rather than a match
## statement, so a new order is one line here and one state, with no branching
## to extend.
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
## Resolved on demand rather than in _ready(). Godot readies siblings in scene
## order, and this node lives under CommanderShip, which sits ABOVE PlayerSwarm
## and RallyMarker in main.tscn -- so at _ready() time neither has joined its
## group and both lookups come back empty. Resolving here instead means the
## references are found the first time the player actually issues an order, by
## which point the whole tree is up, and reordering the scene cannot break it.
func _resolve_targets() -> void:
	if swarm == null:
		var found: Array = get_tree().get_nodes_in_group("swarm_" + str(allegiance))
		if not found.is_empty():
			swarm = found[0] as Swarm
	if marker == null:
		marker = RallyMarker.for_swarm(get_tree(), allegiance)


func _unhandled_input(event: InputEvent) -> void:
	_resolve_targets()
	if swarm == null:
		return
	for action in INTENT_ACTIONS:
		if not event.is_action_pressed(action):
			continue
		var intent: Swarm.Intent = INTENT_ACTIONS[action]
		swarm.order(intent, rally_point())
		if intent == Swarm.Intent.RALLY and marker != null:
			marker.place_at(swarm.rally_point)
		get_viewport().set_input_as_handled()
		return


## Where a RALLY order should send the swarm.
##
## The mouse aim point when the player has one, since aiming is already how
## they point at the world. Falling back to a spot ahead of the ship keeps the
## order usable on a gamepad, where there is no cursor to read.
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
