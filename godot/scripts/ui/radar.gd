## A tilted radar disc with a heading arc wrapping over it.
##
## Modelled on Elite Dangerous's radar: a circular scope seen at an angle
## rather than a flat overhead map, so it reads as a physical instrument in
## the cockpit instead of a menu drawn on the screen. The tilt matches the
## game camera's own angle, which makes the disc feel like a scale model of
## what the player is looking at.
##
## FIXED NORTH, not camera-relative. Up on the disc is always world -Z, so a
## place stays in the same part of the scope however the camera is turned.
## That is the same argument the stepped 45-degree camera rests on: the
## player's sense of where things ARE is most of what both are for, and a
## scope that spins destroys it. The heading arc is the other half of that
## trade -- it says which way the camera currently faces, so the two together
## answer "where is it" and "which way do I turn".
##
## Drawn with _draw() rather than assembled from textures, matching how the
## hulls are built from vertex lists: the look is vector shapes and flat
## colour, and drawing it needs no art pipeline.
class_name Radar
extends Control

## World radius the scope covers. The asteroid field is 900 across.
@export var world_radius: float = 1000.0

## Which side counts as friendly.
@export var allegiance: int = 0

@export_group("Geometry")

## Viewing angle of the disc, in degrees from overhead. 0 is a flat circle,
## 90 is edge-on and invisible. 45 matches the game camera.
@export_range(0.0, 80.0) var tilt_degrees: float = 45.0

## Disc radius as a fraction of the control's width.
@export_range(0.1, 0.6) var disc_radius_ratio: float = 0.42

## Where the disc centre sits vertically, as a fraction of the height. Below
## the middle, because the heading arc wraps over the top and needs the room.
@export_range(0.0, 1.0) var disc_centre_ratio: float = 0.62

## Radius of the heading arc, relative to the disc radius.
@export var arc_radius_ratio: float = 1.26

## How many degrees of heading the arc spans. 180 puts everything ahead of the
## camera on the arc and everything behind it off, which is the distinction
## that matters when flying.
@export var arc_span_degrees: float = 180.0

@export_group("Colours")
@export var disc_colour: Color = Color(0.02, 0.04, 0.03, 0.66)
@export var rim_colour: Color = Color(0.435, 0.812, 0.353, 0.75)
@export var ring_colour: Color = Color(0.435, 0.812, 0.353, 0.22)
@export var ship_colour: Color = Color(0.435, 0.812, 0.353)
@export var drone_colour: Color = Color(0.435, 0.812, 0.353, 0.9)
@export var fleeing_colour: Color = Color(1.0, 0.42, 0.30)
@export var rock_colour: Color = Color(0.42, 0.39, 0.34)
@export var wreck_colour: Color = Color(0.62, 0.62, 0.66, 0.85)
@export var threat_colour: Color = Color(1.0, 0.35, 0.25)
@export var rally_colour: Color = Color(0.4, 1.0, 0.6)
@export var arc_colour: Color = Color(0.435, 0.812, 0.353, 0.55)
@export var cardinal_colour: Color = Color(0.435, 0.812, 0.353)
@export var centre_colour: Color = Color(1.0, 1.0, 1.0, 0.9)

## Cardinal bearings. North is world -Z, matching the disc's fixed-north
## convention so the arc and the scope agree about which way is up.
const CARDINALS: Dictionary = {
	0.0: "N", 45.0: "NE", 90.0: "E", 135.0: "SE",
	180.0: "S", 225.0: "SW", 270.0: "W", 315.0: "NW",
}

## How many segments approximate the disc and the arc. Low on purpose: at
## 640x360 a smoother curve is not visible, and a slightly faceted rim suits
## the rest of the game's geometry.
const CURVE_SEGMENTS: int = 36

var _ship: Node3D
var _field: Node3D
var _wreck: Node3D
var _camera: FollowCamera
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


## Resolved on first draw, never in _ready(). Godot readies siblings in scene
## order, so this Control can be ready before the world it reports on. The
## project has been bitten by that three times.
func _resolve() -> void:
	var tree: SceneTree = get_tree()
	if _ship == null:
		_ship = tree.get_first_node_in_group("commander_" + str(allegiance)) as Node3D
	if _field == null:
		_field = tree.get_root().find_child("AsteroidField", true, false) as Node3D
	if _wreck == null:
		_wreck = tree.get_root().find_child("Wreck", true, false) as Node3D
	if _camera == null:
		_camera = tree.get_root().find_child("Camera3D", true, false) as FollowCamera


