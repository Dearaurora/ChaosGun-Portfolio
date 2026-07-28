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
import struct
from datetime import datetime, timezone
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.geometry import tessellate_polygon


ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = ROOT / "resources" / "maps" / "twin_bays_layout_v1.json"
ART_PROFILE_PATH = ROOT / "resources" / "maps" / "twin_bays_art_v3.json"
TIDE_PROFILE_PATH = ROOT / "resources" / "maps" / "twin_bays_tide_v1.json"
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
ART_SCHEMA = "chaos_gun.twin_bays_art"
ART_SCHEMA_VERSION = 3
TIDE_SCHEMA = "chaos_gun.twin_bays_tide"
TIDE_SCHEMA_VERSION = 1
MAX_PRIMARY_MATERIALS = 12
SAFETY_TRIM_VISIBLE_WIDTH = 0.38
SAFETY_TRIM_RADIUS = SAFETY_TRIM_VISIBLE_WIDTH * 0.5
SAFETY_TRIM_LIFT = 0.02
WALL_CAP_BEVEL_MULTIPLIER = 0.28
WALL_CAP_BEVEL_SEGMENTS = 3
COVER_BEVEL_MULTIPLIER = 1.0
WALL_BODY_BEVEL = 0.0
COVER_TOP_INSET_SCALE = 0.0
COVER_TOP_INSET_HEIGHT = 0.0
PIPE_BAND_RADIUS_BONUS = 0.0
PIPE_BAND_HALF_SPAN = 0.0
WALL_CAP_DEPTH_MULTIPLIER = 1.0
WALL_CAP_OUTSET = 0.0
WALL_CAP_SEGMENT_CUSHIONS = False
WALL_CAP_SEGMENT_GAP = 0.0
WALL_CAP_CUSHION_HEIGHT_MULTIPLIER = 0.0
WALL_CAP_MODULE_LENGTH = 5.2
WALL_CONTINUOUS_SWEEP = False
WALL_CAP_VISUAL_MODULE_SEAMS = False
WALL_CURVE_SUBDIVISIONS = 1
WALL_CAP_PROFILE_SEGMENTS = 16
WALL_CAP_SUPERELLIPSE_POWER = 2.0
PLATFORM_SKIRT_BOTTOM_Y: float | None = None
PLATFORM_CONTACT_FOAM_RADIUS = 0.0
PLATFORM_CONTACT_FOAM_OUTSET = 0.0
PLATFORM_CONTACT_FOAM_CLUSTERS = False
PLATFORM_CONTACT_FOAM_SCALLOPS = False
PLATFORM_CONTACT_BAY_FOAM_SCALLOPS = False
PLATFORM_CONTACT_FOAM_SCALLOP_RADIUS = 0.0
PLATFORM_CONTACT_FOAM_SCALLOP_STRIDE = 3
PLATFORM_CONTACT_FOAM_FRONT_MAX_Y = -1.0e9
PLATFORM_CORAL_BUMPER_RADIUS = 0.0
PLATFORM_CORAL_BUMPER_MAX_Y = -1.0e9
PLATFORM_CORAL_BUMPER_SEAMS = False
PLATFORM_CORAL_BUMPER_SEAM_HALF_SPAN = 0.0
PLATFORM_CORAL_BUMPER_SEAM_RADIUS_BONUS = 0.0
PIPE_OUTER_RADIUS_MULTIPLIER = 1.0
PIPE_COLLAR_RADIUS_MULTIPLIER = 1.0
PIPE_COLLAR_DEPTH_MULTIPLIER = 1.0
PIPE_VISUAL_PATH_FRACTION = 1.0
PIPE_PANEL_SEAMS = False
PIPE_PANEL_SEAM_COUNT = 0
PIPE_PANEL_SEAM_HALF_SPAN = 0.0
PIPE_PANEL_SEAM_RADIUS_BONUS = 0.0
SCENIC_DRESSING_ENABLED = False
SCENIC_SCALE = 1.0
SCENIC_PULL_IN = 0.0
SCENIC_HERO_FLOAT_SCALE = 1.0
SCENIC_HERO_PARASOLS = False
SCENIC_HERO_FOREGROUND_FLOATERS = False
PREVIEW_WATER_ENABLED = False
PREVIEW_RESOLUTION = (1536, 1024)
PREVIEW_ORTHO_SCALE = 124.0
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
    "foam": "#F3FEFF",
    "island_green": "#2DB99B",
    "palm_trunk": "#B87952",
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


def load_art_and_tide_profiles() -> tuple[dict, dict]:
    if not ART_PROFILE_PATH.is_file() or not TIDE_PROFILE_PATH.is_file():
        raise FileNotFoundError("Twin Bays Art V3 and Tide V1 profiles are required")
    art = json.loads(ART_PROFILE_PATH.read_text(encoding="utf-8"))
    tide = json.loads(TIDE_PROFILE_PATH.read_text(encoding="utf-8"))
    if art.get("schema") != ART_SCHEMA or int(art.get("version", 0)) != ART_SCHEMA_VERSION:
        raise ValueError("Unsupported Twin Bays Art profile")
    if tide.get("schema") != TIDE_SCHEMA or int(tide.get("version", 0)) != TIDE_SCHEMA_VERSION:
        raise ValueError("Unsupported Twin Bays Tide profile")
    layout_sha = hashlib.sha256(LAYOUT_PATH.read_bytes()).hexdigest()
    tide_sha = hashlib.sha256(TIDE_PROFILE_PATH.read_bytes()).hexdigest()
    if art.get("layout_sha256") != layout_sha or art.get("tide_sha256") != tide_sha:
        raise ValueError("Twin Bays Art V3 is not bound to the current Layout/Tide fingerprint")
    if tide.get("layout_sha256") != layout_sha:
        raise ValueError("Twin Bays Tide V1 is not bound to the current layout")
    return art, tide


