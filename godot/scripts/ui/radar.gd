## A tilted radar disc with a heading arc wrapping over it. The tilt matches
## the game camera's own angle.
##
## CAMERA-RELATIVE. The disc turns with the camera, so up on the scope is
## always the direction the camera faces. A north marker on the rim gives the
## world reference, and the heading arc reports the camera's world bearing.
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
##
## Everything else is sized relative to this, out to about 1.3 disc radii. The
## ratio has to stay under 1 / 2.6 or the instrument draws outside its own
## control, and a Control does not clip its own drawing.
@export_range(0.1, 0.6) var disc_radius_ratio: float = 0.33

## Where the disc centre sits vertically, as a fraction of the height.
@export_range(0.0, 1.0) var disc_centre_ratio: float = 0.50

## Radius of the heading arc, relative to the disc radius.
##
## Constrained by the control's half-width, since the tick labels sit a
## further 1.12 out and Controls do not clip their own drawing.
@export var arc_radius_ratio: float = 1.30

## How many degrees of heading the arc spans. Anything outside this span is
## off the arc entirely.
@export var arc_span_degrees: float = 90.0

## How much SCREEN arc the band physically occupies, in degrees.
##
## Separate from arc_span_degrees, and the distinction matters: that one says
## how many degrees of HEADING fit on the band, this says how long the band
## LOOKS.
@export var arc_screen_span_degrees: float = 104.0

## Colour of the north marker on the disc rim.
@export var north_colour: Color = Palette.RIVAL

@export_group("Speed bar")

## How many segments the speed bar is cut into.
@export var speed_segments: int = 12

## Where the gauge's ZERO and FULL ends sit, in screen degrees clockwise from
## straight up.
##
## Wraps the disc's right-hand side, filling upward: zero low, full high.
##
## The full end stops short of the heading arc, which occupies the top
## arc_screen_span_degrees / 2 either side of vertical. The two share the ring
## around the disc, so they are placed to abut rather than overlap.
@export var speed_arc_zero: float = 168.0
@export var speed_arc_full: float = 62.0

## Radius of the gauge, relative to the disc radius. Just outside the rim, and
## inside the heading arc, so the instrument reads as concentric bands.
@export var speed_bar_radius_ratio: float = 1.12

## Metres per world unit, for the readout.
##
## The project's scale: the Farragut wreck is 2040 m and 510 units long.
@export var metres_per_unit: float = 4.0

## Half-width of a segment block, in pixels. The block is drawn twice this
## wide, so 4 gives an 8-pixel column.
@export var speed_bar_thickness: float = 4.0

@export_group("Colours")
@export var disc_colour: Color = Color(Palette.PANEL_BACKING, 0.66)
@export var rim_colour: Color = Color(Palette.PLAYER, 0.75)
@export var ring_colour: Color = Color(Palette.PLAYER, 0.22)
@export var ship_colour: Color = Palette.PLAYER
@export var drone_colour: Color = Color(Palette.PLAYER, 0.9)
@export var fleeing_colour: Color = Color(1.0, 0.42, 0.30)

## The rival hive's amber.
@export var rival_colour: Color = Palette.RIVAL
@export var rock_colour: Color = Palette.ROCK
@export var wreck_colour: Color = Color(0.62, 0.62, 0.66, 0.85)
@export var threat_colour: Color = Color(1.0, 0.35, 0.25)
@export var rally_colour: Color = Color(0.4, 1.0, 0.6)
@export var arc_colour: Color = Color(Palette.PLAYER, 0.55)
@export var cardinal_colour: Color = Palette.PLAYER
@export var centre_colour: Color = Color(1.0, 1.0, 1.0, 0.9)

## Lock ring colour when the target is a Barnacle rather than an enemy.
@export var barnacle_lock_colour: Color = Palette.BARNACLE

## Cardinal bearings, in world degrees clockwise from north. North is world -Z.
const CARDINALS: Dictionary = {
	0.0: Strings.NORTH, 45.0: Strings.NORTH_EAST,
	90.0: Strings.EAST, 135.0: Strings.SOUTH_EAST,
	180.0: Strings.SOUTH, 225.0: Strings.SOUTH_WEST,
	270.0: Strings.WEST, 315.0: Strings.NORTH_WEST,
}

## How many segments approximate the disc and the arc.
const CURVE_SEGMENTS: int = 36

var _targeting: Targeting
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
## order, so this Control can be ready before the world it reports on.
func _resolve() -> void:
	var tree: SceneTree = get_tree()
	# Cleared when freed, not merely when null: a cached reference to a freed
	# node is NOT null, and reading global_position off one throws.
	if _ship != null and not is_instance_valid(_ship):
		_ship = null
	if _camera != null and not is_instance_valid(_camera):
		_camera = null
	if _ship == null:
		_ship = tree.get_first_node_in_group(Ship.GROUP_PREFIX + str(allegiance)) as Node3D
	if _field == null:
		_field = tree.get_root().find_child("AsteroidField", true, false) as Node3D
	if _wreck == null:
		_wreck = tree.get_root().find_child("Wreck", true, false) as Node3D
	if _camera == null:
		_camera = tree.get_root().find_child("Camera3D", true, false) as FollowCamera
	if _targeting == null and _ship != null:
		_targeting = _ship.get_node_or_null("Targeting") as Targeting


