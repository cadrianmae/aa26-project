// Procedural three-layer parallax starfield, plus a camera-speed streak layer
// for motion dust (see the streak uniforms and star_layer's stretch below).
//
// Drawn on a large quad parented to the camera (see starfield.gd), positioned
// just inside the camera's far plane so it always fills the view and moves
// and tilts with the camera like a backdrop. depth_draw_never means the quad
// never writes to the depth buffer, so it can never occlude anything by
// writing; depth_test_disabled was removed deliberately -- with the quad
// pushed out near the far plane, ordinary depth testing against the depth
// buffer is exactly what puts every piece of gameplay geometry (and the
// DebugDraw3D gizmos, which also participate in normal depth testing) in
// front of it. That is more reliable than depth_test_disabled plus a low
// render_priority: with the depth test off the quad paints over whatever was
// already drawn regardless of order, and render_priority only meaningfully
// orders transparent materials against each other, so it does not guarantee
// the quad is drawn before opaque gizmo/gameplay geometry. This combination
// was chosen over a Godot Sky/PanoramaSkyMaterial because a sky samples by
// view direction only, which makes per-layer parallax against camera
// world-space movement awkward; a plain quad lets the script hand the shader
// the camera's world position directly and the shader does cheap 2D hashing
// in local quad space, no texture asset required.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

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
// Kept low and the point sizes below correspondingly larger so stars read as
// distinct points of light rather than dense, fine-grained noise.
uniform float far_density : hint_range(1.0, 200.0) = 12.0;
uniform float mid_density : hint_range(1.0, 200.0) = 8.0;
uniform float near_density : hint_range(1.0, 200.0) = 5.0;

// Per-layer brightness ceiling. The nearest layer is deliberately brightest
// so the depth ordering reads clearly.
uniform float far_brightness : hint_range(0.0, 1.0) = 0.35;
uniform float mid_brightness : hint_range(0.0, 1.0) = 0.6;
uniform float near_brightness : hint_range(0.0, 1.0) = 0.9;

// Star point size per layer, in the layer's own hashed cell-space. The
// nearest layer is deliberately largest so the depth ordering reads clearly.
// Sized up to match the lower densities above -- fewer, larger stars.
uniform float far_size : hint_range(0.0, 0.5) = 0.1;
uniform float mid_size : hint_range(0.0, 0.5) = 0.16;
uniform float near_size : hint_range(0.0, 0.5) = 0.24;

// Motion-dust streak layer. Screen-locked (not offset by camera_world_position
// like the parallax layers above) so it reads as debris rushing past close to
// the camera rather than distant stars. camera_velocity_local and
// camera_speed are fed in from starfield.gd each frame: the camera's
// frame-to-frame world displacement projected onto the camera's own local
// right/up axes, so a streak's on-screen direction always matches the
// camera's actual on-screen motion regardless of which way it is facing.
uniform vec2 camera_velocity_local = vec2(0.0);
uniform float camera_speed = 0.0;

// Tunables so the owner can adjust the streak effect without touching code.
uniform float streak_intensity : hint_range(0.0, 3.0) = 1.0;
uniform float max_streak_length : hint_range(0.0, 2.0) = 0.35;
uniform float streak_full_speed : hint_range(0.1, 100.0) = 20.0;

// Dust point cells per screen and their size/brightness, analogous to the
// star layer uniforms above but for the streak layer.
uniform float dust_density : hint_range(1.0, 400.0) = 90.0;
uniform float dust_size : hint_range(0.0, 0.2) = 0.03;
uniform float dust_brightness : hint_range(0.0, 1.0) = 0.85;

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
	// A narrow smoothstep edge plus a power curve gives a hard, small, round
	// core instead of the wide soft falloff that reads as fuzzy grain when
	// stars are packed densely -- exactly the "noise" look this is avoiding.
	float edge = point_size * size_variation * 0.6;
	float star = 1.0 - smoothstep(0.0, edge, dist);
	star = pow(star, 1.5);

	float twinkle = 0.6 + 0.4 * star_hash(cell + 17.0);
	return star * brightness * twinkle;
}

