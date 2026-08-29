// Flat-shaded solid hull shader, in the style of Frontier: Elite II (1993).
// The per-face normal is derived from screen-space derivatives rather than
// carried on the vertices, so the mesh script never has to get triangle
// winding order right by hand: whichever way a face winds, the normal below
// is flipped toward the viewer, so lighting always comes out correct.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 light_direction = vec3(0.4, 0.8, 0.3);
uniform float ambient : hint_range(0.0, 1.0) = 0.15;
uniform float brightness : hint_range(0.1, 4.0) = 1.2;

void fragment() {
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(face_normal, VIEW) < 0.0) {
		face_normal = -face_normal;
	}

	float diffuse = max(dot(face_normal, normalize(light_direction)), 0.0);
	float light = clamp(ambient + diffuse, 0.0, 1.0);

	ALBEDO = COLOR.rgb * light * brightness;
	// Deliberately does NOT write ALPHA. Godot flags any shader that touches
	// ALPHA as transparent and drops it into the alpha queue, where depth
	// writing is off and faces draw in submission order rather than depth
	// order -- so the far side of a hull paints over the near side. Hulls are
	// always opaque, so leaving ALPHA alone keeps the material opaque and
	// depth-sorted.
}
