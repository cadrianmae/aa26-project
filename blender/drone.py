"""The drone: the unit the swarm is made of.

An octahedral pod, matching HullShape.POD in hull.gd. Deliberately simple --
there may be fifty of these on screen at 640x360, where a drone is about six
pixels across, so detail spent here is detail nobody sees.

The brief calls for "the same hull with slight differences" between the two
hives rather than different shapes, so this exports twice: a player variant
and a rival variant differing only in proportion. The colour is applied by
the shader, not baked, so the difference here is purely in silhouette.
"""

import bpy
import bmesh
import sys
import os

sys.path.append(os.path.dirname(__file__))
from common import clear_scene, build, gv

HIVE_GREEN = (0.435, 0.812, 0.353, 1.0)

# Equator radius, and how far the apexes sit above and below it. The player
# pod is slightly squatter, the rival pod slightly more elongated: enough to
# tell apart when they are large on screen, not so much that they read as
# different species.
PLAYER_SHAPE = {"radius": 0.7, "height": 0.6, "name": "drone_player"}
RIVAL_SHAPE = {"radius": 0.6, "height": 0.85, "name": "drone_rival"}


def build_pod(radius, height):
    """An octahedron: a square equator with an apex above and below."""
    mesh = bpy.data.meshes.new("PodMesh")
    bm = bmesh.new()

    ring = [
        bm.verts.new(gv(0.0, 0.0, radius)),
        bm.verts.new(gv(radius, 0.0, 0.0)),
        bm.verts.new(gv(0.0, 0.0, -radius)),
        bm.verts.new(gv(-radius, 0.0, 0.0)),
    ]
    top = bm.verts.new(gv(0.0, height, 0.0))
    bottom = bm.verts.new(gv(0.0, -height, 0.0))
    bm.verts.ensure_lookup_table()

    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((top, ring[i], ring[j]))
        bm.faces.new((bottom, ring[j], ring[i]))

    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("Pod", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def main():
    for shape in (PLAYER_SHAPE, RIVAL_SHAPE):
        clear_scene()
        obj = build_pod(shape["radius"], shape["height"])
        build(obj, HIVE_GREEN, shape["name"])


main()
