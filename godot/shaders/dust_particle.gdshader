// Draw-pass shader for the motion-dust particle quad (see dust_field.gd).
//
// Two jobs, both driven by uniforms dust_field.gd recomputes every frame from
// camera velocity:
//
// 1. Billboard the quad to face the camera. GPUParticles3D bakes each
// particle's own (arbitrary, process-material-driven) rotation into its
// instance transform, so without correction the quads would tumble edge-on
// rather than reading as dust motes. Godot has no render_mode keyword for
// billboarding in a custom spatial shader -- that is only available via
// BaseMaterial3D's billboard flag, which is not exposed on a plain
// ShaderMaterial -- so this uses the standard manual technique: replace
// MODELVIEW_MATRIX's rotation columns with the camera's own inverse-view
// basis, keeping this instance's translation (MODEL_MATRIX's fourth column)
// so the quad still sits at its own particle's world position.
//
// 2. Stretch the quad along stretch_direction by stretch_amount. This
// replaces Godot's built-in particle trails deliberately: the engine tracker
// has open bugs where trails anchor to the scene root instead of following
// local_coords = false particles, and where particles vanish outright when
// the draw mesh is swapped to a trail mesh. A per-vertex stretch along a
// screen-space direction sidesteps both -- it is applied to VERTEX (in local
// quad space, -0.5..0.5 per axis) before the billboard matrix above, so it
// elongates the quad symmetrically about its centre along the camera's own
// screen right/up axes.
//
// 3. Fade alpha two ways, both needed because particles spawn and recycle at
// the boundary of dust_field.gd's emission box, which sits inside the visible
// frustum:
//
//    - Lifetime fade: INSTANCE_CUSTOM.y carries "phase during lifetime (0 to
//      1)" for the default particle process material (confirmed against the
//      Godot 4 spatial shader reference, since this is not something to
//      assume). Fading in/out over the first/last fraction of that phase
//      means a particle's first and last rendered frame are never at full
//      opacity, whatever it is doing spatially.
//    - Distance fade: lifetime fade alone still leaves a particle that spawns
//      at the box's far edge, in clear view, momentarily visible at meaningful
//      opacity. Fading out by the particle's distance from the camera as it
//      approaches the box's horizontal reach means it is already invisible by
//      the time it could spawn or recycle there. This uses horizontal (XZ)
//      distance rather than full 3D distance because the emission box is far
//      wider on the horizontal plane (see dust_field.gd's emission_extents)
//      than it is tall -- a purely 3D distance metric would fade out
//      legitimate nearby-but-elevated dust that was never near the boundary
//      that actually causes visible pop-in.
//
// A small additional near-camera fade handles the opposite case: a particle
// that drifts (in the camera's frame) very close to the lens stretches into a
// huge, jarring streak under part 2 above. Fading it out before it gets that
// close removes the streak instead of merely dimming it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled,
	fog_disabled;

// Camera-space (screen right/up) direction of camera travel, normalised, or
// the zero vector when the camera is effectively still. Set from
// dust_field.gd each frame.
uniform vec2 stretch_direction = vec2(0.0, 0.0);

// How far to stretch the quad along stretch_direction, as a multiple of the
// quad's own half-size. Zero at rest; scales up with camera speed. Set from
// dust_field.gd each frame.
uniform float stretch_amount : hint_range(0.0, 8.0) = 0.0;

// Fraction of a particle's lifetime (0..1) spent fading in from nothing at
// the start, and fading out to nothing at the end.
uniform float lifetime_fade_in : hint_range(0.0, 0.5) = 0.12;
uniform float lifetime_fade_out : hint_range(0.0, 0.5) = 0.12;

// The camera's world position. Set from dust_field.gd each frame.
uniform vec3 camera_position = vec3(0.0, 0.0, 0.0);

// Horizontal (XZ) distance from the camera at which the far fade begins, and
// the distance at which it reaches zero. _end must stay comfortably inside
// the emission box's horizontal reach (see dust_field.gd's emission_extents)
// so a particle is fully invisible before it can spawn or recycle at the
// box's edge.
uniform float distance_fade_start : hint_range(0.0, 60.0) = 20.0;
uniform float distance_fade_end : hint_range(0.0, 60.0) = 28.0;

// Full 3D distance from the camera within which a particle fades out, so it
// never streaks hugely across the screen as the camera passes through it.
// _end is the distance at which it is fully invisible; _start is where the
// fade begins.
uniform float near_fade_start : hint_range(0.0, 10.0) = 4.0;
uniform float near_fade_end : hint_range(0.0, 10.0) = 1.0;

varying float lifetime_alpha;
varying float distance_alpha;

void vertex() {
	float along = dot(VERTEX.xy, stretch_direction);
	VERTEX.xy += stretch_direction * along * stretch_amount;

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);

	float phase = INSTANCE_CUSTOM.y;
	float fade_in_edge = max(lifetime_fade_in, 0.0001);
	float fade_out_edge = max(lifetime_fade_out, 0.0001);
	float fading_in = smoothstep(0.0, fade_in_edge, phase);
	float fading_out = 1.0 - smoothstep(1.0 - fade_out_edge, 1.0, phase);
	lifetime_alpha = fading_in * fading_out;

	vec3 particle_position = MODEL_MATRIX[3].xyz;
	float horizontal_distance = length(particle_position.xz - camera_position.xz);
	float far_alpha = 1.0 - smoothstep(distance_fade_start, distance_fade_end, horizontal_distance);

	float camera_distance = length(particle_position - camera_position);
	float near_alpha = smoothstep(near_fade_end, near_fade_start, camera_distance);

	distance_alpha = far_alpha * near_alpha;
}

void fragment() {
	// Small soft dot, not a hard-edged square -- kept faint (see the 0.5
	// multiplier) so the dust reads as a subtle motion cue behind the cyan
	// wireframe ships and gizmo arrows, never competing with them.
	vec2 centred = UV - 0.5;
	float dist = length(centred) * 2.0;
	float dot_shape = 1.0 - smoothstep(0.5, 1.0, dist);
	vec3 colour = vec3(0.6, 0.75, 0.85);
	float alpha = dot_shape * lifetime_alpha * distance_alpha;
	ALBEDO = colour * alpha * 0.5;
	ALPHA = alpha;
}
