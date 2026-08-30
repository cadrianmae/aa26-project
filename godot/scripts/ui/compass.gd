## A heading strip showing which way the camera faces, and where things are.
##
## The minimap is fixed north, which is right for building a mental map but
## means map-up and screen-up disagree whenever the camera is turned. This is
## the other half of that trade: it reports the camera's heading, and puts
## bearing pips for important places at the screen angle they actually lie in.
##
## So the two read together -- the map says WHERE something is, the compass
## says WHICH WAY to turn to face it.
##
## A linear strip rather than a ring, because the game's camera yaws in
## 45-degree steps: eight fixed headings, and a strip shows the neighbouring
## ones you are about to step to, which a ring hides behind the ship.
class_name Compass
extends Control

## Which side's rally marker to show a pip for.
@export var allegiance: int = 0

## How many degrees of heading the strip spans end to end. 180 shows a
## semicircle, so everything ahead is on the strip and everything behind is
## off it -- which is the distinction that matters when flying.
@export var visible_arc: float = 180.0

@export_group("Colours")
@export var background_colour: Color = Color(0.02, 0.03, 0.03, 0.6)
@export var tick_colour: Color = Color(0.435, 0.812, 0.353, 0.5)
@export var cardinal_colour: Color = Color(0.435, 0.812, 0.353)
@export var centre_colour: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var wreck_colour: Color = Color(0.55, 0.55, 0.58)
@export var rally_colour: Color = Color(0.4, 1.0, 0.6)
@export var threat_colour: Color = Color(1.0, 0.35, 0.25)

## Cardinal names at their world bearings. North is world -Z, matching the
## minimap's fixed-north convention, so the two agree about which way is up.
const CARDINALS: Dictionary = {
	0.0: "N",
	45.0: "NE",
	90.0: "E",
	135.0: "SE",
	180.0: "S",
	225.0: "SW",
	270.0: "W",
	315.0: "NW",
}

var _camera: FollowCamera
var _ship: Node3D
var _wreck: Node3D
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _resolve() -> void:
	var tree: SceneTree = get_tree()
	if _camera == null:
		_camera = tree.get_root().find_child("Camera3D", true, false) as FollowCamera
	if _ship == null:
		_ship = tree.get_first_node_in_group("commander_" + str(allegiance)) as Node3D
	if _wreck == null:
		_wreck = tree.get_root().find_child("Wreck", true, false) as Node3D


## The camera's heading in degrees, 0 at north and increasing clockwise.
func _camera_heading() -> float:
	if _camera == null:
		return 0.0
	return fposmod(rad_to_deg(_camera.yaw), 360.0)


## Screen x for a world bearing, or -1.0 when it falls outside the strip.
func _bearing_to_x(bearing: float) -> float:
	var relative: float = fposmod(bearing - _camera_heading() + 180.0, 360.0) - 180.0
	if absf(relative) > visible_arc * 0.5:
		return -1.0
	return size.x * (0.5 + relative / visible_arc)


## World bearing from the ship to a point, in degrees clockwise from north.
func _bearing_to(point: Vector3) -> float:
	if _ship == null:
		return 0.0
	var delta: Vector3 = point - _ship.global_position
	# atan2(x, -z): north is -Z and bearings run clockwise, which is the
	# opposite handedness to the usual atan2(y, x) convention.
	return fposmod(rad_to_deg(atan2(delta.x, -delta.z)), 360.0)


func _draw() -> void:
	_resolve()

	draw_rect(Rect2(Vector2.ZERO, size), background_colour, true)

	# Minor ticks every 15 degrees, so motion between cardinals is visible.
	var heading: float = _camera_heading()
	var step: float = 15.0
	var first: float = heading - visible_arc * 0.5
	var tick: float = ceilf(first / step) * step
	while tick < heading + visible_arc * 0.5:
		var x: float = _bearing_to_x(fposmod(tick, 360.0))
		if x >= 0.0:
			draw_line(Vector2(x, size.y * 0.62), Vector2(x, size.y), tick_colour, 1.0)
		tick += step

	for bearing in CARDINALS:
		var x: float = _bearing_to_x(bearing)
		if x < 0.0:
			continue
		draw_line(Vector2(x, size.y * 0.35), Vector2(x, size.y), cardinal_colour, 1.5)
		var label: String = CARDINALS[bearing]
		var width: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(
			_font, Vector2(x - width * 0.5, size.y * 0.30), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cardinal_colour
		)

	_draw_pips()

	# The centre line: where the camera is actually pointing.
	draw_line(
		Vector2(size.x * 0.5, 0.0), Vector2(size.x * 0.5, size.y),
		centre_colour, 1.5
	)


## Bearing markers for places worth finding when they are off screen.
func _draw_pips() -> void:
	if _ship == null:
		return

	if _wreck != null:
		_draw_pip(_bearing_to(_wreck.global_position), wreck_colour)

	var marker: RallyMarker = RallyMarker.for_swarm(get_tree(), allegiance)
	if marker != null and marker.active:
		_draw_pip(_bearing_to(marker.global_position), rally_colour)

	for threat in get_tree().get_nodes_in_group("threat"):
		var t: Node3D = threat as Node3D
		if t != null:
			_draw_pip(_bearing_to(t.global_position), threat_colour)


## One downward triangle at a bearing, or nothing if it is off the strip.
func _draw_pip(bearing: float, colour: Color) -> void:
	var x: float = _bearing_to_x(bearing)
	if x < 0.0:
		return
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(x, size.y * 0.55),
			Vector2(x - 4.0, size.y * 0.20),
			Vector2(x + 4.0, size.y * 0.20),
		]),
		colour
	)
