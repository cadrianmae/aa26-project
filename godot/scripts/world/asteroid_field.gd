## Scatters asteroids across the belt.
class_name AsteroidField
extends Node3D

## The asteroid scenes to choose between.
@export var variants: Array[PackedScene] = []

## How many asteroids to place.
@export var count: int = 40

## Radius of the belt, in world units.
@export var field_radius: float = 900.0

## Nothing is placed within this distance of the origin, in world units.
@export var keep_out_radius: float = 320.0

## Half-extent of the vertical scatter, in world units.
@export var vertical_spread: float = 18.0

## Smallest and largest asteroid, as a multiplier on the modelled size.
@export var min_scale: float = 3.5
@export var max_scale: float = 20.0

## Change this to re-roll the entire belt.
@export var seed_value: int = 20260830

## Colour multiplied into every placed rock.
@export var tint: Color = Color(0.42, 0.39, 0.34)

@export_group("Barnacles")

## The Barnacle to grow on chosen asteroids. Left unset, the belt is inert.
@export var barnacle_scene: PackedScene

## How many asteroids carry a Barnacle.
@export var barnacle_count: int = 9

## How far past its rock's collider a Barnacle is placed, in world units.
@export var barnacle_surface_margin: float = 3.0

## Alloys placed in each Barnacle.
@export var barnacle_reserve: float = 120.0

## Every asteroid placed, in placement order.
var asteroids: Array[Node3D] = []

## Every Barnacle grown.
var barnacles: Array[Node3D] = []


func _ready() -> void:
	if variants.is_empty():
		push_warning("%s has no asteroid variants assigned." % name)
		return
	_scatter()
	_grow_barnacles()


func _scatter() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in count:
		var variant: PackedScene = variants[rng.randi() % variants.size()]
		var rock: Node3D = variant.instantiate() as Node3D
		if rock == null:
			continue

		rock.position = _scatter_position(rng)
		rock.rotation = Vector3(
			rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU),
			rng.randf_range(0.0, TAU)
		)
		rock.scale = Vector3.ONE * rng.randf_range(min_scale, max_scale)

		_tint(rock)
		_add_collision(rock)
		add_child(rock)
		asteroids.append(rock)


## Grow Barnacles on a spread of the placed asteroids.
func _grow_barnacles() -> void:
	if barnacle_scene == null or asteroids.is_empty():
		return

	var wanted: int = mini(barnacle_count, asteroids.size())
	if wanted <= 0:
		return
	var stride: float = float(asteroids.size()) / float(wanted)

	for i in wanted:
		var rock: Node3D = asteroids[int(i * stride)]
		var barnacle: Node3D = barnacle_scene.instantiate() as Node3D
		if barnacle == null:
			continue
		# top_level so the Barnacle does not inherit the rock's scale.
		barnacle.top_level = true
		if "reserve" in barnacle:
			barnacle.reserve = barnacle_reserve

		# add_child BEFORE positioning: global_position is meaningless on a node
		# outside the tree and would leave the Barnacle at the origin.
		rock.add_child(barnacle)
		# Placed at y = 0 and outside the rock's collider: steering forces have
		# their Y zeroed, and a Barnacle inside solid geometry is unreachable.
		var rock_radius: float = 1.05 * rock.scale.x
		# Golden angle, so successive Barnacles face different directions.
		var facing: float = float(i) * 2.39996
		var outward := Vector3(cos(facing), 0.0, sin(facing))
		barnacle.global_position = Vector3(
			rock.global_position.x, 0.0, rock.global_position.z
		) + outward * (rock_radius + barnacle_surface_margin)
		barnacles.append(barnacle)


## Give a placed rock a solid body, so ships and drones cannot fly through it.
##
## Layer 1 is the world layer, the only layer drones and ships mask against.
func _add_collision(rock: Node3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0

	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	# The model is roughly 1.05 units in radius before the instance is scaled;
	# the shape is a child so it inherits that scale.
	sphere.radius = 1.05
	shape.shape = sphere

	body.add_child(shape)
	rock.add_child(body)


## A position in the belt annulus: inside the field, outside the keep-out.
##
## Sampled on sqrt of the radius so points spread evenly by area.
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
