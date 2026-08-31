## The rival hatchery's commander: a second player with a script instead of a
## keyboard.
##
## Deliberately issues orders through [method Swarm.order], the SAME call the
## player's hotkeys make. The enemy is not a special case with privileged
## access to the world -- it reads what the player could read and commands
## what the player could command, so a win against it means something.
##
## It decides INTENT, not behaviour. Which state a drone actually enters is
## still [SwarmIntentState]'s answer, per unit, and the flee reflex still
## overrides everything. So even the AI's swarm keeps its autonomy: the
## commander says "harvest" and the drones work out what that means from where
## they each happen to be.
##
## Sampled on an interval rather than per frame. An AI that re-decided sixty
## times a second would thrash between intents on the boundary of a condition,
## and the swarm would visibly twitch instead of committing to anything.
class_name CommanderAI
extends Node

## Emitted when the AI changes its mind, for the write-up and for gizmos.
signal decided(intent: Swarm.Intent)

## Which side this commands.
@export var allegiance: int = 1

## Seconds between decisions. Long enough that an order has visible
## consequences before the next one is considered.
@export var decision_interval: float = 2.5

## How far from its own hatchery the AI will send drones to harvest.
@export var harvest_range: float = 700.0

## Below this many drones the hatchery is considered too weak to fight.
@export var minimum_war_swarm: int = 8

## Below this fraction of starting health the commander disengages.
@export_range(0.0, 1.0) var retreat_health_fraction: float = 0.35

@export_group("Debug")

## Print each decision, so a demo can be narrated from the console.
@export var log_decisions: bool = false

## Resolved on first use, never in _ready(): Godot readies siblings in scene
## order, so any of these may not have joined its group yet.
var swarm: Swarm
var hatchery: Hatchery
var ship: Ship

## The commander's own ship health when first seen, so "hurt" is a proportion
## rather than a hard-coded number.
var full_health: float = 0.0

## The intent currently being issued.
var current_intent: Swarm.Intent = Swarm.Intent.HOLD

var _since_decision: float = 0.0


func _process(delta: float) -> void:
	_since_decision += delta
	if _since_decision < decision_interval:
		return
	_since_decision = 0.0

	_resolve()
	if swarm == null:
		return

	var intent: Swarm.Intent = decide()
	if intent == current_intent:
		return
	current_intent = intent
	swarm.order(intent, rally_point())
	decided.emit(intent)
	if log_decisions:
		print("[CommanderAI %d] %s" % [allegiance, Swarm.Intent.keys()[intent]])


func _resolve() -> void:
	if swarm == null:
		var found: Array = get_tree().get_nodes_in_group("swarm_" + str(allegiance))
		if not found.is_empty():
			swarm = found[0] as Swarm
	if hatchery == null:
		hatchery = Hatchery.for_allegiance(get_tree(), allegiance)
	if ship == null:
		ship = get_tree().get_first_node_in_group(
			"commander_" + str(allegiance)
		) as Ship
	if ship != null and full_health <= 0.0:
		full_health = ship.health


## How many drones this hatchery currently has.
func swarm_size() -> int:
	return swarm.units.size() if swarm != null else 0


## Alloys banked, or 0.0 with no hatchery.
func alloys() -> float:
	return hatchery.alloys if hatchery != null else 0.0


## Whether the commander's own ship is badly hurt.
func is_hurt() -> bool:
	if ship == null or full_health <= 0.0:
		return false
	return ship.health / full_health < retreat_health_fraction


## The nearest Barnacle with alloys left, or null when the belt is stripped.
func nearest_barnacle() -> Barnacle:
	var from: Vector3 = ship.global_position if ship != null else Vector3.ZERO
	return Barnacle.nearest_to(get_tree(), from)


## Whether any Barnacle is close enough to be worth working.
func has_reachable_barnacle() -> bool:
	var barnacle: Barnacle = nearest_barnacle()
	if barnacle == null or ship == null:
		return false
	return ship.global_position.distance_to(barnacle.global_position) <= harvest_range


## The nearest enemy unit, or null.
func nearest_enemy() -> Node3D:
	var enemy: int = 1 - allegiance
	var from: Vector3 = ship.global_position if ship != null else Vector3.ZERO
	var closest: Node3D = null
	var closest_distance: float = INF
	for node in get_tree().get_nodes_in_group("commander_" + str(enemy)):
		var other: Node3D = node as Node3D
		if other == null:
			continue
		var distance: float = from.distance_to(other.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = other
	return closest


## Where a RALLY order should send this swarm.
##
## The nearest worthwhile Barnacle if there is one, otherwise the commander's
## own position, so a rally never sends the swarm to the world origin.
func rally_point() -> Vector3:
	var barnacle: Barnacle = nearest_barnacle()
	if barnacle != null:
		return barnacle.global_position
	if ship != null:
		return ship.global_position
	return Vector3.ZERO


## Choose what this hatchery should be doing.
##
## Called on [member decision_interval]. Everything it needs is available as
## a method above, so it reads as a policy rather than as plumbing.
func decide() -> Swarm.Intent:
	# TODO(human)
	return Swarm.Intent.HOLD
