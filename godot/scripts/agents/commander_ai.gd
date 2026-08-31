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

## Which personality to play with. See [CommanderProfiles].
##
## A future opponent is a new function there and a new name here -- the
## scoring machinery does not change.
@export var profile_name: StringName = &"escalating"

@export_group("Debug")

## Print each decision, so a demo can be narrated from the console.
@export var log_decisions: bool = false

## Print every intent's score, not just the winner.
##
## A utility system is opaque from outside: it names a winner and says nothing
## about why. This is how a demo shows the reasoning, and how a bad decision
## gets diagnosed as a bad WEIGHT rather than a bug.
@export var log_scores: bool = false

## Resolved on first use, never in _ready(): Godot readies siblings in scene
## order, so any of these may not have joined its group yet.
var swarm: Swarm
var hatchery: Hatchery
var ship: Ship

## Where the rival commander is currently steering.
##
## A world-space marker rather than a position handed to the behaviour,
## because [ArriveBehaviour] targets a [Node3D] -- the same shape the player's
## rally marker uses.
var move_marker: Node3D

## The rival's own steering. Disabled in the scene, because the player's
## commander instances the SAME scene and must not be steered by anything but
## the player.
var arrive: SteeringBehaviour

## The commander's own ship health when first seen, so "hurt" is a proportion
## rather than a hard-coded number.
var full_health: float = 0.0

## The intent currently being issued.
var current_intent: Swarm.Intent = Swarm.Intent.HOLD

## The personality this commander plays with.
##
## Built on ready from [member profile_name]. Swapping it swaps the opponent
## entirely, with no code path between the two: the scorer is the same, only
## the table it reads changes.
var profile: UtilityProfile

var _since_decision: float = 0.0


func _ready() -> void:
	profile = _build_profile()


## Look up the named profile.
##
## A match rather than a dictionary of callables, so a typo is a compile-time
## complaint about an unknown identifier instead of a silent fallback that
## makes the enemy inexplicably passive.
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
	_since_decision += delta
	if _since_decision < decision_interval:
		return
	_since_decision = 0.0

	_resolve()
	if swarm == null:
		return

	if log_scores and profile != null:
		var scores: Dictionary = profile.explain(gather_inputs(), current_intent)
		var report: PackedStringArray = PackedStringArray()
		for key in scores:
			report.append("%s %.2f" % [Swarm.Intent.keys()[key], scores[key]])
		print("[CommanderAI %d] " % allegiance + ", ".join(report))

	var intent: Swarm.Intent = decide()

	# Moved every decision, even when the intent has not changed: the world
	# has, and a commander that only re-steers on a change of mind would sit
	# still while its barnacle was stripped.
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
		# Switched on here rather than in the scene: this script only ever
		# runs on the rival, so enabling it here is what guarantees the
		# player's identical ship is never steered for them.
		#
		# The target is wired here too, for the reason PlayerSteeringBehaviour
		# gives about its camera: a NodePath written into commander_ship.tscn
		# arrives as null once the scene is instanced into main.tscn. Assigning
		# it in code needs no scene wiring and cannot be pruned.
		if arrive != null:
			arrive.enabled = true
			arrive.set("target", move_marker)


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


## Everything the profile can reason about, normalised to 0..1.
##
## Gathered once per decision and handed over as data. The profile never
## touches the world -- it sees only these numbers -- which is what lets a
## different personality be a different table rather than different code.
##
## Normalised because a consideration's curve is written against 0..1. Raw
## values would tie every curve to whatever units it happened to be given, and
## a profile tuned on one map would be wrong on the next.
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
##
## Separate from [method decide] on purpose. The intent says what the hive is
## doing; this says where the ship has to BE for that to work -- and because
## the hatchery rides on the ship, those are not the same question. A commander
## that picks HARVEST but parks a kilometre from the barnacle harvests nothing.
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
