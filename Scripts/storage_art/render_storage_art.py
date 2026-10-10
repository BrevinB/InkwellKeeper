"""Render the storage container artwork (binders, troves, boxes, bins) in Blender.

Run headless with Blender 4.2+:

    /Applications/Blender.app/Contents/MacOS/Blender -b -P Scripts/storage_art/render_storage_art.py -- <out_dir> [kind ...]

then install into the app with `install_assets.py <out_dir>`. Set SAMPLES=32 for
quick drafts. With no kinds given, every kind is rendered (about 15 minutes).

Layers
------
The app tints the artwork to the collector's cover color at runtime, so every
moving part is rendered as a pair, framed identically:

  * ``<kind>_<part>_<finish>_shade.png``  the lit object, tintable material in
    near-white so the app can multiply the cover color over it.
  * ``<kind>_<part>_<finish>_mask.png``   opaque where the tintable material is,
    transparent for trim, lining, sleeves and background.

Finishes are ``classic`` (smooth, glossy) and ``stitched`` (grainy, with a stitched
border). Starlight and Holofoil are drawn by the app over the classic render.

Parts are ``base`` and, for lidded boxes, ``lid`` (rendered alone so the app can
lift it). The binder also has a straight-on ``bindercover`` set for the cover that
swings open in the binder view: a stretchable ``surface`` plus the ``plate`` and
``emblem`` ornaments, which the app places without stretching.

``<kind>_metrics.json`` records where the hinge, rim and floor of each object
land in the frame (0–1, top-left origin); `install_assets.py` turns those into
`RenderedArtworkMetrics+Generated.swift`.
"""

import json
import math
import os
import sys
from pathlib import Path

import bmesh
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT_DIR = Path(ARGS[0] if ARGS else "storage_art_out")
ONLY_KINDS = ARGS[1:]
SHADE_SAMPLES = int(os.environ.get("SAMPLES", 96))   # lower for quick drafts
MASK_SAMPLES = 16
FRAME_HEIGHT = 720                                     # pixels; width follows the aspect

TINT_BASE = (0.86, 0.86, 0.86, 1)   # near-white; the app multiplies the cover color
GOLD = (1.0, 0.72, 0.30, 1)
VELVET = (0.035, 0.02, 0.06, 1)
THREAD = (0.93, 0.80, 0.52, 1)
SLEEVE = (0.92, 0.92, 0.94, 1)
PAPER = (0.95, 0.93, 0.88, 1)
LID_TILT_DEGREES = 4                # must match RenderedContainerArtwork

# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------


def reset_scene(aspect, frame_height=FRAME_HEIGHT):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.render.resolution_y = frame_height
    scene.render.resolution_x = round(frame_height * aspect)
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for device in prefs.devices:
            device.use = True
        scene.cycles.device = "GPU"
    except (TypeError, ValueError):
        scene.cycles.device = "CPU"

    world = bpy.data.worlds.new("World")
    world.color = (0.22, 0.21, 0.24)
    scene.world = world
    return scene


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------


