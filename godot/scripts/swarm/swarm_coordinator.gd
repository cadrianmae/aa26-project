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


## Keep the standing harvest order pointed at whatever the player has locked.
##
## The order key sets harvest_target once, at the moment it is pressed. But a
## player who is already harvesting and then locks a different rock expects the
## swarm to switch -- without re-issuing the order, which from their side they
## have no reason to think is necessary. The lock IS the instruction, so it has
## to keep applying rather than only being read on a key press.
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
## An explicit target lock wins over everything. If the player has selected a
## Barnacle with T or Tab, that is unambiguously the one they mean, and an
## order that quietly picked a different rock because the cursor had drifted
## would make the lock look broken.
##
## Otherwise the one nearest where the player is pointing: aiming is already
## how the player indicates a place in the world, so the order needs no extra
## control -- point and press 4. Falling back to the nearest Barnacle to the
## ship keeps it usable on a gamepad, where there is no cursor to read.
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
##
## Resolved through the ship rather than held as a reference, for the reason
## the rest of this class resolves lazily: Targeting lives on the commander
## and may not exist yet when this node is ready.
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
