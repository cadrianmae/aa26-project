## A one-shot detonation: a particle burst, a report, a flash, and area damage.
##
## Builds its own children in code and frees itself after [member duration].
## The blast is dealt once, in [method _ready].
class_name Explosion
extends Node3D

## Damage dealt to every unit within [member blast_radius], regardless of
## allegiance.
@export var blast_damage: float = 14.0

@export var blast_radius: float = 9.0

## How long the effect lives before removing itself.
@export var duration: float = 1.4

@export var core_colour: Color = Color(1.0, 0.45, 0.12)
@export var edge_colour: Color = Color(0.42, 1.0, 0.22)

## How many sparks the burst throws.
@export var spark_count: int = 24

var _age: float = 0.0


## Spawn an explosion at [param at], parented to the scene root so it outlives
## the node that died.
static func burst(tree: SceneTree, at: Vector3, scale_factor: float = 1.0) -> Explosion:
	var boom := Explosion.new()
	boom.blast_damage *= scale_factor
	boom.blast_radius *= scale_factor
	boom.spark_count = int(boom.spark_count * scale_factor)
	# Set before entering the tree: add_child runs _ready, and _deal_blast
	# measures from the position there.
	boom.position = at
	tree.get_root().add_child(boom)
	return boom


func _ready() -> void:
	_build_particles()
	_build_light()
	_build_sound()
	# Deferred, not called here: _ready runs inside add_child, so a blast dealt
	# now would kill neighbours on this same call stack, and each of their
	# explosions would deal its blast inside this one. Deferring unwinds the
	# stack between links, so a chain spreads over frames instead of recursing.
	_deal_blast.call_deferred()


func _process(delta: float) -> void:
	_age += delta
	# The flash fades over the first third of the effect's life.
	var light: OmniLight3D = get_node_or_null("Flash") as OmniLight3D
	if light != null:
		light.light_energy = maxf(0.0, 8.0 * (1.0 - _age / (duration * 0.35)))
	if _age >= duration:
		queue_free()


## The visible burst: sparks thrown outward on the movement plane.
func _build_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "Sparks"
	particles.amount = maxi(spark_count, 1)
	particles.lifetime = duration * 0.7
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	var process := ParticleProcessMaterial.new()
	process.particle_flag_disable_z = false
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.6
	process.direction = Vector3(0.0, 0.0, 0.0)
	process.spread = 180.0
	process.initial_velocity_min = blast_radius * 2.0
	process.initial_velocity_max = blast_radius * 5.0
	process.gravity = Vector3.ZERO
	process.damping_min = 6.0
	process.damping_max = 14.0
	process.scale_min = 0.25
	process.scale_max = 0.7
	var ramp := Gradient.new()
	ramp.set_color(0, core_colour)
	ramp.set_color(1, Color(edge_colour.r, edge_colour.g, edge_colour.b, 0.0))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = core_colour
	mesh.material = material
	particles.draw_pass_1 = mesh

	add_child(particles)


## Build the flash that lights nearby geometry.
func _build_light() -> void:
	var light := OmniLight3D.new()
	light.name = "Flash"
	light.light_color = core_colour
	light.light_energy = 8.0
	light.omni_range = blast_radius * 3.0
	add_child(light)


## Build and play the report.
func _build_sound() -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = "Report"
	player.stream = _render_report()
	player.unit_size = blast_radius * 6.0
	player.max_distance = 400.0
	player.volume_db = -6.0
	add_child(player)
	player.play()


func _render_report() -> AudioStreamWAV:
	var rate: int = 22050
	var frames: int = int(rate * 0.5)
	var data := PackedByteArray()
	data.resize(frames * 2)

	# One-pole low-pass on white noise, cutoff falling with the decay.
	var previous: float = 0.0
	for i in frames:
		var t: float = float(i) / float(frames)
		var envelope: float = pow(1.0 - t, 3.0)
		var cutoff: float = lerpf(0.9, 0.06, t)
		previous = lerpf(previous, randf_range(-1.0, 1.0), cutoff)
		var sample: float = clampf(previous * envelope * 0.9, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = rate
	wav.data = data
	return wav


## Hurt everything inside the blast, once.
func _deal_blast() -> void:
	if blast_damage <= 0.0:
		return
	for side in [0, 1]:
		for node in get_tree().get_nodes_in_group(Swarm.GROUP_PREFIX + str(side)):
			var swarm: Swarm = node as Swarm
			if swarm == null:
				continue
			# Copied before iterating: take_damage can free a drone, and
			# mutating the register mid-loop skips whatever fills the gap.
			for drone in swarm.units.duplicate():
				if drone == null or not is_instance_valid(drone):
					continue
				if global_position.distance_to(drone.global_position) <= blast_radius:
					drone.take_damage(blast_damage)

	for side in [0, 1]:
		for node in get_tree().get_nodes_in_group(Ship.GROUP_PREFIX + str(side)):
			var hull: Node3D = node as Node3D
			if hull == null or not is_instance_valid(hull):
				continue
			if not hull.has_method("take_damage"):
				continue
			if global_position.distance_to(hull.global_position) <= blast_radius:
				hull.take_damage(blast_damage)
