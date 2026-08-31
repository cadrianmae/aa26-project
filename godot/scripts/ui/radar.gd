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
##
## Everything else is sized RELATIVE to this -- the heading arc at 1.13, its
## labels at 1.22, the speed bar at 1.12 -- so the widest thing drawn reaches
## about 1.3 disc radii from the centre. The ratio therefore has to stay under
## 1 / 2.6 or the instrument draws outside its own control, and a Control does
## not clip its own drawing: it spills across the screen rather than being cut
## off at the panel edge.
@export_range(0.1, 0.6) var disc_radius_ratio: float = 0.33

## Where the disc centre sits vertically, as a fraction of the height.
##
## Above the middle, because the disc is squashed to cos(45) but the arc and
## labels above it are not -- so the instrument needs more room over the disc
## than under it.
@export_range(0.0, 1.0) var disc_centre_ratio: float = 0.50

## Radius of the heading arc, relative to the disc radius.
##
## Set well clear of the rim. The arc and the disc are different instruments
## -- one says which way you face, the other where things are -- and drawn
## close together they read as one crowded ring. The gap is what separates
## them.
##
## Constrained by the control's half-width, since the tick labels sit a
## further 1.12 out and Controls do not clip their own drawing: overflow
## paints across the screen rather than being cut off at the panel edge.
@export var arc_radius_ratio: float = 1.30

## How many degrees of heading the arc spans.
##
## 90 rather than a full 180. The arc's job is to say where the camera points
## and roughly what lies either side of that -- a wider sweep runs down the
## disc's flanks, crowds the scope and collides with the speed bar. Anything
## outside this span is off the arc, which is information in itself: it is
## well off to one side or behind you.
@export var arc_span_degrees: float = 90.0

## How much SCREEN arc the band physically occupies, in degrees.
##
## Separate from arc_span_degrees, and the distinction matters: that one says
## how many degrees of HEADING fit on the band, this says how long the band
## LOOKS. The first version hard-coded the screen sweep at 180 degrees, so
## narrowing the heading span only zoomed the scale in -- the arc stayed a
## half circle however it was tuned.
@export var arc_screen_span_degrees: float = 104.0

@export_group("Speed bar")

## How many segments the speed bar is cut into.
##
## Segmented rather than continuous, following Elite Dangerous: discrete
## blocks are readable at a glance and in peripheral vision, where a smoothly
## sliding bar is not. At 640x360 a continuous fill would also be about twenty
## pixels of gradient, which reads as a smudge.
@export var speed_segments: int = 12

## Where the gauge's ZERO and FULL ends sit, in screen degrees clockwise from
## straight up.
##
## Wraps the disc's right-hand side, filling upward: zero low and full high,
## because rising-equals-more is what every physical gauge trains.
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
## The project's scale: the Farragut wreck is 2040 m and 510 units long. The
## gauge reports metres per second because "18" means nothing to a player and
## "72 m/s" means something.
@export var metres_per_unit: float = 4.0

## Half-width of a segment block, in pixels. The block is drawn twice this
## wide, so 4 gives an 8-pixel column.
@export var speed_bar_thickness: float = 4.0

@export_group("Colours")
@export var disc_colour: Color = Color(0.02, 0.04, 0.03, 0.66)
@export var rim_colour: Color = Color(0.435, 0.812, 0.353, 0.75)
@export var ring_colour: Color = Color(0.435, 0.812, 0.353, 0.22)
@export var ship_colour: Color = Color(0.435, 0.812, 0.353)
@export var drone_colour: Color = Color(0.435, 0.812, 0.353, 0.9)
@export var fleeing_colour: Color = Color(1.0, 0.42, 0.30)

## The rival hive, in its amber gold. Same palette as its hulls, so a blip on
## the scope and a ship on screen are recognisably the same faction.
@export var rival_colour: Color = Color(0.851, 0.643, 0.255)
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
	_draw_speed_bar()


