## The rival hatchery's commander: a second player with a script instead of a
## keyboard.
##
## Decides INTENT, not behaviour: [SwarmIntentState] still resolves what each
## unit does, and the flee reflex still overrides it.
class_name CommanderAI
extends Node

## Emitted when the AI changes its mind.
signal decided(intent: Swarm.Intent)

## Which side this commands.
@export var allegiance: int = 1

## Seconds between decisions. Long enough that an order has visible
## consequences before the next one is considered.
@export var decision_interval: float = 2.5

## How far from its own hatchery the AI will send drones to harvest.
@export var harvest_range: float = 700.0

## Below this many drones the hatchery is considered too weak to fight.
@export var minimum_war_swarm: int = 14

## Which personality to play with. See [CommanderProfiles].
@export var profile_name: StringName = &"escalating"

@export_group("Debug")

## Print each decision, so a demo can be narrated from the console.
@export var log_decisions: bool = false

## Print every intent's score, not just the winner.
@export var log_scores: bool = false

## Draw the commander's reasoning in the world: its intent, every option's
## score, and the point it is steering at.
@export var draw_gizmos: bool = true

## Resolved on first use, never in _ready(): Godot readies siblings in scene
## order, so any of these may not have joined its group yet.
var swarm: Swarm
var hatchery: Hatchery
var ship: Ship

## Where the rival commander is currently steering.
##
## A Node3D because [ArriveBehaviour] targets a node, not a position.
var move_marker: Node3D

## The rival's own steering. Disabled in the scene, because the player's
## commander instances the SAME scene.
var arrive: SteeringBehaviour

## The commander's own ship health when first seen, so "hurt" is a proportion
## rather than a hard-coded number.
var full_health: float = 0.0

## The intent currently being issued.
var current_intent: Swarm.Intent = Swarm.Intent.HOLD

## The personality this commander plays with.
var profile: UtilityProfile

var _since_decision: float = 0.0


func _ready() -> void:
	profile = _build_profile()


## Look up the named profile.
func _build_profile() -> UtilityProfile:
	match profile_name:
		&"escalating":
			return CommanderProfiles.escalating()
		_:
			push_warning(
				"%s: no profile named '%s'; the commander will hold."
				% [name, profile_name]
			)
			return CommanderProfiles.escalating()


func _process(delta: float) -> void:
	# Every frame, before the interval gate: a display that appeared for one
	# frame every decision_interval would be unreadable.
	_resolve()
	_process_gizmos()

	_since_decision += delta
	if _since_decision < decision_interval:
		return
	_since_decision = 0.0

	if swarm == null:
		return

	if log_scores and profile != null:
		var scores: Dictionary = profile.explain(gather_inputs(), current_intent)
		var report: PackedStringArray = PackedStringArray()
		for key in scores:
			report.append("%s %.2f" % [Swarm.Intent.keys()[key], scores[key]])
		print("[CommanderAI %d] " % allegiance + ", ".join(report))

	var intent: Swarm.Intent = decide()

	# Re-steered every decision, not only on a change of intent.
	if move_marker != null:
		move_marker.global_position = move_destination(intent)

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
	if ship != null and move_marker == null:
		move_marker = ship.get_node_or_null("MoveTarget") as Node3D
		arrive = ship.get_node_or_null("CommanderArrive") as SteeringBehaviour
		# Enabled and targeted in code, not in the scene: the player instances the
		# same scene, and a NodePath in commander_ship.tscn arrives null once
		# instanced into main.tscn.
		if arrive != null:
			arrive.enabled = true
			arrive.set("target", move_marker)


## How many drones this hatchery currently has.
func swarm_size() -> int:
	return swarm.units.size() if swarm != null else 0


## Alloys banked, or 0.0 with no hatchery.
func alloys() -> float:
	return hatchery.alloys if hatchery != null else 0.0


## The nearest Barnacle with alloys left, or null when the belt is stripped.
func nearest_barnacle() -> Barnacle:
	var from: Vector3 = ship.global_position if ship != null else Vector3.ZERO
	return Barnacle.nearest_to(get_tree(), from)


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


