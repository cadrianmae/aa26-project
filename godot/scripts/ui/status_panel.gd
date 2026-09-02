## One of the two panels flanking the radar: a schematic in a ring, with an
## integrity arc wrapped underneath it.
##
## The same script draws both. On the right it reports the player's own ship;
## on the left, whatever is targeted -- and when nothing is targeted, it draws
## nothing at all rather than an empty frame, so the HUD is quiet until there
## is something to say.
class_name StatusPanel
extends Control

## Which side this panel reports on.
enum Mode { OWN_SHIP, TARGET }

@export var mode: Mode = Mode.OWN_SHIP

## Which hive owns the HUD. The panel follows this commander.
@export var allegiance: int = 0

@export_group("Geometry")

## Ring radius as a fraction of the panel width.
@export_range(0.1, 0.6) var ring_radius_ratio: float = 0.34

## Where the ring's centre sits vertically, as a fraction of panel height.
##
## High, because the integrity arc wraps BELOW the ring and needs the room.
@export_range(0.0, 1.0) var ring_centre_ratio: float = 0.42

## Viewing angle, in degrees from overhead. Matches [member Radar.tilt_degrees].
@export_range(0.0, 80.0) var tilt_degrees: float = 45.0

## How far out the integrity arc sits, as a multiple of the ring radius.
@export var arc_radius_ratio: float = 1.25

## Degrees the integrity arc spans, centred on straight down.
@export var arc_span_degrees: float = 150.0

@export var arc_thickness: float = 3.0

@export_group("Colours")
@export var player_colour: Color = Palette.PLAYER
@export var rival_colour: Color = Palette.RIVAL
@export var barnacle_colour: Color = Palette.BARNACLE
@export var ring_colour: Color = Color(Palette.PLAYER, 0.30)
@export var damage_colour: Color = Color(1.0, 0.42, 0.30)
@export var empty_colour: Color = Color(Palette.PLAYER, 0.16)

const CURVE_SEGMENTS: int = 28

var _ship: Ship
var _targeting: Targeting
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


## Resolved on first draw, never in _ready(). Godot readies siblings in scene
## order, so this Control can be ready before the ship it reports on.
func _resolve() -> void:
	# A destroyed commander is freed, and a freed node is not null.
	if _ship != null and not is_instance_valid(_ship):
		_ship = null
		_targeting = null
	if _ship == null:
		_ship = get_tree().get_first_node_in_group(
			Ship.GROUP_PREFIX + str(allegiance)
		) as Ship
	if _targeting == null and _ship != null:
		_targeting = _ship.get_node_or_null("Targeting") as Targeting


func _draw() -> void:
	_resolve()
	if _ship == null:
		return

	if not is_instance_valid(_ship):
		return
	if mode == Mode.OWN_SHIP:
		_draw_panel(
			Strings.OWN_SHIP, _hull_fraction(_ship), player_colour, _ship_points()
		)
		return

	# Target panel: silent when nothing is selected.
	if _targeting == null or _targeting.current == null:
		return
	_draw_panel(
		_target_label(),
		_targeting.target_health_fraction(),
		_target_colour(),
		_target_points()
	)


