## The player's target selection: what the weapon shoots and the HUD reports.
##
## Cycles through the things worth aiming at -- the rival commander, each
## Barnacle, and the rival swarm -- nearest first, so pressing the key once
## almost always selects the obvious thing.
##
## A swarm is ONE contact, not fifty, targeted at its centre of mass.
##
## Because a centre of mass is a position rather than an object, it is carried
## by a marker node that this keeps updated. Everything downstream -- the
## weapon, the HUD -- then takes a plain [Node3D] and never needs to know
## whether it is pointed at a ship or at the middle of a cloud.
##
## Only the player's commander mounts this. Both hives instance the same
## scene, so the allegiance guard in [method _ready] is what keeps the rival
## from cycling targets off the player's keyboard.
class_name Targeting
extends Node

## Emitted whenever the selection changes, for the HUD to redraw.
signal target_changed(target: Node3D)

## What kind of thing is currently selected. The HUD draws each differently.
enum Kind { NONE, SHIP, SWARM, BARNACLE }

## Furthest a contact can be and still be selectable, in world units.
@export var scan_range: float = 900.0

## How strongly cycling prefers contacts the ship is pointing at.
##
## 0 orders purely by distance; 1 makes something directly behind the ship
## cost twice what the same thing costs directly ahead.
@export_range(0.0, 3.0) var facing_bias: float = 1.0

## How near the cursor must land to a contact to pick it, in world units.
@export var pick_radius: float = 60.0

## The ship this targets from.
var ship: Ship

## The selected contact, or null.
var current: Node3D

## What [member current] is.
var kind: Kind = Kind.NONE

## Carries the swarm's centre of mass, since a position is not a node.
var _swarm_marker: Node3D

## The swarm being tracked when [member kind] is SWARM.
var _tracked_swarm: Swarm

## Largest the tracked swarm has been seen at, so its bar has a denominator.
var _swarm_peak: int = 0


func _ready() -> void:
	ship = get_parent() as Ship
	if ship == null:
		push_error("%s must be a child of a Ship." % name)
		set_process(false)
		return
	if ship.allegiance != 0:
		set_process(false)
		# Input too: set_process(false) does not stop _unhandled_input, and both
		# hives instance this scene.
		set_process_unhandled_input(false)
		return

	_swarm_marker = Node3D.new()
	_swarm_marker.name = "SwarmCentroid"
	# top_level so it holds a world position rather than inheriting the
	# ship's, and added to the tree because global_position is meaningless
	# outside it.
	_swarm_marker.top_level = true
	add_child(_swarm_marker)


func _process(_delta: float) -> void:
	# The centre of mass moves every frame, so the marker has to follow it.
	if kind == Kind.SWARM and _tracked_swarm != null:
		var centre: Vector3 = swarm_centre(_tracked_swarm)
		if centre == Vector3.INF:
			clear()
		else:
			_swarm_marker.global_position = centre

	# A target can die between frames.
	if current != null and not is_instance_valid(current):
		clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("target_under_cursor"):
		target_under_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_next"):
		cycle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("target_clear"):
		clear()
		get_viewport().set_input_as_handled()


## Select whatever the cursor is over.
##
## Nearest contact to the aim point rather than a physics raycast: a swarm's
## centre of mass is not a body and could never be hit by a ray.
func target_under_cursor() -> void:
	var point: Vector3 = cursor_point()
	if not point.is_finite():
		return

	var contacts: Array = available_contacts()
	var best: Dictionary = {}
	var best_distance: float = pick_radius
	for contact in contacts:
		var at: Vector3 = _contact_position(contact)
		if not at.is_finite():
			continue
		var distance: float = point.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = contact

	if best.is_empty():
		clear()
		return
	_select(best)


## Where the cursor points, on the movement plane.
func cursor_point() -> Vector3:
	var steering: Node = ship.get_node_or_null("PlayerSteering") if ship else null
	if steering != null and steering.has_method("aim_point"):
		var aimed: Vector3 = steering.aim_point()
		if aimed.is_finite():
			return aimed
	return Vector3.INF


func _contact_position(contact: Dictionary) -> Vector3:
	if contact["kind"] == Kind.SWARM:
		return swarm_centre(contact["swarm"])
	var node: Node3D = contact["node"]
	if node == null or not is_instance_valid(node):
		return Vector3.INF
	return node.global_position


## Select the next contact, wrapping back to nothing after the last.
##
## Nothing is part of the cycle.
func cycle() -> void:
	var contacts: Array = available_contacts()
	if contacts.is_empty():
		clear()
		return

	# Guarded: a null `current` would match the swarm contact, whose "node" is
	# also null by construction.
	var index: int = -1
	if kind != Kind.NONE:
		for i in contacts.size():
			var matches: bool = (
				contacts[i]["swarm"] == _tracked_swarm
				if kind == Kind.SWARM
				else contacts[i]["node"] == current
			)
			if matches:
				index = i
				break

	var next: int = index + 1
	if next >= contacts.size():
		clear()
		return
	_select(contacts[next])