func _disc_centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * disc_centre_ratio)


func _disc_radius() -> float:
	return size.x * disc_radius_ratio


## cos(tilt): the foreshortening a circle undergoes at that angle.
func _squash() -> float:
	return cos(deg_to_rad(tilt_degrees))


## How far the disc is turned, in radians: the negated camera heading, so the
## disc turns with the camera. No half-turn offset.
func _disc_turn() -> float:
	return -deg_to_rad(_camera_heading())


## A world POSITION, in disc space, before the squash.
##
## World XZ straight through, turned by the camera heading and nothing else.
## Neither axis is negated, so the scope keeps the handedness of the world.
func _position_to_disc(x: float, z: float) -> Vector2:
	return Vector2(x, z).rotated(_disc_turn())


## A world DIRECTION, in disc space, before the squash.
##
## The SAME mapping as [method _position_to_disc]: a heading has to land where
## the place it points to lands.
func _direction_to_disc(x: float, z: float) -> Vector2:
	return _position_to_disc(x, z)


## World position to a point on the tilted disc.
func _to_disc(world: Vector3) -> Vector2:
	var radius: float = _disc_radius()
	# _position_to_disc has already turned it: rotating again here would apply
	# the camera heading twice.
	var offset: Vector2 = _position_to_disc(world.x, world.z) / world_radius * radius
	# Clamped to the rim so contacts cannot escape the scope.
	if offset.length() > radius:
		offset = offset.normalized() * radius
	return _disc_centre() + Vector2(offset.x, offset.y * _squash())


func _draw() -> void:
	_resolve()
	_draw_disc()
	_draw_north()
	_draw_contacts()
	# After the contacts, so the lock ring sits ON the blip rather than under
	# it, and before the arc so the rim furniture stays on top.
	_draw_target_lock()
	_draw_arc()
	_draw_speed_bar()


## A ring around the targeted contact's blip.
##
## When the target is off the disc the blip is clamped to the rim, so the ring
## doubles as a bearing to it.
func _draw_target_lock() -> void:
	if _targeting == null or _targeting.current == null:
		return
	if not is_instance_valid(_targeting.current):
		return

	var at: Vector2 = _to_disc(_targeting.current.global_position)
	var tint: Color = (
		barnacle_lock_colour
		if _targeting.kind == Targeting.Kind.BARNACLE
		else rival_colour
	)

	draw_circle(at, 5.5, tint, false, 1.0)
	draw_circle(at, 3.0, Color(tint, 0.5), false, 1.0)
	for i in 4:
		var angle: float = TAU * float(i) / 4.0 + PI * 0.25
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(at + direction * 5.0, at + direction * 8.0, tint, 1.0)


## A segmented speed gauge wrapping the disc's right-hand side.
##
## Reads actual velocity against max_speed, not thrust input.
func _draw_speed_bar() -> void:
	if _ship == null or not ("max_speed" in _ship):
		return

	var ceiling: float = maxf(_ship.max_speed, 0.001)
	var speed: float = _ship.velocity.length() if "velocity" in _ship else 0.0
	var fraction: float = clampf(speed / ceiling, 0.0, 1.0)

	var centre: Vector2 = _disc_centre()
	var radius: float = _disc_radius() * speed_bar_radius_ratio
	var squash: float = _squash()

	# How far up the gauge the fill has reached, in segments. Fractional, so the
	# leading segment is drawn partly lit.
	var filled: float = fraction * float(speed_segments)

	for i in speed_segments:
		var t0: float = float(i) / float(speed_segments)
		var t1: float = float(i + 1) / float(speed_segments)
		var a0: float = deg_to_rad(lerpf(speed_arc_zero, speed_arc_full, t0))
		var a1: float = deg_to_rad(lerpf(speed_arc_zero, speed_arc_full, t1))
		# A small gap between segments. signf keeps it a gap rather than an
		# overlap whichever direction the gauge runs.
		var gap: float = deg_to_rad(1.2) * signf(a1 - a0)
		a0 += gap
		a1 -= gap

		var from: Vector2 = _on_ring(centre, radius, squash, a0)
		var to: Vector2 = _on_ring(centre, radius, squash, a1)

		# The unlit track is always drawn, so the gauge shows its full range.
		draw_line(from, to, Color(rim_colour, 0.22), speed_bar_thickness)

		var lit: float = clampf(filled - float(i), 0.0, 1.0)
		if lit <= 0.0:
			continue
		# Top fifth warns.
		var colour: Color = ship_colour if t0 < 0.8 else Color(1.0, 0.72, 0.3)
		draw_line(from, from.lerp(to, lit), colour, speed_bar_thickness)

	_draw_speed_reading(
		speed, _on_ring(centre, radius, squash, deg_to_rad(speed_arc_full))
	)


