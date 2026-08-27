## Real world-space motion dust: GPUParticles3D the camera genuinely flies
## through.
##
## Screen-locked shader dust (the previous approach, removed from
## starfield.gdshader) could only elongate fixed on-screen dashes; it never
## had a world position for the camera to pass, so it could never produce
## genuine fly-by motion. This script instead builds a real GPUParticles3D
## system with [member GPUParticles3D.local_coords] = false, which is the
## crucial setting: with world coordinates, spawned particles stay put in the
## world once emitted, and only the emitter itself (this node, recentred on
## the camera every frame) chases the camera around. The camera then
## genuinely flies past particles it spawned moments ago, which gives real
## parallax and fly-by motion for free -- no per-particle scripting needed.
##
## Streak length comes from a small custom shader on the particle quad's
## material (res://shaders/dust_particle.gdshader) rather than Godot's
## built-in particle trails: the engine tracker has open bugs where trails
## anchor to the scene root instead of following local_coords = false
## particles, and where particles vanish outright when the draw mesh is
## swapped to a trail mesh. Instead this script recomputes a camera-velocity
## uniform every frame and the shader stretches each quad along it -- see
## _follow_camera below.
class_name DustField
extends Node3D

## The camera to follow, and whose frame-to-frame velocity drives emission
## and streak length.
@export var camera: Camera3D

## Half-extents of the box particles spawn within, in world units, recentred
## on the camera every frame. Large enough that dust is already present
## ahead of travel rather than only appearing as the camera arrives there.
@export var emission_extents: Vector3 = Vector3(30.0, 16.0, 30.0)

## Particles alive at once. Kept low, and the particles themselves kept small
## (see _PARTICLE_SIZE) -- this is a strategy game where the cyan wireframe
## ships and gizmo arrows must stay clearly readable, so the dust is meant as
## a subtle motion cue, not a spectacle.
@export var particle_amount: int = 140

## Seconds a particle lives before respawning elsewhere in the box.
@export var particle_lifetime: float = 3.0

## Camera speed, in world units/second, below which nothing emits at all --
## this is what makes emission "fall to nothing when the camera is still"
## rather than just fading arbitrarily close to zero.
@export var emission_speed_floor: float = 0.5

## Camera speed at which emission ratio and streak length both reach their
## maximum. Chosen against the ship's own scale (max_speed is ~18 units/s,
## see ship.gd) so full-speed flight reads as a clearly moving field rather
## than sitting at a fraction of the effect.
@export var speed_saturation: float = 20.0

## Maximum streak stretch, as a multiple of the particle quad's own
## half-size. Exposed so the owner can tune how pronounced the streaking
## reads without touching the shader.
@export var max_stretch: float = 6.0

## Base (unstretched) size of each dust particle quad, in world units. Small
## deliberately -- see particle_amount's comment.
const _PARTICLE_SIZE: float = 0.12

var _particles: GPUParticles3D
var _material: ShaderMaterial
var _has_previous_position: bool = false
var _previous_camera_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.local_coords = false
	_particles.amount = particle_amount
	_particles.lifetime = particle_lifetime
	_particles.preprocess = particle_lifetime
	_particles.emitting = false
	_particles.amount_ratio = 0.0

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = emission_extents
	process_material.spread = 180.0
	process_material.initial_velocity_min = 0.0
	process_material.initial_velocity_max = 0.0
	process_material.gravity = Vector3.ZERO
	process_material.scale_min = 0.6
	process_material.scale_max = 1.4
	_particles.process_material = process_material

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(_PARTICLE_SIZE, _PARTICLE_SIZE)
	_particles.draw_pass_1 = quad

	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/dust_particle.gdshader")
	quad.material = _material

	# local_coords = false means particles are simulated in world space, so
	# the culling AABB (in the node's local space) needs enough margin beyond
	# the emission box for particles that have drifted or are about to spawn
	# at its far edge, or they get culled as the camera nears the box edge.
	var aabb_margin: Vector3 = emission_extents * 0.5
	_particles.visibility_aabb = AABB(
		-emission_extents - aabb_margin, (emission_extents + aabb_margin) * 2.0
	)

	add_child(_particles)

	_follow_camera(0.0)


func _process(delta: float) -> void:
	_follow_camera(delta)


## Recentres the emitter box on the camera and updates emission and streak
## uniforms from the camera's frame-to-frame velocity. FollowCamera lerps
## toward its target and has no velocity member of its own, so velocity is
## computed here by differencing the camera's world position between frames,
## guarding the first frame and any zero-delta frame.
func _follow_camera(delta: float) -> void:
	if camera == null:
		return

	global_position = camera.global_position

	var camera_velocity: Vector3 = Vector3.ZERO
	if _has_previous_position and delta > 0.0:
		camera_velocity = (camera.global_position - _previous_camera_position) / delta
	_previous_camera_position = camera.global_position
	_has_previous_position = true

	var speed: float = camera_velocity.length()
	var speed_fraction: float = clamp(speed / max(speed_saturation, 0.001), 0.0, 1.0)

	if _particles != null:
		_particles.emitting = speed > emission_speed_floor
		_particles.amount_ratio = speed_fraction

	if _material == null:
		return
	# Project world-space velocity into the camera's own local right/up axes
	# so the streak's on-screen direction always matches how the view
	# actually moves, regardless of which way the camera faces.
	# basis.transposed() is the inverse of an orthonormal basis, so this
	# recovers local components from the world-space vector.
	var local_velocity: Vector3 = camera.global_transform.basis.transposed() * camera_velocity
	var velocity_screen: Vector2 = Vector2(local_velocity.x, local_velocity.y)
	var direction_screen: Vector2 = Vector2.ZERO
	if velocity_screen.length() > 0.0001:
		direction_screen = velocity_screen.normalized()
	_material.set_shader_parameter("stretch_direction", direction_screen)
	_material.set_shader_parameter("stretch_amount", speed_fraction * max_stretch)
