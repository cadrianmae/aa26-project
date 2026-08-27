// Procedural three-layer parallax starfield.
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
// in screen space (SCREEN_UV), no texture asset required. Screen space is
// deliberate: the quad's own size is derived from the camera's fov and far
// plane and comes out thousands of units across, so hashing in quad-local
// units would put tens of thousands of star cells across the screen and
// every star would land sub-pixel, reading as fine static instead of stars.
// SCREEN_UV is always 0..1 regardless of the quad's world size, so "density"
// below means exactly what it says: cells across the screen.
//
// Star brightness within a layer follows a power-law distribution (see
// brightness_power below) rather than a flat per-layer value: real starfields
// are overwhelmingly faint, small, point-like stars with only a rare few
// bright enough to cover a handful of pixels. Raising the cell hash to a high
// power pushes most cells toward zero brightness while leaving a small tail
// near 1.0, and star size is driven by that same value so the rare bright
// stars are also the only ones large enough to read as a small disc; the
// common faint stars stay pinned near a hard, one-to-two pixel point. The
// falloff itself is a tight smoothstep with almost no soft edge, which is
// what keeps a faint star a crisp dot instead of the wide fuzzy bokeh blobs
// this replaces.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

// The camera's current world-space position, fed in from starfield.gd each
// frame. Each layer is offset by a different fraction of this, and that
// difference in scroll rate is what produces the parallax.
uniform vec3 camera_world_position = vec3(0.0);

// Colour of empty space. The quad is opaque and fills the screen, so this
// overrides both WorldEnvironment's background_color and the project's
// default_clear_color -- neither of those is ever visible behind it.
uniform vec3 background_colour : source_color = vec3(0.0, 0.0, 0.0);

// How strongly each layer scrolls against camera movement, applied directly
// to camera_world_position (in world units) to offset a 0..1 SCREEN_UV
// coordinate -- so these are small fractions, not the 0..1 "almost to
// entirely camera-locked" fractions they would be against a local-space UV.
// Tuned against the ship's own scale (max_speed is ~18 units/second, see
// ship.gd): flying for a few seconds covers on the order of tens to a couple
// of hundred world units, and at these factors that visibly scrolls the near
// layer by a large fraction of the screen while the far layer barely moves.
uniform float far_parallax : hint_range(0.0, 0.02) = 0.0002;
uniform float mid_parallax : hint_range(0.0, 0.02) = 0.0012;
uniform float near_parallax : hint_range(0.0, 0.02) = 0.004;

// Star cells per layer, in cells across the screen HEIGHT (SCREEN_UV's y
// axis runs 0..1; x is aspect-corrected so cells are square). Higher is
// denser. Tuned so the far layer is a faint dusting and the near layer reads
// as distinct, larger points of light -- see the point sizes below.
uniform float far_density : hint_range(1.0, 200.0) = 20.0;
uniform float mid_density : hint_range(1.0, 200.0) = 14.0;
uniform float near_density : hint_range(1.0, 200.0) = 8.0;

// Per-layer brightness ceiling, applied on top of the per-star power-law
// value below. The nearest layer is deliberately brightest so the depth
// ordering reads clearly.
uniform float far_brightness : hint_range(0.0, 1.0) = 0.35;
uniform float mid_brightness : hint_range(0.0, 1.0) = 0.6;
uniform float near_brightness : hint_range(0.0, 1.0) = 0.9;

// Maximum star point size per layer, as a fraction of that layer's own cell
// (so it scales with the density uniforms above rather than the screen). A
// star's actual size is this ceiling scaled down by its own power-law
// brightness (see star_layer), so only the rare bright cells reach it; most
// stars render far smaller. The nearest layer's ceiling is deliberately
// largest, matching its lower density, but even at maximum this is a handful
// of pixels, not the large soft discs the previous flat sizing produced.
uniform float far_size : hint_range(0.0, 0.1) = 0.02;
uniform float mid_size : hint_range(0.0, 0.1) = 0.03;
uniform float near_size : hint_range(0.0, 0.1) = 0.045;

