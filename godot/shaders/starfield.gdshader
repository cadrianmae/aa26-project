// Procedural three-layer parallax starfield.
//
// Drawn on a large quad parented to the camera (see starfield.gd), positioned
// a fixed distance in front of it so it always fills the view and moves and
// tilts with the camera like a backdrop. depth_draw_never plus
// depth_test_disabled below mean the quad never writes to the depth buffer
// and never tests against it, so it can never occlude or be occluded
// incorrectly relative to gameplay geometry; render_priority is set very low
// from the script so the renderer draws it first, before anything opaque.
// That combination was chosen over a Godot Sky/PanoramaSkyMaterial because a
// sky samples by view direction only, which makes per-layer parallax against
// camera world-space movement awkward; a plain quad lets the script hand the
// shader the camera's world position directly and the shader does cheap 2D
// hashing in local quad space, no texture asset required.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled;

// The camera's current world-space position, fed in from starfield.gd each
// frame. Each layer is offset by a different fraction of this, and that
// difference in scroll rate is what produces the parallax.
uniform vec3 camera_world_position = vec3(0.0);

// How strongly each layer scrolls against camera movement. Near 0 reads as
// almost fixed to the screen (very distant); higher values track the camera
// more closely (nearer).
uniform float far_parallax : hint_range(0.0, 1.0) = 0.02;
uniform float mid_parallax : hint_range(0.0, 1.0) = 0.08;
uniform float near_parallax : hint_range(0.0, 1.0) = 0.2;

// Star cells per layer, controlling apparent density. Higher is denser.
uniform float far_density : hint_range(1.0, 200.0) = 40.0;
uniform float mid_density : hint_range(1.0, 200.0) = 24.0;
uniform float near_density : hint_range(1.0, 200.0) = 14.0;

// Per-layer brightness ceiling. The nearest layer is deliberately brightest
// so the depth ordering reads clearly.
uniform float far_brightness : hint_range(0.0, 1.0) = 0.35;
uniform float mid_brightness : hint_range(0.0, 1.0) = 0.6;
uniform float near_brightness : hint_range(0.0, 1.0) = 0.9;

// Star point size per layer, in the layer's own hashed cell-space. The
// nearest layer is deliberately largest so the depth ordering reads clearly.
uniform float far_size : hint_range(0.0, 0.5) = 0.05;
uniform float mid_size : hint_range(0.0, 0.5) = 0.08;
uniform float near_size : hint_range(0.0, 0.5) = 0.12;

varying vec2 local_uv;

void vertex() {
	// The quad's own local XY, before the camera-relative transform. This is
	// the "screen space" the star layers are hashed in.
	local_uv = VERTEX.xy;
}

// Cheap deterministic hash, no texture lookups, so there is no asset to
// ship. Returns a pseudo-random value in [0, 1) for a 2D cell coordinate.
float star_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453123);
}

// Renders one parallax star layer at the given cell-space UV. Returns the
// star's brightness contribution at this fragment, 0 if no star is near.
float star_layer(vec2 uv, float density, float point_size, float brightness) {
	vec2 cell_uv = uv * density;
	vec2 cell = floor(cell_uv);
	vec2 local = fract(cell_uv) - 0.5;

	float star_present = star_hash(cell);
	if (star_present < 0.55) {
		// Most cells carry no star, keeping the field sparse rather than a
		// dense grid of points.
		return 0.0;
	}

	// Jitter the star off the cell centre so the grid does not read as a
	// grid, and vary its size and twinkle brightness per cell.
	vec2 jitter = vec2(star_hash(cell + 4.7), star_hash(cell + 9.3)) - 0.5;
	vec2 offset = local - jitter * 0.6;
	float size_variation = 0.5 + star_hash(cell + 1.3);
	float dist = length(offset);
	float star = 1.0 - smoothstep(0.0, point_size * size_variation, dist);

	float twinkle = 0.6 + 0.4 * star_hash(cell + 17.0);
	return star * brightness * twinkle;
}

void fragment() {
	// Each layer samples "star space" offset by a different fraction of the
	// camera's world position -- that difference in scroll rate is the
	// parallax. Distant layers barely shift; the near layer shifts a lot.
	vec2 far_uv = local_uv + camera_world_position.xz * far_parallax * 0.05;
	vec2 mid_uv = local_uv + camera_world_position.xz * mid_parallax * 0.05;
	vec2 near_uv = local_uv + camera_world_position.xz * near_parallax * 0.05;

	float far_star = star_layer(far_uv, far_density, far_size, far_brightness);
	float mid_star = star_layer(mid_uv, mid_density, mid_size, mid_brightness);
	float near_star = star_layer(near_uv, near_density, near_size, near_brightness);

	// Base near-black background matching the world environment, so the quad
	// blends seamlessly with WorldEnvironment's background_color.
	vec3 background = vec3(0.02, 0.02, 0.04);

	// Stars read white to faint blue -- never as bright or saturated as the
	// gameplay cyan wireframes, which must stay the visually dominant colour.
	vec3 far_colour = vec3(0.75, 0.8, 0.95);
	vec3 mid_colour = vec3(0.85, 0.9, 1.0);
	vec3 near_colour = vec3(1.0, 1.0, 1.0);

	vec3 colour = background;
	colour += far_colour * far_star;
	colour += mid_colour * mid_star;
	colour += near_colour * near_star;

	ALBEDO = colour;
	ALPHA = 1.0;
}