func _disc_centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * disc_centre_ratio)


func _disc_radius() -> float:
	return size.x * disc_radius_ratio


## Vertical squash from the viewing angle. cos(tilt) is the foreshortening a
## circle undergoes when viewed at that angle, which is what turns the disc
## into an ellipse rather than an arbitrary squash.
func _squash() -> float:
	return cos(deg_to_rad(tilt_degrees))


## World position to a point on the tilted disc.
func _to_disc(world: Vector3) -> Vector2:
	var radius: float = _disc_radius()
	var offset: Vector2 = Vector2(world.x, world.z) / world_radius * radius
	# Clamp to the rim rather than letting contacts escape the scope: an
	# instrument that draws outside its own bezel reads as broken.
	if offset.length() > radius:
		offset = offset.normalized() * radius
	return _disc_centre() + Vector2(offset.x, offset.y * _squash())


func _draw() -> void:
	_resolve()
	_draw_disc()
	_draw_contacts()
	_draw_arc()


func _draw_disc() -> void:
	var centre: Vector2 = _disc_centre()
	var radius: float = _disc_radius()
	var squash: float = _squash()

	draw_colored_polygon(_ellipse(centre, radius, radius * squash), disc_colour)
	for fraction in [0.33, 0.66]:
		draw_polyline(
			_ellipse(centre, radius * fraction, radius * fraction * squash, true),
			ring_colour, 1.0
		)
	# Cross-hairs on the world axes, so the scope has a frame of reference
	# even when nothing is near the ship.
	draw_line(
		centre - Vector2(radius, 0.0), centre + Vector2(radius, 0.0),
		ring_colour, 1.0
	)
	draw_line(
		centre - Vector2(0.0, radius * squash), centre + Vector2(0.0, radius * squash),
		ring_colour, 1.0
	)
	draw_polyline(_ellipse(centre, radius, radius * squash, true), rim_colour, 1.0)


func _ellipse(centre: Vector2, rx: float, ry: float, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in CURVE_SEGMENTS:
		var angle: float = TAU * float(i) / float(CURVE_SEGMENTS)
		points.append(centre + Vector2(cos(angle) * rx, sin(angle) * ry))
	if closed:
		points.append(points[0])
	return points


func _draw_contacts() -> void:
	if _wreck != null:
		_draw_wreck()

	if _field != null:
		for rock in _field.get_children():
			var r: Node3D = rock as Node3D
			if r != null:
				draw_circle(
					_to_disc(r.global_position),
					clampf(r.scale.x * 0.10, 0.8, 3.0),
					rock_colour
				)

	for threat in get_tree().get_nodes_in_group("threat"):
		var t: Node3D = threat as Node3D
		if t != null:
			draw_circle(_to_disc(t.global_position), 3.0, threat_colour, false, 1.0)

	var marker: RallyMarker = RallyMarker.for_swarm(get_tree(), allegiance)
	if marker != null and marker.active:
		draw_circle(_to_disc(marker.global_position), 4.0, rally_colour, false, 1.0)

	_draw_drones()
	_draw_ship()


func _draw_wreck() -> void:
	var basis: Basis = _wreck.global_transform.basis
	var origin: Vector3 = _wreck.global_position
	# Half-extents of the modelled hull, scaled by the node's own transform,
	# so the footprint follows the wreck if it is rescaled or re-placed.
	var forward: Vector3 = basis.z.normalized() * 255.0
	var right: Vector3 = basis.x.normalized() * 104.0
	var corners := PackedVector2Array([
		_to_disc(origin + forward + right),
		_to_disc(origin + forward - right),
		_to_disc(origin - forward - right),
		_to_disc(origin - forward + right),
	])
	draw_colored_polygon(corners, Color(wreck_colour, 0.22))
	corners.append(corners[0])
	draw_polyline(corners, wreck_colour, 1.0)


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
			_to_disc(drone.global_position), 1.5,
			fleeing_colour if fleeing else drone_colour
		)