// Renders one streak of the motion-dust layer at the given screen-locked UV.
// Identical cell/hash setup to star_layer, but the point is elongated into a
// capsule along [param streak_dir] by [param streak_length]: distance is
// measured to the nearest point of a line segment of that length through the
// cell centre, rather than to the centre itself, so the streak has a round
// leading edge and a length that grows with camera speed.
float star_streak(
	vec2 uv, float density, float point_size, float brightness,
	vec2 streak_dir, float streak_length
) {
	vec2 cell_uv = uv * density;
	vec2 cell = floor(cell_uv);
	vec2 local = fract(cell_uv) - 0.5;

	float star_present = star_hash(cell);
	if (star_present < 0.55) {
		return 0.0;
	}

	vec2 jitter = vec2(star_hash(cell + 4.7), star_hash(cell + 9.3)) - 0.5;
	vec2 offset = local - jitter * 0.6;
	float size_variation = 0.5 + star_hash(cell + 1.3);

	// Rotate the offset into (along, perpendicular) axes relative to the
	// streak direction, then flatten the along-axis distance to zero across
	// the streak's length -- a cheap capsule signed distance.
	vec2 perp_dir = vec2(-streak_dir.y, streak_dir.x);
	float along = dot(offset, streak_dir);
	float perp = dot(offset, perp_dir);
	float half_length = streak_length * 0.5;
	float along_dist = max(abs(along) - half_length, 0.0);
	float dist = length(vec2(along_dist, perp));

	float edge = point_size * size_variation * 0.6;
	float star = 1.0 - smoothstep(0.0, edge, dist);
	star = pow(star, 1.5);

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

	// Motion dust: only present while the camera is actually moving, and its
	// streak length grows from nothing up to max_streak_length as camera_speed
	// approaches streak_full_speed. Gating on speed_fraction (rather than just
	// letting streak_length shrink to a dot) is what satisfies "only appears
	// when the camera is moving" -- a zero-length streak would otherwise still
	// render as a static dust field.
	float speed_fraction = clamp(camera_speed / max(streak_full_speed, 0.001), 0.0, 1.0);
	float streak_length = speed_fraction * max_streak_length * streak_intensity;
	float dust_star = 0.0;
	if (speed_fraction > 0.01) {
		vec2 streak_dir = vec2(1.0, 0.0);
		float dir_length = length(camera_velocity_local);
		if (dir_length > 0.0001) {
			streak_dir = camera_velocity_local / dir_length;
		}
		// local_uv (not parallax-shifted) keeps the dust locked to the screen
		// so it fills the whole view uniformly rather than clustering near
		// where the ship happens to be, satisfying "everywhere on screen".
		dust_star = star_streak(
			local_uv, dust_density, dust_size, dust_brightness * speed_fraction,
			streak_dir, streak_length
		);
	}

	// Base near-black background matching the world environment, so the quad
	// blends seamlessly with WorldEnvironment's background_color.
	vec3 background = vec3(0.005, 0.005, 0.012);

	// Stars read white to faint blue -- never as bright or saturated as the
	// gameplay cyan wireframes, which must stay the visually dominant colour.
	vec3 far_colour = vec3(0.75, 0.8, 0.95);
	vec3 mid_colour = vec3(0.85, 0.9, 1.0);
	vec3 near_colour = vec3(1.0, 1.0, 1.0);
	vec3 dust_colour = vec3(0.9, 0.95, 1.0);

	vec3 colour = background;
	colour += far_colour * far_star;
	colour += mid_colour * mid_star;
	colour += near_colour * near_star;
	colour += dust_colour * dust_star;

	ALBEDO = colour;
	ALPHA = 1.0;
}