def configure_from_art_profile(art: dict) -> None:
    global MAX_PRIMARY_MATERIALS, SAFETY_TRIM_VISIBLE_WIDTH, SAFETY_TRIM_RADIUS, SAFETY_TRIM_LIFT
    global WALL_CAP_BEVEL_MULTIPLIER, WALL_CAP_BEVEL_SEGMENTS, COVER_BEVEL_MULTIPLIER
    global WALL_BODY_BEVEL, COVER_TOP_INSET_SCALE, COVER_TOP_INSET_HEIGHT
    global PIPE_BAND_RADIUS_BONUS, PIPE_BAND_HALF_SPAN
    global WALL_CAP_DEPTH_MULTIPLIER, WALL_CAP_OUTSET
    global WALL_CAP_SEGMENT_CUSHIONS, WALL_CAP_SEGMENT_GAP, WALL_CAP_CUSHION_HEIGHT_MULTIPLIER
    global WALL_CAP_MODULE_LENGTH
    global WALL_CONTINUOUS_SWEEP, WALL_CAP_VISUAL_MODULE_SEAMS, WALL_CURVE_SUBDIVISIONS
    global WALL_CAP_PROFILE_SEGMENTS, WALL_CAP_SUPERELLIPSE_POWER
    global PLATFORM_SKIRT_BOTTOM_Y, PLATFORM_CONTACT_FOAM_RADIUS, PLATFORM_CONTACT_FOAM_OUTSET
    global PLATFORM_CONTACT_FOAM_CLUSTERS, PLATFORM_CONTACT_FOAM_SCALLOPS
    global PLATFORM_CONTACT_BAY_FOAM_SCALLOPS
    global PLATFORM_CONTACT_FOAM_SCALLOP_RADIUS, PLATFORM_CONTACT_FOAM_SCALLOP_STRIDE
    global PLATFORM_CONTACT_FOAM_FRONT_MAX_Y
    global PLATFORM_CORAL_BUMPER_RADIUS, PLATFORM_CORAL_BUMPER_MAX_Y
    global PLATFORM_CORAL_BUMPER_SEAMS, PLATFORM_CORAL_BUMPER_SEAM_HALF_SPAN
    global PLATFORM_CORAL_BUMPER_SEAM_RADIUS_BONUS
    global PIPE_OUTER_RADIUS_MULTIPLIER, PIPE_COLLAR_RADIUS_MULTIPLIER, PIPE_COLLAR_DEPTH_MULTIPLIER
    global PIPE_VISUAL_PATH_FRACTION, PIPE_PANEL_SEAMS, PIPE_PANEL_SEAM_COUNT
    global PIPE_PANEL_SEAM_HALF_SPAN, PIPE_PANEL_SEAM_RADIUS_BONUS
    global SCENIC_DRESSING_ENABLED, SCENIC_SCALE, SCENIC_PULL_IN
    global SCENIC_HERO_FLOAT_SCALE, SCENIC_HERO_PARASOLS, SCENIC_HERO_FOREGROUND_FLOATERS
    global PREVIEW_WATER_ENABLED, PREVIEW_RESOLUTION, PREVIEW_ORTHO_SCALE
    palette = art["palette"]
    COLOR_CONTRACT.update({
        "dry_cream": palette["cream"],
        "cyan": palette["cyan"],
        "coral": palette["coral"],
        "safety_yellow": palette["safety_yellow"],
        "pickup_orange": palette["pickup_orange"],
        "portal_cyan": palette["portal_cyan"],
    })
    SUPPORT_COLORS.update({
        "cyan_dark": palette["cyan_shadow"],
        "portal_recess": palette["portal_recess"],
        "foam": palette.get("foam", SUPPORT_COLORS["foam"]),
        "island_green": palette.get("island_green", SUPPORT_COLORS["island_green"]),
        "palm_trunk": palette.get("palm_trunk", SUPPORT_COLORS["palm_trunk"]),
    })
    role_mapping = {"dry_cream": "cream", "cyan": "cyan", "cyan_dark": "cyan_shadow", "coral": "coral"}
    for builder_role, profile_role in role_mapping.items():
        source = art["surface_families"][profile_role]
        target = PBR_TEXTURE_SPECS[builder_role]
        for key in (
            "resolution",
            "uv_world_scale",
            "panel_count",
            "seam_width",
            "seam_axis",
            "roughness",
            "roughness_seam",
            "variation",
            "seam_darkening",
            "normal_strength",
        ):
            if key not in source:
                continue
            target[key] = source[key]
        target["surface_style"] = source["style"]
        target["base_hex"] = COLOR_CONTRACT[builder_role] if builder_role in COLOR_CONTRACT else SUPPORT_COLORS[builder_role]
        if "soft_bulge" in source:
            target["soft_bulge"] = bool(source["soft_bulge"])
    visual = art["visual_geometry"]
    SAFETY_TRIM_VISIBLE_WIDTH = float(visual["safety_trim_visible_width"])
    SAFETY_TRIM_RADIUS = SAFETY_TRIM_VISIBLE_WIDTH * 0.5
    SAFETY_TRIM_LIFT = float(visual["safety_trim_lift"])
    WALL_CAP_BEVEL_MULTIPLIER = float(visual["wall_cap_bevel_multiplier"])
    WALL_CAP_BEVEL_SEGMENTS = int(visual["wall_cap_bevel_segments"])
    COVER_BEVEL_MULTIPLIER = float(visual["cover_bevel_multiplier"])
    WALL_BODY_BEVEL = float(visual.get("wall_body_bevel", 0.0))
    COVER_TOP_INSET_SCALE = float(visual.get("cover_top_inset_scale", 0.0))
    COVER_TOP_INSET_HEIGHT = float(visual.get("cover_top_inset_height", 0.0))
    PIPE_BAND_RADIUS_BONUS = float(visual.get("pipe_band_radius_bonus", 0.0))
    PIPE_BAND_HALF_SPAN = float(visual.get("pipe_band_half_span", 0.0))
    WALL_CAP_DEPTH_MULTIPLIER = float(visual.get("wall_cap_depth_multiplier", 1.0))
    WALL_CAP_OUTSET = float(visual.get("wall_cap_outset", 0.0))
    WALL_CAP_SEGMENT_CUSHIONS = bool(visual.get("wall_cap_segment_cushions", False))
    WALL_CAP_SEGMENT_GAP = float(visual.get("wall_cap_segment_gap", 0.0))
    WALL_CAP_CUSHION_HEIGHT_MULTIPLIER = float(
        visual.get("wall_cap_cushion_height_multiplier", 0.0)
    )
    WALL_CAP_MODULE_LENGTH = max(
        3.0,
        float(visual.get("wall_cap_module_length", 5.2)),
    )
    WALL_CONTINUOUS_SWEEP = bool(visual.get("wall_continuous_sweep", False))
    WALL_CAP_VISUAL_MODULE_SEAMS = bool(
        visual.get("wall_cap_visual_module_seams", False)
    )
    WALL_CURVE_SUBDIVISIONS = max(1, int(visual.get("wall_curve_subdivisions", 1)))
    WALL_CAP_PROFILE_SEGMENTS = max(12, int(visual.get("wall_cap_profile_segments", 16)))
    WALL_CAP_SUPERELLIPSE_POWER = max(
        2.0,
        float(visual.get("wall_cap_superellipse_power", 2.0)),
    )
    skirt_bottom = visual.get("platform_skirt_bottom_y")
    PLATFORM_SKIRT_BOTTOM_Y = float(skirt_bottom) if skirt_bottom is not None else None
    PLATFORM_CONTACT_FOAM_RADIUS = float(visual.get("platform_contact_foam_radius", 0.0))
    PLATFORM_CONTACT_FOAM_OUTSET = float(visual.get("platform_contact_foam_outset", 0.0))
    PLATFORM_CONTACT_FOAM_CLUSTERS = bool(
        visual.get("platform_contact_foam_clusters", False)
    )
    PLATFORM_CONTACT_FOAM_SCALLOPS = bool(
        visual.get("platform_contact_foam_scallops", False)
    )
    PLATFORM_CONTACT_BAY_FOAM_SCALLOPS = bool(
        visual.get("platform_contact_bay_foam_scallops", False)
    )
    PLATFORM_CONTACT_FOAM_SCALLOP_RADIUS = float(
        visual.get("platform_contact_foam_scallop_radius", 0.0)
    )
    PLATFORM_CONTACT_FOAM_SCALLOP_STRIDE = max(
        1,
        int(visual.get("platform_contact_foam_scallop_stride", 3)),
    )
    PLATFORM_CONTACT_FOAM_FRONT_MAX_Y = float(
        visual.get("platform_contact_foam_front_max_y", -1.0e9)
    )
    PLATFORM_CORAL_BUMPER_RADIUS = float(visual.get("platform_coral_bumper_radius", 0.0))
    PLATFORM_CORAL_BUMPER_MAX_Y = float(visual.get("platform_coral_bumper_max_y", -1.0e9))
    PLATFORM_CORAL_BUMPER_SEAMS = bool(
        visual.get("platform_coral_bumper_seams", False)
    )
    PLATFORM_CORAL_BUMPER_SEAM_HALF_SPAN = max(
        0.0,
        float(visual.get("platform_coral_bumper_seam_half_span", 0.0)),
    )
    PLATFORM_CORAL_BUMPER_SEAM_RADIUS_BONUS = max(
        0.0,
        float(visual.get("platform_coral_bumper_seam_radius_bonus", 0.0)),
    )
    PIPE_OUTER_RADIUS_MULTIPLIER = float(visual.get("pipe_outer_radius_multiplier", 1.0))
    PIPE_COLLAR_RADIUS_MULTIPLIER = float(visual.get("pipe_collar_radius_multiplier", 1.0))
    PIPE_COLLAR_DEPTH_MULTIPLIER = float(visual.get("pipe_collar_depth_multiplier", 1.0))
    PIPE_VISUAL_PATH_FRACTION = max(
        0.15,
        min(
            1.0,
            float(visual.get("pipe_visual_path_fraction", 1.0)),
        ),
    )
    PIPE_PANEL_SEAMS = bool(visual.get("pipe_panel_seams", False))
    PIPE_PANEL_SEAM_COUNT = max(0, int(visual.get("pipe_panel_seam_count", 0)))
    PIPE_PANEL_SEAM_HALF_SPAN = max(
        0.0,
        float(visual.get("pipe_panel_seam_half_span", 0.0)),
    )
    PIPE_PANEL_SEAM_RADIUS_BONUS = max(
        0.0,
        float(visual.get("pipe_panel_seam_radius_bonus", 0.0)),
    )
    backdrop = art.get("backdrop", {})
    SCENIC_DRESSING_ENABLED = bool(backdrop.get("static_dressing_in_foreground", False))
    SCENIC_SCALE = max(0.75, float(backdrop.get("scenic_scale", 1.0)))
    SCENIC_PULL_IN = max(0.0, float(backdrop.get("scenic_pull_in", 0.0)))
    SCENIC_HERO_FLOAT_SCALE = max(0.75, float(backdrop.get("hero_float_scale", 1.0)))
    SCENIC_HERO_PARASOLS = bool(backdrop.get("hero_parasols", False))
    SCENIC_HERO_FOREGROUND_FLOATERS = bool(
        backdrop.get("hero_foreground_floaters", False)
    )
    preview = art.get("preview", {})
    PREVIEW_WATER_ENABLED = bool(preview.get("water_plane", False))
    preview_resolution = preview.get("resolution", [1536, 1024])
    if isinstance(preview_resolution, list) and len(preview_resolution) >= 2:
        PREVIEW_RESOLUTION = (int(preview_resolution[0]), int(preview_resolution[1]))
    PREVIEW_ORTHO_SCALE = float(preview.get("ortho_scale", 124.0))
    MAX_PRIMARY_MATERIALS = int(art["budgets"]["primary_material_absolute_max"])


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
        seam_axis = str(spec.get("seam_axis", "grid"))
        if seam_axis == "horizontal":
            seam = edge_y <= seam_width
            edge_distance = edge_y
        elif seam_axis == "none":
            seam = np.zeros_like(edge_distance, dtype=bool)
        else:
            seam = edge_distance <= seam_width
        bevel_amount = np.clip((edge_distance - seam_width) / max(seam_width * 2.0, 1.0), 0.0, 1.0)
        bevel_amount = bevel_amount * bevel_amount * (3.0 - 2.0 * bevel_amount)
        if seam_axis == "none":
            bevel_amount = np.ones_like(bevel_amount)

        tile_x = np.floor(x / tile_size).astype(np.int32)
        tile_y = np.floor(y / tile_size).astype(np.int32)
        if seam_axis == "horizontal":
            panel_code = np.mod(tile_y * 17, 7).astype(np.float32) - 3.0
        elif seam_axis == "none":
            panel_code = np.zeros_like(x, dtype=np.float32)
        else:
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
            "TBSA_DryCream", COLOR_CONTRACT["dry_cream"], float(PBR_TEXTURE_SPECS["dry_cream"]["roughness"]), texture_set=texture_sets["dry_cream"],
        ),
        "cyan": make_material(
            "TBSA_Cyan", COLOR_CONTRACT["cyan"], float(PBR_TEXTURE_SPECS["cyan"]["roughness"]), texture_set=texture_sets["cyan"],
        ),
        "cyan_dark": make_material(
            "TBSA_CyanDark", SUPPORT_COLORS["cyan_dark"], float(PBR_TEXTURE_SPECS["cyan_dark"]["roughness"]), texture_set=texture_sets["cyan_dark"],
        ),
        "coral": make_material(
            "TBSA_CoralSoft", COLOR_CONTRACT["coral"], float(PBR_TEXTURE_SPECS["coral"]["roughness"]), texture_set=texture_sets["coral"],
        ),
        "yellow": make_material(
            "TBSA_SafetyYellow", COLOR_CONTRACT["safety_yellow"], 0.58,
            emission_hex=COLOR_CONTRACT["safety_yellow"] if ART_SCHEMA_VERSION >= 5 else None,
            emission_strength=0.04 if ART_SCHEMA_VERSION >= 5 else 0.0,
        ),
        "orange": make_material("TBSA_PickupOrange", COLOR_CONTRACT["pickup_orange"], 0.56),
        "portal_cyan": make_material(
            "TBSA_PortalCyan", COLOR_CONTRACT["portal_cyan"], 0.32,
            emission_hex=COLOR_CONTRACT["portal_cyan"], emission_strength=1.35,
        ),
        "portal_recess": make_material("TBSA_PortalRecess", SUPPORT_COLORS["portal_recess"], 0.48),
        "foam": make_material(
            "TBSA_ContactFoam", SUPPORT_COLORS["foam"], 0.28,
            emission_hex=SUPPORT_COLORS["foam"], emission_strength=0.035,
        ),
        "island_green": make_material("TBSA_IslandGreen", SUPPORT_COLORS["island_green"], 0.72),
        "palm_trunk": make_material("TBSA_PalmTrunk", SUPPORT_COLORS["palm_trunk"], 0.78),
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


