// Unlit emissive line shader for Elite-style wireframe hulls.
// Lines carry their colour in COLOR; brightness is pushed above 1.0 so the
// world environment's glow picks them up.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform float brightness : hint_range(0.5, 6.0) = 2.5;
uniform float fade_start : hint_range(1.0, 500.0) = 120.0;

varying float distance_to_camera;

void vertex() {
	distance_to_camera = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float fade = 1.0 - smoothstep(fade_start * 0.5, fade_start, distance_to_camera);
	ALBEDO = COLOR.rgb * brightness * fade;
	ALPHA = COLOR.a * fade;
}
