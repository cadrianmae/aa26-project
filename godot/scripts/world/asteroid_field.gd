## Scatters asteroids across the belt.
##
## Placed in code rather than by hand in the scene, for three reasons. Hand-
## placing forty rocks is forty transforms to maintain. A seeded scatter gives
## a different belt by changing one number, so the map can be re-rolled until
## one looks right. And Phase 3's Barnacles attach to asteroids, so whatever
## places the rocks has to be able to answer where they are -- which a pile of
## scene nodes cannot do without a search.
##
## The scatter is SEEDED, not random: the same seed always produces the same
## belt. A map that reshuffled every run would make a bug indistinguishable
## from an unlucky layout, and would make the demo video unrepeatable.
class_name AsteroidField
extends Node3D

## The exported asteroid variants. Four different rocks is enough that no two
## neighbours are obviously the same at a glance, without modelling forty.
@export var variants: Array[PackedScene] = []

## How many asteroids to place.
@export var count: int = 40

## Radius of the belt, in world units.
@export var field_radius: float = 900.0

## Nothing is placed within this distance of the origin, keeping the wreck at
## the centre clear rather than growing rocks through its hull.
@export var keep_out_radius: float = 320.0

## Vertical spread. Small, because the game is played on the XZ plane and a
## rock far above or below it is a rock the player never interacts with -- but
## not zero, or the belt reads as a flat sheet.
@export var vertical_spread: float = 18.0

## Smallest and largest asteroid, as a multiplier on the modelled size. The
## models are about 2.3 units across, so at 1 unit to 4 metres these are
## roughly 30 to 180 metres.
@export var min_scale: float = 3.5
@export var max_scale: float = 20.0

## Change this to re-roll the entire belt.
@export var seed_value: int = 20260830

## Neutral grey-brown: asteroids belong to no hive, and the palette keeps them
## outside the green/gold faction range so they can never be misread as units.
@export var tint: Color = Color(0.42, 0.39, 0.34)

## Every asteroid placed, in placement order. Phase 3's Barnacles read this to
## decide which rocks they grow on.
var asteroids: Array[Node3D] = []


func _ready() -> void:
	if variants.is_empty():
		push_warning("%s has no asteroid variants assigned." % name)
		return
	_scatter()


func _scatter() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in count:
		var variant: PackedScene = variants[rng.randi() % variants.size()]
		var rock: Node3D = variant.instantiate() as Node3D
		if rock == null:
			continue

		rock.position = _scatter_position(rng)
		# A random orientation on all three axes, because a rock has no
		# correct way up and identical orientations would betray the four
		# repeated meshes immediately.
		rock.rotation = Vector3(
			rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU)
		)
		rock.scale = Vector3.ONE * rng.randf_range(min_scale, max_scale)

		_tint(rock)
		add_child(rock)
		asteroids.append(rock)


## A position in the belt annulus: inside the field, outside the keep-out.
##
## Sampled on sqrt of the radius rather than linearly. Uniform sampling of the
## radius clusters points toward the centre, because a ring at radius r has
## circumference proportional to r -- so the outer belt would look sparse and
## the inner belt crowded.
func _scatter_position(rng: RandomNumberGenerator) -> Vector3:
	var angle: float = rng.randf_range(0.0, TAU)
	var t: float = rng.randf()
	var radius: float = sqrt(
		lerpf(keep_out_radius * keep_out_radius, field_radius * field_radius, t)
	)
	return Vector3(
		cos(angle) * radius,
		rng.randf_range(-vertical_spread, vertical_spread),
		sin(angle) * radius
	)


## Put the flat hull shader and the neutral tint on one placed rock.
func _tint(rock: Node3D) -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/flat_hull.gdshader")
	material.set_shader_parameter("tint", tint)
	_apply(rock, material)


func _apply(node: Node, material: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_apply(child, material)