// Exponent applied to each star's cell hash to derive its brightness
// (pow(hash, brightness_power)). Higher values make bright stars rarer: the
// fraction of stars with brightness above 0.5 is 1 - 0.5^(1/brightness_power).
// At the default of 8.0 that fraction is about 8%, i.e. roughly one star in
// twelve is above half brightness, and the vast majority sit near-zero and
// render as barely-visible one-pixel points. This is the core of the
// power-law distribution: exposed as a uniform so it can be retuned without
// touching the shader.
uniform float brightness_power : hint_range(1.0, 16.0) = 8.0;

// Cheap deterministic hash, no texture lookups, so there is no asset to
// ship. Returns a pseudo-random value in [0, 1) for a 2D cell coordinate.
float star_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453123);
}

// Renders one parallax star layer at the given screen-space UV (0..1, before
// the density scale below). Returns the star's brightness contribution at
// this fragment, 0 if no star is near.
float star_layer(vec2 uv, float density, float max_point_size, float brightness) {
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
	// grid.
	vec2 jitter = vec2(star_hash(cell + 4.7), star_hash(cell + 9.3)) - 0.5;
	vec2 offset = local - jitter * 0.6;

	// Power-law brightness: raising the hash to a high power concentrates
	// most cells near 0 (faint) with only a rare few near 1 (bright). Point
	// size is driven by the same value, so bright stars are also the large
	// ones; faint stars shrink toward a single hard pixel rather than
	// staying a flat size, which is what breaks up the previous uniform
	// bokeh-blob look.
	float star_power = pow(star_hash(cell + 1.3), brightness_power);
	float point_size = max_point_size * max(star_power, 0.12);
	float dist = length(offset);

	// A tight smoothstep gives a hard, small, crisp edge -- just enough
	// softness across a fraction of a pixel's worth of UV to avoid aliasing,
	// nothing like the wide soft falloff that reads as fuzzy grain when
	// stars are packed densely.
	float edge = point_size * 0.35;
	float core = point_size - edge;
	float star = 1.0 - smoothstep(core, point_size, dist);

	float twinkle = 0.6 + 0.4 * star_hash(cell + 17.0);
	return star * brightness * star_power * twinkle;
}

void fragment() {
	// SCREEN_UV is 0..1 across the viewport regardless of the quad's world
	// size, far plane distance, or window resolution -- that independence is
	// the fix: density below means "cells across the screen" and nothing
	// else. Correct x by the viewport aspect so star cells are square rather
	// than stretched to the window's shape.
	float aspect = VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0);
	vec2 screen_uv = vec2(SCREEN_UV.x * aspect, SCREEN_UV.y);

	// Each layer samples "star space" offset by a different fraction of the
	// camera's world position -- that difference in scroll rate is the
	// parallax. Distant layers barely shift; the near layer shifts a lot.
	// Subtracting (not adding) is deliberate: a star fixed in world space
	// must appear to slide toward the screen edge the camera is moving away
	// from as the camera travels, the same way roadside objects slide past
	// and behind you as you drive forward. Adding here made the sampled
	// pattern shift the same way as camera travel, which reads as stars
	// rushing off in the direction of travel instead of streaming past.
	vec2 far_uv = screen_uv - camera_world_position.xz * far_parallax;
	vec2 mid_uv = screen_uv - camera_world_position.xz * mid_parallax;
	vec2 near_uv = screen_uv - camera_world_position.xz * near_parallax;

	float far_star = star_layer(far_uv, far_density, far_size, far_brightness);
	float mid_star = star_layer(mid_uv, mid_density, mid_size, mid_brightness);
	float near_star = star_layer(near_uv, near_density, near_size, near_brightness);

	// The quad is opaque and covers the whole screen, so this colour REPLACES
	// the WorldEnvironment background and the project's clear colour rather
	// than blending with them. It is therefore the one that actually decides
	// what empty space looks like -- keep it matched to the environment, or
	// set both to black.
	vec3 background = background_colour;

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
