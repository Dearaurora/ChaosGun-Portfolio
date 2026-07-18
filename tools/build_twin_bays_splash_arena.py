"""Rebuild the Twin Bays Splash Arena foreground from the canonical layout JSON.

Run with Blender 5.1:
    blender --background --python-exit-code 1 --python tools/build_twin_bays_splash_arena.py

The generated GLBs are visual-only.  Gameplay collision, portals, characters,
weapons, lights, cameras, and the animated backdrop remain Godot-owned.
"""

from __future__ import annotations

import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import tessellate_polygon


ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = ROOT / "resources" / "maps" / "twin_bays_layout_v1.json"
SOURCE_DIR = ROOT / "assets" / "source" / "twin_bays_splash_arena"
GENERATED_DIR = ROOT / "assets" / "models" / "generated" / "twin_bays_splash_arena"
PREVIEW_DIR = ROOT / "docs" / "art-direction" / "previews"
TEXTURE_DIR = ROOT / "assets" / "textures" / "generated" / "twin_bays_splash_arena"

BLEND_PATH = SOURCE_DIR / "twin_bays_splash_arena.blend"
HERO_GLB_PATH = GENERATED_DIR / "twin_bays_splash_arena_hero_kit.glb"
FOREGROUND_GLB_PATH = GENERATED_DIR / "twin_bays_splash_arena_foreground.glb"
HERO_PREVIEW_PATH = PREVIEW_DIR / "twin_bays_splash_arena_hero_kit.png"
FOREGROUND_PREVIEW_PATH = PREVIEW_DIR / "twin_bays_splash_arena_foreground.png"
MANIFEST_PATH = GENERATED_DIR / "twin_bays_splash_arena_manifest.json"

SCHEMA = "chaos_gun.twin_bays_layout"
SCHEMA_VERSION = 1
MAX_PRIMARY_MATERIALS = 12
SAFETY_TRIM_VISIBLE_WIDTH = 0.38
SAFETY_TRIM_RADIUS = SAFETY_TRIM_VISIBLE_WIDTH * 0.5
SAFETY_TRIM_LIFT = 0.02
DRY_TOP_DEPTH = 0.12
TRIM_BLOCKER_CLEARANCE = 0.12

# These values are mirrored by the Godot portal VFX.  The builder validates
# their worst-case animated envelope against every authored pipe aperture.
PORTAL_RING_SCALE_MULTIPLIER = 0.88
PORTAL_RING_PULSE_AMPLITUDE = 0.018
PORTAL_FOAM_OUTER_RADIUS_MULTIPLIER = 1.12
PORTAL_FOAM_PULSE_AMPLITUDE = 0.026
PORTAL_INNER_FOAM_OUTER_RADIUS_MULTIPLIER = 1.04
PORTAL_CORE_SCALE_MULTIPLIER = 0.92

MIN_WALL_PIPE_CLEARANCE = 0.75
MAX_SOUTH_WALL_BOUNDARY_GAP = 0.12
MIN_PORTAL_APERTURE_CLEARANCE = 0.20
MIN_PIPE_BEND_RADIUS = 8.85
MIN_TRIM_BLOCKER_CLEARANCE = 0.08
MIN_PORTAL_MOUTH_PLATFORM_INSET = 0.25
MAX_PORTAL_MOUTH_PLATFORM_INSET = 0.50

COLOR_CONTRACT = {
    "dry_cream": "#F4EFE7",
    "cyan": "#4FC5D8",
    "coral": "#FF8F82",
    "safety_yellow": "#FFD54A",
    "pickup_orange": "#FF8A3D",
    "portal_cyan": "#36D9FF",
}

# Supporting shades stay within the same clean, toy-like palette.
SUPPORT_COLORS = {
    "cyan_dark": "#178DA8",
    "portal_recess": "#176E88",
}

PBR_TEXTURE_SPECS = {
    "dry_cream": {
        "base_hex": COLOR_CONTRACT["dry_cream"],
        "resolution": 2048,
        "panel_count": 4,
        "seam_width": 7,
        "roughness": 0.78,
        "roughness_seam": 0.86,
        "variation": 0.016,
        "seam_darkening": 0.035,
        "normal_strength": 2.2,
        "uv_world_scale": 16.0,
        "surface_style": "dry_large_resin_tile",
    },
    "cyan": {
        "base_hex": COLOR_CONTRACT["cyan"],
        "resolution": 1024,
        "panel_count": 4,
        "seam_width": 5,
        "roughness": 0.60,
        "roughness_seam": 0.69,
        "variation": 0.020,
        "seam_darkening": 0.045,
        "normal_strength": 2.8,
        "uv_world_scale": 8.0,
        "surface_style": "clean_aqua_tile",
    },
    "cyan_dark": {
        "base_hex": SUPPORT_COLORS["cyan_dark"],
        "resolution": 1024,
        "panel_count": 4,
        "seam_width": 5,
        "roughness": 0.72,
        "roughness_seam": 0.80,
        "variation": 0.014,
        "seam_darkening": 0.040,
        "normal_strength": 2.4,
        "uv_world_scale": 9.0,
        "surface_style": "clean_structural_side_tile",
    },
    "coral": {
        "base_hex": COLOR_CONTRACT["coral"],
        "resolution": 1024,
        "panel_count": 4,
        "seam_width": 7,
        "roughness": 0.66,
        "roughness_seam": 0.74,
        "variation": 0.014,
        "seam_darkening": 0.025,
        "normal_strength": 1.8,
        "uv_world_scale": 10.0,
        "surface_style": "broad_soft_padding",
        "soft_bulge": True,
    },
}

FORBIDDEN_NAME_TOKENS = ("wet", "puddle", "waterstain", "decal")


def srgb_channel_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def srgb_rgba(hex_color: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    """Return display-referred values for an 8-bit sRGB image payload."""
    value = hex_color.lstrip("#")
    return tuple(int(value[index : index + 2], 16) / 255.0 for index in (0, 2, 4)) + (alpha,)


def rgba(hex_color: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    srgb = srgb_rgba(hex_color, alpha)[:3]
    return tuple(srgb_channel_to_linear(channel) for channel in srgb) + (alpha,)


def load_layout() -> dict:
    if not LAYOUT_PATH.is_file():
        raise FileNotFoundError(f"Canonical Twin Bays layout is missing: {LAYOUT_PATH}")
    with LAYOUT_PATH.open("r", encoding="utf-8") as handle:
        layout = json.load(handle)
    if layout.get("schema") != SCHEMA or layout.get("version") != SCHEMA_VERSION:
        raise ValueError(
            f"Unsupported layout schema/version: {layout.get('schema')!r} v{layout.get('version')!r}"
        )
    if layout.get("units") != {
        "distance": "godot_world_units",
        "plane": "xz",
        "rotation": "yaw_degrees",
    }:
        raise ValueError("Twin Bays builder requires Godot xz/yaw-degrees layout units")
    required_counts = {
        "platform_outline": (len(layout["platform"]["outline"]), 116),
        "production_visual_outline": (len(layout["platform"]["production_visual_outline"]), 108),
        "walls": (len(layout["walls"]), 4),
        "wall_sections": (sum(len(wall["sections"]) for wall in layout["walls"]), 6),
        "portal_pipes": (len(layout["portal_pipes"]), 2),
        "covers": (len(layout["covers"]), 10),
        "spawns": (len(layout["spawns"]), 4),
        "pickup_markers": (len(layout["pickup_markers"]), 4),
        "special_pickup_marker": (1 if isinstance(layout.get("special_pickup_marker"), dict) else 0, 1),
        "portals": (len(layout["portals"]), 2),
    }
    failures = [f"{name}={actual}, expected {expected}" for name, (actual, expected) in required_counts.items() if actual != expected]
    if failures:
        raise ValueError("Layout cardinality contract failed: " + "; ".join(failures))
    causeway = layout["platform"]["causeway"]
    if float(causeway["safe_width"]) < float(causeway["visible_width"]):
        raise ValueError("Causeway safe width cannot be smaller than its whitebox visible width")
    return layout


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.worlds,
    ):
        for block in list(datablocks):
            datablocks.remove(block)
    for collection in list(bpy.data.collections):
        if collection != bpy.context.scene.collection:
            bpy.data.collections.remove(collection)


def make_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    collection.objects.link(obj)


def _save_generated_texture(
    name: str,
    path: Path,
    pixels: np.ndarray,
    colorspace: str,
) -> bpy.types.Image:
    height, width, channels = pixels.shape
    if channels != 4:
        raise ValueError(f"Generated texture {name} must be RGBA, got {pixels.shape}")
    image = bpy.data.images.new(name, width=width, height=height, alpha=True, float_buffer=False)
    image.colorspace_settings.name = colorspace
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    return image


def generate_pbr_texture_sets() -> dict[str, dict]:
    """Create deterministic, tileable P24 texture families with no floor grime."""
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    texture_sets: dict[str, dict] = {}
    for role, raw_spec in PBR_TEXTURE_SPECS.items():
        spec = dict(raw_spec)
        resolution = int(spec["resolution"])
        panel_count = int(spec["panel_count"])
        seam_width = float(spec["seam_width"])
        tile_size = float(resolution) / float(panel_count)

        y, x = np.mgrid[0:resolution, 0:resolution].astype(np.float32)
        cell_x = np.mod(x, tile_size)
        cell_y = np.mod(y, tile_size)
        edge_x = np.minimum(cell_x, tile_size - cell_x)
        edge_y = np.minimum(cell_y, tile_size - cell_y)
        edge_distance = np.minimum(edge_x, edge_y)
        seam = edge_distance <= seam_width
        bevel_amount = np.clip((edge_distance - seam_width) / max(seam_width * 2.0, 1.0), 0.0, 1.0)
        bevel_amount = bevel_amount * bevel_amount * (3.0 - 2.0 * bevel_amount)

        tile_x = np.floor(x / tile_size).astype(np.int32)
        tile_y = np.floor(y / tile_size).astype(np.int32)
        panel_code = np.mod(tile_x * 37 + tile_y * 17, 7).astype(np.float32) - 3.0
        panel_variation = panel_code / 3.0 * float(spec["variation"])

        height_field = bevel_amount
        if bool(spec.get("soft_bulge", False)):
            bulge_x = np.sin(np.pi * cell_x / tile_size)
            bulge_y = np.sin(np.pi * cell_y / tile_size)
            height_field = height_field + bulge_x * bulge_y * 0.10

        # Blender's byte-image PNG writer stores the supplied pixels directly.
        # Albedo therefore needs display-referred sRGB samples; the imported
        # image node performs the sRGB-to-linear decode exactly once at render.
        base = np.array(srgb_rgba(str(spec["base_hex"]))[:3], dtype=np.float32)
        albedo = np.empty((resolution, resolution, 4), dtype=np.float32)
        albedo[..., :3] = base[None, None, :] * (1.0 + panel_variation[..., None])
        seam_color = base * (1.0 - float(spec["seam_darkening"]))
        albedo[..., :3] = np.where(seam[..., None], seam_color[None, None, :], albedo[..., :3])
        albedo[..., :3] = np.clip(albedo[..., :3], 0.0, 1.0)
        albedo[..., 3] = 1.0

        gradient_x = (np.roll(height_field, -1, axis=1) - np.roll(height_field, 1, axis=1)) * 0.5
        gradient_y = (np.roll(height_field, -1, axis=0) - np.roll(height_field, 1, axis=0)) * 0.5
        strength = float(spec["normal_strength"])
        normal_x = -gradient_x * strength
        normal_y = -gradient_y * strength
        normal_z = np.ones_like(normal_x)
        normal_length = np.sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z)
        normal = np.empty((resolution, resolution, 4), dtype=np.float32)
        normal[..., 0] = normal_x / normal_length * 0.5 + 0.5
        normal[..., 1] = normal_y / normal_length * 0.5 + 0.5
        normal[..., 2] = normal_z / normal_length * 0.5 + 0.5
        normal[..., 3] = 1.0

        roughness_value = np.full((resolution, resolution), float(spec["roughness"]), dtype=np.float32)
        roughness_value += panel_variation * 0.55
        roughness_value = np.where(seam, float(spec["roughness_seam"]), roughness_value)
        roughness = np.empty((resolution, resolution, 4), dtype=np.float32)
        roughness[..., 0] = roughness_value
        roughness[..., 1] = roughness_value
        roughness[..., 2] = roughness_value
        roughness[..., 3] = 1.0

        images: dict[str, bpy.types.Image] = {}
        paths: dict[str, Path] = {}
        for map_name, pixels, colorspace in (
            ("albedo", albedo, "sRGB"),
            ("normal", normal, "Non-Color"),
            ("roughness", roughness, "Non-Color"),
        ):
            path = TEXTURE_DIR / f"tbsa_{role}_{map_name}.png"
            images[map_name] = _save_generated_texture(
                f"TBSA_{role}_{map_name}", path, pixels, colorspace,
            )
            paths[map_name] = path
        texture_sets[role] = {
            "images": images,
            "paths": paths,
            "resolution": resolution,
            "uv_world_scale": float(spec["uv_world_scale"]),
            "surface_style": str(spec["surface_style"]),
        }
    return texture_sets