## A point on the tilted ring at [param angle], measured clockwise from up.
##
## Shared by the gauge and its reading so the two cannot drift apart.
func _on_ring(
	centre: Vector2, radius: float, squash: float, angle: float
) -> Vector2:
	return centre + Vector2(sin(angle) * radius, -cos(angle) * radius * squash)


## The numeric speed, placed at the gauge's FULL end.
func _draw_speed_reading(speed: float, at: Vector2) -> void:
	var label: String = "%d m/s" % roundi(speed * metres_per_unit)
	var width: float = _font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9
	).x
	# Clamped to the panel: a three-digit reading grows leftward rather than off
	# the side of the control, which a Control does not clip.
	var x: float = clampf(at.x - width * 0.5, 2.0, size.x - width - 2.0)
	draw_string(
		_font, Vector2(x, at.y - 5.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ship_colour
	)


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
	# Cross-hairs on the world axes.
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


## Both swarms, friendly first.
func _draw_drones() -> void:
	_draw_swarm(allegiance, drone_colour)
	_draw_swarm(1 - allegiance, rival_colour)
	_draw_rival_ship()


func _draw_swarm(side: int, colour: Color) -> void:
	var swarms: Array = get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(side))
	if swarms.is_empty():
		return
	var swarm: Swarm = swarms[0] as Swarm
	if swarm == null:
		return
	for drone in swarm.units:
		if drone == null:
			continue
		var machine: Node = drone.get_node_or_null("StateMachine")
		# Only friendly units report their state.
		var fleeing: bool = (
			side == allegiance
			and machine != null
			and machine.current_state != null
			and machine.current_state.name == "Flee"
		)
		draw_circle(
			_to_disc(drone.global_position), 1.5,
			fleeing_colour if fleeing else colour
		)


## The enemy Matriarch, as a larger blip than a drone.
func _draw_rival_ship() -> void:
	for node in get_tree().get_nodes_in_group(Ship.GROUP_PREFIX + str(1 - allegiance)):
		var ship: Node3D = node as Node3D
		if ship == null:
			continue
		var at: Vector2 = _to_disc(ship.global_position)
		draw_circle(at, 3.5, rival_colour)
		draw_circle(at, 5.5, rival_colour, false, 1.0)


## The player, as a triangle pointing along the ship's heading.
func _draw_ship() -> void:
	if _ship == null:
		return
	var centre: Vector2 = _to_disc(_ship.global_position)
	# +Z is forward in this codebase, following Duggan. Vector3.FORWARD is -Z
	# and would draw the marker pointing backwards.
	var heading: Vector3 = _ship.global_transform.basis.z
	var facing: Vector2 = _direction_to_disc(heading.x, heading.z)
	facing = Vector2(facing.x, facing.y * _squash())
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


## The camera's heading in degrees, 0 at north (-Z), increasing clockwise
## through east (+X).
##
## Read from the basis, not the rig's yaw: the camera aims back at the ship, so
## the two differ by an amount that changes as it turns.
func _camera_heading() -> float:
	if _camera == null:
		return 0.0
	var forward: Vector3 = -_camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return 0.0
	# atan2(x, -z): north is -Z and bearings increase clockwise toward +X east.
	return fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)


## Screen position on the heading arc for a world bearing, or a null vector
## when the bearing falls outside the arc's span.
func _arc_point(bearing: float, radius_scale: float = 1.0) -> Vector2:
	var relative: float = fposmod(bearing - _camera_heading() + 180.0, 360.0) - 180.0
	if absf(relative) > arc_span_degrees * 0.5:
		return Vector2.INF
	# Map the heading offset onto an arc over the top of the disc. -90 degrees
	# of screen angle is straight up, so the band centres above the disc.
	var t: float = relative / arc_span_degrees
	var screen_angle: float = -PI * 0.5 + t * deg_to_rad(arc_screen_span_degrees)
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
	# to the usual atan2(y, x) convention.
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
		# Only slightly beyond the ticks, or the labels fall outside the control.
		var text_at: Vector2 = _arc_point(bearing, 1.12)
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


## A marker on the disc rim showing which way world north lies. The disc turns
## with the camera, so this is the display's only fixed world reference.
##
## North is -Z. This codebase treats +Z as forward, so a contact due north of
## the ship sits at negative Z, which maps to the top of an unrotated disc.
func _draw_north() -> void:
	var radius: float = _disc_radius()
	var squash: float = _squash()
	# Through the POSITION mapping: this marks where a contact due north would
	# appear, which is a place on the disc rather than a heading.
	var direction: Vector2 = _position_to_disc(0.0, -1.0)
	var at: Vector2 = _disc_centre() + Vector2(
		direction.x * radius, direction.y * radius * squash
	)

	# A tick pointing outward along the same bearing.
	var outward: Vector2 = Vector2(direction.x, direction.y * squash).normalized()
	draw_line(at - outward * 2.0, at + outward * 4.0, north_colour, 1.0)

	var label_at: Vector2 = at + outward * 11.0
	draw_string(
		_font, label_at + Vector2(-3.0, 3.0), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, north_colour
	)
