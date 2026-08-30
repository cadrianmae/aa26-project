"""Per-model colour rules, applied on export to hand-modelled meshes.

The division of labour: Blender is for SHAPE, this file is for COLOUR. A
model can be built or edited by hand without anyone remembering to paint
vertex colours, because export_all.py applies the rule for its name on the
way out.

That matters because the failure is silent. flat_hull.gdshader reads
COLOR.rgb, so a mesh with no colour attribute renders pure white -- it does
not error, it just looks wrong, and only in game.

A rule takes (index, centre, normal) in BLENDER space and returns RGBA.
Remember Godot's forward is -Y here and Godot's up is +Z; see common.gv().
"""

import math

# The project palette, from the visual style decisions.
HIVE_GREEN = (0.435, 0.812, 0.353, 1.0)
RIVAL_GOLD = (0.851, 0.643, 0.255, 1.0)
ROCK_BROWN = (0.42, 0.39, 0.34, 1.0)
HULL_CHARCOAL = (0.22, 0.22, 0.24, 1.0)
RUST_ORANGE = (0.66, 0.35, 0.20, 1.0)
CAUSTIC_GREEN = (0.62, 0.82, 0.23, 1.0)


def _hash01(index):
    """Deterministic 0..1 from a face index, so patterns survive a re-export."""
    h = math.sin(index * 12.9898) * 43758.5453
    return h - math.floor(h)


def farragut_wreck_flat(index, centre, normal, extent):
    """Flat charcoal, pending the livery pass.

    The wreck is deliberately one colour for now: its shape is still being
    iterated in Blender, and a positional colour rule written against a hull
    that is still moving would have to be rewritten anyway. Swap RULES over to
    farragut_wreck() once the geometry settles.
    """
    return HULL_CHARCOAL


def farragut_wreck(index, centre, normal, extent):
    """Charcoal hull, rust livery along the upper flanks, caustic corrosion.

    `extent` is the model's half-length, so the rule works at whatever scale
    the ship happens to be -- it was 250 units this morning and 2040 by the
    afternoon, and a rule written against absolute distances would have
    quietly stopped matching.
    """
    forward = -centre.y / max(extent, 0.001)
    up = centre.z
    right = centre.x

    # Caustic corrosion: heaviest around the middle, where the hull was
    # breached. Placed rather than scattered, so it reads as the cause of the
    # damage rather than as staining.
    if abs(forward) < 0.30 and _hash01(index) < 0.35:
        return CAUSTIC_GREEN

    # Rust accent stripes: Federation livery runs along the upper flanks, so
    # faces that sit high and face outward rather than straight up.
    if up > 0.0 and abs(normal.z) < 0.55 and _hash01(index * 3 + 1) < 0.5:
        return RUST_ORANGE

    return HULL_CHARCOAL


# Model name to rule. A name absent from here keeps whatever colours the
# .blend already has, and falls back to neutral grey if it has none.
RULES = {
    "wreck_farragut": farragut_wreck_flat,
}

FALLBACK = ROCK_BROWN