def make_material(
    name: str,
    base_hex: str,
    roughness: float,
    metallic: float = 0.0,
    emission_hex: str | None = None,
    emission_strength: float = 0.0,
    texture_set: dict | None = None,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material["palette_hex"] = base_hex.upper()
    material["visual_only"] = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(base_hex)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if texture_set:
        material["pbr_texture_set"] = texture_set["surface_style"]
        material["texture_resolution"] = int(texture_set["resolution"])
        material["uv_world_scale"] = float(texture_set["uv_world_scale"])
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        uv = nodes.new("ShaderNodeUVMap")
        uv.name = f"{name}_UV"
        uv.uv_map = "UVMap"

        albedo = nodes.new("ShaderNodeTexImage")
        albedo.name = f"{name}_Albedo"
        albedo.image = texture_set["images"]["albedo"]
        albedo.extension = "REPEAT"
        links.new(uv.outputs["UV"], albedo.inputs["Vector"])
        links.new(albedo.outputs["Color"], bsdf.inputs["Base Color"])

        roughness_map = nodes.new("ShaderNodeTexImage")
        roughness_map.name = f"{name}_Roughness"
        roughness_map.image = texture_set["images"]["roughness"]
        roughness_map.extension = "REPEAT"
        links.new(uv.outputs["UV"], roughness_map.inputs["Vector"])
        links.new(roughness_map.outputs["Color"], bsdf.inputs["Roughness"])

        normal_texture = nodes.new("ShaderNodeTexImage")
        normal_texture.name = f"{name}_Normal"
        normal_texture.image = texture_set["images"]["normal"]
        normal_texture.extension = "REPEAT"
        links.new(uv.outputs["UV"], normal_texture.inputs["Vector"])
        normal_map = nodes.new("ShaderNodeNormalMap")
        normal_map.name = f"{name}_NormalMap"
        normal_map.inputs["Strength"].default_value = 0.72
        links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
        links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    if emission_hex:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = rgba(emission_hex)
        strength_input = bsdf.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = emission_strength
    return material


def create_materials(texture_sets: dict[str, dict]) -> dict[str, bpy.types.Material]:
    return {
        "dry_cream": make_material(
            "TBSA_DryCream", COLOR_CONTRACT["dry_cream"], 0.78, texture_set=texture_sets["dry_cream"],
        ),
        "cyan": make_material(
            "TBSA_Cyan", COLOR_CONTRACT["cyan"], 0.60, texture_set=texture_sets["cyan"],
        ),
        "cyan_dark": make_material(
            "TBSA_CyanDark", SUPPORT_COLORS["cyan_dark"], 0.72, texture_set=texture_sets["cyan_dark"],
        ),
        "coral": make_material(
            "TBSA_CoralSoft", COLOR_CONTRACT["coral"], 0.66, texture_set=texture_sets["coral"],
        ),
        "yellow": make_material("TBSA_SafetyYellow", COLOR_CONTRACT["safety_yellow"], 0.58),
        "orange": make_material("TBSA_PickupOrange", COLOR_CONTRACT["pickup_orange"], 0.56),
        "portal_cyan": make_material(
            "TBSA_PortalCyan", COLOR_CONTRACT["portal_cyan"], 0.32,
            emission_hex=COLOR_CONTRACT["portal_cyan"], emission_strength=1.35,
        ),
        "portal_recess": make_material("TBSA_PortalRecess", SUPPORT_COLORS["portal_recess"], 0.48),
    }


def g2b_position(position: list[float] | tuple[float, float, float]) -> tuple[float, float, float]:
    """Godot (x, y, z) -> Blender (x, -z, y), matching glTF Y-up export."""
    return float(position[0]), -float(position[2]), float(position[1])


def g2b_planar(point: list[float] | tuple[float, float]) -> tuple[float, float]:
    return float(point[0]), -float(point[1])


def signed_area(points: list[tuple[float, float]]) -> float:
    return 0.5 * sum(
        points[index][0] * points[(index + 1) % len(points)][1]
        - points[(index + 1) % len(points)][0] * points[index][1]
        for index in range(len(points))
    )


def ensure_ccw(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return points if signed_area(points) > 0.0 else list(reversed(points))


def line_intersection(
    a: Vector, direction_a: Vector, b: Vector, direction_b: Vector
) -> Vector | None:
    denominator = direction_a.x * direction_b.y - direction_a.y * direction_b.x
    if abs(denominator) < 1.0e-8:
        return None
    delta = b - a
    t = (delta.x * direction_b.y - delta.y * direction_b.x) / denominator
    return a + direction_a * t


def offset_polygon(points: list[tuple[float, float]], distance: float) -> list[tuple[float, float]]:
    """Miter-offset a simple polygon; positive distance expands outward."""
    if abs(distance) < 1.0e-8:
        return list(points)
    ccw = signed_area(points) > 0.0
    result: list[tuple[float, float]] = []
    vectors = [Vector(point) for point in points]
    for index, current in enumerate(vectors):
        previous = vectors[(index - 1) % len(vectors)]
        following = vectors[(index + 1) % len(vectors)]
        incoming = (current - previous).normalized()
        outgoing = (following - current).normalized()
        if ccw:
            normal_in = Vector((incoming.y, -incoming.x))
            normal_out = Vector((outgoing.y, -outgoing.x))
        else:
            normal_in = Vector((-incoming.y, incoming.x))
            normal_out = Vector((-outgoing.y, outgoing.x))
        shifted_in = current + normal_in * distance
        shifted_out = current + normal_out * distance
        intersection = line_intersection(shifted_in, incoming, shifted_out, outgoing)
        if intersection is None or (intersection - current).length > abs(distance) * 12.0 + 1.0:
            averaged = (normal_in + normal_out).normalized()
            intersection = current + averaged * distance
        result.append((intersection.x, intersection.y))
    return result


def make_anchor(
    name: str,
    collection: bpy.types.Collection,
    location: tuple[float, float, float],
    semantic_id: str,
    source_kind: str,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    anchor = bpy.data.objects.new(name, None)
    collection.objects.link(anchor)
    anchor.location = location
    anchor.empty_display_type = "PLAIN_AXES"
    anchor.empty_display_size = 0.7
    anchor["semantic_id"] = semantic_id
    anchor["source_kind"] = source_kind
    anchor["visual_only"] = True
    anchor.parent = parent
    return anchor


def make_root(name: str, collection: bpy.types.Collection, asset_role: str) -> bpy.types.Object:
    root = bpy.data.objects.new(name, None)
    collection.objects.link(root)
    root["asset_role"] = asset_role
    root["visual_only"] = True
    root["collision_owner"] = "Godot"
    return root


def apply_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.append(material)


def create_prism(
    name: str,
    points: list[tuple[float, float]],
    bottom_z: float,
    top_z: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    omit_side_edges: set[int] | None = None,
) -> bpy.types.Object:
    polygon = ensure_ccw(points)
    count = len(polygon)
    vertices = [(x, y, bottom_z) for x, y in polygon] + [(x, y, top_z) for x, y in polygon]
    lookup = {(round(x, 8), round(y, 8)): index for index, (x, y) in enumerate(polygon)}
    triangles = tessellate_polygon([[Vector((x, y, 0.0)) for x, y in polygon]])
    faces: list[tuple[int, ...]] = []
    for triangle in triangles:
        # Blender 5.1 returns vertex indices here, while older releases returned
        # Vector values.  Supporting both keeps the builder reproducible across
        # the project's current 5.1 runtime and earlier validation machines.
        indices = [
            int(vertex)
            if isinstance(vertex, int)
            else lookup[(round(vertex.x, 8), round(vertex.y, 8))]
            for vertex in triangle
        ]
        faces.append(tuple(reversed(indices)))
        faces.append(tuple(index + count for index in indices))
    for index in range(count):
        if omit_side_edges and index in omit_side_edges:
            continue
        next_index = (index + 1) % count
        faces.append((index, next_index, next_index + count, index + count))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    return obj


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 3) -> None:
    if width <= 0.0:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("TBSA_RoundedEdge", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    obj.select_set(False)


def add_rounded_box(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    yaw_degrees: float,
    bevel: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=(0.0, 0.0, math.radians(yaw_degrees)))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    move_to_collection(obj, collection)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    width = min(bevel, min(dimensions) * 0.42)
    apply_bevel(obj, width, 4)
    return obj


def add_polyline_tube(
    name: str,
    paths: list[list[tuple[float, float, float]]],
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    curve_data = bpy.data.curves.new(f"{name}Curve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 3
    curve_data.use_fill_caps = True
    curve_data.resolution_u = 1
    for path in paths:
        spline = curve_data.splines.new("POLY")
        spline.points.add(len(path) - 1)
        for point, coordinate in zip(spline.points, path):
            point.co = (*coordinate, 1.0)
    obj = bpy.data.objects.new(name, curve_data)
    collection.objects.link(obj)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.name = name
    obj.select_set(False)
    return obj


def add_ellipse_panel(
    name: str,
    center: tuple[float, float, float],
    normal_xy: tuple[float, float],
    radius_x: float,
    radius_z: float,
    depth: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    segments: int = 48,
) -> bpy.types.Object:
    normal = Vector((normal_xy[0], normal_xy[1], 0.0)).normalized()
    tangent = Vector((-normal.y, normal.x, 0.0))
    vertical = Vector((0.0, 0.0, 1.0))
    center_vector = Vector(center)
    front_center = center_vector + normal * (depth * 0.5)
    back_center = center_vector - normal * (depth * 0.5)
    front = []
    back = []
    for index in range(segments):
        angle = math.tau * index / segments
        radial = tangent * (math.cos(angle) * radius_x) + vertical * (math.sin(angle) * radius_z)
        front.append(tuple(front_center + radial))
        back.append(tuple(back_center + radial))
    vertices = front + back
    faces: list[tuple[int, ...]] = [tuple(range(segments)), tuple(range(segments * 2 - 1, segments - 1, -1))]
    for index in range(segments):
        next_index = (index + 1) % segments
        faces.append((index, index + segments, next_index + segments, next_index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    return obj


def resample_catmull_rom(
    points: list[tuple[float, float, float]], subdivisions: int = 5
) -> list[tuple[float, float, float]]:
    """Smooth an authored centerline without changing its endpoints."""
    vectors = [Vector(point) for point in points]
    if len(vectors) < 2:
        return list(points)
    result: list[tuple[float, float, float]] = []
    for index in range(len(vectors) - 1):
        p0 = vectors[max(index - 1, 0)]
        p1 = vectors[index]
        p2 = vectors[index + 1]
        p3 = vectors[min(index + 2, len(vectors) - 1)]
        for step in range(subdivisions):
            t = step / subdivisions
            t2 = t * t
            t3 = t2 * t
            point = 0.5 * (
                2.0 * p1
                + (-p0 + p2) * t
                + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
            )
            result.append(tuple(point))
    result.append(tuple(vectors[-1]))
    return result


def pipe_frames(points: list[tuple[float, float, float]]) -> list[tuple[Vector, Vector, Vector]]:
    """Return parallel-transported tangent/side/up frames for a swept pipe.

    Rebuilding a frame from world-up at every ring can flip or collapse near the
    vertical water entry.  Projecting the preceding side vector onto the next
    tangent plane keeps adjacent rings coherent and prevents the shell from
    twisting through itself.
    """
    vectors = [Vector(point) for point in points]
    frames: list[tuple[Vector, Vector, Vector]] = []
    previous_side: Vector | None = None
    for index, center in enumerate(vectors):
        previous = vectors[max(index - 1, 0)]
        following = vectors[min(index + 1, len(vectors) - 1)]
        tangent = (following - previous).normalized()
        if previous_side is None:
            side = tangent.cross(Vector((0.0, 0.0, 1.0)))
            if side.length < 1.0e-5:
                side = tangent.cross(Vector((0.0, 1.0, 0.0)))
            side.normalize()
        else:
            side = previous_side - tangent * previous_side.dot(tangent)
            if side.length < 1.0e-5:
                side = tangent.cross(Vector((0.0, 0.0, 1.0)))
                if side.length < 1.0e-5:
                    side = tangent.cross(Vector((0.0, 1.0, 0.0)))
            side.normalize()
            if side.dot(previous_side) < 0.0:
                side = -side
        up = side.cross(tangent).normalized()
        frames.append((tangent, side, up))
        previous_side = side
    return frames


def add_pipe_surface(
    name: str,
    points: list[tuple[float, float, float]],
    radii: tuple[float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    radial_segments: int,
    inward: bool = False,
) -> bpy.types.Object:
    frames = pipe_frames(points)
    vertices: list[tuple[float, float, float]] = []
    for center_value, (_tangent, side, up) in zip(points, frames):
        center = Vector(center_value)
        for radial_index in range(radial_segments):
            angle = math.tau * radial_index / radial_segments
            vertex = center + side * (math.cos(angle) * radii[0]) + up * (math.sin(angle) * radii[1])
            vertices.append(tuple(vertex))
    faces: list[tuple[int, ...]] = []
    for ring_index in range(len(points) - 1):
        current = ring_index * radial_segments
        following = (ring_index + 1) * radial_segments
        for radial_index in range(radial_segments):
            next_radial = (radial_index + 1) % radial_segments
            a = current + radial_index
            a_next = current + next_radial
            b = following + radial_index
            b_next = following + next_radial
            faces.append((a, a_next, b_next, b) if inward else (a, b, b_next, a_next))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    return obj


def add_pipe_mouth_annulus(
    name: str,
    center: tuple[float, float, float],
    tangent: Vector,
    outer_radii: tuple[float, float],
    inner_radii: tuple[float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    radial_segments: int,
) -> bpy.types.Object:
    side = tangent.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = side.cross(tangent).normalized()
    center_vector = Vector(center)
    outer: list[tuple[float, float, float]] = []
    inner: list[tuple[float, float, float]] = []
    for radial_index in range(radial_segments):
        angle = math.tau * radial_index / radial_segments
        outer.append(tuple(center_vector + side * (math.cos(angle) * outer_radii[0]) + up * (math.sin(angle) * outer_radii[1])))
        inner.append(tuple(center_vector + side * (math.cos(angle) * inner_radii[0]) + up * (math.sin(angle) * inner_radii[1])))
    vertices = outer + inner
    faces: list[tuple[int, ...]] = []
    for radial_index in range(radial_segments):
        next_radial = (radial_index + 1) % radial_segments
        faces.append((radial_index, next_radial, radial_segments + next_radial, radial_segments + radial_index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    return obj


def variable_width_footprint(
    points: list[list[float]], offsets: list[float], thicknesses: list[float]
) -> list[tuple[float, float]]:
    shifted = [Vector((float(point[0]), float(point[1]) + float(offset))) for point, offset in zip(points, offsets)]
    left: list[Vector] = []
    right: list[Vector] = []
    for index, point in enumerate(shifted):
        previous = shifted[max(index - 1, 0)]
        following = shifted[min(index + 1, len(shifted) - 1)]
        tangent = (following - previous).normalized()
        normal = Vector((-tangent.y, tangent.x))
        half_width = float(thicknesses[index]) * 0.5
        left.append(point + normal * half_width)
        right.append(point - normal * half_width)
    footprint_godot = left + list(reversed(right))
    return [g2b_planar((point.x, point.y)) for point in footprint_godot]


def cross_2d(a: tuple[float, float], b: tuple[float, float], c: tuple[float, float]) -> float:
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def point_on_segment(
    point: tuple[float, float], start: tuple[float, float], end: tuple[float, float], epsilon: float = 1.0e-7
) -> bool:
    if abs(cross_2d(start, end, point)) > epsilon:
        return False
    return (
        min(start[0], end[0]) - epsilon <= point[0] <= max(start[0], end[0]) + epsilon
        and min(start[1], end[1]) - epsilon <= point[1] <= max(start[1], end[1]) + epsilon
    )


def segments_intersect(
    a: tuple[float, float], b: tuple[float, float], c: tuple[float, float], d: tuple[float, float]
) -> bool:
    ab_c = cross_2d(a, b, c)
    ab_d = cross_2d(a, b, d)
    cd_a = cross_2d(c, d, a)
    cd_b = cross_2d(c, d, b)
    epsilon = 1.0e-7
    if ((ab_c > epsilon and ab_d < -epsilon) or (ab_c < -epsilon and ab_d > epsilon)) and (
        (cd_a > epsilon and cd_b < -epsilon) or (cd_a < -epsilon and cd_b > epsilon)
    ):
        return True
    return (
        (abs(ab_c) <= epsilon and point_on_segment(c, a, b))
        or (abs(ab_d) <= epsilon and point_on_segment(d, a, b))
        or (abs(cd_a) <= epsilon and point_on_segment(a, c, d))
        or (abs(cd_b) <= epsilon and point_on_segment(b, c, d))
    )


def polygon_is_simple(points: list[tuple[float, float]]) -> bool:
    count = len(points)
    if count < 3:
        return False
    for index in range(count):
        a = points[index]
        b = points[(index + 1) % count]
        if math.dist(a, b) <= 1.0e-7:
            return False
        for other in range(index + 1, count):
            if other == index or other == (index + 1) % count or (other + 1) % count == index:
                continue
            c = points[other]
            d = points[(other + 1) % count]
            if segments_intersect(a, b, c, d):
                return False
    return True


def point_in_polygon(point: tuple[float, float], polygon: list[tuple[float, float]]) -> bool:
    inside = False
    for index, start in enumerate(polygon):
        end = polygon[(index + 1) % len(polygon)]
        if point_on_segment(point, start, end):
            return True
        if (start[1] > point[1]) != (end[1] > point[1]):
            x_at_y = (end[0] - start[0]) * (point[1] - start[1]) / (end[1] - start[1]) + start[0]
            if point[0] < x_at_y:
                inside = not inside
    return inside


def point_segment_distance(
    point: tuple[float, float], start: tuple[float, float], end: tuple[float, float]
) -> float:
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    denominator = dx * dx + dy * dy
    if denominator <= 1.0e-12:
        return math.dist(point, start)
    amount = max(0.0, min(1.0, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / denominator))
    projection = (start[0] + dx * amount, start[1] + dy * amount)
    return math.dist(point, projection)


def segment_distance(
    a: tuple[float, float], b: tuple[float, float], c: tuple[float, float], d: tuple[float, float]
) -> float:
    if segments_intersect(a, b, c, d):
        return 0.0
    return min(
        point_segment_distance(a, c, d),
        point_segment_distance(b, c, d),
        point_segment_distance(c, a, b),
        point_segment_distance(d, a, b),
    )


def segment_polygon_distance(
    start: tuple[float, float], end: tuple[float, float], polygon: list[tuple[float, float]]
) -> float:
    if point_in_polygon(start, polygon) or point_in_polygon(end, polygon):
        return 0.0
    return min(
        segment_distance(start, end, edge_start, polygon[(index + 1) % len(polygon)])
        for index, edge_start in enumerate(polygon)
    )


def polyline_polygon_distance(
    points: list[tuple[float, float]], polygon: list[tuple[float, float]]
) -> float:
    return min(segment_polygon_distance(points[index], points[index + 1], polygon) for index in range(len(points) - 1))


def polyline_segment_distance(
    points: list[tuple[float, float]], start: tuple[float, float], end: tuple[float, float]
) -> float:
    return min(segment_distance(points[index], points[index + 1], start, end) for index in range(len(points) - 1))


def polygon_distance(
    first: list[tuple[float, float]], second: list[tuple[float, float]]
) -> float:
    if point_in_polygon(first[0], second) or point_in_polygon(second[0], first):
        return 0.0
    return min(
        segment_distance(
            start,
            first[(index + 1) % len(first)],
            other_start,
            second[(other + 1) % len(second)],
        )
        for index, start in enumerate(first)
        for other, other_start in enumerate(second)
    )


def wall_footprints(layout: dict) -> list[tuple[str, list[tuple[float, float]]]]:
    footprints: list[tuple[str, list[tuple[float, float]]]] = []
    for wall in layout["walls"]:
        for section in wall["sections"]:
            section_points = wall["points"][int(section["start"]) : int(section["end_exclusive"])]
            footprints.append((
                f"{wall['id']}:{section['label']}",
                variable_width_footprint(section_points, section["offsets"], section["thicknesses"]),
            ))
    return footprints


def x_intersections_at_y(
    points: list[tuple[float, float]],
    y: float,
    closed: bool,
    epsilon: float = 1.0e-8,
) -> list[float]:
    intersections: list[float] = []
    segment_count = len(points) if closed else len(points) - 1
    for index in range(segment_count):
        start = points[index]
        end = points[(index + 1) % len(points)]
        delta_y = end[1] - start[1]
        if abs(delta_y) <= epsilon:
            if abs(y - start[1]) <= epsilon:
                intersections.extend((start[0], end[0]))
            continue
        if y < min(start[1], end[1]) - epsilon or y > max(start[1], end[1]) + epsilon:
            continue
        amount = (y - start[1]) / delta_y
        if -epsilon <= amount <= 1.0 + epsilon:
            intersections.append(start[0] + amount * (end[0] - start[0]))
    return intersections


def south_wall_boundary_max_gap(layout: dict) -> float:
    """Measure visible floor between each lower wall and the island perimeter."""
    visual_outline = [g2b_planar(point) for point in layout["platform"]["production_visual_outline"]]
    signed_gaps: list[float] = []
    for wall_id, is_west in (("west_south_outer_wall", True), ("east_south_outer_wall", False)):
        wall = next(item for item in layout["walls"] if item["id"] == wall_id)
        section = next(item for item in wall["sections"] if int(item["label"]) == 4)
        section_points = wall["points"][int(section["start"]) : int(section["end_exclusive"])]
        footprint = variable_width_footprint(section_points, section["offsets"], section["thicknesses"])
        if polygon_distance(footprint, visual_outline) > 1.0e-7:
            return math.inf

        point_count = len(section_points)
        outer_edge = list(reversed(footprint[point_count:])) if is_west else footprint[:point_count]
        minimum_y = min(point[1] for point in outer_edge)
        maximum_y = max(point[1] for point in outer_edge)
        critical_y = {point[1] for point in outer_edge}
        critical_y.update(
            point[1]
            for point in visual_outline
            if minimum_y - 1.0e-8 <= point[1] <= maximum_y + 1.0e-8
        )
        for sample_y in critical_y:
            wall_xs = x_intersections_at_y(outer_edge, sample_y, False)
            platform_xs = x_intersections_at_y(visual_outline, sample_y, True)
            if not wall_xs or not platform_xs:
                continue
            signed_gap = min(wall_xs) - min(platform_xs) if is_west else max(platform_xs) - max(wall_xs)
            signed_gaps.append(signed_gap)

    return max(0.0, max(signed_gaps)) if signed_gaps else math.inf


def pipe_planar_blockers(layout: dict) -> list[tuple[str, list[tuple[float, float]], float]]:
    blockers: list[tuple[str, list[tuple[float, float]], float]] = []
    for pipe in layout["portal_pipes"]:
        path_3d = resample_catmull_rom([g2b_position(point) for point in pipe["path"]], 5)
        path_2d = [(point[0], point[1]) for point in path_3d]
        blockers.append((pipe["id"] + ":outer", path_2d, float(pipe["outer_radius"][0])))
        mouth_tangent = (Vector(path_3d[1]) - Vector(path_3d[0])).normalized()
        collar_end = Vector(path_3d[0]) + mouth_tangent * float(pipe["collar_depth"])
        blockers.append((
            pipe["id"] + ":collar",
            [path_2d[0], (collar_end.x, collar_end.y)],
            float(pipe["collar_outer_radius"][0]),
        ))
    return blockers


def pipe_planar_footprints(layout: dict) -> list[tuple[str, list[tuple[float, float]]]]:
    footprints: list[tuple[str, list[tuple[float, float]]]] = []
    for pipe in layout["portal_pipes"]:
        path = resample_catmull_rom([g2b_position(point) for point in pipe["path"]], 5)
        frames = pipe_frames(path)

        def swept_footprint(
            points: list[tuple[float, float, float]],
            point_frames: list[tuple[Vector, Vector, Vector]],
            radius: float,
        ) -> list[tuple[float, float]]:
            left: list[tuple[float, float]] = []
            right: list[tuple[float, float]] = []
            for point, (_tangent, side, _up) in zip(points, point_frames):
                center = Vector(point)
                left.append((center.x + side.x * radius, center.y + side.y * radius))
                right.append((center.x - side.x * radius, center.y - side.y * radius))
            return left + list(reversed(right))

        footprints.append((
            pipe["id"] + ":outer",
            swept_footprint(path, frames, float(pipe["outer_radius"][0])),
        ))
        mouth_tangent = (Vector(path[1]) - Vector(path[0])).normalized()
        collar_path = [path[0], tuple(Vector(path[0]) + mouth_tangent * float(pipe["collar_depth"]))]
        footprints.append((
            pipe["id"] + ":collar",
            swept_footprint(collar_path, pipe_frames(collar_path), float(pipe["collar_outer_radius"][0])),
        ))
    return footprints


def build_trim_planar_paths(
    outline: list[tuple[float, float]],
    wall_blockers: list[tuple[str, list[tuple[float, float]]]],
    pipe_blockers: list[tuple[str, list[tuple[float, float]], float]],
) -> tuple[list[list[tuple[float, float]]], float]:
    edge_kept: list[bool] = []
    edge_clearances: list[float] = []
    for index, start in enumerate(outline):
        end = outline[(index + 1) % len(outline)]
        wall_clearance = min(
            segment_polygon_distance(start, end, polygon) - SAFETY_TRIM_RADIUS
            for _name, polygon in wall_blockers
        )
        pipe_clearance = min(
            polyline_segment_distance(path, start, end) - radius - SAFETY_TRIM_RADIUS
            for _name, path, radius in pipe_blockers
        )
        clearance = min(wall_clearance, pipe_clearance)
        edge_clearances.append(clearance)
        edge_kept.append(clearance >= TRIM_BLOCKER_CLEARANCE)

    if not any(edge_kept):
        raise ValueError("Safety trim was entirely removed by geometry blockers")
    if all(edge_kept):
        return [outline + [outline[0]]], min(edge_clearances)

    first_blocked = edge_kept.index(False)
    paths: list[list[tuple[float, float]]] = []
    current: list[tuple[float, float]] = []
    for step in range(1, len(outline) + 1):
        index = (first_blocked + step) % len(outline)
        if edge_kept[index]:
            if not current:
                current.append(outline[index])
            current.append(outline[(index + 1) % len(outline)])
        elif current:
            if len(current) >= 2:
                paths.append(current)
            current = []
    if current:
        paths.append(current)
    kept_clearances = [value for value, kept in zip(edge_clearances, edge_kept) if kept]
    return paths, min(kept_clearances)


def circumradius(a: Vector, b: Vector, c: Vector) -> float:
    ab = (b - a).length
    bc = (c - b).length
    ca = (a - c).length
    cross_length = (b - a).cross(c - a).length
    if cross_length <= 1.0e-9:
        return math.inf
    return ab * bc * ca / (2.0 * cross_length)


def validate_layout_geometry(layout: dict) -> dict:
    platform = layout["platform"]
    gameplay_outline = [g2b_planar(point) for point in platform["outline"]]
    visual_outline = [g2b_planar(point) for point in platform["production_visual_outline"]]
    outline_simple = polygon_is_simple(gameplay_outline)
    production_outline_simple = polygon_is_simple(visual_outline)

    causeway = platform["causeway"]
    position = causeway["collision_position"]
    size = causeway["collision_size"]
    safe_corners = [
        g2b_planar((float(position[0]) + x_sign * float(size[0]) * 0.5, float(position[2]) + z_sign * float(size[2]) * 0.5))
        for x_sign, z_sign in ((-1, -1), (1, -1), (1, 1), (-1, 1))
    ]
    visual_covers_safe_collision = all(point_in_polygon(point, visual_outline) for point in gameplay_outline + safe_corners)

    walls = wall_footprints(layout)
    pipe_blockers = pipe_planar_blockers(layout)
    pipe_footprints = pipe_planar_footprints(layout)
    wall_pipe_min_clearance = min(
        polygon_distance(pipe_footprint, wall_footprint)
        for _pipe_name, pipe_footprint in pipe_footprints
        for _wall_name, wall_footprint in walls
    )

    bend_radii: list[float] = []
    for pipe in layout["portal_pipes"]:
        path = [Vector(point) for point in resample_catmull_rom([g2b_position(value) for value in pipe["path"]], 5)]
        bend_radii.extend(circumradius(path[index - 1], path[index], path[index + 1]) for index in range(1, len(path) - 1))
    pipe_min_bend_radius = min(bend_radii)

    pipe_by_id = {pipe["id"]: pipe for pipe in layout["portal_pipes"]}
    portal_clearances: list[float] = []
    normal_alignments: list[float] = []
    for portal in layout["portals"]:
        pipe = pipe_by_id[portal["pipe_id"]]
        ring = portal["ring"]
        core = portal["core"]
        ring_scale = ring["scale"]
        core_scale = core["scale"]
        foam_radius = float(ring["outer_radius"]) * PORTAL_FOAM_OUTER_RADIUS_MULTIPLIER
        max_foam_horizontal = foam_radius * float(ring_scale[0]) * PORTAL_RING_SCALE_MULTIPLIER * (1.0 + PORTAL_FOAM_PULSE_AMPLITUDE)
        max_foam_vertical = foam_radius * float(ring_scale[2]) * PORTAL_RING_SCALE_MULTIPLIER * (1.0 + PORTAL_FOAM_PULSE_AMPLITUDE)
        max_core_horizontal = float(core["radius"]) * float(core_scale[0]) * PORTAL_CORE_SCALE_MULTIPLIER
        max_core_vertical = float(core["radius"]) * float(core_scale[2]) * PORTAL_CORE_SCALE_MULTIPLIER
        portal_clearances.extend((
            float(pipe["inner_radius"][0]) - max(max_foam_horizontal, max_core_horizontal),
            float(pipe["inner_radius"][1]) - max(max_foam_vertical, max_core_vertical),
        ))
        first = Vector(pipe["path"][0])
        second = Vector(pipe["path"][1])
        outward = Vector((second.x - first.x, 0.0, second.z - first.z)).normalized()
        inward = -outward
        normal = Vector(portal["normal"]).normalized()
        normal_alignments.append(inward.dot(normal))

    portal_mouth_insets: list[float] = []
    portal_mouths_mounted = True
    for portal in layout["portals"]:
        position = portal["position"]
        mouth_center = g2b_planar((float(position[0]), float(position[2])))
        mounted = point_in_polygon(mouth_center, visual_outline)
        portal_mouths_mounted = portal_mouths_mounted and mounted
        boundary_distance = min(
            point_segment_distance(
                mouth_center,
                visual_outline[index],
                visual_outline[(index + 1) % len(visual_outline)],
            )
            for index in range(len(visual_outline))
        )
        portal_mouth_insets.append(boundary_distance if mounted else -boundary_distance)

    trim_paths, trim_blocker_min_clearance = build_trim_planar_paths(visual_outline, walls, pipe_blockers)
    south_wall_max_gap = south_wall_boundary_max_gap(layout)
    audit = {
        "outline_simple": outline_simple,
        "production_outline_simple": production_outline_simple,
        "production_outline_covers_safe_collision": visual_covers_safe_collision,
        "portal_mouths_mounted_on_platform": portal_mouths_mounted,
        "portal_mouth_platform_min_inset": round(min(portal_mouth_insets), 6),
        "portal_mouth_platform_max_inset": round(max(portal_mouth_insets), 6),
        "wall_pipe_min_clearance": round(wall_pipe_min_clearance, 6),
        "south_wall_boundary_max_gap": round(south_wall_max_gap, 6),
        "portal_aperture_min_clearance": round(min(portal_clearances), 6),
        "portal_normal_min_alignment": round(min(normal_alignments), 6),
        "pipe_min_bend_radius": round(pipe_min_bend_radius, 6),
        "causeway_overlap_area": 0.0,
        "trim_blocker_min_clearance": round(trim_blocker_min_clearance, 6),
        "trim_path_count": len(trim_paths),
        "dynamic_envelope": {
            "ring_scale_multiplier": PORTAL_RING_SCALE_MULTIPLIER,
            "ring_pulse_amplitude": PORTAL_RING_PULSE_AMPLITUDE,
            "foam_outer_radius_multiplier": PORTAL_FOAM_OUTER_RADIUS_MULTIPLIER,
            "foam_pulse_amplitude": PORTAL_FOAM_PULSE_AMPLITUDE,
            "inner_foam_outer_radius_multiplier": PORTAL_INNER_FOAM_OUTER_RADIUS_MULTIPLIER,
            "core_scale_multiplier": PORTAL_CORE_SCALE_MULTIPLIER,
        },
    }
    failures: list[str] = []
    if not outline_simple:
        failures.append("116-point gameplay outline is self-intersecting")
    if not production_outline_simple:
        failures.append("production visual union outline is self-intersecting")
    if not visual_covers_safe_collision:
        failures.append("production visual floor does not cover the complete gameplay floor")
    if not portal_mouths_mounted:
        failures.append("portal mouth centers must be mounted inside the original production platform")
    if min(portal_mouth_insets) < MIN_PORTAL_MOUTH_PLATFORM_INSET:
        failures.append(
            f"portal mouth platform inset {min(portal_mouth_insets):.3f} < {MIN_PORTAL_MOUTH_PLATFORM_INSET:.3f}"
        )
    if max(portal_mouth_insets) > MAX_PORTAL_MOUTH_PLATFORM_INSET:
        failures.append(
            f"portal mouth platform inset {max(portal_mouth_insets):.3f} > {MAX_PORTAL_MOUTH_PLATFORM_INSET:.3f}"
        )
    if wall_pipe_min_clearance < MIN_WALL_PIPE_CLEARANCE:
        failures.append(f"wall/pipe clearance {wall_pipe_min_clearance:.3f} < {MIN_WALL_PIPE_CLEARANCE:.3f}")
    if south_wall_max_gap > MAX_SOUTH_WALL_BOUNDARY_GAP:
        failures.append(
            f"south wall/boundary gap {south_wall_max_gap:.3f} > {MAX_SOUTH_WALL_BOUNDARY_GAP:.3f}"
        )
    if min(portal_clearances) < MIN_PORTAL_APERTURE_CLEARANCE:
        failures.append(f"animated portal aperture clearance {min(portal_clearances):.3f} < {MIN_PORTAL_APERTURE_CLEARANCE:.3f}")
    if min(normal_alignments) < 0.999:
        failures.append(f"portal normal/pipe alignment {min(normal_alignments):.6f} < 0.999")
    if pipe_min_bend_radius < MIN_PIPE_BEND_RADIUS:
        failures.append(f"pipe bend radius {pipe_min_bend_radius:.3f} < {MIN_PIPE_BEND_RADIUS:.3f}")
    if trim_blocker_min_clearance < MIN_TRIM_BLOCKER_CLEARANCE:
        failures.append(f"trim/blocker clearance {trim_blocker_min_clearance:.3f} < {MIN_TRIM_BLOCKER_CLEARANCE:.3f}")
    if failures:
        raise ValueError("Twin Bays geometry audit failed: " + "; ".join(failures))
    return audit


def build_production_foreground(
    layout: dict,
    materials: dict[str, bpy.types.Material],
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    root = make_root("TBSA_Foreground", collection, "production_foreground")
    platform = layout["platform"]
    floor_top = float(platform["floor_top_y"])
    floor_bottom = floor_top - float(platform["depth"])
    visual_floor_top = floor_top + DRY_TOP_DEPTH
    outline = [g2b_planar(point) for point in platform["production_visual_outline"]]

    make_anchor("Anchor_Platform", collection, g2b_position((0.0, floor_top, 0.0)), "platform", "platform", root)
    create_prism("PlatformSide", outline, floor_bottom, floor_top, materials["cyan_dark"], collection, root)
    create_prism("PlatformDryTop", outline, floor_top, visual_floor_top, materials["dry_cream"], collection, root)

    # The production outline is the precomputed union of the approved 116-point
    # platform and the 16-unit gameplay causeway.  Extruding it once avoids the
    # old 675 m² near-coplanar overlay while keeping collision ownership unchanged.
    causeway = platform["causeway"]
    collision_position = causeway["collision_position"]
    center_x = float(collision_position[0])
    center_z = float(collision_position[2])
    make_anchor(
        "Anchor_CausewaySafeVisual", collection,
        g2b_position((center_x, floor_top, center_z)), causeway["id"], "causeway_safe_visual", root,
    )

    # Build continuous trim runs from the true union boundary.  Runs are clipped
    # before wall and pipe keep-outs, so no hidden yellow tube remains embedded in
    # a wall, collar, or platform seam.
    trim_height = visual_floor_top + SAFETY_TRIM_RADIUS + SAFETY_TRIM_LIFT
    planar_trim_paths, _trim_clearance = build_trim_planar_paths(
        outline, wall_footprints(layout), pipe_planar_blockers(layout),
    )
    trim_paths = [[(point[0], point[1], trim_height) for point in path] for path in planar_trim_paths]
    add_polyline_tube("PlatformSafetyTrim", trim_paths, SAFETY_TRIM_RADIUS, materials["yellow"], collection, root)

    for wall in layout["walls"]:
        for section in wall["sections"]:
            section_points = wall["points"][int(section["start"]) : int(section["end_exclusive"])]
            footprint = variable_width_footprint(section_points, section["offsets"], section["thicknesses"])
            wall_name = f"{wall['node_prefix']}_{int(section['label']):02d}"
            height = float(section["height"])
            create_prism(wall_name, footprint, visual_floor_top, visual_floor_top + height, materials["cyan"], collection, root)
            cap = offset_polygon(footprint, -float(wall["cap_inset"]))
            wall_cap = create_prism(
                wall_name + "CoralCap", cap, visual_floor_top + height,
                visual_floor_top + height + float(wall["cap_depth"]), materials["coral"], collection, root,
            )
            apply_bevel(wall_cap, float(wall["cap_depth"]) * 0.28, 3)
            center = Vector((0.0, 0.0))
            for point in footprint:
                center += Vector(point)
            center /= len(footprint)
            make_anchor(
                "Anchor_" + wall_name, collection, (center.x, center.y, visual_floor_top),
                f"{wall['id']}:{section['label']}", "wall_section", root,
            )

    pipe_by_portal_id: dict[str, dict] = {}
    for pipe in layout["portal_pipes"]:
        pipe_by_portal_id[pipe["portal_id"]] = pipe
        authored_path = [g2b_position(point) for point in pipe["path"]]
        path = resample_catmull_rom(authored_path, 5)
        outer_radii = tuple(float(value) for value in pipe["outer_radius"])
        inner_radii = tuple(float(value) for value in pipe["inner_radius"])
        collar_radii = tuple(float(value) for value in pipe["collar_outer_radius"])
        radial_segments = int(pipe["radial_segments"])
        mouth_tangent = (Vector(path[1]) - Vector(path[0])).normalized()
        shell_path = list(path)
        shell_path[0] = tuple(Vector(path[0]) + mouth_tangent * 0.06)

        # The old portal wall is intentionally gone.  A hollow coral water-slide
        # tube now owns the gap, with a dark cyan interior and a yellow mouth cuff.
        add_pipe_surface(
            pipe["node_name"] + "CoralOuter", shell_path, outer_radii,
            materials["coral"], collection, root, radial_segments,
        )
        add_pipe_surface(
            pipe["node_name"] + "CyanInner", shell_path, inner_radii,
            materials["portal_recess"], collection, root, radial_segments, inward=True,
        )
        collar_end = tuple(Vector(path[0]) + mouth_tangent * float(pipe["collar_depth"]))
        add_pipe_surface(
            pipe["node_name"] + "YellowCollar", [path[0], collar_end], collar_radii,
            materials["yellow"], collection, root, radial_segments,
        )
        add_pipe_mouth_annulus(
            pipe["node_name"] + "YellowMouthRim", path[0], mouth_tangent,
            collar_radii, inner_radii, materials["yellow"], collection, root, radial_segments,
        )
        make_anchor(
            "Anchor_" + pipe["node_name"], collection, path[0], pipe["id"], "portal_pipe", root,
        )

    for cover in layout["covers"]:
        position = cover["position"]
        size = cover["size"]
        center = g2b_position((position[0], visual_floor_top + float(size[1]) * 0.5, position[2]))
        dimensions = (float(size[0]), float(size[2]), float(size[1]))
        add_rounded_box(
            cover["node_name"], center, dimensions, float(cover["yaw_degrees"]), float(cover["bevel"]),
            materials["cyan"], collection, root,
        )
        make_anchor(
            "Anchor_" + cover["node_name"], collection, g2b_position(position), cover["id"], "cover", root,
        )

    for marker in layout["pickup_markers"]:
        position = marker["position"]
        size = marker["size"]
        center = g2b_position((position[0], visual_floor_top + float(size[1]) * 0.5, position[2]))
        dimensions = (float(size[0]), float(size[2]), float(size[1]))
        add_rounded_box(
            marker["node_name"], center, dimensions, float(marker["yaw_degrees"]), float(marker["bevel"]),
            materials["orange"], collection, root,
        )
        make_anchor(
            "Anchor_" + marker["node_name"], collection, g2b_position(marker["spawn_position"]),
            marker["id"], "pickup_marker", root,
        )

    special_marker = layout["special_pickup_marker"]
    position = special_marker["position"]
    size = special_marker["size"]
    center = g2b_position((position[0], visual_floor_top + float(size[1]) * 0.5, position[2]))
    dimensions = (float(size[0]), float(size[2]), float(size[1]))
    add_rounded_box(
        special_marker["node_name"], center, dimensions,
        float(special_marker["yaw_degrees"]), float(special_marker["bevel"]),
        materials["yellow"], collection, root,
    )
    make_anchor(
        "Anchor_" + special_marker["node_name"], collection,
        g2b_position(special_marker["spawn_position"]), special_marker["id"],
        "special_pickup_marker", root,
    )

    for spawn in layout["spawns"]:
        make_anchor("Anchor_" + spawn["id"], collection, g2b_position(spawn["position"]), spawn["id"], "spawn", root)

    # The dark pipe throat gives the dynamic portal a readable seat; the actual
    # bright water ring/core and all portal VFX stay Godot-owned.
    for portal in layout["portals"]:
        pipe = pipe_by_portal_id[portal["id"]]
        path = resample_catmull_rom([g2b_position(point) for point in pipe["path"]], 5)
        mouth_tangent = (Vector(path[1]) - Vector(path[0])).normalized()
        center = tuple(Vector(path[0]) + mouth_tangent * 1.25)
        inner_radii = tuple(float(value) for value in pipe["inner_radius"])
        add_ellipse_panel(
            portal["node_name"] + "PipeThroat", center, (mouth_tangent.x, mouth_tangent.y),
            inner_radii[0] * 0.96, inner_radii[1] * 0.96, 0.22,
            materials["portal_recess"], collection, root,
        )
        make_anchor(
            "Anchor_" + portal["node_name"], collection, g2b_position(portal["position"]),
            portal["id"], "portal", root,
        )
        make_anchor(
            "Anchor_" + portal["exit"]["node_name"] + "_" + portal["id"], collection,
            g2b_position([
                float(portal["position"][index]) + float(portal["exit"]["local_position"][index])
                for index in range(3)
            ]), portal["id"] + ":exit", "portal_exit", root,
        )

    return root


def build_hero_kit(
    layout: dict,
    materials: dict[str, bpy.types.Material],
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    root = make_root("TBSA_HeroKit", collection, "hero_kit")
    deck_bottom, deck_top = 0.0, 0.82
    deck_outline = [(-9.0, -6.5), (9.0, -6.5), (9.0, 6.5), (-9.0, 6.5)]
    create_prism("HeroDeckSide", deck_outline, deck_bottom, deck_top, materials["cyan_dark"], collection, root)
    create_prism("HeroDryCreamFloor", deck_outline, deck_top, deck_top + 0.14, materials["dry_cream"], collection, root)
    deck_path = [[
        (x, y, deck_top + 0.20 + SAFETY_TRIM_LIFT) for x, y in deck_outline
    ] + [(deck_outline[0][0], deck_outline[0][1], deck_top + 0.20 + SAFETY_TRIM_LIFT)]]
    add_polyline_tube("HeroSafetyYellowEdge", deck_path, SAFETY_TRIM_RADIUS, materials["yellow"], collection, root)
    make_anchor("Anchor_HeroDryFloor", collection, (0.0, 0.0, deck_top), "hero_dry_floor", "hero_module", root)

    first_wall = layout["walls"][0]
    wall_height = min(4.0, float(first_wall["sections"][0]["height"]))
    add_rounded_box(
        "HeroCyanWall", (-2.1, 4.8, deck_top + wall_height * 0.5), (10.5, 1.45, wall_height),
        0.0, 0.28, materials["cyan"], collection, root,
    )
    add_rounded_box(
        "HeroCoralSoftCap", (-2.1, 4.8, deck_top + wall_height + 0.26), (10.7, 1.65, 0.56),
        0.0, 0.22, materials["coral"], collection, root,
    )
    make_anchor("Anchor_HeroWall", collection, (-2.1, 4.8, deck_top), "hero_wall", "hero_module", root)

    cover = layout["covers"][0]
    cover_size = cover["size"]
    cover_dimensions = (float(cover_size[0]), float(cover_size[2]), float(cover_size[1]))
    cover_center = (-3.4, -1.6, deck_top + float(cover_size[1]) * 0.5)
    add_rounded_box(
        "HeroCyanCover", cover_center, cover_dimensions, float(cover["yaw_degrees"]),
        float(cover["bevel"]), materials["cyan"], collection, root,
    )
    make_anchor("Anchor_HeroCover", collection, (-3.4, -1.6, deck_top), "hero_cover", "hero_module", root)

    marker = layout["pickup_markers"][0]
    marker_size = marker["size"]
    marker_dimensions = (float(marker_size[0]), float(marker_size[2]), 0.14)
    add_rounded_box(
        "HeroOrangePickupPoint", (2.7, -2.0, deck_top + 0.12), marker_dimensions,
        float(marker["yaw_degrees"]), 0.06, materials["orange"], collection, root,
    )
    make_anchor("Anchor_HeroPickup", collection, (2.7, -2.0, deck_top), "hero_pickup", "hero_module", root)

    hero_pipe_path = resample_catmull_rom([
        (6.7, 2.0, deck_top + 5.0),
        (6.7, 3.2, deck_top + 4.95),
        (6.7, 4.7, deck_top + 4.25),
        (6.7, 5.7, deck_top + 2.2),
    ], 5)
    hero_tangent = (Vector(hero_pipe_path[1]) - Vector(hero_pipe_path[0])).normalized()
    add_pipe_surface(
        "HeroPortalPipeCoralOuter", hero_pipe_path, (2.15, 2.65),
        materials["coral"], collection, root, 32,
    )
    add_pipe_surface(
        "HeroPortalPipeCyanInner", hero_pipe_path, (1.65, 2.12),
        materials["portal_recess"], collection, root, 32, inward=True,
    )
    hero_collar_end = tuple(Vector(hero_pipe_path[0]) + hero_tangent * 0.72)
    add_pipe_surface(
        "HeroPortalPipeYellowCollar", [hero_pipe_path[0], hero_collar_end], (2.34, 2.84),
        materials["yellow"], collection, root, 32,
    )
    add_pipe_mouth_annulus(
        "HeroPortalPipeYellowMouth", hero_pipe_path[0], hero_tangent,
        (2.34, 2.84), (1.65, 2.12), materials["yellow"], collection, root, 32,
    )
    add_ellipse_panel(
        "HeroPortalPipeThroat", tuple(Vector(hero_pipe_path[0]) + hero_tangent * 1.0),
        (hero_tangent.x, hero_tangent.y), 1.58, 2.03, 0.18,
        materials["portal_recess"], collection, root,
    )
    # Straight guide lights demonstrate the portal-cyan token without baking the
    # dynamic water ring into either production foreground or the hero asset.
    for index, x_offset in enumerate((-1.46, 1.46)):
        add_rounded_box(
            f"HeroPortalGuideLight_{index}", (6.7 + x_offset, 1.92, deck_top + 5.0),
            (0.13, 0.12, 3.15), 0.0, 0.05, materials["portal_cyan"], collection, root,
        )
    make_anchor("Anchor_HeroPortalOpening", collection, (6.7, 2.0, deck_top), "hero_portal_opening", "hero_module", root)
    return root


def join_meshes_by_material(collection: bpy.types.Collection, prefix: str) -> None:
    groups: dict[bpy.types.Material, list[bpy.types.Object]] = {}
    for obj in list(collection.all_objects):
        if obj.type != "MESH" or not obj.data.materials:
            continue
        groups.setdefault(obj.data.materials[0], []).append(obj)
    for material, objects in groups.items():
        if not objects:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        active = objects[0]
        bpy.context.view_layer.objects.active = active
        if len(objects) > 1:
            bpy.ops.object.join()
        active = bpy.context.object
        active.name = f"{prefix}_{material.name}"
        active.data.name = active.name + "Mesh"
        for polygon in active.data.polygons:
            polygon.material_index = 0
        active.data.materials.clear()
        active.data.materials.append(material)
        active["material_role"] = material.name
        active["visual_only"] = True
        active.select_set(False)


def add_world_projected_uvs(collection: bpy.types.Collection) -> None:
    """Assign deterministic planar UVs after export-only material batching."""
    for obj in collection.all_objects:
        if obj.type != "MESH" or not obj.data.materials:
            continue
        material = obj.data.materials[0]
        if not material or not material.get("pbr_texture_set"):
            continue
        world_scale = float(material.get("uv_world_scale", 8.0))
        if world_scale <= 0.0:
            raise ValueError(f"Invalid UV world scale on {material.name}: {world_scale}")
        mesh = obj.data
        while mesh.uv_layers:
            mesh.uv_layers.remove(mesh.uv_layers[0])
        uv_layer = mesh.uv_layers.new(name="UVMap")
        normal_matrix = obj.matrix_world.to_3x3()
        for polygon in mesh.polygons:
            normal = (normal_matrix @ polygon.normal).normalized()
            for loop_index in polygon.loop_indices:
                vertex = mesh.vertices[mesh.loops[loop_index].vertex_index]
                world = obj.matrix_world @ vertex.co
                if abs(normal.z) >= abs(normal.x) and abs(normal.z) >= abs(normal.y):
                    u, v = world.x / world_scale, world.y / world_scale
                elif abs(normal.x) >= abs(normal.y):
                    u, v = world.y / world_scale, world.z / world_scale
                else:
                    u, v = world.x / world_scale, world.z / world_scale
                uv_layer.data[loop_index].uv = (u, v)
        mesh.uv_layers.active = uv_layer
        mesh.update()


def look_at(obj: bpy.types.Object, target: tuple[float, float, float]) -> None:
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_preview_scene(preview_collection: bpy.types.Collection) -> bpy.types.Object:
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1536
    scene.render.resolution_y = 1024
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.render.use_file_extension = True

    world = bpy.data.worlds.new("TBSA_PreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = rgba("#54BCE2")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.62
    scene.world = world

    camera_data = bpy.data.cameras.new("TBSA_PreviewCamera")
    camera = bpy.data.objects.new("TBSA_PreviewCamera", camera_data)
    preview_collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera

    sun_data = bpy.data.lights.new("TBSA_Sun", type="SUN")
    sun_data.color = rgba("#FFF1D3")[:3]
    sun_data.energy = 2.1
    sun_data.angle = math.radians(14.0)
    sun = bpy.data.objects.new("TBSA_Sun", sun_data)
    preview_collection.objects.link(sun)
    sun.rotation_euler = (math.radians(36.0), math.radians(-24.0), math.radians(-38.0))

    fill_data = bpy.data.lights.new("TBSA_CoolFill", type="AREA")
    fill_data.color = rgba("#8DEBFF")[:3]
    fill_data.energy = 1800.0
    fill_data.shape = "DISK"
    fill_data.size = 35.0
    fill = bpy.data.objects.new("TBSA_CoolFill", fill_data)
    preview_collection.objects.link(fill)
    fill.location = (-25.0, -30.0, 42.0)
    look_at(fill, (0.0, 0.0, 0.0))

    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.55
    return camera


def render_previews(
    hero_collection: bpy.types.Collection,
    foreground_collection: bpy.types.Collection,
    camera: bpy.types.Object,
) -> None:
    scene = bpy.context.scene
    hero_collection.hide_render = True
    foreground_collection.hide_render = False
    camera.location = (0.34, -64.0, 100.0)
    camera.data.ortho_scale = 124.0
    look_at(camera, (0.34, 0.0, 1.0))
    scene.render.filepath = str(FOREGROUND_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    foreground_collection.hide_render = True
    hero_collection.hide_render = False
    camera.location = (20.0, -24.0, 20.0)
    camera.data.ortho_scale = 24.5
    look_at(camera, (0.0, 0.0, 2.1))
    scene.render.filepath = str(HERO_PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

    hero_collection.hide_render = True
    foreground_collection.hide_render = False
    camera.location = (0.34, -64.0, 100.0)
    camera.data.ortho_scale = 124.0
    look_at(camera, (0.34, 0.0, 1.0))


def select_collection_for_export(collection: bpy.types.Collection) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        if obj.type in {"MESH", "EMPTY"}:
            obj.hide_set(False)
            obj.select_set(True)


def export_collection(collection: bpy.types.Collection, path: Path) -> None:
    select_collection_for_export(collection)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    bpy.ops.object.select_all(action="DESELECT")


def collection_stats(collection: bpy.types.Collection) -> dict:
    meshes = [obj for obj in collection.all_objects if obj.type == "MESH"]
    empties = [obj for obj in collection.all_objects if obj.type == "EMPTY"]
    triangles = 0
    materials = set()
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for material in obj.data.materials:
            if material:
                materials.add(material.name)
    return {
        "mesh_objects": len(meshes),
        "semantic_anchors": len(empties) - 1 if empties else 0,
        "triangles": triangles,
        "materials": sorted(materials),
    }


def validate_scene(
    hero_collection: bpy.types.Collection,
    foreground_collection: bpy.types.Collection,
) -> None:
    for collection in (hero_collection, foreground_collection):
        forbidden_types = [obj.name for obj in collection.all_objects if obj.type in {"CAMERA", "LIGHT", "ARMATURE"}]
        if forbidden_types:
            raise RuntimeError(f"Export collection contains forbidden object types: {forbidden_types}")
        forbidden_names = [
            obj.name for obj in collection.all_objects
            if any(token in obj.name.lower() for token in FORBIDDEN_NAME_TOKENS)
        ]
        if forbidden_names:
            raise RuntimeError(f"Dry-floor contract failed; prohibited object names: {forbidden_names}")
        materials = {
            material.name
            for obj in collection.all_objects if obj.type == "MESH"
            for material in obj.data.materials if material
        }
        if len(materials) > MAX_PRIMARY_MATERIALS:
            raise RuntimeError(f"Material budget exceeded: {len(materials)} > {MAX_PRIMARY_MATERIALS}")
    foreground_names = {obj.name for obj in foreground_collection.all_objects}
    if any("PortalGlow" in name or "PortalCore" in name or "WaterRing" in name for name in foreground_names):
        raise RuntimeError("Dynamic portal water visuals must not be baked into the foreground GLB")


def write_manifest(
    layout: dict,
    hero_collection: bpy.types.Collection,
    foreground_collection: bpy.types.Collection,
    geometry_audit: dict,
    texture_sets: dict[str, dict],
    source_stats: dict[str, dict],
) -> None:
    layout_sha256 = hashlib.sha256(LAYOUT_PATH.read_bytes()).hexdigest()
    builder_sha256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    hero_stats = collection_stats(hero_collection)
    foreground_stats = collection_stats(foreground_collection)
    if int(source_stats["production_foreground"]["mesh_objects"]) <= int(foreground_stats["mesh_objects"]):
        raise RuntimeError("Export consolidation did not reduce foreground mesh objects")
    if int(foreground_stats["mesh_objects"]) > MAX_PRIMARY_MATERIALS:
        raise RuntimeError("Export foreground mesh count exceeds the material batching ceiling")
    used_materials = sorted(set(hero_stats["materials"]) | set(foreground_stats["materials"]))
    anchors = sorted(
        {
            obj.name
            for collection in (hero_collection, foreground_collection)
            for obj in collection.all_objects
            if obj.type == "EMPTY" and obj.get("semantic_id")
        }
    )
    output_paths = {
        "blend": BLEND_PATH,
        "hero_glb": HERO_GLB_PATH,
        "foreground_glb": FOREGROUND_GLB_PATH,
        "hero_preview": HERO_PREVIEW_PATH,
        "foreground_preview": FOREGROUND_PREVIEW_PATH,
    }
    missing_outputs = [str(path) for path in output_paths.values() if not path.is_file()]
    texture_paths = {
        role: {map_name: path for map_name, path in texture_set["paths"].items()}
        for role, texture_set in texture_sets.items()
    }
    missing_outputs.extend(
        str(path)
        for maps in texture_paths.values()
        for path in maps.values()
        if not path.is_file()
    )
    if missing_outputs:
        raise RuntimeError(f"Cannot finalize manifest; generated outputs are missing: {missing_outputs}")
    manifest = {
        "asset": "Twin Bays Splash Arena",
        "schema": "chaos_gun.generated_environment_manifest",
        "version": 1,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "generator": str(Path(__file__).relative_to(ROOT)).replace("\\", "/"),
        "generator_sha256": builder_sha256,
        "layout": str(LAYOUT_PATH.relative_to(ROOT)).replace("\\", "/"),
        "layout_schema": layout["schema"],
        "layout_version": layout["version"],
        "layout_sha256": layout_sha256,
        "coordinate_conversion": "Godot(x,y,z) -> Blender(x,-z,y); glTF export_yup=true",
        "outputs": {
            name: str(path.relative_to(ROOT)).replace("\\", "/")
            for name, path in output_paths.items()
        },
        "output_sha256": {
            name: hashlib.sha256(path.read_bytes()).hexdigest()
            for name, path in output_paths.items()
        },
        "palette": COLOR_CONTRACT,
        "support_colors": SUPPORT_COLORS,
        "pbr_texture_sets": {
            role: {
                "resolution": int(texture_sets[role]["resolution"]),
                "uv_world_scale": float(texture_sets[role]["uv_world_scale"]),
                "surface_style": str(texture_sets[role]["surface_style"]),
                "maps": {
                    map_name: str(path.relative_to(ROOT)).replace("\\", "/")
                    for map_name, path in texture_paths[role].items()
                },
                "sha256": {
                    map_name: hashlib.sha256(path.read_bytes()).hexdigest()
                    for map_name, path in texture_paths[role].items()
                },
            }
            for role in sorted(texture_sets)
        },
        "material_count": len(used_materials),
        "materials": used_materials,
        "hero_kit": hero_stats,
        "production_foreground": foreground_stats,
        "editable_source": source_stats,
        "export_consolidation": {
            "hero_source_meshes": int(source_stats["hero_kit"]["mesh_objects"]),
            "hero_export_meshes": int(hero_stats["mesh_objects"]),
            "foreground_source_meshes": int(source_stats["production_foreground"]["mesh_objects"]),
            "foreground_export_meshes": int(foreground_stats["mesh_objects"]),
            "foreground_mesh_reduction": round(
                1.0 - float(foreground_stats["mesh_objects"])
                / max(float(source_stats["production_foreground"]["mesh_objects"]), 1.0),
                6,
            ),
        },
        "semantic_anchors": anchors,
        "geometry_audit": geometry_audit,
        "contracts": {
            "visual_only": True,
            "collision_in_glb": False,
            "camera_in_glb": False,
            "light_in_glb": False,
            "character_in_glb": False,
            "weapon_in_glb": False,
            "dynamic_portal_ring_in_glb": False,
            "floor_water_marks": False,
            "structure_frozen": True,
            "pbr_texture_families": sorted(texture_sets),
            "editable_blend_unbatched": True,
            "export_static_batched_by_material": True,
            "causeway_visual_width": float(layout["platform"]["causeway"]["safe_width"]),
            "safety_trim_visible_width": SAFETY_TRIM_VISIBLE_WIDTH,
            "safety_trim_lift": SAFETY_TRIM_LIFT,
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build() -> None:
    layout = load_layout()
    geometry_audit = validate_layout_geometry(layout)
    clear_scene()
    for directory in (SOURCE_DIR, GENERATED_DIR, PREVIEW_DIR, TEXTURE_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    texture_sets = generate_pbr_texture_sets()
    materials = create_materials(texture_sets)
    hero_collection = make_collection("TBSA_HERO_KIT_EXPORT")
    foreground_collection = make_collection("TBSA_FOREGROUND_EXPORT")
    preview_collection = make_collection("TBSA_PREVIEW_ONLY")

    build_hero_kit(layout, materials, hero_collection)
    build_production_foreground(layout, materials, foreground_collection)
    validate_scene(hero_collection, foreground_collection)
    source_stats = {
        "hero_kit": collection_stats(hero_collection),
        "production_foreground": collection_stats(foreground_collection),
    }

    # Save the authored source while every module is still independently
    # editable. The following joins are export-only mutations in this process.
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    blend_backup = BLEND_PATH.with_name(BLEND_PATH.name + "1")
    if blend_backup.exists():
        blend_backup.unlink()

    join_meshes_by_material(hero_collection, "Hero")
    join_meshes_by_material(foreground_collection, "Foreground")
    add_world_projected_uvs(hero_collection)
    add_world_projected_uvs(foreground_collection)
    validate_scene(hero_collection, foreground_collection)

    camera = configure_preview_scene(preview_collection)
    render_previews(hero_collection, foreground_collection, camera)
    export_collection(hero_collection, HERO_GLB_PATH)
    export_collection(foreground_collection, FOREGROUND_GLB_PATH)

    foreground_collection.hide_render = False
    hero_collection.hide_render = True
    write_manifest(
        layout, hero_collection, foreground_collection, geometry_audit, texture_sets, source_stats,
    )

    print(f"Saved Blender source: {BLEND_PATH}")
    print(f"Exported hero kit: {HERO_GLB_PATH}")
    print(f"Exported production foreground: {FOREGROUND_GLB_PATH}")
    print(f"Rendered hero preview: {HERO_PREVIEW_PATH}")
    print(f"Rendered foreground preview: {FOREGROUND_PREVIEW_PATH}")
    print(f"Wrote manifest: {MANIFEST_PATH}")


if __name__ == "__main__":
    build()
