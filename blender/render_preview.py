"""Render orthographic previews of a .blend, so a silhouette can be checked.

    blender --background --python blender/render_preview.py -- wreck_farragut

Writes top, side and front views to blender/preview/<name>_{top,side,front}.png.

This exists because a silhouette cannot be verified by reading vertex
coordinates. The first Farragut wreck had correct bounds, correct colours and
correct topology, and still looked nothing like the ship -- the numbers were
all fine and the shape was wrong. Rendering closes that loop.

Flat white on black, matching how the models read in game: the shape is the
only thing being judged here, so colour and lighting would only distract.
"""

import bpy
import sys
import os
import math

sys.path.append(os.path.dirname(__file__))
from common import BLEND_DIR

PREVIEW_DIR = os.path.join(os.path.dirname(__file__), "preview")
RESOLUTION = 700

# Camera positions in BLENDER space (Z up), with the rotation that aims each
# one at the origin. Named for what the viewer sees, not for the axis.
VIEWS = {
    "top": ((0.0, 0.0, 60.0), (0.0, 0.0, 0.0)),
    "side": ((60.0, 0.0, 0.0), (math.radians(90.0), 0.0, math.radians(90.0))),
    "front": ((0.0, -60.0, 0.0), (math.radians(90.0), 0.0, 0.0)),
}


def fit_scale():
    """Orthographic width that fits every mesh in the scene, with a margin."""
    extent = 1.0
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            for value in corner:
                extent = max(extent, abs(value))
    return extent * 2.4


def setup_render():
    scene = bpy.context.scene
    scene.render.resolution_x = RESOLUTION
    scene.render.resolution_y = RESOLUTION
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    # Workbench: no lighting setup needed, and it draws flat faces flat, which
    # is what the game's shader does anyway.
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "FLAT"
    shading.color_type = "SINGLE"
    shading.single_color = (1.0, 1.0, 1.0)
    shading.show_object_outline = True
    scene.world.color = (0.0, 0.0, 0.0) if scene.world else None


def render_views(name):
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    setup_render()
    scale = fit_scale()

    camera_data = bpy.data.cameras.new("PreviewCam")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = scale
    camera = bpy.data.objects.new("PreviewCam", camera_data)
    bpy.context.collection.objects.link(camera)
    bpy.context.scene.camera = camera

    for view, (location, rotation) in VIEWS.items():
        camera.location = location
        camera.rotation_euler = rotation
        path = os.path.join(PREVIEW_DIR, "%s_%s.png" % (name, view))
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("RENDERED: %s" % path)


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if not args:
        print("USAGE: blender --background --python render_preview.py -- <name>")
        return
    name = args[0]
    bpy.ops.wm.open_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    render_views(name)


main()
