"""Build Momentum Circuit's deterministic, visual-only foreground GLB.

Run with the project's Blender runtime:
    blender --background --python-exit-code 1 --python tools/build_momentum_circuit_arena.py

The canonical JSON remains authoritative.  This builder exports only static
render geometry: the coverless deck, panel seams, rim lights, activator bases,
and stabilizer bases.
Gameplay collision, camera, lighting, characters, weapons, cloud motion, and
gravity-mechanism animation remain Godot-owned.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = ROOT / "resources" / "maps" / "momentum_circuit_layout_v2.json"
SOURCE_DIR = ROOT / "assets" / "source" / "momentum_circuit"
GENERATED_DIR = ROOT / "assets" / "models" / "generated" / "momentum_circuit"
BLEND_PATH = SOURCE_DIR / "momentum_circuit_foreground.blend"
FOREGROUND_GLB_PATH = GENERATED_DIR / "momentum_circuit_foreground.glb"

SCHEMA = "chaos_gun.momentum_circuit_layout"
SCHEMA_VERSION = 2
TOP_SURFACE_LIFT = 0.02

PALETTE = {
    "platform_top": "#45445F",
    "platform_side": "#3C315F",
    "deck_seam": "#716B91",
    "static_rim": "#B7A8EA",
    "fixture": "#37364D",
    "anchor_cyan": "#52E5F5",
    "activator_orange": "#FF9A3D",
}

DECK_PANEL_SEAMS = (
    ((-48.0, -45.0), (-29.0, -34.0)),
    ((-42.0, -49.0), (-25.0, -34.0)),
    ((-29.0, -40.0), (-10.0, -28.0)),
    ((-17.0, -37.0), (1.0, -24.0)),
    ((16.0, -34.0), (35.0, -25.0)),
    ((28.0, -41.0), (43.0, -25.0)),
    ((35.0, -36.0), (49.0, -27.0)),
    ((-49.0, -15.0), (-33.0, -3.0)),
    ((-47.0, -4.0), (-32.0, -14.0)),
    ((-34.0, -12.0), (-14.0, -3.0)),
    ((7.0, 7.0), (21.0, 19.0)),
    ((14.0, 13.0), (31.0, 28.0)),
    ((25.0, 20.0), (42.0, 37.0)),
    ((31.0, 36.0), (47.0, 26.0)),
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
        "activators": (len(layout.get("shockwave_nodes", [])), 3),
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
    return {
        "platform_top": make_material("MC_DeckTopCeramic", PALETTE["platform_top"], 0.81, 0.02),
        "platform_side": make_material("MC_DeckSideCeramic", PALETTE["platform_side"], 0.84, 0.02),
        "seam": make_material("MC_DeckSeamCeramic", PALETTE["deck_seam"], 0.82, 0.01),
        "static_rim": make_material("MC_StaticRimGlow", PALETTE["static_rim"], 0.78, 0.0, 0.35),
        "fixture": make_material("MC_FixtureCeramic", PALETTE["fixture"], 0.83, 0.03),
        "cyan": make_material("MC_StabilizerCyanInset", PALETTE["anchor_cyan"], 0.80, 0.02),
        "orange": make_material("MC_ActivatorOrangeInset", PALETTE["activator_orange"], 0.80, 0.02),
    }


def make_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    collection.objects.link(obj)


def make_root(collection: bpy.types.Collection) -> bpy.types.Object:
    root = bpy.data.objects.new("MomentumCircuitForeground", None)
    collection.objects.link(root)
    root["asset_role"] = "production_foreground"
    root["visual_only"] = True
    root["collision_owner"] = "Godot"
    root["layout_source"] = "resources/maps/momentum_circuit_layout_v2.json"
    root["art_direction"] = "party_game_non_toy_mattech_ceramic"
    root["surface_panel_count"] = 14
    root["surface_base_color"] = PALETTE["platform_top"]
    root["static_rim_color"] = PALETTE["static_rim"]
    root["static_rim_emission"] = 0.35
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
    outer_godot = [tuple(map(float, point)) for point in platform["visual_top_outline_world_xz"]]
    holes_godot = [
        [tuple(map(float, point)) for point in hole["visual_top_outline_world_xz"]]
        for hole in layout["holes"]
    ]

    create_side_shell(
        "PlatformSideShell",
        [outer] + holes,
        bottom_y,
        top_y,
        materials["platform_side"],
        collection,
        root,
    )
    create_filled_surface(
        "PlatformTopSurface",
        outer,
        holes,
        top_y + TOP_SURFACE_LIFT,
        materials["platform_top"],
        collection,
        root,
        "platform_top_surface",
    )
    create_filled_surface(
        "PlatformUnderside",
        outer,
        holes,
        bottom_y,
        materials["platform_side"],
        collection,
        root,
        "platform_underside",
    )
    create_loop_trim(
        "StaticDeckRim",
        [outer] + holes,
        top_y + TOP_SURFACE_LIFT + 0.035,
        0.06,
        materials["static_rim"],
        collection,
        root,
    )
    for index, seam in enumerate(DECK_PANEL_SEAMS):
        clipped_paths = clip_seam_to_walkable(seam, outer_godot, holes_godot)
        if not clipped_paths:
            raise RuntimeError(f"Deck seam {index + 1:02d} does not intersect the walkable platform")
        create_open_trim(
            f"DeckPanelSeam{index + 1:02d}",
            [[g2b_planar(point) for point in path] for path in clipped_paths],
            top_y + TOP_SURFACE_LIFT + 0.028,
            0.05,
            materials["seam"],
            collection,
            root,
        )
    make_anchor("Anchor_Platform", (0.0, top_y, 0.0), "platform", "platform", collection, root)

    for index, anchor_data in enumerate(layout["portals"]):
        position = anchor_data["position_world"]
        radius = component_radius(anchor_data, layout)
        base_height = 0.18
        inset_height = 0.075
        add_cylinder(
            f"StabilizerBase{index + 1:02d}",
            (position[0], top_y + base_height * 0.5 + 0.02, position[2]),
            radius * 0.98,
            base_height,
            materials["fixture"],
            collection,
            root,
            "stabilizer_base",
            0.055,
        )
        add_cylinder(
            f"StabilizerCyanInset{index + 1:02d}",
            (position[0], top_y + base_height + inset_height * 0.5 + 0.02, position[2]),
            radius * 0.72,
            inset_height,
            materials["cyan"],
            collection,
            root,
            "stabilizer_inset",
            0.025,
        )
        make_anchor(
            f"Anchor_Stabilizer{index + 1:02d}",
            position,
            str(anchor_data["id"]),
            "stabilizer_anchor",
            collection,
            root,
        )

    for index, activator_data in enumerate(layout["shockwave_nodes"]):
        position = activator_data["position_world"]
        radius = component_radius(activator_data, layout)
        base_height = 0.16
        inset_height = 0.07
        add_cylinder(
            f"ActivatorBase{index + 1:02d}",
            (position[0], top_y + base_height * 0.5 + 0.02, position[2]),
            radius * 0.98,
            base_height,
            materials["fixture"],
            collection,
            root,
            "activator_base",
            0.05,
        )
        add_cylinder(
            f"ActivatorOrangeInset{index + 1:02d}",
            (position[0], top_y + base_height + inset_height * 0.5 + 0.02, position[2]),
            radius * 0.69,
            inset_height,
            materials["orange"],
            collection,
            root,
            "activator_inset",
            0.022,
        )
        make_anchor(
            f"Anchor_Activator{index + 1:02d}",
            position,
            str(activator_data["id"]),
            "gravity_activator",
            collection,
            root,
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
    panel_seams = [obj for obj in collection.all_objects if obj.name.startswith("DeckPanelSeam")]
    batched_panel_seams = [
        obj for obj in collection.all_objects if obj.name == "Foreground_DeckSeamCeramic"
    ]
    if len(panel_seams) != 14 and len(batched_panel_seams) != 1:
        raise RuntimeError(
            f"Deck panel seam count {len(panel_seams)} does not match 14; "
            f"objects={[obj.name for obj in collection.all_objects]}"
        )
    cover_materials = [material.name for material in bpy.data.materials if "cover" in material.name.lower()]
    if cover_materials:
        raise RuntimeError(f"Foreground contains prohibited cover materials: {cover_materials}")
    missing_visual_tag = [
        obj.name for obj in collection.all_objects if obj.type in {"MESH", "EMPTY"} and not obj.get("visual_only")
    ]
    if missing_visual_tag:
        raise RuntimeError(f"Foreground objects lack visual_only=true: {missing_visual_tag}")
    expected_anchors = 1 + len(layout["covers"]) + len(layout["portals"]) + len(layout["shockwave_nodes"])
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
    scene["generator"] = "tools/build_momentum_circuit_arena.py"
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
