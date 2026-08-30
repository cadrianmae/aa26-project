"""The Matriarch: the hive's capital ship, and the thing the player flies.

The same geometry hull.gd builds by hand, moved into Blender so the ship and
the modelled world share one pipeline. Kept identical rather than
"improved": the hand-authored version was designed against the camera angle
and the pixel scale, and changing the silhouette now would invalidate that.

Octagonal head-on, three stations along Z: a small octagonal nose face, the
full-width octagon behind it, and a single point at the tail. The band
between the first two stations is the angled front swept back.

+Z is forward, following Duggan and the rest of this codebase. The glTF
exporter is called with export_yup=True, which converts Blender's Z-up to
Godot's Y-up; +Z forward survives that conversion unchanged.
"""

import bpy
import bmesh
import math
import sys
import os

sys.path.append(os.path.dirname(__file__))
from common import clear_scene, build, gv

# Caustic green #6FCF5A. The hull colour is multiplied by the shader, so one
# exported mesh serves the rival hive too by tinting it gold at run time.
HIVE_GREEN = (0.435, 0.812, 0.353, 1.0)

# Radii and Z positions of the two octagonal stations, matching hull.gd.
NOSE_RADIUS = 0.5
NOSE_Z = 1.7
MAIN_RADIUS = 1.2
MAIN_Z = 0.3
TAIL_Z = -2.2
NOSE_TIP_Z = 1.85


def octagon(radius, z):
    """Eight points at 22.5 + 45k degrees, in Godot's XY plane at depth `z`.

    The offset puts the FACETS on the cardinals -- flat top, flat bottom,
    flat sides -- rather than a corner pointing straight up. Corner-up reads
    as a spinning top; facet-up gives the broad panels the flat shading needs.
    """
    points = []
    for k in range(8):
        angle = math.radians(22.5 + 45.0 * k)
        points.append(gv(radius * math.cos(angle), radius * math.sin(angle), z))
    return points


def build_matriarch():
    mesh = bpy.data.meshes.new("MatriarchMesh")
    bm = bmesh.new()

    nose_tip = bm.verts.new(gv(0.0, 0.0, NOSE_TIP_Z))
    nose_ring = [bm.verts.new(p) for p in octagon(NOSE_RADIUS, NOSE_Z)]
    main_ring = [bm.verts.new(p) for p in octagon(MAIN_RADIUS, MAIN_Z)]
    tail = bm.verts.new(gv(0.0, 0.0, TAIL_Z))
    bm.verts.ensure_lookup_table()

    for i in range(8):
        j = (i + 1) % 8
        # Nose cap: a shallow eight-sided pyramid, not a flat disc. A flat
        # disc is coplanar, so every triangle derives the same normal and the
        # face the player looks at most shades as one flat colour.
        bm.faces.new((nose_tip, nose_ring[i], nose_ring[j]))
        # Angled front: each nose edge sweeps back and out to the main ring.
        bm.faces.new((nose_ring[i], nose_ring[j], main_ring[j], main_ring[i]))
        # Rear cone down to the tail point.
        bm.faces.new((main_ring[i], main_ring[j], tail))

    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("Matriarch", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def main():
    clear_scene()
    obj = build_matriarch()
    build(obj, HIVE_GREEN, "matriarch")


main()
