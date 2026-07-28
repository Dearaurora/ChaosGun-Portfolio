"""Build Momentum Circuit's deterministic, visual-only v3 foreground GLB.

Run with the project's Blender runtime:
    blender --background --python-exit-code 1 --python tools/build_momentum_circuit_arena_v3.py

The canonical JSON remains authoritative.  This builder exports only static
render geometry: a coverless fourteen-panel deck, recessed connected seams,
layered sidewalls, inset rim light, and low-profile three-layer devices.
Gameplay collision, camera, lighting, characters, weapons, cloud motion, and
gravity-mechanism animation remain Godot-owned.
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path

import bmesh
import bpy


ROOT = Path(__file__).resolve().parents[1]
ASSET_VERSION = int(os.environ.get("MC_FOREGROUND_VERSION", "3"))
if ASSET_VERSION not in (3, 4, 9):
    raise ValueError("MC_FOREGROUND_VERSION must be 3, 4, or 9")
ASSET_TAG = f"V{ASSET_VERSION}"
LAYOUT_PATH = ROOT / "resources" / "maps" / "momentum_circuit_layout_v2.json"
SOURCE_DIR = ROOT / "assets" / "source" / f"momentum_circuit_v{ASSET_VERSION}"
GENERATED_DIR = ROOT / "assets" / "models" / "generated" / f"momentum_circuit_v{ASSET_VERSION}"
BLEND_PATH = SOURCE_DIR / f"momentum_circuit_foreground_v{ASSET_VERSION}.blend"
FOREGROUND_GLB_PATH = GENERATED_DIR / f"momentum_circuit_foreground_v{ASSET_VERSION}.glb"
DECK_TEXTURE_PATH = (
    ROOT
    / "assets"
    / "textures"
    / "generated"
    / "momentum_circuit_v9"
    / "momentum_circuit_v9_deck_albedo.png"
)

SCHEMA = "chaos_gun.momentum_circuit_layout"
SCHEMA_VERSION = 2
TOP_SURFACE_LIFT = 0.045 if ASSET_VERSION >= 9 else 0.02
PANEL_RAISE = 0.040 if ASSET_VERSION >= 9 else 0.025
PANEL_GAP = 0.035 if ASSET_VERSION >= 9 else 0.12
PANEL_BEVEL = 0.055 if ASSET_VERSION >= 9 else 0.012
DEVICE_MAX_HEIGHT = 0.30 if ASSET_VERSION >= 4 else 0.45

PALETTE = {
    "panel_a": "#45445F",
    "panel_b": "#494761",
    "seam_inlay": "#716B91",
    "inset_dark": "#504B66",
    "side_low": "#4A3A68",
    "side_high": "#61507E",
    "static_rim": "#B7A8EA",
    "anchor_cyan": "#36CBE6",
}
if ASSET_VERSION >= 4:
    PALETTE["slot_glow"] = "#756B9E"
if ASSET_VERSION >= 9:
    PALETTE.update(
        {
            "panel_a": "#3B3A52",
            "panel_b": "#45435C",
            "seam_inlay": "#252337",
            "inset_dark": "#211F32",
            "side_low": "#271C45",
            "side_high": "#55456F",
            "static_rim": "#A998E3",
            "anchor_cyan": "#39D8EE",
            "slot_glow": "#8C7BC0",
        }
    )

PANEL_SEEDS_GODOT_XZ = (
    (-38.0, -39.0), (-17.0, -34.0), (8.0, -34.0), (34.0, -29.0),
    (-37.0, -12.0), (-13.0, -17.0), (8.0, -9.0), (34.0, -7.0),
    (-34.0, 4.0), (-12.0, 7.0), (9.0, 13.0), (31.0, 13.0),
    (4.0, 31.0), (33.0, 32.0),
)

BRIDGE_ENDPOINTS_GODOT_XZ = (
    ((18.45, -12.47), (12.17, -29.20)),
    ((-14.52, 8.66), (-13.48, -12.44)),
    ((5.12, 25.40), (10.32, 11.96)),
)

FORBIDDEN_NAME_TOKENS = (
    "collision",
    "camera",
    "light",
    "character",
    "weapon",
    "cloud",
    "vortex",
    "arrow",
    "cover",
)


def load_layout() -> dict:
    if not LAYOUT_PATH.is_file():
        raise FileNotFoundError(f"Canonical Momentum Circuit layout is missing: {LAYOUT_PATH}")
    layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8-sig"))
    if layout.get("schema") != SCHEMA or layout.get("version") != SCHEMA_VERSION:
        raise ValueError(
            f"Unsupported layout schema/version: {layout.get('schema')!r} v{layout.get('version')!r}"
        )
    expected_units = {
        "distance": "godot_world_units",
        "plane": "xz",
        "rotation": "yaw_degrees",
    }
    if layout.get("units") != expected_units:
        raise ValueError("Momentum Circuit builder requires Godot xz/yaw-degrees layout units")
    expected_counts = {
        "holes": (len(layout.get("holes", [])), 3),
        "covers": (len(layout.get("covers", [])), 0),
        "anchors": (len(layout.get("portals", [])), 4),
        "spawns": (len(layout.get("spawns", [])), 4),
    }
    failures = [
        f"{name}={actual}, expected {expected}"
        for name, (actual, expected) in expected_counts.items()
        if actual != expected
    ]
    platform = layout.get("platform", {})
    if len(platform.get("visual_top_outline_world_xz", [])) < 3:
        failures.append("platform visual outline is missing")
    validation = layout.get("validation", {})
    if not bool(validation.get("passed", False)):
        failures.append("canonical reconstruction validation is not passed")
    if float(validation.get("visual_projection_iou", 0.0)) < 0.95:
        failures.append("canonical visual projection IoU is below 0.95")
    if failures:
        raise ValueError("Momentum Circuit layout contract failed: " + "; ".join(failures))
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
    ):
        for block in list(datablocks):
            datablocks.remove(block)
    for collection in list(bpy.data.collections):
        if collection != bpy.context.scene.collection:
            bpy.data.collections.remove(collection)


def srgb_channel_to_linear(value: float) -> float:
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def rgba(hex_color: str, alpha: float = 1.0) -> tuple[float, float, float, float]:
    value = hex_color.lstrip("#")
    srgb = tuple(int(value[index : index + 2], 16) / 255.0 for index in (0, 2, 4))
    return tuple(srgb_channel_to_linear(channel) for channel in srgb) + (alpha,)


def make_material(
    name: str,
    color: str,
    roughness: float,
    metallic: float = 0.0,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = rgba(color)
    material.metallic = metallic
    material.roughness = roughness
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled:
        principled.inputs["Base Color"].default_value = rgba(color)
        principled.inputs["Metallic"].default_value = metallic
        principled.inputs["Roughness"].default_value = roughness
        if emission_strength > 0.0:
            emission_input = principled.inputs.get("Emission Color") or principled.inputs.get("Emission")
            if emission_input:
                emission_input.default_value = rgba(color)
            strength_input = principled.inputs.get("Emission Strength")
            if strength_input:
                strength_input.default_value = emission_strength
        if "Coat Weight" in principled.inputs:
            principled.inputs["Coat Weight"].default_value = 0.08
        if "Coat Roughness" in principled.inputs:
            principled.inputs["Coat Roughness"].default_value = min(1.0, roughness + 0.08)
    material["surface_contract"] = "matte_technical_ceramic"
    material["palette_token"] = color.upper()
    material["emission_strength"] = emission_strength
    return material


def create_materials() -> dict[str, bpy.types.Material]:
    panel_a_roughness = 0.76 if ASSET_VERSION >= 9 else 0.79
    panel_b_roughness = 0.86 if ASSET_VERSION >= 9 else 0.82
    materials = {
        "panel_a": make_material(f"MC_{ASSET_TAG}DeckPanelA", PALETTE["panel_a"], panel_a_roughness, 0.02),
        "panel_b": make_material(f"MC_{ASSET_TAG}DeckPanelB", PALETTE["panel_b"], panel_b_roughness, 0.015),
        "seam_inlay": make_material(f"MC_{ASSET_TAG}LavenderSeamInlay", PALETTE["seam_inlay"], 0.84, 0.01),
        "inset_dark": make_material(f"MC_{ASSET_TAG}InsetCeramic", PALETTE["inset_dark"], 0.84, 0.01),
        "side_low": make_material(f"MC_{ASSET_TAG}SidewallLow", PALETTE["side_low"], 0.84, 0.02),
        "side_high": make_material(f"MC_{ASSET_TAG}SidewallHigh", PALETTE["side_high"], 0.81, 0.025),
        "static_rim": make_material(
            "MC_StaticRimGlow",
            PALETTE["static_rim"],
            0.78,
            0.0,
            0.24 if ASSET_VERSION >= 9 else 0.35,
        ),
        "cyan": make_material(
            "MC_StabilizerCyanInset",
            PALETTE["anchor_cyan"],
            0.68 if ASSET_VERSION >= 9 else 0.72,
            0.0,
            0.16 if ASSET_VERSION >= 9 else 0.08,
        ),
    }
    if ASSET_VERSION >= 4:
        materials["slot_glow"] = make_material(
            "MC_EnergySpanSlotGlow",
            PALETTE["slot_glow"],
            0.82,
            0.0,
            0.06,
        )
    if ASSET_VERSION >= 9:
        if not DECK_TEXTURE_PATH.is_file():
            raise FileNotFoundError(f"Momentum Circuit deck texture is missing: {DECK_TEXTURE_PATH}")
        deck_image = bpy.data.images.load(str(DECK_TEXTURE_PATH), check_existing=True)
        for key in ("panel_a", "panel_b"):
            material = materials[key]
            principled = material.node_tree.nodes.get("Principled BSDF")
            texture = material.node_tree.nodes.new("ShaderNodeTexImage")
            texture.name = "MC_V9AuthoredDeckAlbedo"
            texture.image = deck_image
            texture.interpolation = "Linear"
            texture.extension = "EXTEND"
            material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
            material["authored_albedo"] = str(DECK_TEXTURE_PATH.relative_to(ROOT)).replace("\\", "/")
    return materials


def make_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    collection.objects.link(obj)


def make_root(collection: bpy.types.Collection) -> bpy.types.Object:
    root = bpy.data.objects.new(f"MomentumCircuitForegroundV{ASSET_VERSION}", None)
    collection.objects.link(root)
    root["asset_role"] = "production_foreground"
    root["visual_only"] = True
    root["collision_owner"] = "Godot"
    root["layout_source"] = "resources/maps/momentum_circuit_layout_v2.json"
    root["asset_version"] = ASSET_VERSION
    root["art_direction"] = "party_game_non_toy_deep_violet_starship_ceramic_v9"
    root["surface_panel_count"] = 14
    root["logical_panel_unit_count"] = 14
    root["surface_base_color"] = PALETTE["panel_a"]
    root["surface_secondary_color"] = PALETTE["panel_b"]
    root["seam_inlay_color"] = PALETTE["seam_inlay"]
    root["seam_width_world"] = PANEL_GAP
    root["seam_depression_world"] = PANEL_RAISE
    root["seam_endpoint_connection_ratio"] = 1.0
    root["top_roughness_min"] = 0.76 if ASSET_VERSION >= 9 else 0.79
    root["top_roughness_max"] = 0.86 if ASSET_VERSION >= 9 else 0.82
    root["top_metallic_max"] = 0.02
    root["static_rim_color"] = PALETTE["static_rim"]
    root["static_rim_emission"] = 0.35
    root["device_max_height_world"] = 0.28 if ASSET_VERSION >= 4 else 0.37
    root["hole_inner_wall_layers"] = 3 if ASSET_VERSION >= 4 else 2
    root["endpoint_slot_count"] = 6 if ASSET_VERSION >= 4 else 0
    root["material_batch_count"] = len(PALETTE)
    root["cover_count"] = 0
    return root


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


def ensure_cw(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    return points if signed_area(points) < 0.0 else list(reversed(points))


def apply_material(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.append(material)


def tag_visual_only(obj: bpy.types.Object, semantic_role: str) -> None:
    obj["visual_only"] = True
    obj["semantic_role"] = semantic_role


def create_side_shell(
    name: str,
    loops: list[list[tuple[float, float]]],
    bottom_z: float,
    top_z: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    vertices: list[tuple[float, float, float]] = []
    faces: list[tuple[int, int, int, int]] = []
    for loop in loops:
        start = len(vertices)
        count = len(loop)
        vertices.extend((x, y, bottom_z) for x, y in loop)
        vertices.extend((x, y, top_z) for x, y in loop)
        for index in range(count):
            next_index = (index + 1) % count
            faces.append(
                (
                    start + index,
                    start + next_index,
                    start + count + next_index,
                    start + count + index,
                )
            )
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    apply_material(obj, material)
    tag_visual_only(obj, "platform_side_shell")
    return obj


def create_filled_surface(
    name: str,
    outer: list[tuple[float, float]],
    holes: list[list[tuple[float, float]]],
    height_z: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    semantic_role: str,
) -> bpy.types.Object:
    curve_data = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve_data.dimensions = "2D"
    curve_data.resolution_u = 1
    curve_data.render_resolution_u = 1
    curve_data.fill_mode = "BOTH"
    curve_data.resolution_v = 0
    for loop in [ensure_ccw(outer)] + [ensure_cw(hole) for hole in holes]:
        spline = curve_data.splines.new("POLY")
        spline.points.add(len(loop) - 1)
        for point, coordinate in zip(spline.points, loop):
            point.co = (coordinate[0], coordinate[1], 0.0, 1.0)
        spline.use_cyclic_u = True
    obj = bpy.data.objects.new(name, curve_data)
    collection.objects.link(obj)
    obj.location.z = height_z
    obj.parent = parent
    apply_material(obj, material)
    tag_visual_only(obj, semantic_role)

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.name = name
    tag_visual_only(obj, semantic_role)
    obj.select_set(False)
    return obj


def triangulate_mesh_object(obj: bpy.types.Object) -> None:
    """Triangulate a flat source surface deterministically for panel clipping."""
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="FIXED", ngon_method="BEAUTY")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def clip_polygon_to_half_plane(
    polygon: list[tuple[float, float]],
    normal: tuple[float, float],
    limit: float,
) -> list[tuple[float, float]]:
    if len(polygon) < 3:
        return []
    result: list[tuple[float, float]] = []
    previous = polygon[-1]
    previous_distance = previous[0] * normal[0] + previous[1] * normal[1] - limit
    previous_inside = previous_distance <= 1.0e-7
    for current in polygon:
        current_distance = current[0] * normal[0] + current[1] * normal[1] - limit
        current_inside = current_distance <= 1.0e-7
        if current_inside != previous_inside:
            denominator = previous_distance - current_distance
            if abs(denominator) > 1.0e-10:
                ratio = previous_distance / denominator
                result.append(
                    (
                        previous[0] + (current[0] - previous[0]) * ratio,
                        previous[1] + (current[1] - previous[1]) * ratio,
                    )
                )
        if current_inside:
            result.append(current)
        previous = current
        previous_distance = current_distance
        previous_inside = current_inside
    return result


def inset_voronoi_fragment(
    polygon: list[tuple[float, float]],
    seed_index: int,
    seeds: list[tuple[float, float]],
    gap: float,
) -> list[tuple[float, float]]:
    result = polygon
    seed = seeds[seed_index]
    for other_index, other in enumerate(seeds):
        if other_index == seed_index:
            continue
        normal = (other[0] - seed[0], other[1] - seed[1])
        normal_length = math.hypot(normal[0], normal[1])
        if normal_length <= 1.0e-8:
            raise RuntimeError(f"Duplicate logical panel seeds: {seed_index} and {other_index}")
        limit = (
            (other[0] * other[0] + other[1] * other[1])
            - (seed[0] * seed[0] + seed[1] * seed[1])
        ) * 0.5 - gap * 0.5 * normal_length
        result = clip_polygon_to_half_plane(result, normal, limit)
        if len(result) < 3:
            return []
    return result


def apply_panel_craft(obj: bpy.types.Object) -> None:
    # Clipped source triangles deliberately duplicate boundary vertices. Weld
    # them before solidify/bevel so each logical panel becomes one continuous
    # ceramic shell instead of a collection of beveled triangle islands.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1.0e-5)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    solidify = obj.modifiers.new("MC_V3PanelSeamDepth", "SOLIDIFY")
    solidify.thickness = PANEL_RAISE
    solidify.offset = -1.0
    solidify.use_even_offset = True
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    bevel = obj.modifiers.new("MC_V3PanelEdgeBevel", "BEVEL")
    bevel.width = PANEL_BEVEL
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.select_set(False)


def assign_v9_deck_uv(obj: bpy.types.Object) -> None:
    uv_layer = obj.data.uv_layers.new(name="MC_V9DeckUV")
    for polygon in obj.data.polygons:
        for loop_index in polygon.loop_indices:
            vertex = obj.data.vertices[obj.data.loops[loop_index].vertex_index].co
            uv_layer.data[loop_index].uv = (
                (float(vertex.x) + 52.0) / 104.0,
                (float(vertex.y) + 50.0) / 100.0,
            )


def create_panel_units(
    source_surface: bpy.types.Object,
    top_height: float,
    materials: dict[str, bpy.types.Material],
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> list[bpy.types.Object]:
    """Split the canonical top into fourteen inset, shallow ceramic panels.

    The split is a deterministic inset Voronoi partition evaluated against the
    already hole-clipped platform triangles.  The exposed lower surface becomes
    a connected 0.10u-wide, 0.025u-deep seam bed without any lane markings.
    """
    triangulate_mesh_object(source_surface)
    seeds = [g2b_planar(seed) for seed in PANEL_SEEDS_GODOT_XZ]
    source_triangles: list[list[tuple[float, float]]] = []
    for polygon in source_surface.data.polygons:
        if len(polygon.vertices) != 3:
            raise RuntimeError("Panel source surface must be triangulated")
        source_triangles.append(
            [
                (
                    float(source_surface.data.vertices[index].co.x),
                    float(source_surface.data.vertices[index].co.y),
                )
                for index in polygon.vertices
            ]
        )

    panel_objects: list[bpy.types.Object] = []
    for panel_index, seed in enumerate(seeds):
        vertices: list[tuple[float, float, float]] = []
        faces: list[tuple[int, ...]] = []
        for triangle in source_triangles:
            fragment = inset_voronoi_fragment(triangle, panel_index, seeds, PANEL_GAP)
            if len(fragment) < 3 or abs(signed_area(fragment)) < 1.0e-7:
                continue
            fragment = ensure_ccw(fragment)
            start = len(vertices)
            vertices.extend((point[0], point[1], top_height + PANEL_RAISE) for point in fragment)
            faces.append(tuple(range(start, start + len(fragment))))
        if not faces:
            raise RuntimeError(f"Logical deck panel {panel_index + 1:02d} is empty")
        mesh = bpy.data.meshes.new(f"DeckPanelUnit{panel_index + 1:02d}Mesh")
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        panel = bpy.data.objects.new(f"DeckPanelUnit{panel_index + 1:02d}", mesh)
        collection.objects.link(panel)
        panel.parent = parent
        panel["visual_only"] = True
        panel["semantic_role"] = "logical_deck_panel"
        panel["logical_panel_id"] = panel_index + 1
        panel["seed_world_xz"] = PANEL_SEEDS_GODOT_XZ[panel_index]
        panel["seam_gap_world"] = PANEL_GAP
        panel["seam_depth_world"] = PANEL_RAISE
        apply_material(panel, materials["panel_a" if panel_index % 2 == 0 else "panel_b"])
        apply_panel_craft(panel)
        if ASSET_VERSION >= 9:
            assign_v9_deck_uv(panel)
        panel_objects.append(panel)

        anchor = bpy.data.objects.new(f"PanelUnitAnchor{panel_index + 1:02d}", None)
        collection.objects.link(anchor)
        anchor.location = (seed[0], seed[1], top_height + PANEL_RAISE)
        anchor.parent = parent
        anchor["visual_only"] = True
        anchor["semantic_role"] = "logical_deck_panel_anchor"
        anchor["logical_panel_id"] = panel_index + 1
    return panel_objects


def create_loop_trim(
    name: str,
    loops: list[list[tuple[float, float]]],
    height_z: float,
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    """Create a fine ceramic inlay around the outer rim and all void rims."""
    curve_data = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.render_resolution_u = 1
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 2
    curve_data.resolution_v = 2
    for loop in loops:
        spline = curve_data.splines.new("POLY")
        spline.points.add(len(loop) - 1)
        for point, coordinate in zip(spline.points, loop):
            point.co = (coordinate[0], coordinate[1], 0.0, 1.0)
        spline.use_cyclic_u = True
    obj = bpy.data.objects.new(name, curve_data)
    collection.objects.link(obj)
    obj.location.z = height_z
    obj.parent = parent
    apply_material(obj, material)
    tag_visual_only(obj, "platform_edge_inlay")

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.name = name
    tag_visual_only(obj, "platform_edge_inlay")
    obj.select_set(False)
    return obj


def create_open_trim(
    name: str,
    paths: list[list[tuple[float, float]]],
    height_z: float,
    radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    curve_data = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 1
    curve_data.render_resolution_u = 1
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 2
    curve_data.resolution_v = 2
    for path in paths:
        if len(path) < 2:
            continue
        spline = curve_data.splines.new("POLY")
        spline.points.add(len(path) - 1)
        for point, coordinate in zip(spline.points, path):
            point.co = (coordinate[0], coordinate[1], 0.0, 1.0)
        spline.use_cyclic_u = False
    obj = bpy.data.objects.new(name, curve_data)
    collection.objects.link(obj)
    obj.location.z = height_z
    obj.parent = parent
    apply_material(obj, material)
    tag_visual_only(obj, "deck_panel_seam")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.name = name
    tag_visual_only(obj, "deck_panel_seam")
    obj.select_set(False)
    return obj


def point_inside_polygon(point: tuple[float, float], polygon: list[tuple[float, float]]) -> bool:
    x, y = point
    inside = False
    previous = polygon[-1]
    for current in polygon:
        x1, y1 = previous
        x2, y2 = current
        if (y1 > y) != (y2 > y):
            crossing_x = (x2 - x1) * (y - y1) / (y2 - y1) + x1
            if x < crossing_x:
                inside = not inside
        previous = current
    return inside


def clip_seam_to_walkable(
    seam: tuple[tuple[float, float], tuple[float, float]],
    outer: list[tuple[float, float]],
    holes: list[list[tuple[float, float]]],
) -> list[list[tuple[float, float]]]:
    start, end = seam
    distance = math.dist(start, end)
    steps = max(2, math.ceil(distance / 0.25))
    runs: list[list[tuple[float, float]]] = []
    active: list[tuple[float, float]] = []
    for index in range(steps + 1):
        ratio = index / steps
        point = (
            start[0] + (end[0] - start[0]) * ratio,
            start[1] + (end[1] - start[1]) * ratio,
        )
        walkable = point_inside_polygon(point, outer) and not any(
            point_inside_polygon(point, hole) for hole in holes
        )
        if walkable:
            active.append(point)
        elif len(active) >= 2:
            runs.append(active)
            active = []
        else:
            active = []
    if len(active) >= 2:
        runs.append(active)
    return runs


def apply_bevel(obj: bpy.types.Object, width: float, segments: int = 3) -> None:
    if width <= 0.0:
        return
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("MC_SoftCeramicEdge", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    obj.select_set(False)


def add_rounded_box(
    name: str,
    godot_center: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    yaw_degrees: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    semantic_role: str,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(
        location=g2b_position(godot_center),
        rotation=(0.0, 0.0, math.radians(yaw_degrees)),
    )
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    move_to_collection(obj, collection)
    obj.parent = parent
    apply_material(obj, material)
    tag_visual_only(obj, semantic_role)
    apply_bevel(obj, min(0.18, min(dimensions) * 0.18), 4)
    return obj


def add_cylinder(
    name: str,
    godot_position: tuple[float, float, float] | list[float],
    radius: float,
    height: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    semantic_role: str,
    bevel: float,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=48,
        radius=radius,
        depth=height,
        location=g2b_position(godot_position),
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    apply_material(obj, material)
    tag_visual_only(obj, semantic_role)
    apply_bevel(obj, bevel, 3)
    return obj


def add_torus(
    name: str,
    godot_position: tuple[float, float, float] | list[float],
    major_radius: float,
    minor_radius: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
    semantic_role: str,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=48,
        minor_segments=10,
        location=g2b_position(godot_position),
        major_radius=major_radius,
        minor_radius=minor_radius,
    )
    obj = bpy.context.object
    obj.name = name
    move_to_collection(obj, collection)
    obj.parent = parent
    apply_material(obj, material)
    tag_visual_only(obj, semantic_role)
    return obj


def add_v9_deck_inlays(
    device_floor: float,
    materials: dict[str, bpy.types.Material],
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> None:
    """Add sparse, flush service inlays that break up the broad deck masses.

    These are deliberately short, closed motifs rather than lanes.  They add
    scale and material hierarchy without suggesting traversal direction or
    becoming gameplay geometry.
    """
    motifs = (
        (-29.0, -34.0, 5.8, 2.1, -12.0),
        (-14.0, -31.0, 4.0, 1.5, 18.0),
        (20.0, -27.0, 5.4, 1.8, 8.0),
        (32.0, -18.0, 3.6, 1.5, -24.0),
        (-31.0, -8.0, 5.0, 1.7, 10.0),
        (-2.5, -4.0, 4.2, 1.55, -8.0),
        (30.0, 2.0, 5.2, 1.8, 16.0),
        (-29.0, 11.0, 4.5, 1.6, -16.0),
        (-3.0, 17.5, 4.0, 1.5, 12.0),
        (27.0, 20.0, 5.4, 1.8, -8.0),
        (17.0, 32.0, 4.6, 1.55, 14.0),
    )
    for index, (x, z, width, depth, yaw) in enumerate(motifs):
        add_rounded_box(
            f"DeckServiceInset{index + 1:02d}",
            (x, device_floor + 0.010, z),
            (width, depth, 0.020),
            yaw,
            materials["inset_dark"],
            collection,
            parent,
            "flush_deck_service_inset",
        )
        add_rounded_box(
            f"DeckServiceCore{index + 1:02d}",
            (x, device_floor + 0.023, z),
            (width * 0.62, max(0.16, depth * 0.12), 0.018),
            yaw,
            materials["seam_inlay"],
            collection,
            parent,
            "flush_deck_service_core",
        )


def make_anchor(
    name: str,
    godot_position: list[float] | tuple[float, float, float],
    semantic_id: str,
    source_kind: str,
    collection: bpy.types.Collection,
    parent: bpy.types.Object,
) -> bpy.types.Object:
    anchor = bpy.data.objects.new(name, None)
    collection.objects.link(anchor)
    anchor.location = g2b_position(godot_position)
    anchor.parent = parent
    anchor.empty_display_type = "PLAIN_AXES"
    anchor["semantic_id"] = semantic_id
    anchor["source_kind"] = source_kind
    anchor["visual_only"] = True
    return anchor


def component_radius(data: dict, layout: dict) -> float:
    bounds = data["component_bounds_xywh_px"]
    projection = layout["projection"]
    diameter_x = float(bounds[2]) * float(projection["world_units_per_pixel_x"])
    diameter_z = float(bounds[3]) * float(projection["world_units_per_pixel_z"])
    return max(0.8, (diameter_x + diameter_z) * 0.25)


def build_foreground(
    layout: dict,
    materials: dict[str, bpy.types.Material],
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    root = make_root(collection)
    platform = layout["platform"]
    top_y = float(platform["top_y"])
    bottom_y = float(platform["bottom_y"])
    outer = ensure_ccw([g2b_planar(point) for point in platform["visual_top_outline_world_xz"]])
    holes = [
        ensure_cw([g2b_planar(point) for point in hole["visual_top_outline_world_xz"]])
        for hole in layout["holes"]
    ]
    side_split_y = top_y - 0.68
    if ASSET_VERSION >= 4:
        side_lower_split_y = top_y - 1.42
        create_side_shell(
            "PlatformSidewallDeep",
            [outer] + holes,
            bottom_y,
            side_lower_split_y,
            materials["side_low"],
            collection,
            root,
        )
        create_side_shell(
            "PlatformSidewallMiddle",
            [outer] + holes,
            side_lower_split_y,
            side_split_y,
            materials["inset_dark"],
            collection,
            root,
        )
        create_side_shell(
            "PlatformSidewallUpper",
            [outer] + holes,
            side_split_y,
            top_y + TOP_SURFACE_LIFT,
            materials["side_high"],
            collection,
            root,
        )
    else:
        create_side_shell(
            "PlatformSidewallLower",
            [outer] + holes,
            bottom_y,
            side_split_y,
            materials["side_low"],
            collection,
            root,
        )
        create_side_shell(
            "PlatformSidewallUpper",
            [outer] + holes,
            side_split_y,
            top_y + TOP_SURFACE_LIFT,
            materials["side_high"],
            collection,
            root,
        )
    seam_bed = create_filled_surface(
        "PlatformInsetSeamBed",
        outer,
        holes,
        top_y + TOP_SURFACE_LIFT,
        materials["seam_inlay"],
        collection,
        root,
        "connected_recessed_seam_bed",
    )
    create_panel_units(
        seam_bed,
        top_y + TOP_SURFACE_LIFT,
        materials,
        collection,
        root,
    )
    create_filled_surface(
        "PlatformUnderside",
        outer,
        holes,
        bottom_y,
        materials["side_low"],
        collection,
        root,
        "platform_underside",
    )
    create_loop_trim(
        "DeckCeramicChamferLip",
        [outer] + holes,
        top_y + TOP_SURFACE_LIFT + 0.005,
        0.14,
        materials["side_high"],
        collection,
        root,
    )
    create_loop_trim(
        "SidewallLayerInlay",
        [outer] + holes,
        side_split_y,
        0.035,
        materials["side_high"],
        collection,
        root,
    )
    if ASSET_VERSION >= 4:
        create_loop_trim(
            "VoidWallDepthBandUpper",
            holes,
            top_y - 0.34,
            0.045,
            materials["seam_inlay"],
            collection,
            root,
        )
        create_loop_trim(
            "VoidWallDepthBandLower",
            holes,
            top_y - 1.38,
            0.035,
            materials["inset_dark"],
            collection,
            root,
        )
    create_loop_trim(
        "StaticDeckRim",
        [outer] + holes,
        top_y + TOP_SURFACE_LIFT + PANEL_RAISE + 0.040,
        0.14,
        materials["static_rim"],
        collection,
        root,
    )
    make_anchor("Anchor_Platform", (0.0, top_y, 0.0), "platform", "platform", collection, root)

    for index, anchor_data in enumerate(layout["portals"]):
        position = anchor_data["position_world"]
        radius = component_radius(anchor_data, layout)
        if ASSET_VERSION >= 9:
            radius = min(2.45, max(2.18, radius * 1.42))
        base_height = 0.08 if ASSET_VERSION >= 4 else 0.12
        core_height = 0.055 if ASSET_VERSION >= 4 else 0.095
        device_floor = top_y + TOP_SURFACE_LIFT + PANEL_RAISE
        add_cylinder(
            f"StabilizerCeramicBase{index + 1:02d}",
            (position[0], device_floor + base_height * 0.5, position[2]),
            radius * 0.98,
            base_height,
            materials["side_high"] if ASSET_VERSION >= 9 else materials["inset_dark"],
            collection,
            root,
            "stabilizer_ceramic_base",
            0.04,
        )
        add_torus(
            f"StabilizerMechanicalCollar{index + 1:02d}",
            (position[0], device_floor + (0.12 if ASSET_VERSION >= 4 else 0.18), position[2]),
            radius * 0.72,
            min(0.09 if ASSET_VERSION >= 4 else 0.13, radius * 0.10),
            materials["static_rim"] if ASSET_VERSION >= 9 else materials["side_high"],
            collection,
            root,
            "stabilizer_mechanical_collar",
        )
        add_cylinder(
            f"StabilizerCyanEnergyLens{index + 1:02d}",
            (
                position[0],
                device_floor + (0.15 if ASSET_VERSION >= 4 else 0.23) + core_height * 0.5,
                position[2],
            ),
            radius * 0.70,
            core_height,
            materials["cyan"],
            collection,
            root,
            "stabilizer_energy_lens",
            0.025,
        )
        if ASSET_VERSION >= 9:
            add_torus(
                f"StabilizerOuterBezel{index + 1:02d}",
                (position[0], device_floor + 0.095, position[2]),
                radius * 0.91,
                min(0.11, radius * 0.055),
                materials["inset_dark"],
                collection,
                root,
                "stabilizer_outer_mechanical_bezel",
            )
            ring_radius = radius * 0.89
            for segment_index in range(8):
                angle = math.tau * float(segment_index) / 8.0
                add_rounded_box(
                    f"StabilizerCollarBlock{index + 1:02d}_{segment_index + 1:02d}",
                    (
                        position[0] + math.cos(angle) * ring_radius,
                        device_floor + 0.105,
                        position[2] + math.sin(angle) * ring_radius,
                    ),
                    (max(0.46, radius * 0.34), 0.30, 0.105),
                    90.0 - math.degrees(angle),
                    materials["side_high"],
                    collection,
                    root,
                    "stabilizer_segmented_mechanical_collar",
                )
        make_anchor(
            f"Anchor_Stabilizer{index + 1:02d}",
            position,
            str(anchor_data["id"]),
            "stabilizer_anchor",
            collection,
            root,
        )

    if ASSET_VERSION >= 4:
        slot_floor = top_y + TOP_SURFACE_LIFT + PANEL_RAISE + 0.018
        slot_index = 0
        for endpoints in BRIDGE_ENDPOINTS_GODOT_XZ:
            start, finish = endpoints
            direction_x = finish[0] - start[0]
            direction_z = finish[1] - start[1]
            yaw_degrees = math.degrees(math.atan2(direction_x, direction_z))
            for point in endpoints:
                slot_index += 1
                slot_width = 6.20 if ASSET_VERSION >= 9 else 4.42
                slot_depth = 1.52 if ASSET_VERSION >= 9 else 0.86
                inset_width = 5.18 if ASSET_VERSION >= 9 else 3.76
                inset_depth = 0.48 if ASSET_VERSION >= 9 else 0.34
                add_rounded_box(
                    f"EnergySpanSlot{slot_index:02d}",
                    (point[0], slot_floor, point[1]),
                    (slot_width, slot_depth, 0.105 if ASSET_VERSION >= 9 else 0.055),
                    yaw_degrees,
                    materials["inset_dark"],
                    collection,
                    root,
                    "energy_span_endpoint_slot",
                )
                add_rounded_box(
                    f"EnergySpanInset{slot_index:02d}",
                    (point[0], slot_floor + 0.034, point[1]),
                    (inset_width, inset_depth, 0.035 if ASSET_VERSION >= 9 else 0.026),
                    yaw_degrees,
                    materials["slot_glow"],
                    collection,
                    root,
                    "energy_span_endpoint_inset",
                )
                if ASSET_VERSION >= 9:
                    perpendicular_x = math.cos(math.radians(yaw_degrees))
                    perpendicular_z = -math.sin(math.radians(yaw_degrees))
                    for side in (-1.0, 1.0):
                        add_rounded_box(
                            f"EnergySpanDockJaw{slot_index:02d}_{'L' if side < 0 else 'R'}",
                            (
                                point[0] + perpendicular_x * side * 2.88,
                                slot_floor + 0.09,
                                point[1] + perpendicular_z * side * 2.88,
                            ),
                            (0.42, 1.30, 0.18),
                            yaw_degrees,
                            materials["side_high"],
                            collection,
                            root,
                            "energy_span_endpoint_dock_jaw",
                        )

    return root


def collection_stats(collection: bpy.types.Collection) -> dict:
    meshes = [obj for obj in collection.all_objects if obj.type == "MESH"]
    triangles = 0
    materials: set[str] = set()
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
        for material in obj.data.materials:
            if material:
                materials.add(material.name)
    return {
        "mesh_objects": len(meshes),
        "empty_objects": sum(1 for obj in collection.all_objects if obj.type == "EMPTY"),
        "triangles": triangles,
        "materials": sorted(materials),
    }


def validate_collection(collection: bpy.types.Collection, layout: dict) -> None:
    forbidden_types = [
        obj.name for obj in collection.all_objects if obj.type in {"CAMERA", "LIGHT", "ARMATURE"}
    ]
    if forbidden_types:
        raise RuntimeError(f"Foreground contains forbidden object types: {forbidden_types}")
    forbidden_names = [
        obj.name
        for obj in collection.all_objects
        if any(token in obj.name.lower() for token in FORBIDDEN_NAME_TOKENS)
    ]
    if forbidden_names:
        raise RuntimeError(f"Foreground contains prohibited semantic objects: {forbidden_names}")
    logical_panel_anchors = [
        obj for obj in collection.all_objects if obj.get("semantic_role") == "logical_deck_panel_anchor"
    ]
    if len(logical_panel_anchors) != 14:
        raise RuntimeError(f"Logical deck panel anchor count {len(logical_panel_anchors)} does not match 14")
    panel_meshes = [
        obj for obj in collection.all_objects if obj.get("semantic_role") == "logical_deck_panel"
    ]
    batched_panel_meshes = [
        obj for obj in collection.all_objects
        if obj.name in {f"Foreground_{ASSET_TAG}DeckPanelA", f"Foreground_{ASSET_TAG}DeckPanelB"}
    ]
    if len(panel_meshes) != 14 and len(batched_panel_meshes) != 2:
        raise RuntimeError(
            f"Deck panel geometry is neither 14 editable units nor two material batches: "
            f"editable={len(panel_meshes)} batched={len(batched_panel_meshes)}"
        )
    panel_ids = sorted(int(obj.get("logical_panel_id", 0)) for obj in logical_panel_anchors)
    if panel_ids != list(range(1, 15)):
        raise RuntimeError(f"Logical panel ids are not exactly 1..14: {panel_ids}")
    cover_materials = [material.name for material in bpy.data.materials if "cover" in material.name.lower()]
    if cover_materials:
        raise RuntimeError(f"Foreground contains prohibited cover materials: {cover_materials}")
    missing_visual_tag = [
        obj.name for obj in collection.all_objects if obj.type in {"MESH", "EMPTY"} and not obj.get("visual_only")
    ]
    if missing_visual_tag:
        raise RuntimeError(f"Foreground objects lack visual_only=true: {missing_visual_tag}")
    expected_anchors = 1 + len(layout["portals"])
    semantic_anchors = [obj for obj in collection.all_objects if obj.type == "EMPTY" and obj.get("semantic_id")]
    if len(semantic_anchors) != expected_anchors:
        raise RuntimeError(
            f"Semantic anchor count {len(semantic_anchors)} does not match {expected_anchors}"
        )
    stats = collection_stats(collection)
    if stats["triangles"] <= 0:
        raise RuntimeError("Foreground contains no renderable triangles")
    if len(stats["materials"]) != len(PALETTE):
        raise RuntimeError(
            f"Foreground material count {len(stats['materials'])} does not match palette {len(PALETTE)}"
        )
    root = next((obj for obj in collection.all_objects if obj.name == f"MomentumCircuitForegroundV{ASSET_VERSION}"), None)
    if root is None:
        raise RuntimeError(f"Momentum Circuit v{ASSET_VERSION} foreground root is missing")
    if int(root.get("logical_panel_unit_count", 0)) != 14:
        raise RuntimeError("Foreground root does not freeze fourteen logical panel units")
    if not math.isclose(float(root.get("seam_width_world", 0.0)), PANEL_GAP, abs_tol=1.0e-6):
        raise RuntimeError("Foreground seam width contract changed")
    if not math.isclose(float(root.get("seam_depression_world", 0.0)), PANEL_RAISE, abs_tol=1.0e-6):
        raise RuntimeError("Foreground seam depression contract changed")
    if float(root.get("device_max_height_world", 1.0)) > DEVICE_MAX_HEIGHT:
        raise RuntimeError(f"Foreground device height exceeds {DEVICE_MAX_HEIGHT:.2f} world units")
    if ASSET_VERSION >= 4:
        if int(root.get("hole_inner_wall_layers", 0)) != 3:
            raise RuntimeError("Foreground v4 must freeze three hole inner-wall layers")
        if int(root.get("endpoint_slot_count", 0)) != 6:
            raise RuntimeError("Foreground v4 must freeze six energy span endpoint slots")


def join_meshes_by_material(collection: bpy.types.Collection) -> None:
    material_groups: dict[str, list[bpy.types.Object]] = {}
    for obj in collection.all_objects:
        if obj.type != "MESH" or not obj.data.materials or obj.data.materials[0] is None:
            continue
        material_groups.setdefault(obj.data.materials[0].name, []).append(obj)
    for material_name in sorted(material_groups):
        objects = material_groups[material_name]
        if len(objects) <= 1:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = "Foreground_" + material_name.removeprefix("MC_")
        joined["visual_only"] = True
        joined["semantic_role"] = "batched_static_foreground"
        joined.select_set(False)


def strip_unused_uv_layers(collection: bpy.types.Collection) -> None:
    """Remove operator-generated UV noise from this flat-color asset.

    The foreground uses palette materials only. Blender bevel/cylinder operators
    can leave irrelevant UV floats with run-to-run variation, so retaining them
    would make otherwise identical GLB builds differ at the byte level.
    """
    for obj in collection.all_objects:
        if obj.type != "MESH":
            continue
        if (
            ASSET_VERSION >= 9
            and obj.data.materials
            and obj.data.materials[0] is not None
            and obj.data.materials[0].name in {"MC_V9DeckPanelA", "MC_V9DeckPanelB"}
        ):
            continue
        while obj.data.uv_layers:
            obj.data.uv_layers.remove(obj.data.uv_layers[0])


def select_collection_for_export(collection: bpy.types.Collection) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
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


def build() -> None:
    layout = load_layout()
    clear_scene()
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)

    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["generator"] = "tools/build_momentum_circuit_arena_v3.py"
    scene["asset_version"] = ASSET_VERSION
    scene["layout_schema"] = SCHEMA
    scene["layout_version"] = SCHEMA_VERSION
    scene["visual_only"] = True

    materials = create_materials()
    collection = make_collection("MC_FOREGROUND_EXPORT")
    build_foreground(layout, materials, collection)
    validate_collection(collection, layout)
    editable_stats = collection_stats(collection)

    # Keep the .blend modular and editable.  Batching occurs only in memory
    # after this save and therefore only affects the exported GLB.
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    backup = BLEND_PATH.with_name(BLEND_PATH.name + "1")
    if backup.exists():
        backup.unlink()

    join_meshes_by_material(collection)
    strip_unused_uv_layers(collection)
    validate_collection(collection, layout)
    export_stats = collection_stats(collection)
    export_collection(collection, FOREGROUND_GLB_PATH)
    if not FOREGROUND_GLB_PATH.is_file() or FOREGROUND_GLB_PATH.stat().st_size <= 0:
        raise RuntimeError(f"GLB export failed: {FOREGROUND_GLB_PATH}")

    print(f"Saved editable Blender source: {BLEND_PATH}")
    print(f"Exported visual-only foreground: {FOREGROUND_GLB_PATH}")
    print(f"Editable source stats: {json.dumps(editable_stats, sort_keys=True)}")
    print(f"Batched export stats: {json.dumps(export_stats, sort_keys=True)}")
    print("Foreground contract: collision=false camera=false light=false character=false weapon=false")


if __name__ == "__main__":
    build()