def add_cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    vertices: int = 24,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    if bevel > 0.0:
        apply_bevel(obj, min(bevel, depth * 0.32, radius * 0.32), 3)
    return obj


def add_cone(
    name: str,
    location: tuple[float, float, float],
    radius_top: float,
    radius_bottom: float,
    depth: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    vertices: int = 24,
    bevel: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    if bevel > 0.0:
        apply_bevel(obj, min(bevel, depth * 0.24, radius_bottom * 0.24), 3)
    return obj


def add_sphere(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    segments: int = 20,
    rings: int = 10,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        radius=radius,
        location=location,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_torus(
    name: str,
    location: tuple[float, float, float],
    major_radius: float,
    minor_radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    yaw_degrees: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        align="WORLD",
        major_segments=32,
        minor_segments=12,
        location=location,
        rotation=(0.0, 0.0, math.radians(yaw_degrees)),
        major_radius=major_radius,
        minor_radius=minor_radius,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    obj["visual_only"] = True
    apply_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
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


def sample_wall_section(
    points: list[list[float]],
    offsets: list[float],
    thicknesses: list[float],
    subdivisions: int,
) -> tuple[list[tuple[float, float]], list[float]]:
    """Return a smooth Blender-planar wall centerline and matching widths.

    The layout points remain authoritative. Catmull-Rom interpolation only
    increases visual sampling between those points, while widths are linearly
    interpolated per authored segment to avoid overshoot at narrow wall ends.
    """
    authored = [
        Vector(g2b_planar((float(point[0]), float(point[1]) + float(offset))))
        for point, offset in zip(points, offsets)
    ]
    if len(authored) < 2:
        return [tuple(point) for point in authored], [float(value) for value in thicknesses]
    samples: list[tuple[float, float]] = []
    widths: list[float] = []
    for index in range(len(authored) - 1):
        p0 = authored[max(index - 1, 0)]
        p1 = authored[index]
        p2 = authored[index + 1]
        p3 = authored[min(index + 2, len(authored) - 1)]
        for step in range(subdivisions):
            amount = float(step) / float(subdivisions)
            amount_2 = amount * amount
            amount_3 = amount_2 * amount
            sample = 0.5 * (
                2.0 * p1
                + (-p0 + p2) * amount
                + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * amount_2
                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * amount_3
            )
            if samples and (sample - Vector(samples[-1])).length <= 1.0e-5:
                continue
            samples.append((float(sample.x), float(sample.y)))
            widths.append(
                float(thicknesses[index])
                + (float(thicknesses[index + 1]) - float(thicknesses[index])) * amount
            )
    samples.append((float(authored[-1].x), float(authored[-1].y)))
    widths.append(float(thicknesses[-1]))
    return samples, widths


def wall_footprint_from_samples(
    centerline: list[tuple[float, float]],
    widths: list[float],
) -> list[tuple[float, float]]:
    left: list[Vector] = []
    right: list[Vector] = []
    vectors = [Vector(point) for point in centerline]
    for index, point in enumerate(vectors):
        previous = vectors[max(index - 1, 0)]
        following = vectors[min(index + 1, len(vectors) - 1)]
        tangent = (following - previous).normalized()
        normal = Vector((-tangent.y, tangent.x))
        half_width = float(widths[index]) * 0.5
        left.append(point + normal * half_width)
        right.append(point - normal * half_width)
    return [tuple(point) for point in left + list(reversed(right))]


def add_swept_soft_wall_cap(
    name: str,
    centerline: list[tuple[float, float]],
    widths: list[float],
    bottom_z: float,
    depth: float,
    outset: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    profile_segments: int,
    superellipse_power: float,
) -> bpy.types.Object:
    """Create one continuous soft cap instead of a chain of rounded boxes."""
    vectors = [Vector(point) for point in centerline]
    tangents: list[Vector] = []
    for index in range(len(vectors)):
        previous = vectors[max(index - 1, 0)]
        following = vectors[min(index + 1, len(vectors) - 1)]
        tangents.append((following - previous).normalized())

    half_depth = depth * 0.5
    longitudinal_radius = min(half_depth, min(widths) * 0.22)
    cap_steps = 3
    rings: list[tuple[Vector, Vector, float, float]] = []
    start = vectors[0]
    start_tangent = tangents[0]
    for step in range(1, cap_steps + 1):
        theta = (float(step) / float(cap_steps + 1)) * math.pi * 0.5
        rings.append(
            (
                start - start_tangent * (math.cos(theta) * longitudinal_radius),
                start_tangent,
                widths[0],
                math.sin(theta),
            )
        )
    rings.extend(
        (center, tangent, width, 1.0)
        for center, tangent, width in zip(vectors, tangents, widths)
    )
    end = vectors[-1]
    end_tangent = tangents[-1]
    for step in range(1, cap_steps + 1):
        theta = (1.0 - float(step) / float(cap_steps + 1)) * math.pi * 0.5
        rings.append(
            (
                end + end_tangent * (math.cos(theta) * longitudinal_radius),
                end_tangent,
                widths[-1],
                math.sin(theta),
            )
        )

    vertices: list[tuple[float, float, float]] = []
    for center, tangent, width, radial_scale in rings:
        lateral = Vector((-tangent.y, tangent.x))
        half_width = (float(width) * 0.5 + outset) * radial_scale
        vertical_radius = half_depth * radial_scale
        for profile_index in range(profile_segments):
            angle = math.tau * float(profile_index) / float(profile_segments)
            cosine = math.cos(angle)
            sine = math.sin(angle)
            side_shape = math.copysign(
                abs(cosine) ** (2.0 / superellipse_power),
                cosine,
            )
            vertical_shape = math.copysign(
                abs(sine) ** (2.0 / superellipse_power),
                sine,
            )
            planar = center + lateral * (side_shape * half_width)
            vertices.append(
                (
                    float(planar.x),
                    float(planar.y),
                    bottom_z + half_depth + vertical_shape * vertical_radius,
                )
            )

    faces: list[tuple[int, ...]] = []
    for ring_index in range(len(rings) - 1):
        current = ring_index * profile_segments
        following = (ring_index + 1) * profile_segments
        for profile_index in range(profile_segments):
            next_profile = (profile_index + 1) % profile_segments
            faces.append(
                (
                    current + profile_index,
                    following + profile_index,
                    following + next_profile,
                    current + next_profile,
                )
            )

    start_tip = len(vertices)
    vertices.append(
        (
            float((start - start_tangent * longitudinal_radius).x),
            float((start - start_tangent * longitudinal_radius).y),
            bottom_z + half_depth,
        )
    )
    end_tip = len(vertices)
    vertices.append(
        (
            float((end + end_tangent * longitudinal_radius).x),
            float((end + end_tangent * longitudinal_radius).y),
            bottom_z + half_depth,
        )
    )
    first_ring = 0
    last_ring = (len(rings) - 1) * profile_segments
    for profile_index in range(profile_segments):
        next_profile = (profile_index + 1) % profile_segments
        faces.append((start_tip, first_ring + next_profile, first_ring + profile_index))
        faces.append((end_tip, last_ring + profile_index, last_ring + next_profile))

    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj["visual_only"] = True
    obj["construction"] = "continuous_superellipse_sweep"
    apply_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_wall_cap_cushion_modules(
    name_prefix: str,
    centerline: list[tuple[float, float]],
    widths: list[float],
    bottom_z: float,
    cap_depth: float,
    outset: float,
    cushion_height: float,
    gap: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> int:
    """Seat camera-readable soft modules on a continuous collision-free cap."""
    vectors = [Vector(point) for point in centerline]
    segment_lengths = [
        (vectors[index + 1] - vectors[index]).length
        for index in range(len(vectors) - 1)
    ]
    total_length = sum(segment_lengths)
    if total_length <= 0.4:
        return 0
    module_count = max(1, int(math.ceil(total_length / WALL_CAP_MODULE_LENGTH)))
    module_span = total_length / float(module_count)
    visible_length = max(0.40, module_span - gap)
    created = 0
    for module_index in range(module_count):
        distance = (float(module_index) + 0.5) * module_span
        traversed = 0.0
        segment_index = 0
        for candidate_index, segment_length in enumerate(segment_lengths):
            if distance <= traversed + segment_length or candidate_index == len(segment_lengths) - 1:
                segment_index = candidate_index
                break
            traversed += segment_length
        segment_length = max(segment_lengths[segment_index], 1.0e-6)
        amount = min(1.0, max(0.0, (distance - traversed) / segment_length))
        start = vectors[segment_index]
        end = vectors[segment_index + 1]
        tangent = (end - start).normalized()
        center = start.lerp(end, amount)
        width = (
            float(widths[segment_index]) * (1.0 - amount)
            + float(widths[segment_index + 1]) * amount
            + outset * 2.0
        )
        add_rounded_box(
            f"{name_prefix}Cushion{module_index + 1:02d}",
            (
                center.x,
                center.y,
                bottom_z + cap_depth + cushion_height * 0.18,
            ),
            (visible_length, width * 1.10, cushion_height),
            math.degrees(math.atan2(tangent.y, tangent.x)),
            min(
                cushion_height * 0.46,
                width * 0.30,
                visible_length * 0.20,
            ),
            material,
            collection,
            parent,
        )
        created += 1
    return created


def add_bumper_seam_bands(
    name_prefix: str,
    paths: list[list[tuple[float, float, float]]],
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> int:
    """Add narrow visual rings without splitting the continuous bumper mesh."""
    created = 0
    for path_index, path in enumerate(paths):
        vectors = [Vector(point) for point in path]
        if len(vectors) < 2:
            continue
        lengths = [
            (vectors[index + 1] - vectors[index]).length
            for index in range(len(vectors) - 1)
        ]
        total_length = sum(lengths)
        seam_distance = WALL_CAP_MODULE_LENGTH
        while seam_distance < total_length - WALL_CAP_MODULE_LENGTH * 0.35:
            traversed = 0.0
            segment_index = 0
            for candidate_index, segment_length in enumerate(lengths):
                if seam_distance <= traversed + segment_length:
                    segment_index = candidate_index
                    break
                traversed += segment_length
            segment_length = max(lengths[segment_index], 1.0e-6)
            amount = min(
                1.0,
                max(0.0, (seam_distance - traversed) / segment_length),
            )
            start = vectors[segment_index]
            end = vectors[segment_index + 1]
            tangent = (end - start).normalized()
            center = start.lerp(end, amount)
            seam_path = [
                tuple(center - tangent * PLATFORM_CORAL_BUMPER_SEAM_HALF_SPAN),
                tuple(center + tangent * PLATFORM_CORAL_BUMPER_SEAM_HALF_SPAN),
            ]
            created += 1
            add_pipe_surface(
                f"{name_prefix}{path_index + 1:02d}_{created:02d}",
                seam_path,
                (
                    radius + PLATFORM_CORAL_BUMPER_SEAM_RADIUS_BONUS,
                    radius + PLATFORM_CORAL_BUMPER_SEAM_RADIUS_BONUS,
                ),
                material,
                collection,
                parent,
                18,
            )
            seam_distance += WALL_CAP_MODULE_LENGTH
    return created


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


def add_static_scenic_dressing(
    materials: dict[str, bpy.types.Material],
    collection: bpy.types.Collection,
    root: bpy.types.Object,
    water_z: float,
) -> None:
    """Add peripheral waterpark silhouettes outside the gameplay footprint."""

    def pulled_center(center: tuple[float, float]) -> tuple[float, float]:
        value = Vector(center)
        if SCENIC_PULL_IN <= 0.0 or value.length <= 0.001:
            return center
        value -= value.normalized() * SCENIC_PULL_IN
        return (value.x, value.y)

    islets = [
        # The production camera crops aggressively. These remain outside the
        # gameplay footprint but sit close enough for their palms and rims to
        # frame the arena instead of disappearing beyond the viewport.
        ("NorthWest", (-49.0, 45.0), 5.8, -10.0),
        ("NorthEast", (49.0, 45.0), 5.7, 14.0),
        ("SouthWest", (-54.5, -25.5), 6.2, 8.0),
        ("SouthEast", (54.5, -25.5), 6.3, -12.0),
    ]
    for index, (label, center, radius, yaw) in enumerate(islets):
        x, y = pulled_center(center)
        radius *= SCENIC_SCALE
        add_cylinder(
            f"Scenic{label}SandBase",
            (x, y, water_z + 0.34),
            radius + 0.85,
            0.82,
            materials["dry_cream"],
            collection,
            root,
            vertices=28,
            bevel=0.22,
        )
        add_cylinder(
            f"Scenic{label}Turf",
            (x, y, water_z + 0.80),
            radius,
            0.30,
            materials["island_green"],
            collection,
            root,
            vertices=28,
            bevel=0.10,
        )
        palm_offsets = [(-1.7, 0.6, 0.96), (2.0, -0.8, 0.78)]
        if ART_SCHEMA_VERSION >= 6:
            palm_offsets.append((0.3, 2.25, 0.64))
        for palm_index, (offset_x, offset_y, scale) in enumerate(palm_offsets):
            palm_x = x + offset_x
            palm_y = y + offset_y
            trunk_height = 6.2 * scale * (1.08 if ART_SCHEMA_VERSION >= 6 else 1.0)
            add_cylinder(
                f"Scenic{label}Palm{palm_index + 1:02d}Trunk",
                (palm_x, palm_y, water_z + 0.96 + trunk_height * 0.5),
                0.38 * scale,
                trunk_height,
                materials["palm_trunk"],
                collection,
                root,
                vertices=12,
                bevel=0.10,
            )
            crown_z = water_z + 0.96 + trunk_height
            for leaf_index in range(7):
                angle = yaw + leaf_index * (360.0 / 7.0) + index * 9.0
                radians = math.radians(angle)
                leaf_length = 4.8 * scale * (1.10 if ART_SCHEMA_VERSION >= 6 else 1.0)
                leaf_center = (
                    palm_x + math.cos(radians) * leaf_length * 0.32,
                    palm_y + math.sin(radians) * leaf_length * 0.32,
                    crown_z - 0.12 - 0.10 * float(leaf_index % 2),
                )
                add_rounded_box(
                    f"Scenic{label}Palm{palm_index + 1:02d}Leaf{leaf_index + 1:02d}",
                    leaf_center,
                    (leaf_length, 0.82 * scale, 0.22 * scale),
                    angle,
                    0.11,
                    materials["island_green"],
                    collection,
                    root,
                )

    floats = [
        ("NorthCoral", (-31.0, 42.0, water_z + 0.16), 2.55, 0.68, "coral"),
        ("NorthYellow", (31.0, 42.0, water_z + 0.16), 2.30, 0.65, "yellow"),
        ("SouthCoral", (40.0, -28.0, water_z + 0.16), 2.45, 0.67, "coral"),
        ("SouthYellow", (-40.0, -28.0, water_z + 0.16), 2.20, 0.62, "yellow"),
    ]
    for label, location, major_radius, minor_radius, role in floats:
        pulled_x, pulled_y = pulled_center((location[0], location[1]))
        location = (pulled_x, pulled_y, location[2])
        major_radius *= SCENIC_HERO_FLOAT_SCALE
        minor_radius *= SCENIC_HERO_FLOAT_SCALE
        add_torus(
            f"ScenicFloat{label}",
            location,
            major_radius,
            minor_radius,
            materials[role],
            collection,
            root,
        )

    if SCENIC_HERO_FOREGROUND_FLOATERS:
        hero_floaters = [
            ("ForegroundCoral", (-25.5, -35.5), 3.15, 0.78, "coral", -14.0),
            ("ForegroundYellow", (27.5, -34.5), 2.75, 0.70, "yellow", 18.0),
        ]
        for label, center, major_radius, minor_radius, role, yaw in hero_floaters:
            x, y = pulled_center(center)
            add_torus(
                f"ScenicHeroFloat{label}",
                (x, y, water_z + 0.18),
                major_radius,
                minor_radius,
                materials[role],
                collection,
                root,
                yaw_degrees=yaw,
            )

    if SCENIC_HERO_PARASOLS:
        parasols = [
            ("NorthWest", (-36.0, 43.0), "coral", "yellow"),
            ("NorthEast", (36.0, 43.0), "yellow", "coral"),
        ]
        for label, center, canopy_role, trim_role in parasols:
            x, y = pulled_center(center)
            pole_height = 5.8
            add_cylinder(
                f"Scenic{label}ParasolPole",
                (x, y, water_z + 0.82 + pole_height * 0.5),
                0.18,
                pole_height,
                materials["portal_recess"],
                collection,
                root,
                vertices=16,
                bevel=0.05,
            )
            canopy_z = water_z + 0.82 + pole_height
            add_cone(
                f"Scenic{label}ParasolCanopy",
                (x, y, canopy_z),
                0.42,
                3.85,
                0.86,
                materials[canopy_role],
                collection,
                root,
                vertices=32,
                bevel=0.10,
            )
            add_torus(
                f"Scenic{label}ParasolTrim",
                (x, y, canopy_z - 0.40),
                3.42,
                0.16,
                materials[trim_role],
                collection,
                root,
            )

    for line_index, y in enumerate((43.0, -30.0)):
        start_x, end_x, count = (-33.0, 33.0, 11 if line_index == 0 else 9)
        rope_path = [[(start_x, y, water_z + 0.10), (end_x, y, water_z + 0.10)]]
        add_polyline_tube(
            f"ScenicBuoyRope{line_index + 1:02d}",
            rope_path,
            0.075,
            materials["portal_recess"],
            collection,
            root,
        )
        for buoy_index in range(count):
            amount = float(buoy_index) / float(max(count - 1, 1))
            add_sphere(
                f"ScenicBuoy{line_index + 1:02d}_{buoy_index + 1:02d}",
                (start_x + (end_x - start_x) * amount, y, water_z + 0.42),
                0.56,
                materials["yellow" if buoy_index % 2 == 0 else "coral"],
                collection,
                root,
                segments=16,
                rings=8,
            )

    tower_specs = [
        ("West", -42.0, 44.0),
        ("East", 42.0, 44.0),
    ]
    for label, x, y in tower_specs:
        x, y = pulled_center((x, y))
        base_z = water_z + 1.0
        tower_scale = 1.08 if ART_SCHEMA_VERSION >= 6 else 1.0
        add_cylinder(
            f"Scenic{label}WaterTowerBody",
            (x, y, base_z + 2.8 * tower_scale),
            2.4 * tower_scale,
            5.6 * tower_scale,
            materials["cyan"],
            collection,
            root,
            vertices=24,
            bevel=0.24,
        )
        add_cylinder(
            f"Scenic{label}WaterTowerCanopy",
            (x, y, base_z + 6.0 * tower_scale),
            3.1 * tower_scale,
            0.72 * tower_scale,
            materials["coral"],
            collection,
            root,
            vertices=24,
            bevel=0.24,
        )
        add_torus(
            f"Scenic{label}WaterTowerBand",
            (x, y, base_z + 4.8 * tower_scale),
            2.35 * tower_scale,
            0.22 * tower_scale,
            materials["yellow"],
            collection,
            root,
        )

    scenic_pipe_specs = [
        (
            "SouthWest",
            [(-59.0, -29.0, water_z + 0.4), (-56.0, -26.0, water_z + 3.1), (-52.0, -23.5, water_z + 5.5)],
        ),
        (
            "SouthEast",
            [(59.0, -29.0, water_z + 0.4), (56.0, -26.0, water_z + 3.3), (52.0, -23.5, water_z + 5.7)],
        ),
    ]
    for label, authored_path in scenic_pipe_specs:
        if ART_SCHEMA_VERSION >= 6:
            authored_path = [
                (
                    point[0] - math.copysign(SCENIC_PULL_IN, point[0]),
                    point[1] + SCENIC_PULL_IN * 0.55,
                    point[2] + (0.35 if index == len(authored_path) - 1 else 0.0),
                )
                for index, point in enumerate(authored_path)
            ]
        path = resample_catmull_rom(authored_path, 6)
        add_pipe_surface(
            f"Scenic{label}SlideYellowShell",
            path,
            (2.25, 2.25),
            materials["yellow"],
            collection,
            root,
            24,
        )
        add_pipe_surface(
            f"Scenic{label}SlideCoralBody",
            path,
            (1.78, 1.78),
            materials["coral"],
            collection,
            root,
            24,
        )


def build_production_foreground(
    layout: dict,
    materials: dict[str, bpy.types.Material],
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    root = make_root("TBSA_Foreground", collection, "production_foreground")
    platform = layout["platform"]
    floor_top = float(platform["floor_top_y"])
    collision_floor_bottom = floor_top - float(platform["depth"])
    floor_bottom = (
        min(collision_floor_bottom, PLATFORM_SKIRT_BOTTOM_Y)
        if PLATFORM_SKIRT_BOTTOM_Y is not None
        else collision_floor_bottom
    )
    visual_floor_top = floor_top + DRY_TOP_DEPTH
    outline = [g2b_planar(point) for point in platform["production_visual_outline"]]

    make_anchor("Anchor_Platform", collection, g2b_position((0.0, floor_top, 0.0)), "platform", "platform", root)
    create_prism("PlatformSide", outline, floor_bottom, floor_top, materials["cyan_dark"], collection, root)
    create_prism("PlatformDryTop", outline, floor_top, visual_floor_top, materials["dry_cream"], collection, root)
    if PLATFORM_CONTACT_FOAM_RADIUS > 0.0:
        foam_outline = offset_polygon(outline, PLATFORM_CONTACT_FOAM_OUTSET)
        foam_height = floor_bottom - PLATFORM_CONTACT_FOAM_RADIUS * 0.15
        if ART_SCHEMA_VERSION >= 5:
            # V5 uses one continuous seated waterline. It reads as water
            # contact at the production camera distance, not a series of
            # disconnected white dashes.
            closed_outline = foam_outline + [foam_outline[0]]
            foam_paths = [[
                (point[0], point[1], foam_height) for point in closed_outline
            ]]
        else:
            foam_paths = []
            for start in range(0, len(foam_outline), 8):
                segment = foam_outline[start : start + 5]
                if len(segment) >= 2:
                    foam_paths.append([
                        (point[0], point[1], foam_height) for point in segment
                    ])
        add_polyline_tube(
            "PlatformContactFoam",
            foam_paths,
            PLATFORM_CONTACT_FOAM_RADIUS,
            materials["foam"],
            collection,
            root,
        )
        if PLATFORM_CONTACT_FOAM_CLUSTERS:
            for cluster_index in range(0, len(foam_outline), 6):
                previous = Vector(foam_outline[(cluster_index - 1) % len(foam_outline)])
                current = Vector(foam_outline[cluster_index])
                following = Vector(foam_outline[(cluster_index + 1) % len(foam_outline)])
                tangent = (following - previous).normalized()
                yaw = math.atan2(tangent.y, tangent.x)
                base_radius = PLATFORM_CONTACT_FOAM_RADIUS * (
                    2.35 + 0.22 * float(cluster_index % 3)
                )
                for bubble_index, along in enumerate((-0.72, 0.0, 0.68)):
                    radius = base_radius * (0.70 if bubble_index != 1 else 1.0)
                    center = current + tangent * along * base_radius
                    bubble = add_sphere(
                        f"PlatformFoamCluster{cluster_index:03d}_{bubble_index + 1:02d}",
                        (center.x, center.y, foam_height + radius * 0.04),
                        radius,
                        materials["foam"],
                        collection,
                        root,
                        segments=16,
                        rings=8,
                    )
                    bubble.scale = (
                        1.28 if bubble_index == 1 else 0.92,
                        0.68 if bubble_index == 1 else 0.78,
                        0.28,
                    )
                    bubble.rotation_euler[2] = yaw
        if PLATFORM_CONTACT_FOAM_SCALLOPS and PLATFORM_CONTACT_FOAM_SCALLOP_RADIUS > 0.0:
            # V6 adds one authored, camera-facing scallop language at the
            # background-water contact. These meshes batch into the existing
            # foam material and never alter the platform or collision outline.
            scallop_number = 0
            for outline_index in range(
                0,
                len(foam_outline),
                PLATFORM_CONTACT_FOAM_SCALLOP_STRIDE,
            ):
                current = Vector(foam_outline[outline_index])
                if current.y > PLATFORM_CONTACT_FOAM_FRONT_MAX_Y:
                    continue
                previous = Vector(foam_outline[(outline_index - 1) % len(foam_outline)])
                following = Vector(foam_outline[(outline_index + 1) % len(foam_outline)])
                tangent = (following - previous).normalized()
                yaw = math.atan2(tangent.y, tangent.x)
                scallop_number += 1
                phase = float((outline_index // PLATFORM_CONTACT_FOAM_SCALLOP_STRIDE) % 4)
                radius = PLATFORM_CONTACT_FOAM_SCALLOP_RADIUS * (0.82 + phase * 0.07)
                scallop = add_sphere(
                    f"PlatformFoamScallop{scallop_number:03d}",
                    (current.x, current.y, foam_height + radius * 0.04),
                    radius,
                    materials["foam"],
                    collection,
                    root,
                    segments=18,
                    rings=8,
                )
                scallop.scale = (
                    1.55 + 0.10 * float(scallop_number % 2),
                    0.74,
                    0.18 + 0.02 * float(scallop_number % 3),
                )
                scallop.rotation_euler[2] = yaw
            # The concept's most visible authored water contact sits around the
            # two central bay cut-outs. Seat a second, flatter scallop chain on
            # the baseline water surface so it reads as foam against the dark
            # skirt instead of another white structural trim.
            if PLATFORM_CONTACT_BAY_FOAM_SCALLOPS:
                bay_scallop_number = 0
                for outline_index in range(0, len(foam_outline), 2):
                    current = Vector(foam_outline[outline_index])
                    if abs(current.x) >= 24.5 or abs(current.y) <= 4.5:
                        continue
                    previous = Vector(foam_outline[(outline_index - 1) % len(foam_outline)])
                    following = Vector(foam_outline[(outline_index + 1) % len(foam_outline)])
                    tangent = (following - previous).normalized()
                    yaw = math.atan2(tangent.y, tangent.x)
                    bay_scallop_number += 1
                    phase = float(bay_scallop_number % 5)
                    radius = PLATFORM_CONTACT_FOAM_SCALLOP_RADIUS * (0.88 + phase * 0.055)
                    scallop = add_sphere(
                        f"BayWaterFoamScallop{bay_scallop_number:03d}",
                        (current.x, current.y, -5.69 + radius * 0.03),
                        radius,
                        materials["foam"],
                        collection,
                        root,
                        segments=18,
                        rings=8,
                    )
                    scallop.scale = (
                        1.35 + 0.12 * float(bay_scallop_number % 3),
                        0.78,
                        0.15 + 0.015 * float(bay_scallop_number % 2),
                    )
                    scallop.rotation_euler[2] = yaw
    if PLATFORM_CORAL_BUMPER_RADIUS > 0.0:
        bumper_paths = []
        active_path = []
        bumper_height = visual_floor_top - PLATFORM_CORAL_BUMPER_RADIUS - 0.10
        for point in outline + [outline[0]]:
            if point[1] <= PLATFORM_CORAL_BUMPER_MAX_Y:
                active_path.append((point[0], point[1], bumper_height))
            elif len(active_path) >= 2:
                bumper_paths.append(active_path)
                active_path = []
            else:
                active_path = []
        if len(active_path) >= 2:
            bumper_paths.append(active_path)
        if bumper_paths:
            add_polyline_tube(
                "PlatformSouthCoralBumper",
                bumper_paths,
                PLATFORM_CORAL_BUMPER_RADIUS,
                materials["coral"],
                collection,
                root,
            )
            if (
                PLATFORM_CORAL_BUMPER_SEAMS
                and PLATFORM_CORAL_BUMPER_SEAM_HALF_SPAN > 0.0
            ):
                add_bumper_seam_bands(
                    "PlatformSouthCoralBumperSeam",
                    bumper_paths,
                    PLATFORM_CORAL_BUMPER_RADIUS,
                    materials["portal_recess"],
                    collection,
                    root,
                )

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
            if WALL_CONTINUOUS_SWEEP:
                shifted_centerline, sampled_widths = sample_wall_section(
                    section_points,
                    section["offsets"],
                    section["thicknesses"],
                    WALL_CURVE_SUBDIVISIONS,
                )
                footprint = wall_footprint_from_samples(shifted_centerline, sampled_widths)
            else:
                shifted_centerline = [
                    g2b_planar((point[0], float(point[1]) + float(offset)))
                    for point, offset in zip(section_points, section["offsets"])
                ]
                sampled_widths = [float(value) for value in section["thicknesses"]]
                footprint = variable_width_footprint(
                    section_points,
                    section["offsets"],
                    section["thicknesses"],
                )
            wall_name = f"{wall['node_prefix']}_{int(section['label']):02d}"
            height = float(section["height"])
            wall_body = create_prism(
                wall_name, footprint, visual_floor_top, visual_floor_top + height,
                materials["cyan"], collection, root,
            )
            if WALL_BODY_BEVEL > 0.0:
                apply_bevel(wall_body, WALL_BODY_BEVEL, max(WALL_CAP_BEVEL_SEGMENTS - 1, 2))
            if WALL_CONTINUOUS_SWEEP:
                wall_body["construction"] = "continuous_smoothed_footprint"
                wall_body["curve_subdivisions"] = WALL_CURVE_SUBDIVISIONS
                for polygon in wall_body.data.polygons:
                    polygon.use_smooth = abs(float(polygon.normal.z)) < 0.78
            cap_offset = WALL_CAP_OUTSET if abs(WALL_CAP_OUTSET) > 1.0e-8 else -float(wall["cap_inset"])
            cap_depth = float(wall["cap_depth"]) * WALL_CAP_DEPTH_MULTIPLIER
            cushion_height = (
                cap_depth * WALL_CAP_CUSHION_HEIGHT_MULTIPLIER
                if WALL_CAP_SEGMENT_CUSHIONS
                and WALL_CAP_CUSHION_HEIGHT_MULTIPLIER > 0.0
                else 0.0
            )
            if WALL_CONTINUOUS_SWEEP:
                add_swept_soft_wall_cap(
                    wall_name + "CoralCap",
                    shifted_centerline,
                    sampled_widths,
                    visual_floor_top + height,
                    cap_depth,
                    cap_offset,
                    materials["coral"],
                    collection,
                    root,
                    WALL_CAP_PROFILE_SEGMENTS,
                    WALL_CAP_SUPERELLIPSE_POWER,
                )
                if cushion_height > 0.0:
                    add_wall_cap_cushion_modules(
                        wall_name,
                        shifted_centerline,
                        sampled_widths,
                        visual_floor_top + height,
                        cap_depth,
                        WALL_CAP_OUTSET,
                        cushion_height,
                        WALL_CAP_SEGMENT_GAP,
                        materials["coral"],
                        collection,
                        root,
                    )
            else:
                cap = offset_polygon(footprint, cap_offset)
                wall_cap = create_prism(
                    wall_name + "CoralCap", cap, visual_floor_top + height,
                    visual_floor_top + height + cap_depth, materials["coral"], collection, root,
                )
                apply_bevel(
                    wall_cap,
                    cap_depth * WALL_CAP_BEVEL_MULTIPLIER,
                    WALL_CAP_BEVEL_SEGMENTS,
                )
                if cushion_height > 0.0:
                    for segment_index in range(len(shifted_centerline) - 1):
                        start = Vector(shifted_centerline[segment_index])
                        end = Vector(shifted_centerline[segment_index + 1])
                        delta = end - start
                        segment_length = delta.length
                        if segment_length <= 0.2:
                            continue
                        module_count = max(1, int(math.ceil(segment_length / 5.2)))
                        tangent = delta.normalized()
                        yaw = math.degrees(math.atan2(tangent.y, tangent.x))
                        thickness = (
                            float(section["thicknesses"][segment_index])
                            + float(section["thicknesses"][segment_index + 1])
                        ) * 0.5 + WALL_CAP_OUTSET * 2.0
                        module_length = segment_length / float(module_count)
                        for module_index in range(module_count):
                            amount = (float(module_index) + 0.5) / float(module_count)
                            center = start.lerp(end, amount)
                            visible_length = max(0.35, module_length - WALL_CAP_SEGMENT_GAP)
                            add_rounded_box(
                                (
                                    f"{wall_name}Cushion"
                                    f"{segment_index + 1:02d}_{module_index + 1:02d}"
                                ),
                                (
                                    center.x,
                                    center.y,
                                    visual_floor_top + height + cap_depth
                                    + cushion_height * 0.18,
                                ),
                                (visible_length, thickness * 1.12, cushion_height),
                                yaw,
                                min(
                                    cushion_height * 0.46,
                                    thickness * 0.30,
                                    visible_length * 0.20,
                                ),
                                materials["coral"],
                                collection,
                                root,
                            )
            if WALL_CAP_VISUAL_MODULE_SEAMS:
                # Preserve the premium continuous sweep while restoring the
                # camera-readable padded-module language from the approved target.
                # These are shallow visual grooves only; collision stays layout-owned.
                seam_number = 0
                traversed_length = 0.0
                next_seam_distance = WALL_CAP_MODULE_LENGTH
                for segment_index in range(len(shifted_centerline) - 1):
                    start = Vector(shifted_centerline[segment_index])
                    end = Vector(shifted_centerline[segment_index + 1])
                    delta = end - start
                    segment_length = delta.length
                    if segment_length <= 0.2:
                        continue
                    tangent = delta.normalized()
                    yaw = math.degrees(math.atan2(tangent.y, tangent.x)) + 90.0
                    segment_end_distance = traversed_length + segment_length
                    while next_seam_distance < segment_end_distance - 0.20:
                        seam_number += 1
                        amount = (
                            next_seam_distance - traversed_length
                        ) / segment_length
                        current = start.lerp(end, amount)
                        seam_width = (
                            float(sampled_widths[segment_index]) * (1.0 - amount)
                            + float(sampled_widths[segment_index + 1]) * amount
                        ) * 0.86 + WALL_CAP_OUTSET * 0.86
                        add_rounded_box(
                            f"{wall_name}CapModuleSeam{seam_number:02d}",
                            (
                                current.x,
                                current.y,
                                visual_floor_top + height + cap_depth
                                + cushion_height * 0.70 + 0.035,
                            ),
                            (seam_width, 0.12, 0.055),
                            yaw,
                            0.030,
                            materials["portal_recess"],
                            collection,
                            root,
                        )
                        next_seam_distance += WALL_CAP_MODULE_LENGTH
                    traversed_length = segment_end_distance
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
        outer_radii = tuple(float(value) * PIPE_OUTER_RADIUS_MULTIPLIER for value in pipe["outer_radius"])
        inner_radii = tuple(float(value) for value in pipe["inner_radius"])
        collar_radii = tuple(float(value) * PIPE_COLLAR_RADIUS_MULTIPLIER for value in pipe["collar_outer_radius"])
        radial_segments = int(pipe["radial_segments"])
        mouth_tangent = (Vector(path[1]) - Vector(path[0])).normalized()
        shell_point_count = max(
            3,
            min(
                len(path),
                int(round(float(len(path) - 1) * PIPE_VISUAL_PATH_FRACTION)) + 1,
            ),
        )
        shell_path = list(path[:shell_point_count])
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
        collar_end = tuple(
            Vector(path[0])
            + mouth_tangent * float(pipe["collar_depth"]) * PIPE_COLLAR_DEPTH_MULTIPLIER
        )
        add_pipe_surface(
            pipe["node_name"] + "YellowCollar", [path[0], collar_end], collar_radii,
            materials["yellow"], collection, root, radial_segments,
        )
        add_pipe_mouth_annulus(
            pipe["node_name"] + "YellowMouthRim", path[0], mouth_tangent,
            collar_radii, inner_radii, materials["yellow"], collection, root, radial_segments,
        )
        if PIPE_BAND_RADIUS_BONUS > 0.0 and PIPE_BAND_HALF_SPAN > 0.0:
            band_radii = (
                outer_radii[0] + PIPE_BAND_RADIUS_BONUS,
                outer_radii[1] + PIPE_BAND_RADIUS_BONUS,
            )
            band_indices = sorted({max(2, len(path) // 3), max(3, (len(path) * 2) // 3)})
            for band_number, band_index in enumerate(band_indices):
                if band_index >= len(path) - 1:
                    continue
                band_center = Vector(path[band_index])
                band_tangent = (Vector(path[band_index + 1]) - Vector(path[band_index - 1])).normalized()
                band_path = [
                    tuple(band_center - band_tangent * PIPE_BAND_HALF_SPAN),
                    tuple(band_center + band_tangent * PIPE_BAND_HALF_SPAN),
                ]
                add_pipe_surface(
                    f"{pipe['node_name']}CoralBand{band_number + 1:02d}",
                    band_path, band_radii, materials["coral"], collection, root, radial_segments,
                )
        if (
            PIPE_PANEL_SEAMS
            and PIPE_PANEL_SEAM_COUNT > 0
            and PIPE_PANEL_SEAM_HALF_SPAN > 0.0
            and len(shell_path) >= 5
        ):
            seam_radii = (
                outer_radii[0] + PIPE_PANEL_SEAM_RADIUS_BONUS,
                outer_radii[1] + PIPE_PANEL_SEAM_RADIUS_BONUS,
            )
            for seam_number in range(1, PIPE_PANEL_SEAM_COUNT + 1):
                amount = float(seam_number) / float(PIPE_PANEL_SEAM_COUNT + 1)
                seam_index = max(
                    2,
                    min(
                        len(shell_path) - 2,
                        int(round(amount * float(len(shell_path) - 1))),
                    ),
                )
                seam_center = Vector(shell_path[seam_index])
                seam_tangent = (
                    Vector(shell_path[seam_index + 1])
                    - Vector(shell_path[seam_index - 1])
                ).normalized()
                seam_path = [
                    tuple(seam_center - seam_tangent * PIPE_PANEL_SEAM_HALF_SPAN),
                    tuple(seam_center + seam_tangent * PIPE_PANEL_SEAM_HALF_SPAN),
                ]
                add_pipe_surface(
                    f"{pipe['node_name']}PanelSeam{seam_number:02d}",
                    seam_path,
                    seam_radii,
                    materials["portal_recess"],
                    collection,
                    root,
                    radial_segments,
                )
        make_anchor(
            "Anchor_" + pipe["node_name"], collection, path[0], pipe["id"], "portal_pipe", root,
        )

    if SCENIC_DRESSING_ENABLED:
        add_static_scenic_dressing(materials, collection, root, -5.85)

    for cover in layout["covers"]:
        position = cover["position"]
        size = cover["size"]
        center = g2b_position((position[0], visual_floor_top + float(size[1]) * 0.5, position[2]))
        dimensions = (float(size[0]), float(size[2]), float(size[1]))
        add_rounded_box(
            cover["node_name"], center, dimensions, float(cover["yaw_degrees"]), float(cover["bevel"]) * COVER_BEVEL_MULTIPLIER,
            materials["cyan"], collection, root,
        )
        if COVER_TOP_INSET_SCALE > 0.0 and COVER_TOP_INSET_HEIGHT > 0.0:
            top_center = (
                center[0],
                center[1],
                center[2] + dimensions[2] * 0.5 + COVER_TOP_INSET_HEIGHT * 0.5,
            )
            add_rounded_box(
                cover["node_name"] + "TopInset",
                top_center,
                (
                    dimensions[0] * COVER_TOP_INSET_SCALE,
                    dimensions[1] * COVER_TOP_INSET_SCALE,
                    COVER_TOP_INSET_HEIGHT,
                ),
                float(cover["yaw_degrees"]),
                min(float(cover["bevel"]) * 0.72, COVER_TOP_INSET_HEIGHT * 0.46),
                materials["cyan"],
                collection,
                root,
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
        float(cover["bevel"]) * COVER_BEVEL_MULTIPLIER, materials["cyan"], collection, root,
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
    for obj in sorted(collection.all_objects, key=lambda item: item.name):
        if obj.type != "MESH" or not obj.data.materials:
            continue
        groups.setdefault(obj.data.materials[0], []).append(obj)
    for material, grouped_objects in sorted(groups.items(), key=lambda item: item[0].name):
        objects = sorted(grouped_objects, key=lambda item: item.name)
        if not objects:
            continue
        active = objects[0]
        # Join one source at a time in a stable name order. Blender does not
        # guarantee that a multi-selected join consumes objects in selection
        # order, which made the exported element/index buffers vary by build.
        for source in objects[1:]:
            bpy.ops.object.select_all(action="DESELECT")
            active.select_set(True)
            source.select_set(True)
            bpy.context.view_layer.objects.active = active
            bpy.ops.object.join()
            active = bpy.context.object
        bpy.ops.object.select_all(action="DESELECT")
        active.select_set(True)
        bpy.context.view_layer.objects.active = active
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
                # Blender's matrix math can vary by one float32 ULP between
                # clean CLI processes. Quantizing well below a texel keeps the
                # visual projection identical while making exported GLBs
                # byte-deterministic.
                uv_layer.data[loop_index].uv = (round(u, 4), round(v, 4))
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
    scene.render.resolution_x = PREVIEW_RESOLUTION[0]
    scene.render.resolution_y = PREVIEW_RESOLUTION[1]
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = False
    scene.render.use_file_extension = True

    world = bpy.data.worlds.new("TBSA_PreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = rgba("#54BCE2")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.28
    scene.world = world

    camera_data = bpy.data.cameras.new("TBSA_PreviewCamera")
    camera = bpy.data.objects.new("TBSA_PreviewCamera", camera_data)
    preview_collection.objects.link(camera)
    camera.data.type = "ORTHO"
    scene.camera = camera

    sun_data = bpy.data.lights.new("TBSA_Sun", type="SUN")
    sun_data.color = rgba("#FFF1D3")[:3]
    sun_data.energy = 1.95
    sun_data.angle = math.radians(10.0)
    sun = bpy.data.objects.new("TBSA_Sun", sun_data)
    preview_collection.objects.link(sun)
    sun.rotation_euler = (math.radians(36.0), math.radians(-24.0), math.radians(-38.0))

    fill_data = bpy.data.lights.new("TBSA_CoolFill", type="AREA")
    fill_data.color = rgba("#8DEBFF")[:3]
    fill_data.energy = 260.0
    fill_data.shape = "DISK"
    fill_data.size = 35.0
    fill = bpy.data.objects.new("TBSA_CoolFill", fill_data)
    preview_collection.objects.link(fill)
    fill.location = (-25.0, -30.0, 42.0)
    look_at(fill, (0.0, 0.0, 0.0))

    if PREVIEW_WATER_ENABLED:
        bpy.ops.mesh.primitive_plane_add(size=300.0, location=(0.0, 0.0, -5.85))
        water = bpy.context.object
        water.name = "TBSA_PreviewWater"
        move_to_collection(water, preview_collection)
        water["preview_only"] = True
        preview_water = make_material(
            "TBSA_PreviewWaterMaterial",
            "#079FB9",
            0.28,
            emission_hex="#045E7C",
            emission_strength=0.06,
        )
        nodes = preview_water.node_tree.nodes
        links = preview_water.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        coordinates = nodes.new("ShaderNodeTexCoord")
        voronoi = nodes.new("ShaderNodeTexVoronoi")
        voronoi.feature = "DISTANCE_TO_EDGE"
        voronoi.distance = "EUCLIDEAN"
        voronoi.inputs["Scale"].default_value = 76.0
        voronoi.inputs["Randomness"].default_value = 0.86
        ramp = nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "EASE"
        ramp.color_ramp.elements[0].position = 0.010
        ramp.color_ramp.elements[0].color = rgba("#A4F4EA")
        ramp.color_ramp.elements[1].position = 0.052
        ramp.color_ramp.elements[1].color = rgba("#079FB9")
        links.new(coordinates.outputs["Generated"], voronoi.inputs["Vector"])
        links.new(voronoi.outputs["Distance"], ramp.inputs["Fac"])
        links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.24
        apply_material(water, preview_water)

    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.20
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
    camera.data.ortho_scale = PREVIEW_ORTHO_SCALE
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
    camera.data.ortho_scale = PREVIEW_ORTHO_SCALE
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
    canonicalize_glb_mesh_data(path)
    bpy.ops.object.select_all(action="DESELECT")


def canonicalize_glb_mesh_data(path: Path, decimal_places: int = 5) -> None:
    """Canonicalize harmless Blender export-order and floating-point drift.

    Blender 5.1 can produce byte-different GLBs from the same scene because a
    handful of generated UV, position, normal and tangent floats vary between
    clean processes, and it can emit the same triangle set in different index
    order after procedural object joins. Quantizing floating mesh attributes to
    five decimals and sorting equivalent triangle records is far below a
    rendered pixel at the production camera and makes artifacts reproducible.
    """

    raw = bytearray(path.read_bytes())
    if len(raw) < 28 or raw[:4] != b"glTF":
        raise RuntimeError(f"Cannot canonicalize invalid GLB: {path}")
    json_length, json_type = struct.unpack_from("<II", raw, 12)
    if json_type != 0x4E4F534A:
        raise RuntimeError(f"GLB JSON chunk is missing: {path}")
    json_start = 20
    json_end = json_start + json_length
    document = json.loads(bytes(raw[json_start:json_end]).rstrip(b" \0"))
    binary_header = json_end
    binary_length, binary_type = struct.unpack_from("<II", raw, binary_header)
    if binary_type != 0x004E4942:
        raise RuntimeError(f"GLB binary chunk is missing: {path}")
    binary_start = binary_header + 8
    binary_end = binary_start + binary_length
    if binary_end > len(raw):
        raise RuntimeError(f"GLB binary chunk is truncated: {path}")

    float_attribute_accessors: set[int] = set()
    triangle_index_accessors: set[int] = set()
    for mesh in document.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            for semantic, accessor_index in primitive.get("attributes", {}).items():
                if semantic in {"POSITION", "NORMAL", "TANGENT"} or semantic.startswith("TEXCOORD_"):
                    float_attribute_accessors.add(int(accessor_index))
            if primitive.get("mode", 4) == 4 and "indices" in primitive:
                triangle_index_accessors.add(int(primitive["indices"]))

    component_counts = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    accessors = document.get("accessors", [])
    buffer_views = document.get("bufferViews", [])
    for accessor_index in sorted(float_attribute_accessors):
        accessor = accessors[accessor_index]
        if accessor.get("componentType") != 5126 or accessor.get("sparse"):
            continue
        view = buffer_views[int(accessor["bufferView"])]
        component_count = component_counts.get(accessor.get("type"))
        if component_count is None:
            continue
        element_size = component_count * 4
        stride = int(view.get("byteStride", element_size))
        base_offset = (
            binary_start
            + int(view.get("byteOffset", 0))
            + int(accessor.get("byteOffset", 0))
        )
        for element_index in range(int(accessor["count"])):
            element_offset = base_offset + element_index * stride
            for component_index in range(component_count):
                offset = element_offset + component_index * 4
                value = struct.unpack_from("<f", raw, offset)[0]
                struct.pack_into("<f", raw, offset, round(value, decimal_places))

    integer_formats = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}
    for accessor_index in sorted(triangle_index_accessors):
        accessor = accessors[accessor_index]
        integer_format = integer_formats.get(accessor.get("componentType"))
        if integer_format is None or accessor.get("sparse"):
            continue
        count = int(accessor["count"])
        if accessor.get("type") != "SCALAR" or count % 3 != 0:
            continue
        component_format, component_size = integer_format
        view = buffer_views[int(accessor["bufferView"])]
        stride = int(view.get("byteStride", component_size))
        base_offset = (
            binary_start
            + int(view.get("byteOffset", 0))
            + int(accessor.get("byteOffset", 0))
        )
        indices = [
            struct.unpack_from(
                f"<{component_format}",
                raw,
                base_offset + index * stride,
            )[0]
            for index in range(count)
        ]
        triangles: list[tuple[int, int, int]] = []
        for index in range(0, count, 3):
            triangle = indices[index:index + 3]
            minimum_index = triangle.index(min(triangle))
            canonical = triangle[minimum_index:] + triangle[:minimum_index]
            triangles.append((canonical[0], canonical[1], canonical[2]))
        canonical_indices = [value for triangle in sorted(triangles) for value in triangle]
        for index, value in enumerate(canonical_indices):
            struct.pack_into(
                f"<{component_format}",
                raw,
                base_offset + index * stride,
                value,
            )

    path.write_bytes(raw)


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


def validate_wall_visual_contract(
    layout: dict,
    foreground_collection: bpy.types.Collection,
) -> dict:
    expected_sections = sum(len(wall["sections"]) for wall in layout["walls"])
    names = [obj.name for obj in foreground_collection.all_objects]
    modular_cushions = [
        name
        for name in names
        if "Cushion" in name
    ]
    visual_module_seams = [name for name in names if "CapModuleSeam" in name]
    cap_objects = [
        obj
        for obj in foreground_collection.all_objects
        if obj.type == "MESH" and obj.name.endswith("CoralCap")
    ]
    body_objects = [
        obj
        for obj in foreground_collection.all_objects
        if obj.type == "MESH"
        and obj.get("construction") == "continuous_smoothed_footprint"
    ]
    if WALL_CONTINUOUS_SWEEP:
        if modular_cushions and not WALL_CAP_SEGMENT_CUSHIONS:
            raise RuntimeError(
                "Continuous wall contract generated unrequested cap modules: "
                + ", ".join(sorted(modular_cushions))
            )
        if WALL_CAP_SEGMENT_CUSHIONS and not modular_cushions:
            raise RuntimeError(
                "Continuous wall contract requested cap modules but generated none"
            )
        if WALL_CAP_VISUAL_MODULE_SEAMS and not visual_module_seams:
            raise RuntimeError(
                "Continuous wall contract requested visual module seams but generated none"
            )
        if not WALL_CAP_VISUAL_MODULE_SEAMS and visual_module_seams:
            raise RuntimeError(
                "Continuous wall contract generated unrequested visual module seams: "
                + ", ".join(sorted(visual_module_seams))
            )
        if len(cap_objects) != expected_sections:
            raise RuntimeError(
                f"Continuous wall contract expected {expected_sections} caps, got {len(cap_objects)}"
            )
        if len(body_objects) != expected_sections:
            raise RuntimeError(
                f"Continuous wall contract expected {expected_sections} smoothed bodies, got {len(body_objects)}"
            )
        invalid_caps = [
            obj.name
            for obj in cap_objects
            if obj.get("construction") != "continuous_superellipse_sweep"
            or len(obj.data.vertices) < WALL_CAP_PROFILE_SEGMENTS * 4
        ]
        if invalid_caps:
            raise RuntimeError(
                "Wall caps are not continuous high-resolution sweeps: "
                + ", ".join(sorted(invalid_caps))
            )
    return {
        "enabled": WALL_CONTINUOUS_SWEEP,
        "expected_section_count": expected_sections,
        "continuous_cap_count": len(cap_objects),
        "smoothed_body_count": len(body_objects),
        "modular_cushion_count": len(modular_cushions),
        "visual_module_seams_enabled": WALL_CAP_VISUAL_MODULE_SEAMS,
        "visual_module_seam_count": len(visual_module_seams),
        "curve_subdivisions": WALL_CURVE_SUBDIVISIONS,
        "cap_profile_segments": WALL_CAP_PROFILE_SEGMENTS,
        "cap_superellipse_power": WALL_CAP_SUPERELLIPSE_POWER,
    }


def write_manifest(
    layout: dict,
    art: dict,
    tide: dict,
    hero_collection: bpy.types.Collection,
    foreground_collection: bpy.types.Collection,
    geometry_audit: dict,
    texture_sets: dict[str, dict],
    source_stats: dict[str, dict],
) -> None:
    layout_sha256 = hashlib.sha256(LAYOUT_PATH.read_bytes()).hexdigest()
    art_sha256 = hashlib.sha256(ART_PROFILE_PATH.read_bytes()).hexdigest()
    tide_sha256 = hashlib.sha256(TIDE_PROFILE_PATH.read_bytes()).hexdigest()
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
    runtime_shader_paths = {
        "shallow_water": ROOT / "assets/shaders/twin_bays_water_master.gdshader",
        "backdrop_water": ROOT / "assets/shaders/twin_bays_backdrop_water.gdshader",
    }
    missing_outputs.extend(
        str(path)
        for maps in texture_paths.values()
        for path in maps.values()
        if not path.is_file()
    )
    missing_outputs.extend(str(path) for path in runtime_shader_paths.values() if not path.is_file())
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
        "art_profile": str(ART_PROFILE_PATH.relative_to(ROOT)).replace("\\", "/"),
        "art_profile_schema": art["schema"],
        "art_profile_version": art["version"],
        "art_profile_sha256": art_sha256,
        "tide_profile": str(TIDE_PROFILE_PATH.relative_to(ROOT)).replace("\\", "/"),
        "tide_profile_schema": tide["schema"],
        "tide_profile_version": tide["version"],
        "tide_profile_sha256": tide_sha256,
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
        "runtime_shaders": {
            name: {
                "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "precompiled_project_resource": True,
            }
            for name, path in runtime_shader_paths.items()
        },
        "contracts": {
            "visual_only": True,
            "collision_in_glb": False,
            "camera_in_glb": False,
            "light_in_glb": False,
            "character_in_glb": False,
            "weapon_in_glb": False,
            "dynamic_portal_ring_in_glb": False,
            "floor_water_marks": False,
            "static_floor_puddles": False,
            "tide_visuals_godot_owned": True,
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
    art, tide = load_art_and_tide_profiles()
    configure_from_art_profile(art)
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
    geometry_audit["wall_visual_contract"] = validate_wall_visual_contract(
        layout,
        foreground_collection,
    )
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
        layout, art, tide, hero_collection, foreground_collection, geometry_audit, texture_sets, source_stats,
    )

    print(f"Saved Blender source: {BLEND_PATH}")
    print(f"Exported hero kit: {HERO_GLB_PATH}")
    print(f"Exported production foreground: {FOREGROUND_GLB_PATH}")
    print(f"Rendered hero preview: {HERO_PREVIEW_PATH}")
    print(f"Rendered foreground preview: {FOREGROUND_PREVIEW_PATH}")
    print(f"Wrote manifest: {MANIFEST_PATH}")


if __name__ == "__main__":
    build()