## The player, as a triangle pointing along the ship's heading.
##
## A triangle rather than a blip because heading is the one thing the tilted
## 3D view makes hard to read at a glance, and it is exactly what the player
## needs when choosing which way to fly.
func _draw_ship() -> void:
	if _ship == null:
		return
	var centre: Vector2 = _to_disc(_ship.global_position)
	# +Z is forward in this codebase, following Duggan. Vector3.FORWARD is -Z
	# and would draw the marker pointing backwards.
	var heading: Vector3 = _ship.global_transform.basis.z
	var facing: Vector2 = Vector2(heading.x, heading.z * _squash())
	if facing.length() < 0.001:
		facing = Vector2.UP
	facing = facing.normalized()
	var side: Vector2 = Vector2(-facing.y, facing.x)
	draw_colored_polygon(
		PackedVector2Array([
			centre + facing * 5.0,
			centre - facing * 3.0 + side * 3.0,
			centre - facing * 3.0 - side * 3.0,
		]),
		ship_colour
	)


## The camera's heading in degrees, 0 at north, increasing clockwise.
func _camera_heading() -> float:
	if _camera == null:
		return 0.0
	return fposmod(rad_to_deg(_camera.yaw), 360.0)


## Screen position on the heading arc for a world bearing, or a null vector
## when the bearing falls outside the arc's span.
func _arc_point(bearing: float, radius_scale: float = 1.0) -> Vector2:
	var relative: float = fposmod(bearing - _camera_heading() + 180.0, 360.0) - 180.0
	if absf(relative) > arc_span_degrees * 0.5:
		return Vector2.INF
	# Map the heading offset onto an arc over the top of the disc: -90 degrees
	# of screen angle is straight up, so the centre of the arc sits above the
	# disc's centre and the ends sweep down its sides.
	var t: float = relative / arc_span_degrees
	var screen_angle: float = -PI * 0.5 + t * PI
	var radius: float = _disc_radius() * arc_radius_ratio * radius_scale
	return _disc_centre() + Vector2(
		cos(screen_angle) * radius,
		sin(screen_angle) * radius * _squash()
	)


## World bearing from the ship to a point, clockwise from north.
func _bearing_to(point: Vector3) -> float:
	if _ship == null:
		return 0.0
	var delta: Vector3 = point - _ship.global_position
	# atan2(x, -z): bearings run clockwise from north, the opposite handedness
	# to the usual atan2(y, x) convention. Getting this wrong mirrors the arc,
	# which reads as roughly working until it sends you the wrong way.
	return fposmod(rad_to_deg(atan2(delta.x, -delta.z)), 360.0)


func _draw_arc() -> void:
	# The arc band itself, drawn as a run of short segments.
	var previous: Vector2 = Vector2.INF
	var degrees: float = -arc_span_degrees * 0.5
	while degrees <= arc_span_degrees * 0.5:
		var point: Vector2 = _arc_point(fposmod(_camera_heading() + degrees, 360.0))
		if previous != Vector2.INF and point != Vector2.INF:
			draw_line(previous, point, arc_colour, 1.0)
		previous = point
		degrees += 5.0

	for bearing in CARDINALS:
		var inner: Vector2 = _arc_point(bearing, 0.94)
		var outer: Vector2 = _arc_point(bearing, 1.06)
		if inner == Vector2.INF or outer == Vector2.INF:
			continue
		draw_line(inner, outer, cardinal_colour, 1.0)
		var label: String = CARDINALS[bearing]
		var width: float = _font.get_string_size(
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8
		).x
		var text_at: Vector2 = _arc_point(bearing, 1.22)
		if text_at != Vector2.INF:
			draw_string(
				_font, text_at - Vector2(width * 0.5, 0.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cardinal_colour
			)

	_draw_arc_pips()

	# The mark showing where the camera actually points: the centre of the arc.
	var top: Vector2 = _arc_point(_camera_heading(), 1.0)
	if top != Vector2.INF:
		draw_line(top - Vector2(0.0, 4.0), top + Vector2(0.0, 3.0), centre_colour, 1.0)


## Bearing pips for places worth finding when they are off screen.
func _draw_arc_pips() -> void:
	if _ship == null:
		return
	var targets: Array = []
	if _wreck != null:
		targets.append([_wreck.global_position, wreck_colour])
	var marker: RallyMarker = RallyMarker.for_swarm(get_tree(), allegiance)
	if marker != null and marker.active:
		targets.append([marker.global_position, rally_colour])
	for threat in get_tree().get_nodes_in_group("threat"):
		var t: Node3D = threat as Node3D
		if t != null:
			targets.append([t.global_position, threat_colour])

	for target in targets:
		var point: Vector2 = _arc_point(_bearing_to(target[0]), 1.10)
		if point == Vector2.INF:
			continue
		draw_circle(point, 2.0, target[1])
