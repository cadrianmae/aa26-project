"""The Farragut wreck: a dead Federation capital ship, and the map's hazard.

Silhouette taken from the Federation Farragut Battle Cruiser. From above the
ship is NOT a single hull with wings -- it is a long central spine flanked by
two separate parallel outrigger hulls, each tapering to its own point at the
front. That three-pronged read is the whole silhouette, and it is what has to
survive the downscale to 640x360.

Proportions from the published blueprint: 2040 m long by 806 m wide, so
length to width is 2.53 to 1. The first version of this model came out at
1.8 to 1 with two large triangular wings, and read as a stubby arrowhead
rather than as a capital ship.

It is the map's anti-xeno installation from the design: hostile to BOTH
hives, since its point-defence never stopped running. Mechanically it is a
Threat with an obstacle attached, which is why it is one object rather than
scenery plus a separate trigger.

The ship LOST. Thargoid caustic has eaten through the hull in patches, and
the port outrigger has been torn away from the spine -- so the wreck reads as
the aftermath of exactly the war the player is still fighting, rather than as
parked scenery.

Attribution: the Farragut Battle Cruiser is a Frontier Developments design
from Elite Dangerous. This is an original low-poly interpretation of its
silhouette for a non-commercial student artefact. See ATTRIBUTIONS.md.
"""

import bpy
import bmesh
import math
import sys
import os

sys.path.append(os.path.dirname(__file__))
from common import clear_scene, build, gv

# Charcoal hull, rust accent panels, caustic corrosion. Taken from the in-game
# colour reference: a dark grey ship striped with rust orange. The caustic
# green is the only part that is not Federation livery -- it is what killed it.
HULL_CHARCOAL = (0.22, 0.22, 0.24, 1.0)
RUST_ORANGE = (0.66, 0.35, 0.20, 1.0)
CAUSTIC_GREEN = (0.62, 0.82, 0.23, 1.0)

# Overall length in world units, and the blueprint's length-to-width ratio.
LENGTH = 44.0
ASPECT = 2.53
HALF_WIDTH = LENGTH / ASPECT / 2.0


def hull_prong(bm, x_offset, z_front, z_back, half_width, half_height, tip_ratio):
    """One elongated hull section, tapering to a point at the front.

    The Farragut is three of these side by side: a long central spine and two
    shorter outriggers. Each is a box whose front end narrows almost to
    nothing, which is what gives the ship its spear-like prow from above.

    Coordinates are GODOT space -- +Z forward, +Y up -- and converted on the
    way into Blender by gv().
    """
    length = z_front - z_back
    # The shoulder sits well forward, so the hull is mostly full-width and
    # only the last stretch tapers. Putting it at the middle produces a
    # needle, which is what the first attempt looked like.
    mid_z = z_back + length * 0.74

    # Back face, full width.
    back = [
        bm.verts.new(gv(x_offset - half_width, -half_height, z_back)),
        bm.verts.new(gv(x_offset + half_width, -half_height, z_back)),
        bm.verts.new(gv(x_offset + half_width, half_height, z_back)),
        bm.verts.new(gv(x_offset - half_width, half_height, z_back)),
    ]
    # Shoulder, the widest point, set well forward so the taper is long.
    shoulder = [
        bm.verts.new(gv(x_offset - half_width, -half_height, mid_z)),
        bm.verts.new(gv(x_offset + half_width, -half_height, mid_z)),
        bm.verts.new(gv(x_offset + half_width, half_height, mid_z)),
        bm.verts.new(gv(x_offset - half_width, half_height, mid_z)),
    ]
    # Prow, narrowed to tip_ratio of the width and flattened vertically.
    tw = half_width * tip_ratio
    th = half_height * tip_ratio
    prow = [
        bm.verts.new(gv(x_offset - tw, -th, z_front)),
        bm.verts.new(gv(x_offset + tw, -th, z_front)),
        bm.verts.new(gv(x_offset + tw, th, z_front)),
        bm.verts.new(gv(x_offset - tw, th, z_front)),
    ]
    bm.verts.ensure_lookup_table()

    bm.faces.new(back[::-1])
    bm.faces.new(prow)
    for ring_a, ring_b in ((back, shoulder), (shoulder, prow)):
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((ring_a[i], ring_a[j], ring_b[j], ring_b[i]))