def principled(name, color, roughness, metallic=0.0, coat=0.0, sheen=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Sheen Weight"].default_value = sheen
    return mat


def add_grain(mat, strength, cell_scale=70, roughness_spread=0.08):
    """Leather-like pebbling: smooth Voronoi cells broken up by noise."""
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    roughness = bsdf.inputs["Roughness"].default_value
    coords = nodes.new("ShaderNodeTexCoord")
    cells = nodes.new("ShaderNodeTexVoronoi")
    cells.feature = "SMOOTH_F1"
    cells.inputs["Scale"].default_value = cell_scale
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 9
    mix = nodes.new("ShaderNodeMath")
    mix.operation = "MULTIPLY_ADD"
    mix.inputs[2].default_value = 0.0
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = 0.02
    links.new(coords.outputs["Object"], cells.inputs["Vector"])
    links.new(coords.outputs["Object"], noise.inputs["Vector"])
    links.new(cells.outputs["Distance"], mix.inputs[0])
    links.new(noise.outputs["Fac"], mix.inputs[1])
    links.new(mix.outputs[0], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    spread = nodes.new("ShaderNodeMapRange")
    spread.inputs["To Min"].default_value = roughness - roughness_spread
    spread.inputs["To Max"].default_value = roughness + roughness_spread
    links.new(noise.outputs["Fac"], spread.inputs["Value"])
    links.new(spread.outputs["Result"], bsdf.inputs["Roughness"])


class Materials:
    """The palette for one render. `tint` is the only material the app recolors."""

    def __init__(self, finish, surface="leather"):
        stitched = finish == "stitched"
        if surface == "plastic":
            self.tint = principled("Tint", TINT_BASE, 0.3 if stitched else 0.2, coat=0.5)
        elif surface == "board":
            self.tint = principled("Tint", TINT_BASE, 0.6, coat=0.05 if stitched else 0.25)
            add_grain(self.tint, 0.1 if stitched else 0.04, cell_scale=140)
        else:
            self.tint = principled("Tint", TINT_BASE, 0.5 if stitched else 0.36, coat=0.15 if stitched else 0.45)
            add_grain(self.tint, 0.2 if stitched else 0.06)
        self.gold = principled("Gold", GOLD, 0.22, metallic=1.0)
        self.velvet = principled("Velvet", VELVET, 0.9, sheen=1.0)
        self.thread = principled("Thread", THREAD, 0.6, sheen=0.4)
        self.sleeve = principled("Sleeve", SLEEVE, 0.12, coat=0.6)
        self.paper = principled("Paper", PAPER, 0.8)
        self.shadow = principled("Recess", (0.02, 0.015, 0.03, 1), 0.9)


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, bm, mat, smooth=True):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    for poly in obj.data.polygons:
        poly.use_smooth = smooth
    obj.data.materials.append(mat)
    return obj


def bevel(obj, width, segments=4):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    return mod


def slab(name, size, location, mat, radius):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    obj = mesh_object(name, bm, mat)
    obj.location = location
    bevel(obj, radius, 4)
    return obj


def shell(name, size, location, mat, thickness, remove=("top",), top_scale=1.0):
    """A box with faces removed ("top"/"bottom"/"sides") and walls of `thickness`."""
    width, depth, height = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    doomed = []
    for face in bm.faces:
        z = face.calc_center_median().z
        if ("top" in remove and z > height / 2 - 1e-4) or ("bottom" in remove and z < -height / 2 + 1e-4):
            doomed.append(face)
    bmesh.ops.delete(bm, geom=doomed, context="FACES_ONLY")
    if top_scale != 1.0:
        for vert in bm.verts:
            if vert.co.z > 0:
                vert.co.x *= top_scale
                vert.co.y *= top_scale
    obj = mesh_object(name, bm, mat)
    obj.location = location
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = -1
    solid.use_even_offset = True
    bevel(obj, thickness * 0.45, 3)
    return obj


def sparkle(name, radius, location, mat, inner_ratio=0.28, thickness=0.035):
    """The four-pointed Lorcana sparkle, lying in the XZ plane facing −Y."""
    bm = bmesh.new()
    points = []
    for i in range(8):
        angle = math.pi / 2 + i * math.pi / 4
        r = radius if i % 2 == 0 else radius * inner_ratio
        points.append(bm.verts.new((r * math.cos(angle), 0, r * math.sin(angle))))
    face = bm.faces.new(points)
    extruded = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [v for v in extruded["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, thickness, 0), verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mesh_object(name, bm, mat)
    obj.location = location
    bevel(obj, thickness * 0.4, 3)
    return obj


def ring(name, radius, tube, location, mat):
    """A torus facing the camera (axis along Y)."""
    bpy.ops.mesh.primitive_torus_add(
        major_radius=radius, minor_radius=tube, major_segments=64, minor_segments=16,
        location=location, rotation=(math.pi / 2, 0, 0),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def frame_bars(name, center, size, bar, mat):
    """A rectangular frame of four bars on a front face (center is x, y, z)."""
    cx, y, cz = center
    width, height = size
    bm = bmesh.new()
    for dx, dz, sx, sz in (
        (0, height / 2, width + bar, bar), (0, -height / 2, width + bar, bar),
        (-width / 2, 0, bar, height), (width / 2, 0, bar, height),
    ):
        matrix = Matrix.Translation((cx + dx, y, cz + dz)) @ Matrix.Diagonal((sx, bar * 0.6, sz, 1))
        bmesh.ops.create_cube(bm, size=1.0, matrix=matrix)
    obj = mesh_object(name, bm, mat)
    bevel(obj, bar * 0.25, 2)
    return obj


def stitches(name, center, size, y, mat, spacing=0.075, dash=0.045, horizontal_only=False):
    """A dashed stitch line around a rectangle on a front face at depth `y`."""
    cx, cz = center
    width, height = size
    bm = bmesh.new()

    def run(x0, z0, x1, z1):
        length = math.hypot(x1 - x0, z1 - z0)
        count = max(1, int(length / spacing))
        along_x = abs(x1 - x0) > abs(z1 - z0)
        for i in range(count):
            t = (i + 0.5) / count
            x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
            scale = (dash, 0.012, 0.011) if along_x else (0.011, 0.012, dash)
            matrix = Matrix.Translation((x, y, z)) @ Matrix.Diagonal((*scale, 1))
            bmesh.ops.create_cube(bm, size=1.0, matrix=matrix)

    left, right = cx - width / 2, cx + width / 2
    bottom, top = cz - height / 2, cz + height / 2
    run(left, top, right, top)
    if not horizontal_only:
        run(left, bottom, right, bottom)
        run(left, bottom, left, top)
        run(right, bottom, right, top)
    obj = mesh_object(name, bm, mat)
    bevel(obj, 0.004, 1)
    return obj


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------


class Model:
    """What a kind builder returns: its parts and the 3D points the app needs."""

    def __init__(self):
        self.parts = {"base": []}
        self.anchors = {}

    def add(self, part, *objects):
        self.parts.setdefault(part, []).extend(objects)


def lidded_box(mats, finish, w, d, h, lid_h, overlap, grow=0.035, wall=0.06, lining_depth=0.35):
    """An open box with a velvet lining and a lid that sleeves over its top."""
    model = Model()
    model.add("base", shell("BaseShell", (w, d, h), (0, 0, h / 2), mats.tint, wall))
    model.add("base", slab("Lining", (w - wall * 2.2, d - wall * 2.2, 0.02), (0, 0, h - lining_depth), mats.velvet, 0.005))

    lid_w, lid_d = w + grow * 2, d + grow * 2
    lid_z = h - overlap + lid_h / 2
    model.add("lid", shell("LidShell", (lid_w, lid_d, lid_h), (0, 0, lid_z), mats.tint, wall, remove=("bottom",)))

    if finish == "stitched":
        inset = 0.08
        visible_h = h - overlap
        model.add("base", stitches("BaseStitch", (0, visible_h / 2), (w - inset * 2, visible_h - inset * 2), -d / 2 - 0.004, mats.thread))
        model.add("lid", stitches("LidStitch", (0, lid_z), (lid_w - inset * 2, lid_h - inset * 1.6), -lid_d / 2 - 0.004, mats.thread))

    model.anchors = {
        "lidHinge": (-lid_w / 2, -lid_d / 2, h - overlap),
        "rim": (0, -d / 2, h),
        "openingLeft": (-w / 2 + wall, -d / 2, h),
        "openingRight": (w / 2 - wall, -d / 2, h),
        "bottom": (0, -d / 2, 0),
    }
    model.dims = dict(w=w, d=d, h=h, lid_w=lid_w, lid_d=lid_d, lid_z=lid_z, lid_h=lid_h, overlap=overlap)
    return model


def build_trove(mats, finish):
    w, d, h = 2.4, 1.6, 1.0
    model = lidded_box(mats, finish, w, d, h, lid_h=0.36, overlap=0.26)
    m = model.dims
    model.add("base", sparkle("Crest", 0.3, (0, -d / 2 - 0.02, (h - m["overlap"]) / 2 + 0.02), mats.gold, thickness=0.035))
    model.add("base", slab("LockPlate", (0.26, 0.03, 0.16), (0, -d / 2 - 0.012, h - m["overlap"] - 0.09), mats.gold, 0.02))
    for sx in (-1, 1):
        for sy in (-1, 1):
            model.add("base", slab("Foot", (0.2, 0.2, 0.08), (sx * (w / 2 - 0.08), sy * (d / 2 - 0.08), -0.02), mats.gold, 0.03))
            model.add("lid", slab("LidCap", (0.2, 0.2, 0.2), (sx * (m["lid_w"] / 2 - 0.08), sy * (m["lid_d"] / 2 - 0.08), m["lid_z"] + m["lid_h"] / 2 - 0.08), mats.gold, 0.035))
    band = shell("LidBand", (m["lid_w"] + 0.012, m["lid_d"] + 0.012, 0.05), (0, 0, m["lid_z"] - m["lid_h"] / 2 + 0.035), mats.gold, 0.02, remove=("bottom",))
    band.modifiers["Bevel"].width = 0.008
    model.add("lid", band)
    model.add("lid", slab("Hasp", (0.16, 0.035, 0.2), (0, -m["lid_d"] / 2 - 0.018, m["lid_z"] - m["lid_h"] / 2 - 0.02), mats.gold, 0.03))
    return model


def build_deckbox(mats, finish):
    w, d, h = 1.3, 0.95, 1.75
    model = lidded_box(mats, finish, w, d, h, lid_h=0.6, overlap=0.48, lining_depth=0.2)
    m = model.dims
    center_z = (h - m["overlap"]) / 2 + 0.02
    model.add("base", ring("Emblem", 0.3, 0.028, (0, -d / 2 - 0.02, center_z), mats.gold))
    model.add("base", sparkle("EmblemStar", 0.2, (0, -d / 2 - 0.02, center_z), mats.gold, thickness=0.03))
    # A thin gold rule around the lid's lower edge.
    band = shell("LidBand", (m["lid_w"] + 0.01, m["lid_d"] + 0.01, 0.035), (0, 0, m["lid_z"] - m["lid_h"] / 2 + 0.03), mats.gold, 0.015, remove=("bottom",))
    band.modifiers["Bevel"].width = 0.006
    model.add("lid", band)
    return model


def build_storagebox(mats, finish):
    w, d, h = 3.8, 1.5, 1.05
    model = lidded_box(mats, finish, w, d, h, lid_h=0.34, overlap=0.26, wall=0.05, lining_depth=0.3)
    visible_mid = (h - model.dims["overlap"]) / 2
    front = -d / 2
    model.add("base", slab("Label", (1.05, 0.02, 0.44), (-w / 2 + 0.85, front - 0.008, visible_mid), mats.paper, 0.03))
    for i in (1, 2):
        model.add("base", slab("LabelRule", (0.85, 0.012, 0.012), (-w / 2 + 0.85, front - 0.02, visible_mid + 0.22 - i * 0.147), mats.shadow, 0.004))
    model.add("base", slab("Handle", (0.5, 0.02, 0.18), (w / 2 - 0.55, front - 0.004, visible_mid), mats.shadow, 0.08))
    model.add("base", sparkle("Mark", 0.16, (0, front - 0.02, visible_mid), mats.gold, thickness=0.025))
    return model


def build_otherbox(mats, finish):
    w, d, h = 1.9, 1.7, 1.35
    model = lidded_box(mats, finish, w, d, h, lid_h=0.42, overlap=0.32)
    m = model.dims
    model.add("base", sparkle("Mark", 0.32, (0, -d / 2 - 0.02, (h - m["overlap"]) / 2 + 0.02), mats.gold))
    band = shell("LidBand", (m["lid_w"] + 0.012, m["lid_d"] + 0.012, 0.05), (0, 0, m["lid_z"] - m["lid_h"] / 2 + 0.035), mats.gold, 0.02, remove=("bottom",))
    band.modifiers["Bevel"].width = 0.008
    model.add("lid", band)
    return model


def build_bulkbin(mats, finish):
    w, d, h, flare = 2.6, 1.5, 1.0, 1.1
    model = Model()
    wall = 0.05
    model.add("base", shell("Tray", (w, d, h), (0, 0, h / 2), mats.tint, wall, top_scale=flare))
    rim = shell("Rim", (w * flare + 0.1, d * flare + 0.1, 0.08), (0, 0, h - 0.02), mats.tint, 0.05, remove=("top", "bottom"))
    rim.modifiers["Bevel"].width = 0.02
    model.add("base", rim)
    model.add("base", slab("Floor", (w - 0.2, d - 0.2, 0.02), (0, 0, 0.06), mats.velvet, 0.005))
    front_mid_y = -(d * (1 + flare) / 4) - 0.02
    model.add("base", sparkle("Mark", 0.24, (0, front_mid_y - 0.01, h * 0.45), mats.gold, thickness=0.03))
    if finish == "stitched":
        model.add("base", stitches("RimStitch", (0, h - 0.16), (w * 1.02, 0), -(d * (1 + (flare - 1) * 0.84) / 2) - 0.03, mats.thread, horizontal_only=True))
    model.anchors = {
        "rim": (0, -(d * flare) / 2 - 0.05, h + 0.02),
        "openingLeft": (-w * flare / 2, -(d * flare) / 2, h),
        "openingRight": (w * flare / 2, -(d * flare) / 2, h),
        "bottom": (0, -d / 2, 0),
    }
    return model


BINDER = dict(w=2.0, h=2.56, t=0.5, spine=0.3)


def build_binder(mats, finish, cover_only=False):
    w, h, t, spine = BINDER["w"], BINDER["h"], BINDER["t"], BINDER["spine"]
    model = Model()
    left = -w / 2
    cover_w = w - spine * 0.5
    cover_cx = left + spine * 0.5 + cover_w / 2
    front_y = -t / 2 + 0.03
    face_y = front_y - 0.03

    model.add("base", slab("FrontCover", (cover_w, 0.06, h), (cover_cx, front_y, h / 2), mats.tint, 0.045))
    model.add("base", slab("Spine", (spine, t, h), (left + spine / 2, 0, h / 2), mats.tint, spine * 0.45))
    model.add("base", slab("Hinge", (0.035, 0.03, h * 0.97), (left + spine, face_y - 0.004, h / 2), mats.tint, 0.014))
    if not cover_only:
        model.add("base", slab("BackCover", (cover_w, 0.06, h), (cover_cx, t / 2 - 0.03, h / 2), mats.tint, 0.045))
        model.add("base", slab("Pages", (cover_w - 0.12, t - 0.16, h - 0.05), (cover_cx - 0.02, 0, h / 2 - 0.01), mats.sleeve, 0.02))

    # Gold corner guards on the open edge.
    for z in (0.09, h - 0.09):
        model.add("base", slab("Corner", (0.2, 0.08, 0.2), (left + w - 0.1, front_y, z), mats.gold, 0.03))

    # Label plate a quarter of the way down, emblem below it — where the app puts the name.
    plate_cx = left + spine + (w - spine) / 2
    plate = frame_bars("Plate", (plate_cx, face_y - 0.01, h * 0.75), (1.0, 0.36), 0.045, mats.gold)
    emblem = sparkle("Emblem", 0.3, (plate_cx, face_y - 0.018, h * 0.38), mats.gold, thickness=0.035)
    if cover_only:
        model.add("plate", plate)
        model.add("emblem", emblem)
    else:
        model.add("base", plate, emblem)

    if finish == "stitched":
        inset = 0.1
        stitch_w = w - spine - inset * 2
        model.add("base", stitches("CoverStitch", (left + spine + inset + stitch_w / 2, h / 2), (stitch_w, h - inset * 2), face_y - 0.004, mats.thread))
    model.anchors = {"bottom": (0, front_y, 0)}
    return model


def facing_spine(obj, location):
    """Turn a part built facing −Y (toward the front camera) to face −X, the spine side."""
    obj.location = location
    obj.rotation_euler = (0, 0, -math.pi / 2)
    return obj


def build_binderspine(mats, finish):
    """The binder seen spine-on, as it stands on a bookcase. Its name goes on the label."""
    model = build_binder(mats, finish, cover_only=False)
    # Keep only what the spine view sees; the cover ornaments face the other way.
    w, h, t = BINDER["w"], BINDER["h"], BINDER["t"]
    face_x = -w / 2 - 0.004
    for band_z in (h * 0.07, h * 0.93):
        model.add("base", facing_spine(slab("Band", (t * 0.84, 0.02, 0.06), (0, 0, 0), mats.gold, 0.01), (face_x, 0, band_z)))
    label_size = (t * 0.6, h * 0.5)
    label_z = h * 0.56
    model.add("base", facing_spine(frame_bars("SpineLabel", (0, 0, 0), label_size, 0.03, mats.gold), (face_x - 0.004, 0, label_z)))
    model.add("base", facing_spine(sparkle("SpineMark", 0.1, (0, 0, 0), mats.gold, thickness=0.025), (face_x - 0.004, 0, h * 0.18)))
    if finish == "stitched":
        model.add("base", facing_spine(stitches("SpineStitch", (0, h / 2), (t * 0.74, h * 0.96), 0, mats.thread, spacing=0.07, dash=0.04), (face_x, 0, 0)))
    # Label corners in world space, for placing the name.
    model.anchors = {
        "bottom": (face_x, 0, 0),
        "labelA": (face_x, label_size[0] / 2, label_z + label_size[1] / 2),
        "labelB": (face_x, -label_size[0] / 2, label_z - label_size[1] / 2),
    }
    return model


# ---------------------------------------------------------------------------
# Kinds
# ---------------------------------------------------------------------------

# aspect matches ContainerArtwork.aspectRatio(for:). headroom is the empty band left
# above the closed object for the lid to rise into (or cards to heap into).
KINDS = {
    "trove": dict(build=build_trove, aspect=1.2, headroom=0.3, elevation=13, lens=70, card_share=0.3),
    "deckbox": dict(build=build_deckbox, aspect=0.7, headroom=0.36, elevation=13, lens=70, card_share=0.42),
    "storagebox": dict(build=build_storagebox, aspect=1.8, headroom=0.32, elevation=13, lens=70, card_share=0.18),
    "otherbox": dict(build=build_otherbox, aspect=1.0, headroom=0.4, elevation=13, lens=70, card_share=0.3),
    "bulkbin": dict(build=build_bulkbin, aspect=1.5, headroom=0.36, elevation=16, lens=70, surface="plastic", card_share=0.24),
    "binder": dict(build=build_binder, aspect=0.78, headroom=0.02, elevation=7, lens=85),
    "bindercover": dict(build=lambda mats, finish: build_binder(mats, finish, cover_only=True), aspect=0.78, ortho=True, height=1400),  # fills a page on iPad
    "binderspine": dict(build=build_binderspine, aspect=0.2, ortho=True, view="side", height=900),
}
SURFACES = {"storagebox": "board"}


# ---------------------------------------------------------------------------
# Lights and camera
# ---------------------------------------------------------------------------


def all_objects(model, framing=False):
    """Every object in the model; for framing, leave out stitching so both finishes frame alike."""
    return [
        obj for objects in model.parts.values() for obj in objects
        if not (framing and obj.data.materials and obj.data.materials[0].name.startswith("Thread"))
    ]


def world_bounds(objects):
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        points += [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    return points


def setup_lights(model, side=False):
    points = world_bounds(all_objects(model, framing=True))
    center = sum(points, Vector((0, 0, 0))) / len(points)
    size = max((p - center).length for p in points) / 1.45     # 1.0 for the trove
    for name, offset, energy, spread, color in (
        ("Key", (-3.2, -4.2, 3.6), 260, 3.0, (1.0, 0.97, 0.92)),
        ("Fill", (4.0, -3.2, 1.0), 50, 4.0, (0.9, 0.93, 1.0)),
        ("Rim", (0.5, 3.5, 3.4), 180, 2.5, (1, 1, 1)),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy * size * size
        data.size = spread * size
        data.color = color
        obj = link(bpy.data.objects.new(name, data))
        if side:
            # Same rig, turned so "toward the camera" is −X instead of −Y.
            offset = (offset[1], -offset[0], offset[2])
        obj.location = center + Vector(offset) * size
        obj.rotation_euler = (center - obj.location).to_track_quat("-Z", "Y").to_euler()


def project(scene, cam, point):
    p = world_to_camera_view(scene, cam, Vector(point))
    return p.x, 1 - p.y


def setup_camera(scene, model, spec):
    data = bpy.data.cameras.new("Camera")
    cam = link(bpy.data.objects.new("Camera", data))
    scene.camera = cam
    points = world_bounds(all_objects(model, framing=True))
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = (lo + hi) / 2

    if spec.get("ortho"):
        # Straight on, the frame is exactly the front face.
        data.type = "ORTHO"
        # ortho_scale spans the frame's longer side.
        side = spec.get("view") == "side"
        width, height = (hi.y - lo.y) if side else (hi.x - lo.x), hi.z - lo.z
        if spec["aspect"] >= 1:
            data.ortho_scale = max(width, height * spec["aspect"])
        else:
            data.ortho_scale = max(height, width / spec["aspect"])
        if side:
            # Looking along +X at the spine; the front cover ends up on the right.
            cam.location = (lo.x - 10, center.y, center.z)
            cam.rotation_euler = (math.pi / 2, 0, -math.pi / 2)
        else:
            cam.location = (center.x, lo.y - 10, center.z)
            cam.rotation_euler = (math.pi / 2, 0, 0)
        return cam

    data.lens = spec["lens"]
    elevation = math.radians(spec["elevation"])
    direction = Vector((0, -math.cos(elevation), math.sin(elevation)))
    distance = 10.0
    headroom, bottom_target, width_target = spec["headroom"], 0.965, 0.92
    for _ in range(12):
        cam.location = center + direction * distance
        cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        bpy.context.view_layer.update()
        projected = [project(scene, cam, p) for p in points]
        xs, ys = [p[0] for p in projected], [p[1] for p in projected]
        scale = max((max(xs) - min(xs)) / width_target, (max(ys) - min(ys)) / (bottom_target - headroom))
        distance *= scale
        # Slide the frame so the object's base sits on the bottom margin.
        frame_ratio = scene.render.resolution_y / max(scene.render.resolution_x, scene.render.resolution_y)
        data.shift_y -= (max(ys) - bottom_target) * frame_ratio
    return cam


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------


def render(scene, path, samples, denoise):
    scene.cycles.samples = samples
    scene.cycles.use_denoising = denoise
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def emission_material(name, holdout):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    if holdout:
        shader = nodes.new("ShaderNodeHoldout")
    else:
        shader = nodes.new("ShaderNodeEmission")
        shader.inputs["Color"].default_value = (1, 1, 1, 1)
    mat.node_tree.links.new(shader.outputs[0], out.inputs[0])
    return mat


def render_mask(scene, path, objects, tint):
    """White where the tintable material is, holdout everywhere else."""
    white, hole = emission_material("MaskWhite", False), emission_material("MaskHoldout", True)
    originals = {obj: obj.data.materials[0] for obj in objects}
    for obj, mat in originals.items():
        obj.data.materials[0] = white if mat == tint else hole
    render(scene, path, MASK_SAMPLES, denoise=False)
    for obj, mat in originals.items():
        obj.data.materials[0] = mat


def show_only(model, part):
    for name, objects in model.parts.items():
        for obj in objects:
            obj.hide_render = name != part


def metrics_for(scene, cam, model, spec):
    """Frame positions the app needs, 0–1 with a top-left origin."""
    def point(key):
        return project(scene, cam, model.anchors[key])

    metrics = {"bottomY": point("bottom")[1]} if "bottom" in model.anchors else {}
    if "labelA" in model.anchors:
        (ax, ay), (bx, by) = point("labelA"), point("labelB")
        metrics.update(labelX=min(ax, bx), labelY=min(ay, by), labelWidth=abs(bx - ax), labelHeight=abs(by - ay))
    if "rim" in model.anchors:
        metrics["rimY"] = point("rim")[1]
        metrics["openingLeft"] = point("openingLeft")[0]
        metrics["openingRight"] = point("openingRight")[0]
    if "lid" in model.parts:
        hinge = point("lidHinge")
        lid_points = [project(scene, cam, p) for p in world_bounds(model.parts["lid"])]
        lid_top = min(p[1] for p in lid_points)
        lid_width = max(p[0] for p in lid_points) - min(p[0] for p in lid_points)
        # Tipping raises the far end of the lid; keep that clear of the top edge too.
        tip = lid_width * spec["aspect"] * math.sin(math.radians(LID_TILT_DEGREES))
        lid_rise = max(0.08, lid_top - tip - 0.015)
        metrics.update(lidHingeX=hinge[0], lidHingeY=hinge[1], lidRise=lid_rise)
        metrics["cardPeakY"] = hinge[1] - lid_rise + 0.02
    if "card_share" in spec and "rimY" in metrics:
        opening = metrics["openingRight"] - metrics["openingLeft"]
        width = opening * spec["card_share"]
        # A card must still reach below the rim at full rise, and fit above it in a heap.
        to_height = spec["aspect"] * 88 / 63
        peak = metrics.get("cardPeakY", 0.04)
        room = metrics["bottomY"] - peak
        width = min(width, room / to_height)
        if "lid" not in model.parts:
            width = min(width, (metrics["rimY"] - 0.03) / (0.72 * to_height))
        metrics["cardWidth"] = width
    return {key: round(value, 4) for key, value in metrics.items()}


def render_kind(kind):
    spec = KINDS[kind]
    base_metrics = None
    for finish in ("classic", "stitched"):
        scene = reset_scene(spec["aspect"], spec.get("height", FRAME_HEIGHT))
        mats = Materials(finish, SURFACES.get(kind, spec.get("surface", "leather")))
        model = spec["build"](mats, finish)
        setup_lights(model, side=spec.get("view") == "side")
        cam = setup_camera(scene, model, spec)
        for part in model.parts:
            if part in ("plate", "emblem"):
                if finish == "classic":
                    show_only(model, part)
                    render(scene, OUT_DIR / f"{kind}_{part}.png", SHADE_SAMPLES, denoise=True)
                continue
            show_only(model, part)
            render(scene, OUT_DIR / f"{kind}_{part}_{finish}_shade.png", SHADE_SAMPLES, denoise=True)
            render_mask(scene, OUT_DIR / f"{kind}_{part}_{finish}_mask.png", model.parts[part], mats.tint)
        if finish == "classic":
            base_metrics = metrics_for(scene, cam, model, spec)
    (OUT_DIR / f"{kind}_metrics.json").write_text(json.dumps(base_metrics, indent=2))
    print(kind, json.dumps(base_metrics))


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for kind in ONLY_KINDS or KINDS:
        render_kind(kind)


main()