## A segmented speed gauge wrapping the disc's right-hand side.
##
## Reads the ship's actual velocity against its max_speed rather than the
## thrust input, so it reports what the Matriarch is DOING. Those differ
## whenever the ship is turning, drifting, or fighting its own damping, and
## the difference is exactly what a pilot needs to see.
func _draw_speed_bar() -> void:
	if _ship == null or not ("max_speed" in _ship):
		return

	var ceiling: float = maxf(_ship.max_speed, 0.001)
	var speed: float = _ship.velocity.length() if "velocity" in _ship else 0.0
	var fraction: float = clampf(speed / ceiling, 0.0, 1.0)

	var centre: Vector2 = _disc_centre()
	var radius: float = _disc_radius() * speed_bar_radius_ratio
	var squash: float = _squash()

	# How far up the gauge the fill has reached, in segments. Fractional: the
	# leading segment is drawn PARTLY lit rather than switching on all at
	# once, so acceleration reads as continuous rather than as a ratchet.
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

		# The unlit track is always drawn, so the gauge shows its full range
		# rather than appearing to shrink as the ship slows.
		draw_line(from, to, Color(rim_colour, 0.22), speed_bar_thickness)

		var lit: float = clampf(filled - float(i), 0.0, 1.0)
		if lit <= 0.0:
			continue
		# Top fifth warns: at full speed a capital ship is committed, and
		# turning it takes a while.
		var colour: Color = ship_colour if t0 < 0.8 else Color(1.0, 0.72, 0.3)
		draw_line(from, from.lerp(to, lit), colour, speed_bar_thickness)

	_draw_speed_reading(
		speed, _on_ring(centre, radius, squash, deg_to_rad(speed_arc_full))
	)


## A point on the tilted ring at [param angle], measured clockwise from up.
##
## Shared by the gauge and its reading so the two cannot drift apart, which is
## how the reading ended up beside the wrong end of the bar once already.
func _on_ring(
	centre: Vector2, radius: float, squash: float, angle: float
) -> Vector2:
	return centre + Vector2(sin(angle) * radius, -cos(angle) * radius * squash)


## The numeric speed, placed at the gauge's FULL end.
##
## At the top of the bar, where the fill is heading. A reading at the zero end
## sits where the needle starts rather than where it is going, and it hung
## below the panel; at the top it reads as the label for the gauge it belongs
## to. The heading arc is now short enough and far enough out that the two do
## not meet.
func _draw_speed_reading(speed: float, at: Vector2) -> void:
	var label: String = "%d m/s" % roundi(speed * metres_per_unit)
	var width: float = _font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9
	).x
	# Clamped to the panel, so a three-digit reading grows leftward into empty
	# space rather than off the side of the control -- which would not be
	# clipped, because a Control does not clip its own drawing.
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


## Both swarms, so the scope answers "where is the enemy" as well as "where
## are mine". A radar that only showed your own units would be a formation
## display, not a radar.
func _draw_drones() -> void:
	_draw_swarm(allegiance, drone_colour)
	_draw_swarm(1 - allegiance, rival_colour)
	_draw_rival_ship()


func _draw_swarm(side: int, colour: Color) -> void:
	var swarms: Array = get_tree().get_nodes_in_group("swarm_" + str(side))
	if swarms.is_empty():
		return
	var swarm: Swarm = swarms[0] as Swarm
	if swarm == null:
		return
	for drone in swarm.units:
		if drone == null:
			continue
		var machine: Node = drone.get_node_or_null("StateMachine")
		# Only friendly units report their state. Knowing an enemy drone is
		# fleeing is information the player has no way to see in the world,
		# and the radar should not know more than the ships do.
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


## The enemy Matriarch, as a larger blip. It is the thing that ends the match,
## so it should not look like one more drone.
func _draw_rival_ship() -> void:
	for node in get_tree().get_nodes_in_group("commander_" + str(1 - allegiance)):
		var ship: Node3D = node as Node3D
		if ship == null:
			continue
		var at: Vector2 = _to_disc(ship.global_position)
		draw_circle(at, 3.5, rival_colour)
		draw_circle(at, 5.5, rival_colour, false, 1.0)


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
	# Map the heading offset onto an arc over the top of the disc. -90 degrees
	# of screen angle is straight up, so the band centres above the disc and
	# its ends sweep down either side by half the screen span.
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
		# Only slightly beyond the ticks. The arc itself now sits well out from
		# the disc, so a large further offset would push the labels outside
		# the control.
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
