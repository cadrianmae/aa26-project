// The system the belt sits in: a white star, a tan gas giant, and the belt
// itself seen edge-on as a band across the sky.
//
// A real Sky shader rather than a painted quad, because Godot builds a
// radiance map from it. That is what makes the sun and the planet actually
// LIGHT the ships: ambient_light_source = SKY samples this, so the gas
// giant's tan bounces onto hulls facing it without anything being wired up.
// A quad in the world cannot do that -- it is just pixels.
//
// Everything is procedural. No textures, matching how the hulls and the radar
// are built, and it means the whole system is a handful of numbers rather
// than an art pipeline.
shader_type sky;

group_uniforms Star;
// Direction TO the star, normalised. Written by StarSystem, which drives this,
// the DirectionalLight3D and the hull shader from one value so the sun in the
// sky is the sun doing the lighting.
uniform vec3 sun_direction = vec3(0.4, 0.35, 0.85);
uniform vec4 sun_colour : source_color = vec4(1.0, 0.957, 0.91, 1.0);
// Angular size of the disc, as a cosine threshold. Small: a star that reads
// as a disc rather than a glow needs to be genuinely small, with the size
// impression coming from the halo around it.
uniform float sun_size : hint_range(0.9990, 0.99999) = 0.99965;
uniform float sun_glow : hint_range(1.0, 400.0) = 90.0;
uniform float sun_intensity : hint_range(0.0, 12.0) = 6.0;

group_uniforms Planet;
uniform vec3 planet_direction = vec3(-0.75, 0.12, -0.65);
uniform vec4 planet_colour : source_color = vec4(0.72, 0.60, 0.42, 1.0);
uniform vec4 planet_band_colour : source_color = vec4(0.55, 0.44, 0.31, 1.0);
// Cosine threshold for the planet's disc. Larger than the sun's because a gas
// giant close enough to see bands on subtends a much wider angle.
uniform float planet_size : hint_range(0.90, 0.9999) = 0.982;
uniform float planet_bands : hint_range(1.0, 40.0) = 11.0;
// How much of the planet is unlit. The terminator is what makes it read as a
// sphere lit by the star rather than as a flat sticker.
uniform float planet_night : hint_range(0.0, 1.0) = 0.16;

group_uniforms Belt;
// The belt seen edge-on, as a band around the sky. Its plane is the game's
// own XZ plane, so the band lies where the asteroids actually are -- fly to
// the horizon and the rocks you see are in the direction the band runs.
uniform vec4 belt_colour : source_color = vec4(0.42, 0.37, 0.31, 1.0);
uniform float belt_thickness : hint_range(0.005, 0.4) = 0.055;
uniform float belt_density : hint_range(0.0, 1.0) = 0.5;

group_uniforms Stars;
uniform vec4 background_colour : source_color = vec4(0.004, 0.005, 0.010, 1.0);
// How fine the grid of candidate star positions is. Lower is FEWER, larger
// stars. At 640x360 every star is a chunky block, so a dense field reads as
// television static rather than as sky -- this is the single most important
// number in the shader for whether space looks empty or noisy.
uniform float star_density : hint_range(1.0, 400.0) = 46.0;
uniform float star_brightness : hint_range(0.0, 4.0) = 1.0;
// Only cells whose hash clears this threshold become stars at all. Without a
// hard cutoff, the smooth falloff gives every cell a faint value and the sky
// fills up with dim speckle.
uniform float star_threshold : hint_range(0.5, 0.999) = 0.955;

// A cheap 3D hash. Deterministic, so the starfield is the same every run --
// stars that reshuffled would make the sky useless as a sense of direction.
float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Stars, from a hash over a grid of directions.
//
// Two stages of rejection, not one. The threshold discards the great majority
// of cells outright, and the remainder are then spread across a brightness
// range so the survivors are not all identical. A single smooth falloff --
// which is what the first version used -- leaves every cell with some faint
// value, and a sky where everything is slightly lit reads as static.
float starfield(vec3 dir) {
	vec3 cell = floor(dir * star_density);
	float h = hash13(cell);
	if (h < star_threshold) {
		return 0.0;
	}
	// Remap the surviving range to 0..1, then curve it so most stars are dim
	// and a few are bright, as a real sky is.
	float magnitude = (h - star_threshold) / (1.0 - star_threshold);
	magnitude = pow(magnitude, 2.2);

	// Position within the cell, from a second hash, so a star sits anywhere
	// in its cell rather than at the centre -- a lattice of evenly spaced
	// stars is immediately readable as a grid.
	vec3 jitter = vec3(
		hash13(cell + 11.0), hash13(cell + 23.0), hash13(cell + 37.0)
	) - 0.5;
	vec3 offset = fract(dir * star_density) - 0.5 - jitter * 0.6;
	// A tight falloff: at this resolution a star should be one or two pixels,
	// and a soft one just becomes a grey smudge.
	float falloff = 1.0 - smoothstep(0.0, 0.16, length(offset));

	return magnitude * falloff * star_brightness;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun = normalize(sun_direction);
	vec3 planet = normalize(planet_direction);

	vec3 colour = background_colour.rgb;

	// Stars first: everything else paints over them.
	colour += vec3(starfield(dir));

	// The belt, as a soft band about the XZ plane. Its brightness falls off
	// with height above that plane, and noise breaks it up so it reads as
	// countless rocks rather than as a painted stripe.
	float height = abs(dir.y);
	float band = 1.0 - smoothstep(0.0, belt_thickness, height);
	// Coarse grain, gently applied. A fine hash here produced a second field
	// of speckle on top of the stars: the band should read as a dusty haze
	// with some structure, not as more noise.
	float grain = hash13(floor(dir * 34.0));
	colour += belt_colour.rgb * band * belt_density * (0.7 + grain * 0.45);

	// The gas giant. Inside its disc, latitude banding plus a terminator.
	float planet_dot = dot(dir, planet);
	if (planet_dot > planet_size) {
		// Position within the disc, 0 at the rim and 1 at the centre.
		float within = (planet_dot - planet_size) / (1.0 - planet_size);
		// Offset from the planet's centre, used for latitude. Bands run
		// across the disc rather than round it, which is what makes a gas
		// giant look like a gas giant.
		vec3 to_edge = dir - planet * planet_dot;
		float latitude = to_edge.y / max(1.0 - planet_size, 0.0001);
		float bands = sin(latitude * planet_bands) * 0.5 + 0.5;
		vec3 surface = mix(planet_band_colour.rgb, planet_colour.rgb, bands);

		// Lit by the star. The terminator runs across the disc according to
		// where the sun is relative to the planet, so the crescent turns as
		// the system is re-arranged rather than being painted on.
		vec3 normal = normalize(to_edge + planet * sqrt(max(within, 0.0)));
		float lit = clamp(dot(normal, sun), 0.0, 1.0);
		surface *= mix(planet_night, 1.0, smoothstep(0.0, 0.45, lit));
		surface *= sun_colour.rgb;

		// A soft rim so the disc does not have a hard aliased edge, which at
		// 640x360 would stair-step badly.
		float edge = smoothstep(0.0, 0.06, within);
		colour = mix(colour, surface, edge);
	}

	// The star. Halo first, then the disc over it.
	float sun_dot = dot(dir, sun);
	float halo = pow(max(sun_dot, 0.0), sun_glow);
	colour += sun_colour.rgb * halo * 0.55;
	if (sun_dot > sun_size) {
		float disc = smoothstep(sun_size, sun_size + 0.00012, sun_dot);
		colour = mix(colour, sun_colour.rgb * sun_intensity, disc);
	}

	COLOR = colour;
}
