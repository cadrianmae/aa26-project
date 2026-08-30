## The one place the star and the gas giant are defined.
##
## Three things need to agree about where the sun is, and they are all
## configured differently: the sky shader draws it, a DirectionalLight3D casts
## from it, and every hull shader shades against it. Left to themselves they
## drift -- the sun ends up visibly in one corner of the sky while the ships
## are lit from the other, which reads as broken without being obviously
## wrong.
##
## So this node owns the direction and the colour, and writes them to all
## three. Move the sun here and everything follows.
##
## The hull shaders are reached through GLOBAL shader uniforms rather than by
## setting materials. Hull materials are built in code in three separate
## places, so there is no single material to write to, and walking the tree to
## find them all would silently miss any created later -- a drone spawned by
## the factory, for instance.
class_name StarSystem
extends Node3D

@export_group("Star")

## Direction TO the star from the belt. Normalised on use, so it can be typed
## as any convenient vector.
@export var sun_direction: Vector3 = Vector3(0.4, 0.35, 0.85):
	set(value):
		sun_direction = value
		_push()

## The star's colour. Cool white: a strongly tinted star would push the
## player's caustic green toward the rival's amber gold, and telling the two
## hives apart at six pixels is already the hardest thing the palette does.
@export var sun_colour: Color = Color(1.0, 0.957, 0.91):
	set(value):
		sun_colour = value
		_push()

## Brightness of the directional light.
@export var sun_energy: float = 1.35:
	set(value):
		sun_energy = value
		_push()

@export_group("Fill")

## What a surface facing away from the star still receives: bounce off the tan
## gas giant. Without it, unlit faces render pure black and hulls lose their
## silhouette against space entirely.
@export var fill_colour: Color = Color(0.16, 0.14, 0.11):
	set(value):
		fill_colour = value
		_push()

@export_group("Planet")

## Direction to the gas giant. Deliberately away from the sun, so the planet
## shows a crescent rather than a fully lit disc -- a full disc has no
## terminator, and the terminator is what makes it read as a sphere.
@export var planet_direction: Vector3 = Vector3(-0.75, 0.12, -0.65):
	set(value):
		planet_direction = value
		_push()

## Tan, as a gas giant should be.
@export var planet_colour: Color = Color(0.72, 0.60, 0.42):
	set(value):
		planet_colour = value
		_push()

## The darker bands.
@export var planet_band_colour: Color = Color(0.55, 0.44, 0.31):
	set(value):
		planet_band_colour = value
		_push()

## The light this drives. Left unset, a child named SunLight is used.
@export var light: DirectionalLight3D

## The environment holding the sky. Left unset, the first WorldEnvironment in
## the tree is used.
@export var environment: WorldEnvironment


func _ready() -> void:
	if light == null:
		light = get_node_or_null("SunLight") as DirectionalLight3D
	if environment == null:
		environment = get_tree().get_root().find_child(
			"WorldEnvironment", true, false
		) as WorldEnvironment
	_push()


## Write the current values to the sky, the light and the global uniforms.
func _push() -> void:
	if not is_inside_tree():
		return
	_push_globals()
	_push_light()
	_push_sky()


## The hull shaders, via globals.
func _push_globals() -> void:
	RenderingServer.global_shader_parameter_set(
		"sun_direction", sun_direction.normalized()
	)
	RenderingServer.global_shader_parameter_set("sun_colour", sun_colour)
	RenderingServer.global_shader_parameter_set("fill_colour", fill_colour)


## The DirectionalLight3D.
##
## A DirectionalLight3D casts along its own -Z, so it has to be turned to face
## AWAY from the star: look_at() aims -Z at its target, and the target here is
## the point the light travels toward.
func _push_light() -> void:
	if light == null:
		return
	var direction: Vector3 = sun_direction.normalized()
	if direction.is_zero_approx():
		return
	# An up-hint parallel to the look direction makes look_at fail, so swap it
	# when the star is near vertical.
	var up: Vector3 = Vector3.UP
	if absf(direction.dot(Vector3.UP)) > 0.99:
		up = Vector3.FORWARD
	light.look_at_from_position(global_position, global_position - direction, up)
	light.light_color = sun_colour
	light.light_energy = sun_energy


## The sky shader.
func _push_sky() -> void:
	if environment == null or environment.environment == null:
		return
	var sky: Sky = environment.environment.sky
	if sky == null:
		return
	var material: ShaderMaterial = sky.sky_material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("sun_direction", sun_direction.normalized())
	material.set_shader_parameter("sun_colour", sun_colour)
	material.set_shader_parameter("planet_direction", planet_direction.normalized())
	material.set_shader_parameter("planet_colour", planet_colour)
	material.set_shader_parameter("planet_band_colour", planet_band_colour)
