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

// Multiplied with the mesh's vertex colour. Two jobs.
//
// It lets one mesh serve both hives -- the same drone tinted green for the
// player and gold for the rival -- which is what the palette decision asks
// for, since both sides are the same species.
//
// And it gives modelled meshes a colour without needing vertex colours at
// all. Blender exports white when a mesh has no colour attribute, and white
// multiplied by the tint IS the tint, so a hand-modelled hull is coloured
// from the Inspector rather than from a paint pass in Blender.
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(face_normal, VIEW) < 0.0) {
		face_normal = -face_normal;
	}

	float diffuse = max(dot(face_normal, normalize(light_direction)), 0.0);
	float light = clamp(ambient + diffuse, 0.0, 1.0);

	ALBEDO = COLOR.rgb * tint.rgb * light * brightness;
	// Deliberately does NOT write ALPHA. Godot flags any shader that touches
	// ALPHA as transparent and drops it into the alpha queue, where depth
	// writing is off and faces draw in submission order rather than depth
	// order -- so the far side of a hull paints over the near side. Hulls are
	// always opaque, so leaving ALPHA alone keeps the material opaque and
	// depth-sorted.
}
