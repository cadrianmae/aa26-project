## An engine exhaust: a ribbon trail and a glow at the nozzle.
##
## Placed as a child of a Ship or Drone at the point the exhaust leaves the
## hull. Four on the Matriarch, one on each drone. It reads the agent it is
## attached to and does nothing else -- so a hull gets thrusters by having
## Thruster nodes, and neither Ship nor Drone knows this class exists.
##
## Colour matches the weapons on purpose. Everything this species emits comes
## out the same hot orange-red, so a trail and a bolt read as the same
## technology rather than as two unrelated effects that happen to share a
## screen.
##
## The trail is in WORLD space, not local. A local-space trail is dragged along
## behind the ship and looks painted on; a world-space one is left BEHIND, so
## it hangs in the belt and marks where the ship has been. That difference is
## most of what makes exhaust read as thrust rather than as decoration.
class_name Thruster
extends Node3D

## Exhaust colour at the nozzle. The projectiles' core colour.
@export var flame_colour: Color = Color(1.0, 0.30, 0.10)

## Colour the ribbon fades to along its length, as the exhaust cools.
@export var ember_colour: Color = Color(0.65, 0.12, 0.03)

## How many past positions the ribbon spans. Longer reads as faster.
@export var trail_points: int = 18

## Half-width of the ribbon at the nozzle, tapering to nothing at the tail.
@export var trail_width: float = 0.3

## Brightness of the nozzle glow at full throttle.
@export var glow_energy: float = 3.0

## Radius of the nozzle glow.
@export var glow_range: float = 6.0

## Least throttle at which the thruster shows anything at all.
##
## An engine at rest should be dark. Without a floor the trail never fully
## stops, and a parked ship sits there quietly smoking.
@export_range(0.0, 0.5) var idle_cutoff: float = 0.04

## How quickly the flame follows the throttle. Fast, but not instant: a step
## change reads as a light switch rather than as an engine responding.
@export var response_speed: float = 8.0

var _agent: Node3D
var _trail: TrailRibbon
var _glow: OmniLight3D
var _level: float = 0.0


func _ready() -> void:
	_agent = _find_agent()
	_build_trail()
	_build_glow()


## Walk up for whatever has a velocity, so this works on either hull type.
##
## Resolved by looking for the PROPERTY rather than the class, because Ship and
## Drone share no base type -- one is the player's hull and one is a swarm
## unit, and neither derives from the other.
func _find_agent() -> Node3D:
	var node: Node = get_parent()
	while node != null:
		if node is Node3D and "velocity" in node and "max_speed" in node:
			return node as Node3D
		node = node.get_parent()
	return null


func _process(delta: float) -> void:
	if _agent == null:
		return

	var speed: float = _agent.velocity.length()
	var top: float = maxf(_agent.max_speed, 0.001)
	var target: float = clampf(speed / top, 0.0, 1.0)
	_level = lerpf(_level, target, minf(delta * response_speed, 1.0))

	var lit: bool = _level > idle_cutoff
	if _trail != null:
		# Fed the nozzle's CURRENT world position every frame. When the engine
		# is not lit the ribbon is still advanced, but with nothing added, so
		# the existing tail runs itself out instead of freezing in place.
		_trail.advance(global_position, lit)
		_trail.width = trail_width * maxf(_level, 0.25)
	if _glow != null:
		_glow.visible = lit
		_glow.light_energy = glow_energy * _level


## The trail itself: a ribbon through the path the nozzle has taken.
func _build_trail() -> void:
	_trail = TrailRibbon.new()
	_trail.name = "Trail"
	_trail.points = maxi(trail_points, 2)
	_trail.width = trail_width
	_trail.head_colour = flame_colour
	_trail.tail_colour = Color(ember_colour.r, ember_colour.g, ember_colour.b, 0.0)
	# A child, but the ribbon sets top_level itself, so it holds world
	# positions and is not dragged along by the nozzle it hangs from.
	add_child(_trail)


## The glow where the exhaust leaves the hull.
func _build_glow() -> void:
	_glow = OmniLight3D.new()
	_glow.name = "Nozzle"
	_glow.light_color = flame_colour
	_glow.light_energy = 0.0
	_glow.omni_range = glow_range
	_glow.visible = false
	add_child(_glow)