## Everything the profile can reason about, normalised to 0..1.
##
## Normalised because a consideration's curve is written against 0..1.
func gather_inputs() -> Dictionary:
	var barnacle: Barnacle = nearest_barnacle()
	var enemy: Node3D = nearest_enemy()
	var from: Vector3 = ship.global_position if ship != null else Vector3.ZERO

	var health: float = 1.0
	if ship != null and full_health > 0.0:
		health = clampf(ship.health / full_health, 0.0, 1.0)

	var swarm_fraction: float = 0.0
	if hatchery != null and hatchery.max_drones > 0:
		swarm_fraction = clampf(
			float(swarm_size()) / float(hatchery.max_drones), 0.0, 1.0
		)

	# 1.0 means "as many drones as this commander thinks it needs to fight".
	var war_readiness: float = 0.0
	if minimum_war_swarm > 0:
		war_readiness = clampf(
			float(swarm_size()) / float(minimum_war_swarm), 0.0, 1.0
		)

	var alloy_fraction: float = 0.0
	if hatchery != null and hatchery.drone_cost > 0.0:
		alloy_fraction = clampf(alloys() / hatchery.drone_cost, 0.0, 1.0)

	# Distances against harvest_range, so 1.0 is "as far as I am willing to go".
	var barnacle_distance: float = 1.0
	if barnacle != null and harvest_range > 0.0:
		barnacle_distance = clampf(
			from.distance_to(barnacle.global_position) / harvest_range, 0.0, 1.0
		)

	var enemy_distance: float = 1.0
	if enemy != null and harvest_range > 0.0:
		enemy_distance = clampf(
			from.distance_to(enemy.global_position) / harvest_range, 0.0, 1.0
		)

	return {
		&"health": health,
		&"swarm_fraction": swarm_fraction,
		&"war_readiness": war_readiness,
		&"alloy_fraction": alloy_fraction,
		&"has_barnacle": 1.0 if barnacle != null else 0.0,
		&"barnacle_distance": barnacle_distance,
		&"has_enemy": 1.0 if enemy != null else 0.0,
		&"enemy_distance": enemy_distance,
	}


## Choose what this hatchery should be doing.
##
## Called on [member decision_interval]. The reasoning lives in the profile,
## so this only reads the world and asks.
func decide() -> Swarm.Intent:
	if profile == null:
		return Swarm.Intent.HOLD
	return profile.best_intent(gather_inputs(), current_intent) as Swarm.Intent


## Where the commander should physically fly, given the intent it just chose.
func move_destination(intent: Swarm.Intent) -> Vector3:
	if ship == null:
		return Vector3.ZERO

	match intent:
		Swarm.Intent.HARVEST:
			var barnacle: Barnacle = nearest_barnacle()
			if barnacle != null:
				return barnacle.global_position
		Swarm.Intent.ENGAGE:
			var enemy: Node3D = nearest_enemy()
			if enemy != null:
				return enemy.global_position
		Swarm.Intent.HOLD:
			return ship.global_position

	return ship.global_position


## Draw what the commander is thinking.
##
## Drawn every frame, though decisions are made on decision_interval.
func _process_gizmos() -> void:
	if not draw_gizmos or ship == null:
		return

	var at: Vector3 = ship.global_position

	# The standing intent, above the ship.
	DebugDraw3D.draw_text(
		at + Vector3(0.0, 14.0, 0.0),
		Swarm.Intent.keys()[current_intent],
		24,
		_intent_colour(current_intent)
	)

	# Where the commander is steering, and the line it is taking to get there.
	if move_marker != null:
		DebugDraw3D.draw_line(at, move_marker.global_position, Color(1.0, 0.85, 0.4, 0.6))
		DebugDraw3D.draw_sphere(move_marker.global_position, 6.0, Color(1.0, 0.85, 0.4))

	# Every option's score, not just the winner.
	if profile == null:
		return
	var scores: Dictionary = profile.explain(gather_inputs(), current_intent)
	var row: int = 0
	for intent in scores:
		var winner: bool = intent == current_intent
		DebugDraw3D.draw_text(
			at + Vector3(0.0, 11.0 - float(row) * 2.2, 0.0),
			"%s %.2f" % [Swarm.Intent.keys()[intent], scores[intent]],
			16,
			Color(1.0, 0.95, 0.7) if winner else Color(0.7, 0.7, 0.7, 0.7)
		)
		row += 1


## Intent to colour, so the label reads at a glance.
func _intent_colour(intent: Swarm.Intent) -> Color:
	match intent:
		Swarm.Intent.ENGAGE:
			return Color(1.0, 0.42, 0.30)
		Swarm.Intent.HARVEST:
			return Color(0.62, 0.82, 0.23)
		Swarm.Intent.PATROL:
			return Color(0.85, 0.64, 0.26)
	return Color(0.7, 0.75, 0.8)
