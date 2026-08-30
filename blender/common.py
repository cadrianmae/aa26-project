"""Shared helpers for the Blender model scripts.

The scripts in this directory are the SOURCE OF TRUTH for the project's
modelled geometry. The .gltf files under godot/models/ are build artefacts:
regenerate them with

    blender --background --python blender/<name>.py

rather than editing them. A script is diffable in git; a binary mesh is not.

Two things every model here must get right, both of them driven by
shaders/flat_hull.gdshader:

1. VERTEX COLOURS. The shader reads COLOR.rgb, so a mesh exported without a
   colour attribute renders white. Blender's colour attribute exports as
   glTF COLOR_0, which Godot imports into Mesh.ARRAY_COLOR.

2. FLAT SHADING is NOT this script's job. The shader derives a per-face
   normal from screen-space derivatives, so whatever normals a mesh carries
   are ignored. Faces are still shaded flat in Blender for the sake of anyone
   opening the .blend by hand.
"""

import bpy
import bmesh
import math
import os

# Where the exported .gltf files land, relative to this file.
EXPORT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "godot", "models")

# Where the .blend files land. Separate from the scripts so the directory
# listing stays readable, and outside godot/ so Godot never tries to import
# them.
BLEND_DIR = os.path.join(os.path.dirname(__file__), "blend")


def gv(x, y, z):
    """Convert Godot coordinates to Blender ones.

    Blender is Z-up; Godot is Y-up. The glTF exporter runs with
    export_yup=True, and the mapping it applies was measured, not assumed:
    a vertex at Blender +Y = 5 arrives in Godot at (0, 0, -5).

        Godot X (right)   = Blender  X
        Godot Y (up)      = Blender  Z
        Godot Z (forward) = Blender -Y

    Model scripts author in GODOT coordinates and pass every vertex through
    here. That keeps them readable against hull.gd, which is also in Godot
    space and +Z forward, and it means a .blend opened by hand still sits the
    right way up with its nose toward Blender's front view.

    Getting this wrong is silent: the first version of these scripts authored
    length along Blender Z, and the ships imported standing on their tails.
    Nothing errored -- the bounding box was simply transposed.
    """
    return (x, -z, y)


def clear_scene():
    """Empty the default scene, cube and all."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in block:
            if item.users == 0:
                block.remove(item)


def paint(obj, colour):
    """Give every face corner of `obj` the same colour.

    A flat per-object colour, not a texture: the whole point of the Frontier
    look is untextured facets. Per-face variation is applied at run time by
    Hull._facet_shade(), not baked here, so one exported mesh can serve both
    hives by having its colour multiplied in the shader.
    """
    mesh = obj.data
    layer = colour_layer(mesh)
    for i in range(len(mesh.loops)):
        layer.data[i].color = colour


def colour_layer(mesh):
    """The mesh's corner colour layer, creating one named "Color" if absent.

    Never assumes the layer is called "Color". A mesh modelled by hand
    arrives with whatever Blender or the modeller named it -- often
    "Attribute" or "Col" -- and looking the name up directly raises KeyError
    on exactly the meshes this pipeline exists to serve.

    A layer on the wrong domain is replaced rather than used: the exporter
    reads CORNER colours, and a POINT-domain layer would export colours that
    bleed across face boundaries, which defeats flat shading.
    """
    for layer in mesh.color_attributes:
        # Must be CORNER *and* actually populated. A hand-modelled mesh can
        # carry an empty colour attribute -- Blender creates one named
        # "Attribute" with len(data) == 0 -- which looks usable and then
        # raises IndexError on the first write.
        if layer.domain == "CORNER" and len(layer.data) == len(mesh.loops):
            return layer
    while mesh.color_attributes:
        mesh.color_attributes.remove(mesh.color_attributes[0])
    return mesh.color_attributes.new(
        name="Color", type="BYTE_COLOR", domain="CORNER"
    )


def paint_faces(obj, colour_for_face):
    """Colour each face independently via a callback.

    `colour_for_face(index, centre, normal)` returns an RGBA tuple for that
    polygon. This is how a mesh carries more than one colour without a
    texture: the Farragut wreck is charcoal hull, rust accent stripes and
    caustic corrosion, all in one mesh, decided by where each face sits.

    Per-face rather than per-vertex, because a vertex shared between a
    charcoal face and a rust face would have to be one or the other. Writing
    into face CORNERS instead of vertices means each face keeps its own
    colour even where they meet, which is the same reason the meshes are
    non-indexed.
    """
    mesh = obj.data
    layer = colour_layer(mesh)
    for index, polygon in enumerate(mesh.polygons):
        colour = colour_for_face(index, polygon.center, polygon.normal)
        for loop_index in polygon.loop_indices:
            layer.data[loop_index].color = colour


def shade_flat(obj):
    """Mark every polygon flat, for anyone opening the .blend by hand."""
    for polygon in obj.data.polygons:
        polygon.use_smooth = False


def triangulate(obj):
    """Convert to triangles.

    Godot triangulates on import anyway, but doing it here means the exported
    face count is the face count the game actually draws -- so the numbers in
    the write-up match what is on screen.
    """
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()


def finalise(obj, colour, name):
    """Triangulate, flat-shade, paint and rename, in the order that matters.

    Painting comes after triangulation because triangulating rebuilds the
    loops that carry the colour; painting first would lose it.
    """
    triangulate(obj)
    shade_flat(obj)
    paint(obj, colour)
    obj.name = name
    obj.data.name = name + "Mesh"


def export(name):
    """Write the current scene to godot/models/<name>.gltf."""
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, name + ".gltf")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLTF_SEPARATE",
        export_materials="NONE",
        # "ACTIVE", not the default "MATERIAL": the default takes its colours
        # from the material, and materials are excluded above, so it would
        # silently export no colours at all and every mesh would render white.
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_normals=True,
        export_apply=True,
        export_yup=True,
    )
    print("EXPORTED: %s" % path)
    return path


def save_blend(name):
    """Write the current scene to blender/blend/<name>.blend.

    The script remains the source of truth -- re-running it overwrites this
    file -- but saving one means the model can be opened, inspected and
    adjusted by hand. Hand edits are lost on the next run, so anything worth
    keeping goes back into the script.
    """
    os.makedirs(BLEND_DIR, exist_ok=True)
    path = os.path.join(BLEND_DIR, name + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=path, check_existing=False)
    print("SAVED: %s" % path)
    return path


def build(obj, colour, name):
    """Finalise, report, save the .blend and export the .gltf.

    One call so no model script can accidentally export without saving, which
    is exactly what happened the first time round.

    `colour` is either an RGBA tuple applied to the whole object, or a
    callable taking (index, centre, normal) and returning one, for meshes
    that carry several colours.
    """
    triangulate(obj)
    shade_flat(obj)
    if callable(colour):
        paint_faces(obj, colour)
    else:
        paint(obj, colour)
    obj.name = name
    obj.data.name = name + "Mesh"
    report(obj)
    save_blend(name)
    export(name)


def report(obj):
    """Print the vertex and triangle count, so a run says what it built."""
    print(
        "BUILT: %s  verts=%d  tris=%d"
        % (obj.name, len(obj.data.vertices), len(obj.data.polygons))
    )
