"""Re-export every .blend in blender/blend/ to godot/models/.

This is the step to run after editing a model by hand in Blender. It opens
each .blend as it is on disk and exports it, so hand edits reach the game
without the generator scripts running and overwriting them.

    blender --background --python blender/export_all.py

The two halves of the pipeline are deliberately separate:

    blender/<name>.py     GENERATES a .blend from scratch. Overwrites any
                          hand edits. Run it when you want to start over,
                          or when the parameters in the script changed.

    blender/export_all.py EXPORTS whatever the .blend currently holds.
                          Never modifies a .blend. Safe to run any time.

So the .blend is the working file once you start iterating, and the script is
the recipe that produced it. If a hand edit is worth keeping permanently, put
it back in the script -- otherwise the next generator run loses it.
"""

import bpy
import glob
import os
import sys

sys.path.append(os.path.dirname(__file__))
from common import BLEND_DIR, export, paint_faces, colour_layer
from palette import RULES, FALLBACK


def needs_painting(mesh):
    """True when a mesh has no usable colours of its own.

    Either no colour attribute at all, or one left at Blender's default
    white. Both render white under flat_hull.gdshader, so both want the
    palette applying. A mesh that was painted deliberately is left alone.
    """
    if not mesh.color_attributes:
        return True
    layer = colour_layer(mesh)
    if not len(layer.data):
        return True
    first = layer.data[0].color
    return first[0] > 0.99 and first[1] > 0.99 and first[2] > 0.99


def apply_palette(obj, name):
    """Paint `obj` using the rule registered for `name`, if it needs it.

    Painting is best-effort. A hand-modelled mesh can carry a colour
    attribute Blender refuses to write into -- an empty CORNER layer that
    reports the right domain and holds no data -- and there is no reliable
    way to repair it from a script.

    That is survivable, because the mesh does not have to carry its colour:
    it exports white, and flat_hull.gdshader multiplies white by its `tint`
    uniform, so an unpainted hull is coloured from the Godot Inspector
    instead. Set `tint` on the material rather than fighting Blender.
    """
    if not needs_painting(obj.data):
        return "kept its own colours"

    extent = max(
        (abs(c[i]) for c in obj.bound_box for i in range(3)), default=1.0
    )
    rule = RULES.get(name, lambda i, c, n, e: FALLBACK)
    try:
        paint_faces(obj, lambda i, c, n: rule(i, c, n, extent))
    except (IndexError, KeyError, RuntimeError) as error:
        return "UNPAINTED (%s) -- exports white, set `tint` in Godot" % type(error).__name__
    return "painted by rule"


def main():
    blends = sorted(glob.glob(os.path.join(BLEND_DIR, "*.blend")))
    if not blends:
        print("NOTHING TO EXPORT: no .blend files in %s" % BLEND_DIR)
        return

    for path in blends:
        name = os.path.splitext(os.path.basename(path))[0]
        bpy.ops.wm.open_mainfile(filepath=path)

        # Report what is actually in the file, not what the generator once
        # built: after a hand edit these differ, and the .blend wins.
        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        for obj in meshes:
            note = apply_palette(obj, name)
            print(
                "FROM BLEND: %s  verts=%d  tris=%d  %s"
                % (obj.name, len(obj.data.vertices), len(obj.data.polygons), note)
            )
        export(name)


main()
