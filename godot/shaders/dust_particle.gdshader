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

void vertex() {
	float along = dot(VERTEX.xy, stretch_direction);
	VERTEX.xy += stretch_direction * along * stretch_amount;

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// Small soft dot, not a hard-edged square -- kept faint (see the 0.5
	// multiplier) so the dust reads as a subtle motion cue behind the cyan
	// wireframe ships and gizmo arrows, never competing with them.
	vec2 centred = UV - 0.5;
	float dist = length(centred) * 2.0;
	float dot_shape = 1.0 - smoothstep(0.5, 1.0, dist);
	vec3 colour = vec3(0.6, 0.75, 0.85);
	ALBEDO = colour * dot_shape * 0.5;
	ALPHA = dot_shape;
}