func _draw_panel(
	label: String, fraction: float, tint: Color, points: PackedVector2Array
) -> void:
	var centre: Vector2 = Vector2(size.x * 0.5, size.y * ring_centre_ratio)
	var radius: float = size.x * ring_radius_ratio
	var squash: float = cos(deg_to_rad(tilt_degrees))

	_draw_ellipse(centre, radius, squash, ring_colour, 1.0)
	_draw_ellipse(centre, radius * 0.82, squash, ring_colour, 1.0)

	# A swarm is a scatter, not a silhouette -- drawn instead of the polygon.
	if mode == Mode.TARGET and _targeting != null \
			and _targeting.kind == Targeting.Kind.SWARM:
		_draw_swarm_cluster(centre, radius)
	elif points.size() >= 3:
		var placed: PackedVector2Array = PackedVector2Array()
		for point in points:
			placed.append(centre + point * radius)
		draw_colored_polygon(placed, Color(tint, 0.30))
		placed.append(placed[0])
		draw_polyline(placed, tint, 1.0)

	if fraction >= 0.0:
		_draw_integrity(centre, radius, squash, fraction)
		var percent: String = "%d%%" % [roundi(fraction * 100.0)]
		draw_string(
			_font, centre + Vector2(-14.0, radius * squash * arc_radius_ratio + 16.0),
			percent, HORIZONTAL_ALIGNMENT_CENTER, 28.0, 8, tint
		)

	draw_string(
		_font, Vector2(4.0, 10.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 8, tint
	)


## The integrity arc, wrapped under the ring.
##
## Drawn as two arcs over the same span: the whole span faintly, then the
## filled portion over it.
func _draw_integrity(
	centre: Vector2, radius: float, squash: float, fraction: float
) -> void:
	var arc_radius: float = radius * arc_radius_ratio
	var half: float = deg_to_rad(arc_span_degrees) * 0.5
	# 90 degrees is straight down in screen space, which is where the arc is
	# centred so it cradles the ring.
	var from: float = PI * 0.5 - half
	var to: float = PI * 0.5 + half

	_draw_arc_segment(centre, arc_radius, squash, from, to, empty_colour)
	if fraction > 0.0:
		var filled_to: float = from + (to - from) * clampf(fraction, 0.0, 1.0)
		var tint: Color = damage_colour if fraction < 0.35 else (
			player_colour if mode == Mode.OWN_SHIP else _target_colour()
		)
		_draw_arc_segment(centre, arc_radius, squash, from, filled_to, tint)


func _draw_arc_segment(
	centre: Vector2, radius: float, squash: float,
	from: float, to: float, tint: Color
) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in CURVE_SEGMENTS + 1:
		var angle: float = lerpf(from, to, float(i) / float(CURVE_SEGMENTS))
		points.append(centre + Vector2(cos(angle) * radius, sin(angle) * radius * squash))
	if points.size() > 1:
		draw_polyline(points, tint, arc_thickness)


func _draw_ellipse(
	centre: Vector2, radius: float, squash: float, tint: Color, width: float
) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in CURVE_SEGMENTS + 1:
		var angle: float = TAU * float(i) / float(CURVE_SEGMENTS)
		points.append(centre + Vector2(cos(angle) * radius, sin(angle) * radius * squash))
	draw_polyline(points, tint, width)


## Hull integrity as 0..1.
##
## Measured against the health the ship started with, captured on first draw.
var _full_health: float = 0.0


func _hull_fraction(ship: Ship) -> float:
	if _full_health <= 0.0:
		_full_health = ship.health
	if _full_health <= 0.0:
		return -1.0
	return clampf(ship.health / _full_health, 0.0, 1.0)


func _target_label() -> String:
	match _targeting.kind:
		Targeting.Kind.SHIP:
			return Strings.TARGET_SHIP
		Targeting.Kind.SWARM:
			return Strings.TARGET_SWARM
		Targeting.Kind.BARNACLE:
			return Strings.TARGET_BARNACLE
	return ""


func _target_colour() -> Color:
	if _targeting.kind == Targeting.Kind.BARNACLE:
		return barnacle_colour
	return rival_colour


## The Matriarch silhouette, in units of the ring radius.
##
## The hull seen from above: flat angled bow, swept flanks, a sharp tail.
func _ship_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -0.62),
		Vector2(0.30, -0.26),
		Vector2(0.58, 0.10),
		Vector2(0.24, 0.24),
		Vector2(0.0, 0.66),
		Vector2(-0.24, 0.24),
		Vector2(-0.58, 0.10),
		Vector2(-0.30, -0.26),
	])


## What to draw inside the target ring, by kind.
##
## A swarm has no single silhouette, so it returns an empty array and is drawn
## as a cluster instead.
func _target_points() -> PackedVector2Array:
	match _targeting.kind:
		Targeting.Kind.SHIP:
			return _ship_points()
		Targeting.Kind.BARNACLE:
			return PackedVector2Array([
				Vector2(0.0, -0.52), Vector2(0.45, -0.30), Vector2(0.52, 0.18),
				Vector2(0.20, 0.50), Vector2(-0.28, 0.46), Vector2(-0.52, 0.06),
				Vector2(-0.38, -0.34),
			])
	return PackedVector2Array()


## Swarm targets are drawn as a scatter of drones rather than a polygon.
func _draw_swarm_cluster(centre: Vector2, radius: float) -> void:
	var seeds: Array = [
		Vector2(0.0, 0.0), Vector2(0.34, -0.18), Vector2(-0.30, -0.10),
		Vector2(0.16, 0.30), Vector2(-0.22, 0.34), Vector2(0.44, 0.12),
		Vector2(-0.46, 0.16),
	]
	for seed in seeds:
		draw_circle(centre + seed * radius, 1.6, rival_colour)
