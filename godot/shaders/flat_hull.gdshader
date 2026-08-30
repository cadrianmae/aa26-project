// Flat-shaded solid hull shader, in the style of Frontier: Elite II (1993).
// The per-face normal is derived from screen-space derivatives rather than
// carried on the vertices, so the mesh script never has to get triangle
// winding order right by hand: whichever way a face winds, the normal below
// is flipped toward the viewer, so lighting always comes out correct.
shader_type spatial;
render_mode unshaded, cull_disabled;

// GLOBAL uniforms, shared by every hull in the game and written once by
// StarSystem. Declared in project.godot under [shader_globals].
//
// Global rather than per-material because hull materials are created in code
// -- Hull builds one per mesh, ModelledHull and AsteroidField each build their
// own -- so there is no single material to set the sun on. Pushing to all of
// them would mean walking the tree and hoping nothing was missed; a global is
// written once and every shader sees it.
//
// This is also what makes the sun in the sky the sun doing the lighting: the
// sky shader, the DirectionalLight3D and every hull all read one direction.
global uniform vec3 sun_direction;
global uniform vec4 sun_colour;
// Fill light: what a surface facing away from the star still receives, which
// here is bounce off the tan gas giant. Without it, unlit faces go pure black
// and the hulls lose their silhouette against space.
global uniform vec4 fill_colour;

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

	float diffuse = max(dot(face_normal, normalize(sun_direction)), 0.0);

	// Two coloured terms rather than one white one. The lit side takes the
	// star's colour and the unlit side takes the gas giant's bounce, so a
	// facet turning away from the sun shifts in HUE as well as dimming --
	// which is most of what separates adjacent facets at 640x360, where the
	// brightness difference alone is only a few pixel values.
	vec3 lighting = sun_colour.rgb * diffuse + fill_colour.rgb * (1.0 - diffuse);
	lighting += vec3(ambient);

	ALBEDO = COLOR.rgb * tint.rgb * lighting * brightness;
	// Deliberately does NOT write ALPHA. Godot flags any shader that touches
	// ALPHA as transparent and drops it into the alpha queue, where depth
	// writing is off and faces draw in submission order rather than depth
	// order -- so the far side of a hull paints over the near side. Hulls are
	// always opaque, so leaving ALPHA alone keeps the material opaque and
	// depth-sorted.
}
