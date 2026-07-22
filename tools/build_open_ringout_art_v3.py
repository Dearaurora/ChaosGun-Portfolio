"""Build P32's isolated Open Ring-Out visual quality-jump asset pack.

This is intentionally a visual-only comparison deliverable.  It preserves the
existing gameplay footprint in world space, but does not contain collision,
spawns, characters, cameras, or runtime logic.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "assets" / "source" / "open_ringout_art_v3"
MODEL_DIR = ROOT / "assets" / "models" / "generated" / "open_ringout_art_v3"
TEXTURE_DIR = ROOT / "assets" / "textures" / "generated" / "open_ringout_art_v3"
BLEND_PATH = SOURCE_DIR / "open_ringout_art_v3.blend"
GLB_PATH = MODEL_DIR / "open_ringout_art_v3.glb"
PREVIEW_PATH = TEXTURE_DIR / "open_ringout_art_v3_preview.png"
MANIFEST_PATH = SOURCE_DIR / "open_ringout_art_v3_manifest.json"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


def make_collection(name: str, parent: bpy.types.Collection | None = None) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(collection)
    return collection


def make_root(name: str, collection: bpy.types.Collection, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def material(name: str, color: str, roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    value = color.lstrip("#")
    rgb = tuple(int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4))
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def materials() -> dict[str, bpy.types.Material]:
    return {
        "deck": material("M_P32_HoneyOrangeDeck", "#E77A28", 0.62),
        "deck_gold": material("M_P32_GoldenDeckHighlight", "#FFB447", 0.54),
        "deck_seam": material("M_P32_DeckSeam", "#9F4729", 0.77),
        "warm_band": material("M_P32_WarmCoralBand", "#A94538", 0.74),
        "cliff_deep": material("M_P32_CoolPlumDeep", "#1F1A3A", 0.91),
        "cliff_mid": material("M_P32_CoolPlumMid", "#3B2D61", 0.88),
        "cliff_light": material("M_P32_CoolPlumLight", "#5A477E", 0.85),
        "bridge": material("M_P32_BridgeWood", "#A85732", 0.71),
        "bridge_trim": material("M_P32_BridgeTrim", "#F0B764", 0.49),
        "post": material("M_P32_BridgePost", "#874B5D", 0.63),
        "cloud": material("M_P32_SingleLayerCloud", "#F3AEAF", 0.97),
        "balloon": material("M_P32_BalloonPlum", "#733D9B", 0.53),
        "balloon_band": material("M_P32_BalloonGold", "#F3A13B", 0.41, 0.08),
        "basket": material("M_P32_Basket", "#8C5037", 0.82),
    }


def rounded_rect_outline(center: tuple[float, float], size: tuple[float, float], radius: float, segments: int = 7) -> list[tuple[float, float]]:
    cx, cy = center
    sx, sy = size
    radius = min(radius, sx * 0.48, sy * 0.48)
    corners = (
        (cx + sx * 0.5 - radius, cy - sy * 0.5 + radius, -90.0, 0.0),
        (cx + sx * 0.5 - radius, cy + sy * 0.5 - radius, 0.0, 90.0),
        (cx - sx * 0.5 + radius, cy + sy * 0.5 - radius, 90.0, 180.0),
        (cx - sx * 0.5 + radius, cy - sy * 0.5 + radius, 180.0, 270.0),
    )
    points = []
    for x, y, start, end in corners:
        for index in range(segments):
            angle = math.radians(start + (end - start) * index / float(segments))
            points.append((x + math.cos(angle) * radius, y + math.sin(angle) * radius))
    return points


def smooth_outline(points: list[tuple[float, float]], amount: float = 0.16, iterations: int = 2) -> list[tuple[float, float]]:
    result = list(points)
    for _ in range(iterations):
        next_points = []
        for index, start in enumerate(result):
            end = result[(index + 1) % len(result)]
            next_points.append((start[0] * (1.0 - amount) + end[0] * amount, start[1] * (1.0 - amount) + end[1] * amount))
            next_points.append((start[0] * amount + end[0] * (1.0 - amount), start[1] * amount + end[1] * (1.0 - amount)))
        result = next_points
    return result


def scale_outline(points: list[tuple[float, float]], center: tuple[float, float], scale: float) -> list[tuple[float, float]]:
    cx, cy = center
    return [(cx + (x - cx) * scale, cy + (y - cy) * scale) for x, y in points]


def create_mesh(name: str, vertices: list[tuple[float, float, float]], faces: list[tuple[int, ...]], collection: bpy.types.Collection, parent: bpy.types.Object, mats: list[bpy.types.Material], material_indices: list[int] | None = None, bevel: float = 0.0) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    for mat in mats:
        mesh.materials.append(mat)
    if material_indices:
        for polygon, index in zip(mesh.polygons, material_indices):
            polygon.material_index = index
    if bevel > 0.0:
        modifier = obj.modifiers.new("ToySoftEdge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = "ANGLE"
    return obj


def create_deck_shell(name: str, outline: list[tuple[float, float]], top_z: float, depth: float, parent: bpy.types.Object, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    count = len(outline)
    lower = scale_outline(outline, centroid(outline), 0.987)
    vertices = [(x, y, top_z - depth) for x, y in lower] + [(x, y, top_z) for x, y in outline]
    faces: list[tuple[int, ...]] = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    indices = [0, 0]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
        indices.append(1 if index % 6 in (0, 1) else 0)
    return create_mesh(name, vertices, faces, collection, parent, [mats["deck"], mats["deck_gold"]], indices, 0.16)


def create_continuous_underside(name: str, outline: list[tuple[float, float]], top_z: float, depth: float, center: tuple[float, float], parent: bpy.types.Object, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material], tip_offset: tuple[float, float]) -> bpy.types.Object:
    count = len(outline)
    # Keep broad, readable silhouette rings before tapering into the lower point.
    scales = (0.994, 0.968, 0.875, 0.735, 0.52)
    heights = (top_z, top_z - depth * 0.16, top_z - depth * 0.43, top_z - depth * 0.74, top_z - depth * 0.94)
    vertices: list[tuple[float, float, float]] = []
    for ring, (scale, height) in enumerate(zip(scales, heights)):
        ring_points = scale_outline(outline, center, scale)
        for index, (x, y) in enumerate(ring_points):
            angle = math.atan2(y - center[1], x - center[0])
            wobble = (math.sin(angle * 3.0 + ring) * 0.18 + math.cos(angle * 5.0 - ring) * 0.11) * ring / 4.0
            vertices.append((x + math.cos(angle) * wobble, y + math.sin(angle) * wobble, height))
    tip = len(vertices)
    vertices.append((center[0] + tip_offset[0], center[1] + tip_offset[1], top_z - depth * 1.18))
    faces: list[tuple[int, ...]] = []
    indices: list[int] = []
    for ring in range(len(scales) - 1):
        for index in range(count):
            next_index = (index + 1) % count
            faces.append((ring * count + index, ring * count + next_index, (ring + 1) * count + next_index, (ring + 1) * count + index))
            indices.append(2 if ring == 0 and index % 5 == 0 else (1 if ring < 3 else 0))
    last = (len(scales) - 1) * count
    for index in range(count):
        faces.append((tip, last + (index + 1) % count, last + index))
        indices.append(0)
    return create_mesh(name, vertices, faces, collection, parent, [mats["cliff_deep"], mats["cliff_mid"], mats["cliff_light"]], indices, 0.10)


def centroid(points: list[tuple[float, float]]) -> tuple[float, float]:
    return (sum(x for x, _ in points) / len(points), sum(y for _, y in points) / len(points))


def add_box(name: str, location: tuple[float, float, float], size: tuple[float, float, float], mat: bpy.types.Material, collection: bpy.types.Collection, parent: bpy.types.Object, bevel: float = 0.16) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    modifier = obj.modifiers.new("ToySoftEdge", "BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    return obj


def add_cylinder(name: str, location: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material, collection: bpy.types.Collection, parent: bpy.types.Object, vertices: int = 24) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    modifier = obj.modifiers.new("ToySoftEdge", "BEVEL")
    modifier.width = min(radius * 0.18, depth * 0.20)
    modifier.segments = 3
    return obj


def add_sphere(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material, collection: bpy.types.Collection, parent: bpy.types.Object) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def main_outline() -> list[tuple[float, float]]:
    points = rounded_rect_outline((0.0, 0.0), (59.0, 37.0), 6.8, 8)
    # Gentle lobe offsets preserve the current topology while making the contour feel authored.
    result = []
    for x, y in points:
        result.append((x + (1.25 if x > 19.0 and -4.0 < y < 10.0 else (-0.95 if x < -19.0 and 2.0 < y < 13.0 else 0.0)), y))
    return smooth_outline(result, 0.13, 1)


def island_root(name: str, center: tuple[float, float], size: tuple[float, float], depth: float, tip: tuple[float, float], root: bpy.types.Object, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> bpy.types.Object:
    island = make_root(name, collection, root)
    outline = rounded_rect_outline(center, size, min(size) * 0.27, 8)
    outline = smooth_outline(outline, 0.12, 1)
    create_continuous_underside(f"{name}_ContinuousUnderside", outline, -0.68, depth, center, island, collection, mats, tip)
    create_deck_shell(f"{name}_DeckShell", outline, 0.62, 1.36, island, collection, mats)
    create_deck_shell(f"{name}_WarmBand", scale_outline(outline, center, 1.008), -0.43, 0.58, island, collection, {**mats, "deck": mats["warm_band"], "deck_gold": mats["warm_band"]})
    return island


def add_deck_seams(parent: bpy.types.Object, center: tuple[float, float], size: tuple[float, float], collection: bpy.types.Collection, mats: dict[str, bpy.types.Material], prefix: str) -> None:
    cx, cy = center
    sx, sy = size
    for index, offset in enumerate((-0.25, 0.25)):
        add_box(f"{prefix}_DeckSeamX_{index}", (cx + sx * offset, cy, 0.655), (0.065, sy * 0.68, 0.035), mats["deck_seam"], collection, parent, 0.015)
    add_box(f"{prefix}_DeckSeamY", (cx, cy, 0.655), (sx * 0.72, 0.065, 0.035), mats["deck_seam"], collection, parent, 0.015)


def add_socket(name: str, location: tuple[float, float], axis: str, parent: bpy.types.Object, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    root = make_root(name, collection, parent)
    x, y = location
    if axis == "x":
        bed_size, beam_size, rail_size = (5.4, 7.3, 0.34), (3.8, 0.46, 0.74), (0.22, 7.3, 0.18)
        offsets = ((0.0, -3.65), (0.0, 3.65))
    else:
        bed_size, beam_size, rail_size = (7.3, 5.4, 0.34), (0.46, 3.8, 0.74), (7.3, 0.22, 0.18)
        offsets = ((-3.65, 0.0), (3.65, 0.0))
    add_box(f"{name}_SocketBed", (x, y, 0.30), bed_size, mats["bridge"], collection, root, 0.14)
    inset_size = (4.7, 6.1, 0.18) if axis == "x" else (6.1, 4.7, 0.18)
    add_box(f"{name}_SocketInsetDeck", (x, y, 0.70), inset_size, mats["bridge_trim"], collection, root, 0.10)
    if axis == "x":
        transition_size = (4.5, 0.28, 0.22)
        transition_offsets = ((0.0, -3.54), (0.0, 3.54))
        support_size = (1.05, 1.05, 0.34)
    else:
        transition_size = (0.28, 4.5, 0.22)
        transition_offsets = ((-3.54, 0.0), (3.54, 0.0))
        support_size = (1.05, 1.05, 0.34)
    for index, (dx, dy) in enumerate(transition_offsets):
        add_box(f"{name}_InsetEdge_{index}", (x + dx, y + dy, 0.54), transition_size, mats["deck_seam"], collection, root, 0.06)
    for index, (dx, dy) in enumerate(offsets):
        add_box(f"{name}_LandingSupport_{index}", (x + dx, y + dy, 0.53), support_size, mats["cliff_deep"], collection, root, 0.10)
        add_box(f"{name}_LandingPost_{index}", (x + dx, y + dy, 1.04), beam_size, mats["post"], collection, root, 0.16)
    for index, offset in enumerate((-0.90, 0.90)):
        position = (x + (-1.35, 1.35)[index], y, 0.84) if axis == "x" else (x, y + (-1.35, 1.35)[index], 0.84)
        add_box(f"{name}_LandingPlank_{index}", position, (1.80, 6.85, 0.22) if axis == "x" else (6.85, 1.80, 0.22), mats["bridge_trim"], collection, root, 0.08)
    add_box(f"{name}_Backstop", (x, y, 0.91), rail_size, mats["bridge_trim"], collection, root, 0.07)


def add_cloud_bank(name: str, location: tuple[float, float, float], scale: float, parent: bpy.types.Object, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    cloud = make_root(name, collection, parent)
    for index, (dx, dy, dz, radius) in enumerate(((-1.1, 0.1, 0.0, 0.84), (-0.35, -0.12, 0.12, 1.05), (0.55, 0.04, 0.03, 0.92), (1.22, 0.18, -0.04, 0.66))):
        add_sphere(f"{name}_Puff_{index}", (location[0] + dx * scale, location[1] + dy * scale, location[2] + dz * scale), (radius * scale, radius * scale * 0.48, radius * scale * 0.58), mats["cloud"], collection, cloud)


def add_balloon(parent: bpy.types.Object, collection: bpy.types.Collection, mats: dict[str, bpy.types.Material]) -> None:
    balloon = make_root("P32_HotAirBalloon", collection, parent)
    add_sphere("P32_HotAirBalloon_Envelope", (50.0, -22.0, 13.0), (2.8, 2.8, 3.9), mats["balloon"], collection, balloon)
    for index, angle in enumerate((0.0, math.pi * 0.5, math.pi, math.pi * 1.5)):
        x = 50.0 + math.cos(angle) * 2.3
        y = -22.0 + math.sin(angle) * 2.3
        add_cylinder(f"P32_HotAirBalloon_Seam_{index}", (x, y, 13.0), 0.15, 7.15, mats["balloon_band"], collection, balloon, 16)
    add_box("P32_HotAirBalloon_Basket", (50.0, -22.0, 7.2), (1.8, 1.5, 1.1), mats["basket"], collection, balloon, 0.16)


def build_art_pack() -> tuple[bpy.types.Collection, dict[str, bpy.types.Material]]:
    clear_scene()
    visual_collection = make_collection("P32_OPEN_RINGOUT_ART_V3")
    root = make_root("P32_OpenRingoutArtV3", visual_collection)
    mats = materials()

    main = make_root("P32_MainIsland", visual_collection, root)
    outline = main_outline()
    create_continuous_underside("P32_MainIsland_ContinuousUnderside", outline, -0.68, 10.4, (0.0, 0.0), main, visual_collection, mats, (0.45, -0.35))
    create_deck_shell("P32_MainIsland_DeckShell", outline, 0.62, 1.36, main, visual_collection, mats)
    create_deck_shell("P32_MainIsland_WarmBand", scale_outline(outline, (0.0, 0.0), 1.008), -0.43, 0.58, main, visual_collection, {**mats, "deck": mats["warm_band"], "deck_gold": mats["warm_band"]})
    add_deck_seams(main, (0.0, 0.0), (54.0, 32.0), visual_collection, mats, "P32_MainIsland")

    outer_specs = (
        ("P32_OuterIsland_North", (4.0, -30.0), (22.0, 15.0), 9.6, (-0.5, 0.2)),
        ("P32_OuterIsland_East", (41.75, 3.0), (12.5, 18.0), 9.2, (0.4, -0.3)),
        ("P32_OuterIsland_South", (9.0, 30.0), (24.0, 16.0), 9.7, (-0.3, -0.4)),
        ("P32_OuterIsland_West", (-41.55, 2.0), (12.9, 20.0), 9.3, (0.4, 0.3)),
    )
    for name, center, size, depth, tip in outer_specs:
        island = island_root(name, center, size, depth, tip, root, visual_collection, mats)
        add_deck_seams(island, center, size, visual_collection, mats, name)

    socket_specs = (
        ("P32_BridgeSocket_MainNorth", (4.0, -18.1), "y"), ("P32_BridgeSocket_OuterNorth", (4.0, -22.5), "y"),
        ("P32_BridgeSocket_MainEast", (29.9, 2.0), "x"), ("P32_BridgeSocket_OuterEast", (35.8, 2.0), "x"),
        ("P32_BridgeSocket_MainSouth", (7.0, 18.0), "y"), ("P32_BridgeSocket_OuterSouth", (7.0, 22.4), "y"),
        ("P32_BridgeSocket_MainWest", (-28.0, 2.0), "x"), ("P32_BridgeSocket_OuterWest", (-35.6, 2.0), "x"),
    )
    for name, position, axis in socket_specs:
        add_socket(name, position, axis, root, visual_collection, mats)

    background = make_root("P32_BackgroundDressing", visual_collection, root)
    for spec in (
        ("P32_CloudLayer_West", (-40.0, -17.0, -7.2), 4.7),
        ("P32_CloudLayer_South", (-3.0, 39.0, -8.5), 5.2),
        ("P32_CloudLayer_East", (42.0, 22.0, -7.6), 4.4),
        ("P32_CloudLayer_North", (18.0, -48.0, -7.0), 4.2),
    ):
        add_cloud_bank(*spec, background, visual_collection, mats)
    add_balloon(background, visual_collection, mats)
    return visual_collection, mats


def setup_preview_camera() -> None:
    preview = make_collection("P32_PREVIEW_ONLY")
    bpy.ops.object.camera_add(location=(63.0, 74.0, 86.0))
    camera = bpy.context.object
    camera.name = "P32_PreviewCamera"
    for existing in list(camera.users_collection):
        existing.objects.unlink(camera)
    preview.objects.link(camera)
    camera.data.lens = 48
    bpy.context.scene.camera = camera
    target = (0.0, 0.0, -2.0)
    direction = mathutils.Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    for name, location, energy, color, size in (
        ("P32_Key", (-26.0, -30.0, 58.0), 22000.0, (1.0, 0.49, 0.25), 22.0),
        ("P32_Fill", (40.0, 30.0, 42.0), 14000.0, (0.36, 0.43, 1.0), 20.0),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        for existing in list(light.users_collection):
            existing.objects.unlink(light)
        preview.objects.link(light)
        light.rotation_euler = (mathutils.Vector(target) - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.object.light_add(type="SUN", location=(0.0, 0.0, 40.0))
    sun = bpy.context.object
    sun.name = "P32_SunsetRim"
    sun.data.energy = 2.2
    sun.data.color = (1.0, 0.58, 0.34)
    sun.rotation_euler = (math.radians(28.0), math.radians(-22.0), math.radians(-32.0))
    for existing in list(sun.users_collection):
        existing.objects.unlink(sun)
    preview.objects.link(sun)
    scene = bpy.context.scene
    # Blender 5.1 exposes the current Eevee renderer as BLENDER_EEVEE.
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1536
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.10, 0.07, 0.26, 1.0)
    background.inputs["Strength"].default_value = 0.52
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 1.4


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def export_visual_collection(collection: bpy.types.Collection) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        if obj.type in {"MESH", "EMPTY"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = next(obj for obj in collection.all_objects if obj.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_materials="EXPORT")


def write_manifest(collection: bpy.types.Collection) -> None:
    manifest = {
        "schema_version": 1,
        "asset": "open_ringout_art_v3",
        "purpose": "P32 isolated visual-only comparison pack; no collision or runtime integration",
        "units": "Blender units aligned to existing Open Ring-Out world coordinates; Z-up source, Y-up GLB export",
        "roots": ["P32_OpenRingoutArtV3", "P32_MainIsland", "P32_OuterIsland_North", "P32_OuterIsland_East", "P32_OuterIsland_South", "P32_OuterIsland_West", "P32_BackgroundDressing"],
        "bridge_socket_roots": [name for name in sorted(obj.name for obj in collection.all_objects if obj.name.startswith("P32_BridgeSocket_"))],
        "materials": sorted(material.name for material in bpy.data.materials),
        "constraints": {"visual_only": True, "collision_in_glb": False, "cloud_layers": 1, "runtime_integration": False},
        "source_blend": str(BLEND_PATH.relative_to(ROOT)).replace("\\", "/"),
        "export_glb": str(GLB_PATH.relative_to(ROOT)).replace("\\", "/"),
        "preview": str(PREVIEW_PATH.relative_to(ROOT)).replace("\\", "/"),
        "hashes": {
            "source_blend_sha256": sha256(BLEND_PATH),
            "export_glb_sha256": sha256(GLB_PATH),
            "preview_sha256": sha256(PREVIEW_PATH),
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    for directory in (SOURCE_DIR, MODEL_DIR, TEXTURE_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    visual_collection, _mats = build_art_pack()
    setup_preview_camera()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.context.scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)
    export_visual_collection(visual_collection)
    if not GLB_PATH.is_file() or GLB_PATH.stat().st_size < 4096:
        raise RuntimeError(f"GLB export failed: {GLB_PATH}")
    write_manifest(visual_collection)
    print(f"Saved source: {BLEND_PATH}")
    print(f"Exported visual-only GLB: {GLB_PATH}")
    print(f"Rendered comparison preview: {PREVIEW_PATH}")
    print(f"Wrote manifest: {MANIFEST_PATH}")


if __name__ == "__main__":
    import mathutils

    main()
