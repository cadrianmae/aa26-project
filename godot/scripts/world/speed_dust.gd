## Motion dust that streams past the ship, opposite its direction of travel.
##
## Two [GPUParticles3D] children give this its own parallax: a near layer,
## close to the hull and moving fast relative to the camera, and a far layer,
## further out and moving slower, matching how foreground and background
## debris would appear to separate at different distances in a real flythrough.
## Both are driven from the same per-frame read of the ship's velocity, so the
## effect scales smoothly from nothing at rest up to a brisk streak at
## [member Ship.max_speed] without ever overwhelming the wireframe geometry
## that carries the actual gameplay information.
class_name SpeedDust
extends Node3D

## The ship whose velocity drives emission rate and particle speed.
@export var ship: Ship

## Speed, as a fraction of the ship's max_speed, below which emission is
## treated as zero. Keeps the dust from twitching on at the smallest crawl.
@export var idle_threshold: float = 0.02

## How many world units per second the near layer's particles trail past the
## ship at full speed, on top of the ship's own speed.
@export var near_speed_multiplier: float = 2.2

## As above, for the far layer. Lower than the near multiplier so the far
## layer reads as further away.
@export var far_speed_multiplier: float = 1.2

@onready var _near: GPUParticles3D = $NearDust
@onready var _far: GPUParticles3D = $FarDust


func _ready() -> void:
	_configure_layer(_near, 0.35, 20.0, near_speed_multiplier, 0.9)
	_configure_layer(_far, 0.9, 40.0, far_speed_multiplier, 0.5)


func _process(_delta: float) -> void:
	if ship == null:
		return
	var speed: float = ship.velocity.length()
	var speed_ratio: float = clampf(speed / maxf(ship.max_speed, 0.001), 0.0, 1.0)
	var emitting: bool = speed_ratio > idle_threshold

	# Particles stream opposite the ship's travel; fall back to the ship's
	# facing when it is stationary so the layers still have a direction ready
	# for the moment it starts moving.
	var travel_direction: Vector3 = ship.velocity.normalized()
	if travel_direction == Vector3.ZERO:
		travel_direction = -ship.global_transform.basis.z

	_update_layer(_near, speed_ratio, emitting, speed, near_speed_multiplier, travel_direction)
	_update_layer(_far, speed_ratio, emitting, speed, far_speed_multiplier, travel_direction)


## One-time setup of a dust layer's mesh, material, and emission shape.
## [param emission_radius] sets how far around the ship particles spawn;
## [param amount] is the pool size the layer scales down from via
## amount_ratio; [param speed_multiplier] seeds a sane starting velocity;
## [param brightness] separates the near layer from the far one visually.
func _configure_layer(
	layer: GPUParticles3D,
	emission_radius: float,
	amount: float,
	speed_multiplier: float,
	brightness: float
) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 4
	mesh.rings = 2

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.9, 1.0, brightness)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material

	layer.draw_pass_1 = mesh
	layer.amount = int(amount)
	layer.lifetime = 1.2
	layer.local_coords = false
	layer.emitting = false

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = emission_radius
	process_material.direction = Vector3(0.0, 0.0, -1.0)
	process_material.spread = 8.0
	process_material.gravity = Vector3.ZERO
	process_material.initial_velocity_min = speed_multiplier
	process_material.initial_velocity_max = speed_multiplier * 1.5
	process_material.damping_min = 0.0
	process_material.damping_max = 0.0
	layer.process_material = process_material


## Applies this frame's speed and direction to an already-configured layer.
func _update_layer(
	layer: GPUParticles3D,
	speed_ratio: float,
	emitting: bool,
	speed: float,
	speed_multiplier: float,
	travel_direction: Vector3
) -> void:
	layer.global_position = ship.global_position
	layer.emitting = emitting
	layer.amount_ratio = speed_ratio

	var process_material: ParticleProcessMaterial = layer.process_material
	if process_material == null:
		return
	process_material.direction = -travel_direction
	var trail_speed: float = speed * speed_multiplier
	process_material.initial_velocity_min = trail_speed
	process_material.initial_velocity_max = trail_speed * 1.5
