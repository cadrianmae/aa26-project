"""An irregular belt asteroid.

This is the model that justifies the whole Blender pipeline. A convincing
irregular rock is twenty-odd hand-typed coordinates in hull.gd and looks it;
here it is a subdivided icosphere pushed around by noise, and changing the
seed gives a different rock for free.

Neutral grey-brown: asteroids belong to no hive, and the palette keeps them
outside the green/gold range so they can never be misread as a side's units.
"""

import bpy
import bmesh
import math
import sys
import os

sys.path.append(os.path.dirname(__file__))
from common import clear_scene, build

# Dull grey-brown #6B6357 -- the neutral of the palette, deliberately outside
# the green/gold faction range.
ROCK_COLOUR = (0.42, 0.39, 0.34, 1.0)

# How many rocks to build. Each gets its own seed and its own exported file,
# so the map can place visibly different asteroids without hand-authoring any
# of them.
VARIANT_COUNT = 4


def build_asteroid(seed, subdivisions=2, deform=0.45):
    """An icosphere pushed out of round by per-vertex noise.

    Subdivision 2 gives 80 faces, which is the right order for the Frontier
    look: enough facets to read as a rock, few enough that each one is a
    visible plane rather than a smooth patch. Subdivision 1 is a bare
    20-face icosahedron, which reads as a die rather than as a rock.
    """
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0)
    obj = bpy.context.active_object

    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)

    # A cheap deterministic hash per vertex. Deterministic matters: the same
    # seed must always give the same rock, or the map changes shape every time
    # the models are rebuilt.
    for index, vert in enumerate(bm.verts):
        h = math.sin((index + 1) * 12.9898 + seed * 78.233) * 43758.5453
        noise = h - math.floor(h)
        # Squash on Y as well, so rocks read as lumps rather than as balls.
        vert.co *= 1.0 + (noise - 0.5) * 2.0 * deform
        # Squash on Godot's Y, which is Blender's Z.
        vert.co.z *= 0.75

    bm.to_mesh(mesh)
    bm.free()
    return obj


def main():
    for variant in range(VARIANT_COUNT):
        clear_scene()
        obj = build_asteroid(seed=variant * 7 + 3)
        build(obj, ROCK_COLOUR, "asteroid_%d" % variant)


main()
