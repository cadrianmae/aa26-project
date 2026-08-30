## A fixed-north overview of the whole belt.
##
## Drawn with _draw() rather than assembled from textures, for the same reason
## the hulls are built from vertex lists: the game's look is vector shapes and
## flat colour, and a drawn map matches it without an art pipeline.
##
## FIXED NORTH, not camera-relative. Up on the map is always world -Z, so a
## place stays in the same corner of the map however the camera is turned.
## That is the same argument the stepped 45-degree camera rests on -- the
## player's sense of where things ARE is most of what both the camera and the
## map are for, and a map that spins destroys it.
##
## Everything is found by group or by node, never wired in the Inspector. The
## Godot editor has pruned instance-override properties from this project's
## scenes twice, and a minimap that silently stops finding the swarm would
## look like a minimap bug rather than a wiring one.
class_name Minimap
extends Control

## World radius the map covers. The asteroid field is 900, so this shows the
## whole playfield with a little margin.
@export var world_radius: float = 1000.0

## Which side's swarm to draw as friendly.
@export var allegiance: int = 0

@export_group("Colours")
@export var background_colour: Color = Color(0.02, 0.03, 0.03, 0.72)
@export var border_colour: Color = Color(0.435, 0.812, 0.353, 0.55)
@export var grid_colour: Color = Color(0.435, 0.812, 0.353, 0.13)
@export var ship_colour: Color = Color(0.435, 0.812, 0.353)
@export var drone_colour: Color = Color(0.435, 0.812, 0.353, 0.85)
@export var fleeing_colour: Color = Color(1.0, 0.42, 0.30)
@export var rock_colour: Color = Color(0.42, 0.39, 0.34)
@export var wreck_colour: Color = Color(0.55, 0.55, 0.58, 0.8)
@export var threat_colour: Color = Color(1.0, 0.35, 0.25, 0.85)
@export var rally_colour: Color = Color(0.4, 1.0, 0.6)

## Resolved on first draw, not in _ready(): Godot readies siblings in scene
## order, and this Control may be ready before the world it draws.
var _ship: Node3D
var _field: Node3D
var _wreck: Node3D


func _ready() -> void:
	# Redraw every frame. The map is a handful of primitives, and the
	# alternative -- invalidating on movement -- means tracking every mover.
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _resolve() -> void:
	var tree: SceneTree = get_tree()
	if _ship == null:
		_ship = tree.get_first_node_in_group("commander_" + str(allegiance)) as Node3D
	if _field == null:
		_field = tree.get_root().find_child("AsteroidField", true, false) as Node3D
	if _wreck == null:
		_wreck = tree.get_root().find_child("Wreck", true, false) as Node3D


## World XZ to map pixels. World -Z is up, matching a north-up chart.
func _to_map(world: Vector3) -> Vector2:
	var half: Vector2 = size * 0.5
	var scale_factor: float = minf(half.x, half.y) / world_radius
	return half + Vector2(world.x, world.z) * scale_factor


func _draw() -> void:
	_resolve()

	draw_rect(Rect2(Vector2.ZERO, size), background_colour, true)
	_draw_grid()

	if _wreck != null:
		_draw_wreck()
	if _field != null:
		for rock in _field.get_children():
			var r: Node3D = rock as Node3D
			if r == null:
				continue
			# Radius scaled from the rock's own size, so the map reports the
			# big ones as big -- which is what makes them usable landmarks.
			var dot: float = clampf(r.scale.x * 0.16, 1.0, 5.0)
			draw_circle(_to_map(r.global_position), dot, rock_colour)

	for threat in get_tree().get_nodes_in_group("threat"):
		var t: Node3D = threat as Node3D
		if t != null:
			draw_circle(_to_map(t.global_position), 4.0, threat_colour, false, 1.5)

	_draw_rally()
	_draw_drones()
	_draw_ship()

	draw_rect(Rect2(Vector2.ZERO, size), border_colour, false, 1.5)


## Cross-hairs through the origin, so the map has a frame of reference even
## when the ship is far from anything.
func _draw_grid() -> void:
	var centre: Vector2 = _to_map(Vector3.ZERO)
	draw_line(Vector2(centre.x, 0.0), Vector2(centre.x, size.y), grid_colour, 1.0)
	draw_line(Vector2(0.0, centre.y), Vector2(size.x, centre.y), grid_colour, 1.0)


func _draw_wreck() -> void:
	# The wreck's footprint, taken from its actual transform rather than a
	# hard-coded box, so it stays right if the model is rescaled or re-placed.
	var half_length: float = 255.0
	var half_beam: float = 104.0
	var basis: Basis = _wreck.global_transform.basis
	var forward: Vector3 = basis.z.normalized() * half_length
	var right: Vector3 = basis.x.normalized() * half_beam
	var origin: Vector3 = _wreck.global_position
	var corners: PackedVector2Array = PackedVector2Array([
		_to_map(origin + forward + right),
		_to_map(origin + forward - right),
		_to_map(origin - forward - right),
		_to_map(origin - forward + right),
	])
	draw_colored_polygon(corners, Color(wreck_colour, 0.22))
	corners.append(corners[0])
	draw_polyline(corners, wreck_colour, 1.0)


func _draw_rally() -> void:
	var marker: RallyMarker = RallyMarker.for_swarm(get_tree(), allegiance)
	if marker == null or not marker.active:
		return
	var point: Vector2 = _to_map(marker.global_position)
	draw_circle(point, 5.0, rally_colour, false, 1.5)
	draw_circle(point, 1.5, rally_colour)


func _draw_drones() -> void:
	var swarms: Array = get_tree().get_nodes_in_group("swarm_" + str(allegiance))
	if swarms.is_empty():
		return
	var swarm: Swarm = swarms[0] as Swarm
	if swarm == null:
		return
	for drone in swarm.units:
		if drone == null:
			continue
		var machine: Node = drone.get_node_or_null("StateMachine")
		var fleeing: bool = (
			machine != null
			and machine.current_state != null
			and machine.current_state.name == "Flee"
		)
		draw_circle(
			_to_map(drone.global_position),
			2.0,
			fleeing_colour if fleeing else drone_colour
		)


## The player, drawn as a triangle pointing along the ship's heading.
##
## A triangle rather than a dot because heading is the one thing the 3D view
## makes hard to read at a glance when the camera is turned, and it is exactly
## what the player needs when deciding which way to fly.
func _draw_ship() -> void:
	if _ship == null:
		return
	var centre: Vector2 = _to_map(_ship.global_position)
	# +Z is forward in this codebase, following Duggan -- NOT Vector3.FORWARD,
	# which is -Z and would draw the marker pointing backwards.
	var heading: Vector3 = _ship.global_transform.basis.z
	var facing: Vector2 = Vector2(heading.x, heading.z).normalized()
	if facing == Vector2.ZERO:
		facing = Vector2.UP
	var side: Vector2 = Vector2(-facing.y, facing.x)
	draw_colored_polygon(
		PackedVector2Array([
			centre + facing * 7.0,
			centre - facing * 4.0 + side * 4.0,
			centre - facing * 4.0 - side * 4.0,
		]),
		ship_colour
	)