def dorsal_block(bm, z_front, z_back, half_width, base_y, top_y):
    """The raised superstructure along the spine's top.

    Read from the side view, where the Farragut is otherwise almost flat.
    Without it the ship has no profile at all from the game's tilted camera.
    """
    lower = [
        bm.verts.new(gv(-half_width, base_y, z_back)),
        bm.verts.new(gv(half_width, base_y, z_back)),
        bm.verts.new(gv(half_width, base_y, z_front)),
        bm.verts.new(gv(-half_width, base_y, z_front)),
    ]
    upper = [
        bm.verts.new(gv(-half_width * 0.55, top_y, z_back + 1.5)),
        bm.verts.new(gv(half_width * 0.55, top_y, z_back + 1.5)),
        bm.verts.new(gv(half_width * 0.55, top_y, z_front - 3.0)),
        bm.verts.new(gv(-half_width * 0.55, top_y, z_front - 3.0)),
    ]
    bm.verts.ensure_lookup_table()
    bm.faces.new(lower[::-1])
    bm.faces.new(upper)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lower[i], lower[j], upper[j], upper[i]))


def build_wreck():
    mesh = bpy.data.meshes.new("FarragutWreckMesh")
    bm = bmesh.new()

    half = LENGTH / 2.0

    # Stern block first: a single slab spanning the full beam at the back.
    # This is what makes the three prongs one ship rather than three spikes,
    # and it is exactly what the first attempt was missing.
    hull_prong(
        bm,
        x_offset=0.0,
        z_front=-half * 0.52,
        z_back=-half,
        half_width=HALF_WIDTH * 0.74,
        half_height=1.9,
        tip_ratio=1.0,
    )

    # Central spine: the longest prong, running from the stern to the prow.
    hull_prong(
        bm,
        x_offset=0.0,
        z_front=half,
        z_back=-half * 0.9,
        half_width=HALF_WIDTH * 0.26,
        half_height=1.7,
        tip_ratio=0.3,
    )

    # Starboard outrigger, overlapping the spine so the gap reads as a
    # channel between hulls rather than as empty space.
    hull_prong(
        bm,
        x_offset=HALF_WIDTH * 0.46,
        z_front=half * 0.80,
        z_back=-half * 0.9,
        half_width=HALF_WIDTH * 0.26,
        half_height=1.3,
        tip_ratio=0.34,
    )

    # Port outrigger: shorter and pushed outboard, torn part-way off the
    # stern. The asymmetry is the damage -- a symmetric wreck reads as a
    # parked ship.
    hull_prong(
        bm,
        x_offset=-HALF_WIDTH * 0.52,
        z_front=half * 0.62,
        z_back=-half * 0.9,
        half_width=HALF_WIDTH * 0.26,
        half_height=1.3,
        tip_ratio=0.34,
    )

    # Superstructure on the spine.
    dorsal_block(
        bm,
        z_front=half * 0.30,
        z_back=-half * 0.72,
        half_width=HALF_WIDTH * 0.22,
        base_y=1.5,
        top_y=3.4,
    )

    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("FarragutWreck", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def wreck_colour(index, centre, normal):
    """Charcoal hull, rust stripes along the flanks, caustic at the breaks.

    centre and normal arrive in BLENDER space, so Godot's forward axis is -Y
    here and Godot's up is Z. Converting back rather than reasoning in two
    coordinate systems at once.
    """
    godot_forward = -centre.y
    godot_up = centre.z
    godot_right = centre.x

    # Caustic corrosion: heaviest on the torn-off port outrigger and around
    # the middle of the spine where it was cut. Placed rather than scattered,
    # so the corrosion reads as the cause of the damage.
    torn_side = godot_right < -HALF_WIDTH * 0.5
    mid_ship = abs(godot_forward) < LENGTH * 0.16
    if torn_side or mid_ship:
        h = math.sin(index * 12.9898) * 43758.5453
        if (h - math.floor(h)) < (0.6 if torn_side else 0.4):
            return CAUSTIC_GREEN

    # Rust accent stripes: Federation livery runs along the upper flanks, so
    # pick faces that sit high and face outward rather than up.
    if godot_up > 0.5 and abs(normal.z) < 0.5:
        return RUST_ORANGE

    return HULL_CHARCOAL


def main():
    clear_scene()
    obj = build_wreck()
    build(obj, wreck_colour, "wreck_farragut")


main()