## Drop the current target.
func clear() -> void:
	if current == null and kind == Kind.NONE:
		return
	current = null
	kind = Kind.NONE
	_tracked_swarm = null
	_swarm_peak = 0
	target_changed.emit(null)


func _select(contact: Dictionary) -> void:
	# Cleared per selection: a baseline carried over from the last target
	# would make the new one's bar read against the wrong maximum.
	_swarm_peak = 0
	kind = contact["kind"]
	if kind == Kind.SWARM:
		# No marker means this is not the player's copy of the node and should
		# never have got here. Refuse rather than crash.
		if _swarm_marker == null:
			kind = Kind.NONE
			return
		_tracked_swarm = contact["swarm"]
		_swarm_marker.global_position = swarm_centre(_tracked_swarm)
		current = _swarm_marker
	else:
		_tracked_swarm = null
		current = contact["node"]
	target_changed.emit(current)


## Everything selectable right now, nearest first.
func available_contacts() -> Array:
	var contacts: Array = []
	if ship == null:
		return contacts
	var from: Vector3 = ship.global_position
	var enemy: int = 1 - ship.allegiance

	for node in get_tree().get_nodes_in_group(Ship.GROUP_PREFIX + str(enemy)):
		var other: Node3D = node as Node3D
		if other == null or not is_instance_valid(other):
			continue
		if from.distance_to(other.global_position) <= scan_range:
			contacts.append({
				"kind": Kind.SHIP,
				"node": other,
				"swarm": null,
				"distance": from.distance_to(other.global_position),
			})

	for node in get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(enemy)):
		var swarm: Swarm = node as Swarm
		if swarm == null:
			continue
		var centre: Vector3 = swarm_centre(swarm)
		if centre == Vector3.INF:
			continue
		if from.distance_to(centre) <= scan_range:
			contacts.append({
				"kind": Kind.SWARM,
				"node": null,
				"swarm": swarm,
				"distance": from.distance_to(centre),
			})

	for node in get_tree().get_nodes_in_group(Barnacle.GROUP):
		var barnacle: Node3D = node as Node3D
		if barnacle == null or not is_instance_valid(barnacle):
			continue
		if from.distance_to(barnacle.global_position) <= scan_range:
			contacts.append({
				"kind": Kind.BARNACLE,
				"node": barnacle,
				"swarm": null,
				"distance": from.distance_to(barnacle.global_position),
			})

	# Scored, then sorted on the score rather than on distance alone.
	for contact in contacts:
		contact["score"] = _cycle_cost(contact)
	contacts.sort_custom(func(a, b): return a["score"] < b["score"])
	return contacts


## What cycling charges for a contact: its distance, penalised by how far off
## the nose it sits.
func _cycle_cost(contact: Dictionary) -> float:
	var at: Vector3 = _contact_position(contact)
	if not at.is_finite() or ship == null:
		return INF

	var to_contact: Vector3 = at - ship.global_position
	to_contact.y = 0.0
	# +Z is the model's front in this codebase, not Vector3.FORWARD.
	var facing: Vector3 = ship.global_basis.z
	facing.y = 0.0
	if to_contact.length_squared() < 0.0001 or facing.length_squared() < 0.0001:
		return contact["distance"]

	# 0 dead ahead, 1 dead astern.
	var offness: float = facing.normalized().angle_to(to_contact.normalized()) / PI
	return contact["distance"] * (1.0 + facing_bias * offness)


## The mean position of a swarm's living units, or [constant Vector3.INF] when
## it has none.
##
## An unweighted mean.
static func swarm_centre(swarm: Swarm) -> Vector3:
	if swarm == null:
		return Vector3.INF
	var total: Vector3 = Vector3.ZERO
	var count: int = 0
	for unit in swarm.units:
		var drone: Node3D = unit as Node3D
		if drone == null or not is_instance_valid(drone):
			continue
		total += drone.global_position
		count += 1
	if count == 0:
		return Vector3.INF
	return total / float(count)


## Health of the current target as a 0..1 fraction, or -1.0 when it has none.
##
## A swarm's fraction is how much of it is left, not any one drone's health.
func target_health_fraction() -> float:
	if kind == Kind.SWARM and _tracked_swarm != null:
		var alive: int = 0
		for unit in _tracked_swarm.units:
			if unit != null and is_instance_valid(unit):
				alive += 1
		# Denominator is the peak seen, not a configured cap.
		_swarm_peak = maxi(_swarm_peak, alive)
		return clampf(float(alive) / float(maxi(_swarm_peak, 1)), 0.0, 1.0)
	if current == null or not is_instance_valid(current):
		return -1.0

	# A Barnacle reports how much alloy is left in it, not health: it has no
	# `health` field at all.
	if kind == Kind.BARNACLE and current.has_method("fullness"):
		return clampf(current.fullness(), 0.0, 1.0)

	if "health" in current:
		# Against the target's own max_health, not a constant: Ship starts at
		# 500, Drone at 100.
		var maximum: float = current.max_health if "max_health" in current else 0.0
		if maximum <= 0.0:
			return -1.0
		return clampf(current.health / maximum, 0.0, 1.0)

	return -1.0
