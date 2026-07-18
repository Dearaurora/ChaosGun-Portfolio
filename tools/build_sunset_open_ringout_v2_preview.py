from pathlib import Path
import math
import re
import sys

import bpy


TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import build_sunset_toy_sky_islands_hero as hero


SOURCE_PATH = ROOT / "assets" / "source" / "sunset_toy_sky_islands" / "open_ringout_v2_preview.blend"
GLB_PATH = ROOT / "assets" / "models" / "generated" / "sunset_toy_sky_islands" / "open_ringout_v2_preview.glb"
TEXTURE_DIR = ROOT / "assets" / "textures" / "generated" / "sunset_toy_sky_islands"
INTEGRATION_VERIFIER_PATH = ROOT / "scripts" / "tests" / "sunset_open_ringout_v2_integration_verifier.gd"

P26_EXPORT_PRESERVE_EXACT = {
    "V3NorthWindmillHub",
    "V10CentralFloorTile_2",
    "V3SouthBarrelBlue",
    "V3SouthBarrelGold",
    "V3EastTreeBTrunk",
}
FRAGMENTED_CLIFF_PREFIXES = (
    "V10CentralSouthCliffFacet_",
    "V10CentralEastCliffFacet_",
    "V10NorthIslandFrontCliffFacet_",
)
P26_EXPORT_PRESERVE_PREFIXES = (
    "V3NorthWindmillBlade_",
    "V4NorthWindmillBladeTip_",
    "V3Cloud",
    "V3DistantIsland",
    "V3HotAirBalloon",
) + FRAGMENTED_CLIFF_PREFIXES


def bpos(godot_pos):
    x, y, z = godot_pos
    return (x, -z, y)


def bsize(godot_size):
    x, y, z = godot_size
    return (x, z, y)


def scale_outline(points, factor):
    return [(x * factor, z * factor) for x, z in points]


def scale_outline_about(points, center, factor):
    center_x, center_z = center
    return [
        (center_x + (x - center_x) * factor, center_z + (z - center_z) * factor)
        for x, z in points
    ]


def notched_rect_outline(center, size, radius, notch_side, mouth_center, mouth_width, notch_depth):
    center_x, center_z = center
    size_x, size_z = size
    x_min = center_x - size_x * 0.5
    x_max = center_x + size_x * 0.5
    z_min = center_z - size_z * 0.5
    z_max = center_z + size_z * 0.5
    mouth_low = mouth_center - mouth_width * 0.5
    mouth_high = mouth_center + mouth_width * 0.5
    radius = min(radius, size_x * 0.22, size_z * 0.22)
    if notch_side == "west":
        return [
            (x_min + radius, z_min), (x_max - radius, z_min),
            (x_max, z_min + radius), (x_max, z_max - radius),
            (x_max - radius, z_max), (x_min + radius, z_max),
            (x_min, z_max - radius), (x_min, mouth_high),
            (x_min + notch_depth, mouth_high), (x_min + notch_depth, mouth_low),
            (x_min, mouth_low), (x_min, z_min + radius),
        ]
    if notch_side == "east":
        return [
            (x_min + radius, z_min), (x_max - radius, z_min),
            (x_max, z_min + radius), (x_max, mouth_low),
            (x_max - notch_depth, mouth_low), (x_max - notch_depth, mouth_high),
            (x_max, mouth_high), (x_max, z_max - radius),
            (x_max - radius, z_max), (x_min + radius, z_max),
            (x_min, z_max - radius), (x_min, z_min + radius),
        ]
    if notch_side == "south":
        return [
            (x_min + radius, z_min), (x_max - radius, z_min),
            (x_max, z_min + radius), (x_max, z_max - radius),
            (x_max - radius, z_max), (mouth_high, z_max),
            (mouth_high, z_max - notch_depth), (mouth_low, z_max - notch_depth),
            (mouth_low, z_max), (x_min + radius, z_max),
            (x_min, z_max - radius), (x_min, z_min + radius),
        ]
    if notch_side == "north":
        return [
            (x_min + radius, z_min), (mouth_low, z_min),
            (mouth_low, z_min + notch_depth), (mouth_high, z_min + notch_depth),
            (mouth_high, z_min), (x_max - radius, z_min),
            (x_max, z_min + radius), (x_max, z_max - radius),
            (x_max - radius, z_max), (x_min + radius, z_max),
            (x_min, z_max - radius), (x_min, z_min + radius),
        ]
    raise ValueError(f"Unsupported notch side: {notch_side}")


def rounded_rect_outline(center, size, radius, corner_segments=5):
    center_x, center_z = center
    size_x, size_z = size
    x_min = center_x - size_x * 0.5
    x_max = center_x + size_x * 0.5
    z_min = center_z - size_z * 0.5
    z_max = center_z + size_z * 0.5
    radius = min(radius, size_x * 0.48, size_z * 0.48)
    corners = (
        (x_max - radius, z_min + radius, -90.0, 0.0),
        (x_max - radius, z_max - radius, 0.0, 90.0),
        (x_min + radius, z_max - radius, 90.0, 180.0),
        (x_min + radius, z_min + radius, 180.0, 270.0),
    )
    points = []
    for corner_x, corner_z, start_angle, end_angle in corners:
        for segment in range(corner_segments + 1):
            ratio = float(segment) / float(corner_segments)
            angle = math.radians(start_angle + (end_angle - start_angle) * ratio)
            points.append((corner_x + math.cos(angle) * radius, corner_z + math.sin(angle) * radius))
    return points


def smooth_closed_outline(points, iterations=2, corner_ratio=0.18):
    result = list(points)
    for _iteration in range(iterations):
        smoothed = []
        for index, start in enumerate(result):
            end = result[(index + 1) % len(result)]
            smoothed.append(
                (
                    start[0] * (1.0 - corner_ratio) + end[0] * corner_ratio,
                    start[1] * (1.0 - corner_ratio) + end[1] * corner_ratio,
                )
            )
            smoothed.append(
                (
                    start[0] * corner_ratio + end[0] * (1.0 - corner_ratio),
                    start[1] * corner_ratio + end[1] * (1.0 - corner_ratio),
                )
            )
        result = smoothed
    return result


def sample_closed_outline(points, target_count):
    if len(points) <= target_count:
        return list(points)
    return [points[int(float(index) * float(len(points)) / float(target_count))] for index in range(target_count)]


def add_tapered_polygon(name, top_points, bottom_points, center_y, height, material, collection, edge_bevel=0.08):
    count = len(top_points)
    if count != len(bottom_points):
        raise ValueError(f"Mismatched outline counts for {name}")
    bottom_y = center_y - height * 0.5
    top_y = center_y + height * 0.5
    vertices = [(x, -z, bottom_y) for x, z in bottom_points]
    vertices.extend((x, -z, top_y) for x, z in top_points)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    hero.apply_material(obj, material)
    hero.apply_bevel(obj, edge_bevel, 3)
    return obj


def add_sculpted_island_cliff(
    name,
    outline,
    top_y,
    depth,
    mats,
    collection,
    center=(0.0, 0.0),
    bottom_scale=0.68,
    ring_scales=None,
    tip_depth=1.16,
    tip_offset=(0.28, -0.18),
):
    outline = sample_closed_outline(outline, 32)
    center_x, center_z = center
    count = len(outline)
    if ring_scales is None:
        ring_scales = (1.00, 0.975, 0.865, 0.705, bottom_scale)
    if len(ring_scales) != 5:
        raise ValueError(f"Expected five cliff ring scales for {name}")
    ring_specs = (
        (0.00, ring_scales[0], 0.000, 0.00),
        (0.18, ring_scales[1], 0.018, 0.35),
        (0.43, ring_scales[2], 0.038, 1.10),
        (0.70, ring_scales[3], 0.060, 2.00),
        (0.94, ring_scales[4], 0.085, 2.85),
    )
    vertices = []
    for ring_index, (depth_ratio, base_scale, noise_strength, phase) in enumerate(ring_specs):
        for index, (x, z) in enumerate(outline):
            angle = math.atan2(z - center_z, x - center_x)
            wave = (
                math.sin(angle * 3.0 + phase) * 0.56
                + math.cos(angle * 5.0 - phase * 0.72) * 0.30
                + math.sin(angle * 7.0 + 0.45) * 0.14
            )
            ring_scale = base_scale * (1.0 + noise_strength * wave)
            lateral = depth_ratio * 0.40
            ring_x = center_x + (x - center_x) * ring_scale + math.cos(angle * 2.0 + phase) * lateral
            ring_z = center_z + (z - center_z) * ring_scale + math.sin(angle * 2.35 - phase) * lateral
            height_variation = 0.0 if ring_index == 0 else depth * (
                0.034 * math.sin(angle * 4.0 + phase)
                + 0.016 * math.cos(angle * 7.0 - phase * 0.65)
            )
            ring_y = top_y - depth * depth_ratio + height_variation
            vertices.append((ring_x, -ring_z, ring_y))

    bottom_tip_index = len(vertices)
    vertices.append((
        center_x + tip_offset[0],
        -(center_z + tip_offset[1]),
        top_y - depth * tip_depth,
    ))
    faces = []
    material_indices = []
    ring_count = len(ring_specs)
    for ring_index in range(ring_count - 1):
        for index in range(count):
            next_index = (index + 1) % count
            current = ring_index * count + index
            current_next = ring_index * count + next_index
            lower = (ring_index + 1) * count + index
            lower_next = (ring_index + 1) * count + next_index
            faces.append((current, current_next, lower_next, lower))
            angle = math.atan2(outline[index][1] - center_z, outline[index][0] - center_x)
            light_bias = math.sin(angle - 0.65) + math.cos(angle + 0.35) * 0.45
            facet_group = index // 2
            facet_bias = math.sin(facet_group * 1.71 + 0.35) * 0.74
            tone = 1
            if light_bias > 0.05:
                tone = 2
            if light_bias > 0.92:
                tone = 3
            if facet_bias < -0.35:
                tone = max(0, tone - 1)
            elif facet_bias > 0.48:
                tone = min(3, tone + 1)
            if ring_index >= 2 and (facet_group + ring_index) % 4 == 0:
                tone = max(0, tone - 1)
            material_indices.append(tone)
    for index in range(count):
        next_index = (index + 1) % count
        last_ring_start = (ring_count - 1) * count
        faces.append((bottom_tip_index, last_ring_start + next_index, last_ring_start + index))
        material_indices.append(0)

    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.data.materials.append(mats["cliff_deep"])
    obj.data.materials.append(mats["cliff"])
    obj.data.materials.append(mats["cliff_mid"])
    obj.data.materials.append(mats["cliff_light"])
    for polygon, material_index in zip(obj.data.polygons, material_indices):
        polygon.material_index = material_index
        polygon.use_smooth = False
    hero.apply_bevel(obj, 0.08, 2)
    return obj


def add_irregular_cliff_module(
    name,
    godot_pos,
    top_size,
    height,
    material,
    collection,
    yaw=0.0,
    variant=0,
    bottom_scale=(0.56, 0.48),
):
    patterns = (
        ((-0.50, -0.22), (-0.28, -0.50), (0.18, -0.46), (0.52, -0.14), (0.43, 0.34), (0.05, 0.50), (-0.46, 0.33)),
        ((-0.48, -0.36), (-0.08, -0.51), (0.42, -0.34), (0.50, 0.08), (0.24, 0.49), (-0.22, 0.43), (-0.53, 0.06)),
        ((-0.52, -0.10), (-0.34, -0.46), (0.12, -0.52), (0.48, -0.27), (0.46, 0.29), (0.02, 0.48), (-0.42, 0.37)),
    )
    pattern = patterns[variant % len(patterns)]
    width, depth = top_size
    shift_x = (0.08 if variant % 2 == 0 else -0.07) * width
    shift_y = (-0.06 if variant % 3 == 0 else 0.05) * depth
    top_points = [(px * width, py * depth) for px, py in pattern]
    bottom_points = [
        (px * width * bottom_scale[0] + shift_x, py * depth * bottom_scale[1] + shift_y)
        for px, py in pattern
    ]
    z0 = -height * 0.5
    z1 = height * 0.5
    vertices = [(px, py, z0) for px, py in bottom_points] + [(px, py, z1) for px, py in top_points]
    count = len(pattern)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = bpos(godot_pos)
    obj.rotation_euler[2] = yaw
    collection.objects.link(obj)
    hero.apply_material(obj, material)
    hero.apply_bevel(obj, min(0.20, min(width, depth) * 0.08), 2)
    return obj


def add_box(name, godot_pos, godot_size, material, collection, bevel=0.12):
    return hero.add_rounded_box(name, bpos(godot_pos), bsize(godot_size), material, collection, bevel)


def make_textured_material(name, texture_name, roughness):
    texture_path = TEXTURE_DIR / f"{texture_name}.png"
    normal_path = TEXTURE_DIR / f"{texture_name}_normal.png"
    roughness_path = TEXTURE_DIR / f"{texture_name}_roughness.png"
    for required_path in (texture_path, normal_path, roughness_path):
        if not required_path.exists():
            raise FileNotFoundError(f"Missing generated texture: {required_path}")
    image = bpy.data.images.load(str(texture_path), check_existing=True)
    material = hero.make_material(name, "#FFFFFF", roughness)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])

    roughness_image = bpy.data.images.load(str(roughness_path), check_existing=True)
    roughness_image.colorspace_settings.name = "Non-Color"
    roughness_texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    roughness_texture.image = roughness_image
    roughness_texture.interpolation = "Linear"
    material.node_tree.links.new(roughness_texture.outputs["Color"], bsdf.inputs["Roughness"])

    normal_image = bpy.data.images.load(str(normal_path), check_existing=True)
    normal_image.colorspace_settings.name = "Non-Color"
    normal_texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    normal_texture.image = normal_image
    normal_texture.interpolation = "Linear"
    normal_map = material.node_tree.nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.34
    material.node_tree.links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
    material.node_tree.links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    return material


def materials():
    return {
        "deck": hero.make_material("p24_sunset_deck_frame", "#8F3D24", 0.78),
        "deck_light": hero.make_material("p24_sunset_outer_deck_frame", "#AF572A", 0.80),
        "deck_panel_a": make_textured_material("p24_sunset_deck_panel_light", "deck_wood_light", 0.72),
        "deck_panel_b": make_textured_material("p24_sunset_deck_panel_mid", "deck_wood_mid", 0.78),
        "deck_panel_c": make_textured_material("p24_sunset_deck_panel_gold", "deck_wood_gold", 0.70),
        "side": hero.make_material("p24_sunset_warm_side", "#8E372C", 0.84),
        "cliff_deep": hero.make_material("v7_sunset_plum_cliff_deep", "#312448", 0.94),
        "cliff": hero.make_material("v2_sunset_plum_cliff", "#443064", 0.92),
        "cliff_mid": hero.make_material("v2_sunset_plum_cliff_mid", "#604688", 0.93),
        "cliff_light": hero.make_material("v2_sunset_plum_cliff_light", "#755DA2", 0.90),
        "bridge": make_textured_material("p24_sunset_bridge_wood", "bridge_wood_mid", 0.84),
        "bridge_alt": make_textured_material("p24_sunset_bridge_wood_alt", "bridge_wood_light", 0.80),
        "seam": hero.make_material("p24_sunset_floor_seam", "#AC5846", 0.94),
        "rim": hero.make_material("p24_sunset_edge_rim", "#E39A36", 0.66),
        "fastener": hero.make_material("v2_sunset_bridge_fastener", "#493455", 0.68, 0.10),
        "post": hero.make_material("v10_sunset_edge_post", "#713B4B", 0.72, 0.08),
        "cyan": hero.make_material("v2_sunset_cyan_marker", "#45C9EE", 0.32, emission_hex="#45C9EE", emission_strength=1.45),
        "shadow": hero.make_material("v2_sunset_bridge_shadow", "#281C4C", 0.96),
        "red": hero.make_material("p24_prop_red", "#C83243", 0.64),
        "red_light": hero.make_material("p24_prop_red_light", "#F05E57", 0.58),
        "red_dark": hero.make_material("p24_prop_red_dark", "#69243E", 0.80),
        "orange": hero.make_material("p24_prop_orange", "#D45A2D", 0.68),
        "orange_light": hero.make_material("p24_prop_orange_light", "#F39147", 0.60),
        "orange_dark": hero.make_material("p24_prop_orange_dark", "#71303A", 0.82),
        "gold": hero.make_material("v3_prop_gold", "#D99D28", 0.72),
        "gold_light": hero.make_material("v3_prop_gold_light", "#F2C04B", 0.64),
        "gold_dark": hero.make_material("v3_prop_gold_dark", "#80502C", 0.82),
        "wood": hero.make_material("v3_prop_wood", "#A75C2D", 0.82),
        "wood_light": hero.make_material("v3_prop_wood_light", "#D18A43", 0.76),
        "wood_dark": hero.make_material("v3_prop_wood_dark", "#613B35", 0.88),
        "green": hero.make_material("v3_landmark_green", "#588F43", 0.86),
        "green_light": hero.make_material("v3_landmark_green_light", "#84B34D", 0.82),
        "green_dark": hero.make_material("v3_landmark_green_dark", "#35583B", 0.90),
        "blue": hero.make_material("v3_landmark_blue", "#2878B8", 0.76),
        "blue_light": hero.make_material("v3_landmark_blue_light", "#4FA9D5", 0.70),
        "tire": hero.make_material("v3_landmark_tire", "#29233D", 0.88),
        "cream": hero.make_material("v3_landmark_cream", "#F1D9AE", 0.82),
        "cloud_cream": hero.make_material("v3_cloud_cream", "#F3C6B6", 0.98),
        "cloud_pink": hero.make_material("v3_cloud_pink", "#D995B4", 0.98),
        "cloud_violet": hero.make_material("v3_cloud_violet", "#8E83C8", 0.98),
        "distance_cliff": hero.make_material("v3_distance_cliff", "#4A3D75", 0.96),
        "distance_top": hero.make_material("v3_distance_top", "#C96E33", 0.90),
        "balloon": hero.make_material("v3_balloon_purple", "#7047A4", 0.72),
        "balloon_gold": hero.make_material("v3_balloon_gold", "#E7A73A", 0.68),
    }


def central_outline():
    return [
        (-23.6, -18.0), (-2.0, -18.0), (-2.0, -16.55),
        (10.0, -16.55), (10.0, -18.0), (23.6, -18.0), (25.6, -16.0),
        (25.6, -14.5), (28.0, -14.5), (30.0, -12.5),
        (30.0, -2.2), (28.60, -2.2), (28.60, 6.2), (30.0, 6.2),
        (30.0, 6.5), (28.0, 8.5), (26.0, 8.5),
        (26.0, 15.8), (23.8, 18.0), (12.8, 18.0),
        (12.8, 16.55), (1.2, 16.55), (1.2, 18.0), (-10.5, 18.0),
        (-12.5, 19.0), (-27.0, 19.0), (-29.0, 17.0),
        (-29.0, 7.2), (-28.0, 7.2), (-28.0, 6.7),
        (-26.60, 6.7), (-26.60, -2.7), (-28.0, -2.7), (-28.0, -3.2),
        (-29.0, -3.2), (-27.0, -4.2), (-26.0, -4.2),
        (-26.0, -16.0), (-23.6, -18.0),
    ]


def central_cliff_outline():
    """Continuous underbody; bridge sockets belong only to the deck shell."""
    return [
        (-23.6, -18.0), (23.6, -18.0), (25.6, -16.0),
        (25.6, -14.5), (28.0, -14.5), (30.0, -12.5),
        (30.0, 6.5), (28.0, 8.5), (26.0, 8.5),
        (26.0, 15.8), (23.8, 18.0), (-10.5, 18.0),
        (-12.5, 19.0), (-27.0, 19.0), (-29.0, 17.0),
        (-29.0, -3.2), (-27.0, -4.2), (-26.0, -4.2),
        (-26.0, -16.0),
    ]


def add_central_surface_panels(collection, mats):
    panel_materials = (mats["deck_panel_a"], mats["deck_panel_b"], mats["deck_panel_c"])
    x_positions = (-21.75, -13.05, -4.35, 4.35, 13.05, 21.75)
    z_positions = (-12.0, -4.0, 4.0, 12.0)
    for row_index, z in enumerate(z_positions):
        for column_index, x in enumerate(x_positions):
            panel_index = row_index * len(x_positions) + column_index
            add_box(
                f"V10CentralFloorTile_{panel_index}",
                (x, 0.326, z),
                (8.64, 0.075, 7.94),
                panel_materials[(row_index + column_index * 2) % len(panel_materials)],
                collection,
                0.065,
            )
    for index, (x, z, sx, sz) in enumerate((
        (28.05, -10.2, 2.72, 6.70),
        (28.05, -3.0, 2.72, 6.70),
        (28.05, 4.2, 2.72, 6.70),
        (-27.45, 2.8, 2.30, 6.95),
        (-27.45, 10.3, 2.30, 6.95),
        (-27.45, 16.1, 2.30, 4.10),
    )):
        add_box(
            f"V10CentralLobeTile_{index}",
            (x, 0.326, z),
            (sx, 0.075, sz),
            panel_materials[(index + 1) % len(panel_materials)],
            collection,
            0.065,
        )


def add_central_platform(collection, mats):
    outline = scale_outline(smooth_closed_outline(central_outline()), 1.018)
    cliff_outline = scale_outline(smooth_closed_outline(central_cliff_outline()), 1.018)
    add_sculpted_island_cliff(
        "V2CentralCliff",
        scale_outline(cliff_outline, 0.992),
        -1.42,
        9.70,
        mats,
        collection,
        (0.0, 0.0),
        0.32,
        (1.00, 0.970, 0.840, 0.640, 0.400),
        1.20,
        (0.42, 0.24),
    )
    add_tapered_polygon(
        "V7CentralCliffShoulder",
        scale_outline(cliff_outline, 0.987),
        scale_outline(cliff_outline, 0.920),
        -1.62,
        0.30,
        mats["cliff_mid"],
        collection,
        0.08,
    )
    add_tapered_polygon("V2CentralWarmBand", scale_outline(outline, 1.020), scale_outline(outline, 0.990), -1.12, 1.20, mats["side"], collection, 0.14)
    add_tapered_polygon("V2CentralTop", outline, scale_outline(outline, 0.990), -0.27, 1.02, mats["deck"], collection, 0.12)
    add_tapered_polygon("V2CentralTopInset", scale_outline(outline, 0.958), scale_outline(outline, 0.958), 0.270, 0.04, mats["deck_panel_a"], collection, 0.025)
    add_central_surface_panels(collection, mats)

    rim_outline = scale_outline(outline, 0.968)
    for index, start in enumerate(rim_outline):
        end = rim_outline[(index + 1) % len(rim_outline)]
        delta_x = end[0] - start[0]
        delta_z = end[1] - start[1]
        length = math.hypot(delta_x, delta_z)
        if length < 0.05:
            continue
        midpoint = ((start[0] + end[0]) * 0.5, (start[1] + end[1]) * 0.5)
        yaw = math.atan2(-delta_z, delta_x)
        hero.add_rounded_box(
            f"V2CentralEdgeRim_{index}",
            (midpoint[0], -midpoint[1], 0.285),
            (length + 0.08, 0.17, 0.085),
            mats["rim"],
            collection,
            0.04,
            (0.0, 0.0, yaw),
        )

    for index, x in enumerate((-17.40, -8.70, 0.0, 8.70, 17.40)):
        add_box(f"V4CentralSeamX_{index}", (x, 0.302, 0.0), (0.07, 0.020, 31.10), mats["seam"], collection, 0.014)
    for index, z in enumerate((-7.80, 0.0, 7.80)):
        add_box(f"V4CentralSeamZ_{index}", (0.0, 0.304, z), (51.60, 0.020, 0.07), mats["seam"], collection, 0.014)

    edge_posts = [
        (-23.0, -16.5), (22.5, -16.5), (28.2, -11.5),
        (23.5, 16.2), (-9.5, 17.2), (-26.8, 16.5),
    ]
    for index, (x, z) in enumerate(edge_posts):
        add_box(f"V2CentralEdgePost_{index}", (x, 0.55, z), (0.72, 0.82, 0.72), mats["post"], collection, 0.18)
        add_box(f"V2CentralEdgeGem_{index}", (x, 1.00, z), (0.34, 0.12, 0.34), mats["cyan"], collection, 0.08)
    add_vertical_bridge_landing("V6CentralNorthLanding", 4.0, -18.02, 12.0, 1.0, collection, mats, 1.38, -17.60)
    add_vertical_bridge_landing("V6CentralSouthLanding", 7.0, 18.02, 11.6, -1.0, collection, mats, 1.38, 17.50)
    add_horizontal_bridge_landing("V6CentralEastLanding", 30.02, 2.0, 8.4, -1.0, collection, mats, 1.38, 29.50)
    add_horizontal_bridge_landing("V6CentralWestLanding", -28.02, 2.0, 9.4, 1.0, collection, mats, 1.38, -28.50)


def add_bridge_module(prefix, center, length, width, span_axis, collection, mats):
    center_x, center_z = center
    if span_axis == "x":
        support_positions = ((center_x, center_z - width * 0.39), (center_x, center_z + width * 0.39))
        support_size = (length + 0.4, 0.58, 0.72)
    else:
        support_positions = ((center_x - width * 0.39, center_z), (center_x + width * 0.39, center_z))
        support_size = (0.72, 0.58, length + 0.4)
    add_box(f"{prefix}Shadow", (support_positions[0][0], -0.72, support_positions[0][1]), support_size, mats["shadow"], collection, 0.24)
    add_box(f"{prefix}SupportB", (support_positions[1][0], -0.72, support_positions[1][1]), support_size, mats["shadow"], collection, 0.24)

    plank_count = 6
    step = length / plank_count
    for index in range(6):
        offset = -length * 0.5 + step * (float(index) + 0.5)
        material = mats["bridge_alt"] if index % 3 == 1 else mats["bridge"]
        if span_axis == "x":
            plank_pos = (center_x + offset, -0.17, center_z)
            plank_size = (step * 0.88, 0.70, width * 0.94)
            fastener_positions = ((center_x + offset, center_z - width * 0.39), (center_x + offset, center_z + width * 0.39))
        else:
            plank_pos = (center_x, -0.17, center_z + offset)
            plank_size = (width * 0.94, 0.70, step * 0.88)
            fastener_positions = ((center_x - width * 0.39, center_z + offset), (center_x + width * 0.39, center_z + offset))
        add_box(f"{prefix}Plank_{index}", plank_pos, plank_size, material, collection, 0.16)
        for side_index, fastener_pos in enumerate(fastener_positions):
            hero.add_cylinder(
                f"{prefix}Fastener_{index}_{side_index}",
                bpos((fastener_pos[0], 0.225, fastener_pos[1])),
                0.11,
                0.065,
                mats["fastener"],
                collection,
                bevel=0.025,
                vertices=18,
            )
    corner_positions = (
        (center_x - length * 0.5, center_z - width * 0.5),
        (center_x - length * 0.5, center_z + width * 0.5),
        (center_x + length * 0.5, center_z - width * 0.5),
        (center_x + length * 0.5, center_z + width * 0.5),
    ) if span_axis == "x" else (
        (center_x - width * 0.5, center_z - length * 0.5),
        (center_x + width * 0.5, center_z - length * 0.5),
        (center_x - width * 0.5, center_z + length * 0.5),
        (center_x + width * 0.5, center_z + length * 0.5),
    )
    for index, (x, z) in enumerate(corner_positions):
        add_box(f"{prefix}Post_{index}", (x, 0.52, z), (0.68, 1.02, 0.68), mats["post"], collection, 0.18)
        add_box(f"{prefix}Gem_{index}", (x, 1.08, z), (0.34, 0.12, 0.34), mats["cyan"], collection, 0.08)

    if span_axis == "x":
        for end_index, end_x in enumerate((center_x - length * 0.5, center_x + length * 0.5)):
            add_box(
                f"{prefix}MouthBeam_{end_index}",
                (end_x, -0.24, center_z),
                (0.88, 1.20, width * 0.92),
                mats["gold_dark"],
                collection,
                0.16,
            )
        for rail_index, rail_z in enumerate((center_z - width * 0.49, center_z + width * 0.49)):
            add_box(f"{prefix}SideRail_{rail_index}", (center_x, 0.72, rail_z), (length * 0.72, 0.18, 0.18), mats["cream"], collection, 0.07)
    else:
        for end_index, end_z in enumerate((center_z - length * 0.5, center_z + length * 0.5)):
            add_box(
                f"{prefix}MouthBeam_{end_index}",
                (center_x, -0.24, end_z),
                (width * 0.92, 1.20, 0.88),
                mats["gold_dark"],
                collection,
                0.16,
            )
        for rail_index, rail_x in enumerate((center_x - width * 0.49, center_x + width * 0.49)):
            add_box(f"{prefix}SideRail_{rail_index}", (rail_x, 0.72, center_z), (0.18, 0.18, length * 0.72), mats["cream"], collection, 0.07)


def add_vertical_bridge_landing(prefix, mouth_center_x, mouth_z, mouth_width, inward_direction, collection, mats, depth=1.15, bridge_end_z=None):
    socket_center_z = mouth_z + inward_direction * depth * 0.5
    inner_z = mouth_z + inward_direction * depth
    deck_outer_z = mouth_z if bridge_end_z is None else bridge_end_z
    deck_center_z = (deck_outer_z + inner_z) * 0.5
    deck_length = abs(inner_z - deck_outer_z)
    add_box(f"{prefix}SocketBed", (mouth_center_x, -0.42, socket_center_z), (mouth_width - 0.38, 0.22, depth + 0.26), mats["shadow"], collection, 0.10)
    add_vertical_socket_deck(prefix, mouth_center_x, deck_center_z, mouth_width, deck_length, collection, mats)
    for side_index, side_x in enumerate((mouth_center_x - mouth_width * 0.5, mouth_center_x + mouth_width * 0.5)):
        add_box(f"{prefix}SocketSideBeam_{side_index}", (side_x, -0.12, socket_center_z), (0.48, 0.78, depth + 0.44), mats["gold_dark"], collection, 0.13)
    add_box(f"{prefix}SocketBackBeam", (mouth_center_x, -0.18, inner_z), (mouth_width + 0.12, 0.64, 0.52), mats["wood_dark"], collection, 0.13)


def add_horizontal_bridge_landing(prefix, mouth_x, mouth_center_z, mouth_width, inward_direction, collection, mats, depth=1.15, bridge_end_x=None):
    socket_center_x = mouth_x + inward_direction * depth * 0.5
    inner_x = mouth_x + inward_direction * depth
    deck_outer_x = mouth_x if bridge_end_x is None else bridge_end_x
    deck_center_x = (deck_outer_x + inner_x) * 0.5
    deck_length = abs(inner_x - deck_outer_x)
    add_box(f"{prefix}SocketBed", (socket_center_x, -0.42, mouth_center_z), (depth + 0.26, 0.22, mouth_width - 0.38), mats["shadow"], collection, 0.10)
    add_horizontal_socket_deck(prefix, deck_center_x, mouth_center_z, mouth_width, deck_length, collection, mats)
    for side_index, side_z in enumerate((mouth_center_z - mouth_width * 0.5, mouth_center_z + mouth_width * 0.5)):
        add_box(f"{prefix}SocketSideBeam_{side_index}", (socket_center_x, -0.12, side_z), (depth + 0.44, 0.78, 0.48), mats["gold_dark"], collection, 0.13)
    add_box(f"{prefix}SocketBackBeam", (inner_x, -0.18, mouth_center_z), (0.52, 0.64, mouth_width + 0.12), mats["wood_dark"], collection, 0.13)


def add_vertical_socket_deck(prefix, center_x, center_z, width, length, collection, mats):
    if length < 0.16:
        return
    plank_count = 2 if length >= 1.0 else 1
    step = length / plank_count
    for index in range(plank_count):
        offset = -length * 0.5 + step * (float(index) + 0.5)
        material = mats["bridge_alt"] if index % 2 else mats["bridge"]
        add_box(
            f"{prefix}SocketDeck_{index}",
            (center_x, -0.17, center_z + offset),
            (width - 0.36, 0.70, step * 0.88),
            material,
            collection,
            0.12,
        )


def add_horizontal_socket_deck(prefix, center_x, center_z, width, length, collection, mats):
    if length < 0.16:
        return
    plank_count = 2 if length >= 1.0 else 1
    step = length / plank_count
    for index in range(plank_count):
        offset = -length * 0.5 + step * (float(index) + 0.5)
        material = mats["bridge_alt"] if index % 2 else mats["bridge"]
        add_box(
            f"{prefix}SocketDeck_{index}",
            (center_x + offset, -0.17, center_z),
            (step * 0.88, 0.70, width - 0.36),
            material,
            collection,
            0.12,
        )


def add_all_bridges(collection, mats):
    add_bridge_module("V2EastBridge", (32.75, 2.0), 6.5, 8.0, "x", collection, mats)
    add_bridge_module("V3WestBridge", (-32.10, 2.0), 7.2, 9.0, "x", collection, mats)
    add_bridge_module("V3NorthBridge", (4.0, -20.2), 5.2, 11.0, "z", collection, mats)
    add_bridge_module("V3SouthBridge", (7.0, 20.0), 5.0, 11.0, "z", collection, mats)


def add_bridge_socket(name, center, size, notch, collection, mats):
    x, z = center
    sx, sz = size
    if notch["side"] == "west":
        outer_x = x - sx * 0.5
        inner_x = outer_x + notch["depth"]
        socket_center_x = (outer_x + inner_x) * 0.5
        socket_length = abs(inner_x - outer_x)
        mouth_center = notch["mouth_center"]
        mouth_width = notch["mouth_width"]
        add_box(f"{name}V5SocketBed", (socket_center_x, -0.46, mouth_center), (socket_length + 0.35, 0.26, mouth_width - 0.42), mats["shadow"], collection, 0.10)
        deck_outer_x = notch.get("bridge_end", outer_x)
        deck_center_x = (deck_outer_x + inner_x) * 0.5
        add_horizontal_socket_deck(f"{name}V5", deck_center_x, mouth_center, mouth_width, abs(inner_x - deck_outer_x), collection, mats)
        for side_index, side_z in enumerate((mouth_center - mouth_width * 0.5, mouth_center + mouth_width * 0.5)):
            add_box(f"{name}V5SocketSideBeam_{side_index}", (socket_center_x, -0.12, side_z), (socket_length + 0.52, 0.78, 0.48), mats["gold_dark"], collection, 0.13)
        add_box(f"{name}V5SocketBackBeam", (inner_x, -0.18, mouth_center), (0.52, 0.64, mouth_width + 0.18), mats["wood_dark"], collection, 0.13)
    else:
        if notch["side"] == "south":
            outer_z = z + sz * 0.5
            inner_z = outer_z - notch["depth"]
        elif notch["side"] == "north":
            outer_z = z - sz * 0.5
            inner_z = outer_z + notch["depth"]
        elif notch["side"] == "east":
            outer_z = None
        else:
            raise ValueError(f"Unsupported notch side: {notch['side']}")
        if outer_z is not None:
            socket_center_z = (outer_z + inner_z) * 0.5
            socket_length = abs(inner_z - outer_z)
            mouth_center = notch["mouth_center"]
            mouth_width = notch["mouth_width"]
            add_box(f"{name}V5SocketBed", (mouth_center, -0.46, socket_center_z), (mouth_width - 0.42, 0.26, socket_length + 0.35), mats["shadow"], collection, 0.10)
            deck_outer_z = notch.get("bridge_end", outer_z)
            deck_center_z = (deck_outer_z + inner_z) * 0.5
            add_vertical_socket_deck(f"{name}V5", mouth_center, deck_center_z, mouth_width, abs(inner_z - deck_outer_z), collection, mats)
            for side_index, side_x in enumerate((mouth_center - mouth_width * 0.5, mouth_center + mouth_width * 0.5)):
                add_box(f"{name}V5SocketSideBeam_{side_index}", (side_x, -0.12, socket_center_z), (0.48, 0.78, socket_length + 0.52), mats["gold_dark"], collection, 0.13)
            add_box(f"{name}V5SocketBackBeam", (mouth_center, -0.18, inner_z), (mouth_width + 0.18, 0.64, 0.52), mats["wood_dark"], collection, 0.13)
            return
        outer_x = x + sx * 0.5
        inner_x = outer_x - notch["depth"]
        socket_center_x = (outer_x + inner_x) * 0.5
        socket_length = abs(inner_x - outer_x)
        mouth_center = notch["mouth_center"]
        mouth_width = notch["mouth_width"]
        add_box(f"{name}V5SocketBed", (socket_center_x, -0.46, mouth_center), (socket_length + 0.35, 0.26, mouth_width - 0.42), mats["shadow"], collection, 0.10)
        deck_outer_x = notch.get("bridge_end", outer_x)
        deck_center_x = (deck_outer_x + inner_x) * 0.5
        add_horizontal_socket_deck(f"{name}V5", deck_center_x, mouth_center, mouth_width, abs(inner_x - deck_outer_x), collection, mats)
        for side_index, side_z in enumerate((mouth_center - mouth_width * 0.5, mouth_center + mouth_width * 0.5)):
            add_box(f"{name}V5SocketSideBeam_{side_index}", (socket_center_x, -0.12, side_z), (socket_length + 0.52, 0.78, 0.48), mats["gold_dark"], collection, 0.13)
        add_box(f"{name}V5SocketBackBeam", (inner_x, -0.18, mouth_center), (0.52, 0.64, mouth_width + 0.18), mats["wood_dark"], collection, 0.13)


def add_side_island(
    name,
    center,
    size,
    panel_mat,
    collection,
    mats,
    notch=None,
    radius_ratio=0.22,
    cliff_depth=8.55,
    cliff_scales=(1.00, 0.965, 0.800, 0.550, 0.350),
    cliff_tip=(0.28, -0.18),
):
    x, z = center
    sx, sz = size
    radius = min(sx, sz) * radius_ratio
    island_outline = None
    if notch:
        island_outline = smooth_closed_outline(
            notched_rect_outline(
                center,
                size,
                radius,
                notch["side"],
                notch["mouth_center"],
                notch["mouth_width"],
                notch["depth"],
            ),
            iterations=2,
            corner_ratio=0.14,
        )
    else:
        island_outline = rounded_rect_outline(center, size, radius, 6)

    add_sculpted_island_cliff(
        f"{name}Cliff",
        scale_outline_about(island_outline, center, 0.965),
        -1.44,
        cliff_depth,
        mats,
        collection,
        center,
        cliff_scales[-1],
        cliff_scales,
        1.20,
        cliff_tip,
    )
    add_tapered_polygon(
        f"{name}CliffMidShelf",
        scale_outline_about(island_outline, center, 0.970),
        scale_outline_about(island_outline, center, 0.895),
        -1.64,
        0.30,
        mats["cliff_mid"],
        collection,
        0.08,
    )
    add_tapered_polygon(
        f"{name}WarmBand",
        scale_outline_about(island_outline, center, 1.012),
        scale_outline_about(island_outline, center, 0.958),
        -1.10,
        1.20,
        mats["side"],
        collection,
        0.13,
    )
    add_tapered_polygon(
        f"{name}Top",
        island_outline,
        scale_outline_about(island_outline, center, 0.982),
        -0.27,
        1.02,
        mats["deck_light"],
        collection,
        0.12,
    )
    inset_outline = scale_outline_about(island_outline, center, 0.84)
    add_tapered_polygon(f"{name}TopInset", inset_outline, inset_outline, 0.270, 0.045, panel_mat, collection, 0.04)
    side_panel_materials = (mats["deck_panel_a"], mats["deck_panel_b"], mats["deck_panel_c"])
    for row_index, z_direction in enumerate((-1.0, 1.0)):
        for column_index, x_direction in enumerate((-1.0, 1.0)):
            panel_index = row_index * 2 + column_index
            deep_notch = notch and notch["depth"] > sx * 0.20
            if deep_notch and ((notch["side"] == "west" and x_direction < 0.0) or (notch["side"] == "east" and x_direction > 0.0)):
                continue
            add_box(
                f"{name}V4TopPanel_{panel_index}",
                (x + x_direction * sx * 0.205, 0.296, z + z_direction * sz * 0.198),
                (sx * 0.405, 0.036, sz * 0.390),
                side_panel_materials[(panel_index + len(name)) % len(side_panel_materials)],
                collection,
                radius * 0.18,
            )
    add_box(f"{name}V4TopSeamX", (x, 0.320, z), (0.055, 0.018, sz * 0.77), mats["seam"], collection, 0.010)
    if notch:
        if notch["side"] in ["east", "west"]:
            outer_edge_x = x - sx * 0.40 if notch["side"] == "east" else x + sx * 0.40
            inner_x = x + sx * 0.5 - notch["depth"] if notch["side"] == "east" else x - sx * 0.5 + notch["depth"]
            seam_center_x = (outer_edge_x + inner_x) * 0.5
            add_box(f"{name}V4TopSeamZ", (seam_center_x, 0.322, z), (abs(outer_edge_x - inner_x), 0.018, 0.055), mats["seam"], collection, 0.010)
        else:
            outer_edge_z = z + sz * 0.40 if notch["side"] == "south" else z - sz * 0.40
            inner_z = z + sz * 0.5 - notch["depth"] if notch["side"] == "south" else z - sz * 0.5 + notch["depth"]
            seam_center_z = (outer_edge_z + inner_z) * 0.5
            add_box(f"{name}V4TopSeamZ", (x, 0.322, seam_center_z), (sx * 0.80, 0.018, abs(outer_edge_z - inner_z)), mats["seam"], collection, 0.010)
    else:
        add_box(f"{name}V4TopSeamZ", (x, 0.322, z), (sx * 0.80, 0.018, 0.055), mats["seam"], collection, 0.010)
    if notch:
        add_bridge_socket(name, center, size, notch, collection, mats)

    post_positions = (
        (x - sx * 0.40, z - sz * 0.38),
        (x + sx * 0.40, z - sz * 0.38),
        (x - sx * 0.40, z + sz * 0.38),
        (x + sx * 0.40, z + sz * 0.38),
    )
    for index, (post_x, post_z) in enumerate(post_positions):
        add_box(f"{name}EdgePost_{index}", (post_x, 0.48, post_z), (0.62, 0.76, 0.62), mats["post"], collection, 0.17)
        add_box(f"{name}EdgeGem_{index}", (post_x, 0.90, post_z), (0.30, 0.11, 0.30), mats["cyan"], collection, 0.07)


def add_outer_islands(collection, mats):
    add_side_island(
        "V3NorthIsland",
        (4.0, -30.0),
        (22.0, 15.0),
        mats["deck_panel_a"],
        collection,
        mats,
        {"side": "south", "mouth_center": 4.0, "mouth_width": 11.4, "depth": 0.85, "bridge_end": -22.80},
        radius_ratio=0.29,
        cliff_depth=9.35,
        cliff_scales=(1.00, 0.895, 0.670, 0.445, 0.270),
        cliff_tip=(-0.42, 0.18),
    )
    add_side_island(
        "V3EastIsland",
        (41.75, 3.0),
        (12.5, 18.0),
        mats["deck_panel_b"],
        collection,
        mats,
        {"side": "west", "mouth_center": 2.0, "mouth_width": 8.8, "depth": 0.65, "bridge_end": 36.00},
        radius_ratio=0.24,
        cliff_depth=9.10,
        cliff_scales=(1.00, 0.920, 0.715, 0.490, 0.305),
        cliff_tip=(0.34, -0.30),
    )
    add_side_island(
        "V3SouthIsland",
        (9.0, 30.0),
        (24.0, 16.0),
        mats["deck_panel_a"],
        collection,
        mats,
        {"side": "north", "mouth_center": 7.0, "mouth_width": 11.4, "depth": 0.85, "bridge_end": 22.50},
        radius_ratio=0.31,
        cliff_depth=9.55,
        cliff_scales=(1.00, 0.885, 0.645, 0.420, 0.245),
        cliff_tip=(-0.28, -0.42),
    )
    add_side_island(
        "V3WestIsland",
        (-41.55, 2.0),
        (12.9, 20.0),
        mats["deck_panel_b"],
        collection,
        mats,
        {"side": "east", "mouth_center": 2.0, "mouth_width": 9.8, "depth": 0.65, "bridge_end": -35.70},
        radius_ratio=0.21,
        cliff_depth=9.20,
        cliff_scales=(1.00, 0.910, 0.695, 0.465, 0.285),
        cliff_tip=(0.40, 0.28),
    )


def add_windmill(collection, mats):
    x, z = (7.0, -31.0)
    hero.add_cylinder("V4NorthWindmillBase", bpos((x, 0.42, z)), 2.58, 0.76, mats["blue"], collection, bevel=0.20, vertices=32)
    hero.add_cylinder("V4NorthWindmillBaseTrim", bpos((x, 0.82, z)), 2.24, 0.20, mats["blue_light"], collection, bevel=0.08, vertices=32)
    hero.add_cone("V3NorthWindmillTower", bpos((x, 3.05, z)), 2.02, 1.28, 5.0, mats["cream"], collection)
    hero.add_torus("V9NorthWindmillLowerBand", bpos((x, 1.02, z)), 1.90, 0.12, mats["blue_light"], collection)
    hero.add_torus("V9NorthWindmillUpperBand", bpos((x, 4.82, z)), 1.38, 0.10, mats["wood_light"], collection)
    add_box("V3NorthWindmillDoor", (x, 1.58, z + 1.88), (1.18, 1.92, 0.20), mats["wood_dark"], collection, 0.16)
    add_box("V3NorthWindmillSill", (x, 2.66, z + 1.91), (1.62, 0.20, 0.22), mats["gold_dark"], collection, 0.07)
    hero.add_cone("V3NorthWindmillRoof", bpos((x, 5.86, z)), 1.92, 0.20, 1.62, mats["red_dark"], collection)
    hero.add_cylinder(
        "V8NorthWindmillWindow",
        bpos((x, 3.42, z + 1.58)),
        0.58,
        0.20,
        mats["blue_light"],
        collection,
        rotation=(math.pi / 2.0, 0.0, 0.0),
        bevel=0.08,
        vertices=28,
    )
    blade_center = bpos((x, 4.60, z + 1.62))
    for index, angle in enumerate((45.0, 135.0)):
        hero.add_rounded_box(
            f"V3NorthWindmillBlade_{index}",
            blade_center,
            (6.35, 0.28, 0.62),
            mats["orange_light"],
            collection,
            0.15,
            (0.0, math.radians(angle), 0.0),
        )
        angle_radians = math.radians(angle)
        for tip_index, direction in enumerate((-1.0, 1.0)):
            tip_x = blade_center[0] + math.cos(angle_radians) * 3.12 * direction
            tip_z = blade_center[2] - math.sin(angle_radians) * 3.12 * direction
            hero.add_rounded_box(
                f"V4NorthWindmillBladeTip_{index}_{tip_index}",
                (tip_x, blade_center[1], tip_z),
                (0.96, 0.34, 0.82),
                mats["gold_light"],
                collection,
                0.16,
                (0.0, math.radians(angle), 0.0),
            )
    hero.add_cylinder(
        "V3NorthWindmillHub",
        blade_center,
        0.60,
        0.58,
        mats["gold_dark"],
        collection,
        rotation=(math.pi / 2.0, 0.0, 0.0),
        bevel=0.10,
        vertices=24,
    )


def add_tree(name, godot_pos, scale, collection, mats):
    x, _y, z = godot_pos
    hero.add_cylinder(f"{name}Trunk", bpos((x, 1.25 * scale, z)), 0.32 * scale, 2.5 * scale, mats["wood_dark"], collection, bevel=0.08, vertices=18)
    hero.add_cone(f"{name}FoliageLower", bpos((x, 3.0 * scale, z)), 1.65 * scale, 0.48 * scale, 3.0 * scale, mats["green"], collection)
    hero.add_cone(f"{name}FoliageUpper", bpos((x, 4.35 * scale, z)), 1.25 * scale, 0.18 * scale, 2.5 * scale, mats["green_light"], collection)
    hero.add_cone(f"{name}V4FoliageMiddle", bpos((x, 3.72 * scale, z)), 1.42 * scale, 0.30 * scale, 2.55 * scale, mats["green_dark"], collection)
    hero.add_sphere(f"{name}Shrub", bpos((x + 1.25 * scale, 0.62 * scale, z + 0.45 * scale)), bsize((0.80 * scale, 0.62 * scale, 0.80 * scale)), mats["green_dark"], collection, 20, 10)


def add_toy_duck(name, godot_pos, scale, collection, mats):
    x, y, z = godot_pos
    hero.add_sphere(
        f"{name}Body",
        bpos((x, y + 0.58 * scale, z)),
        bsize((1.20 * scale, 0.78 * scale, 1.48 * scale)),
        mats["gold_light"],
        collection,
        24,
        14,
    )
    hero.add_sphere(
        f"{name}Head",
        bpos((x, y + 1.18 * scale, z + 0.38 * scale)),
        bsize((0.78 * scale, 0.78 * scale, 0.78 * scale)),
        mats["gold_light"],
        collection,
        24,
        14,
    )
    add_box(
        f"{name}Beak",
        (x, y + 1.14 * scale, z + 0.84 * scale),
        (0.54 * scale, 0.22 * scale, 0.36 * scale),
        mats["orange"],
        collection,
        0.10 * scale,
    )
    for side_index, side in enumerate((-1.0, 1.0)):
        hero.add_sphere(
            f"{name}Wing_{side_index}",
            bpos((x + side * 0.52 * scale, y + 0.68 * scale, z - 0.05 * scale)),
            bsize((0.28 * scale, 0.46 * scale, 0.74 * scale)),
            mats["gold"],
            collection,
            18,
            10,
        )
        hero.add_sphere(
            f"{name}Eye_{side_index}",
            bpos((x + side * 0.19 * scale, y + 1.32 * scale, z + 0.70 * scale)),
            bsize((0.10 * scale, 0.12 * scale, 0.10 * scale)),
            mats["tire"],
            collection,
            14,
            8,
        )


def add_barrel(name, godot_pos, body_mat, collection, mats):
    hero.add_cylinder(name, bpos(godot_pos), 0.95, 1.65, body_mat, collection, bevel=0.16, vertices=28)
    hero.add_cylinder(
        f"{name}V5BottomFoot",
        bpos((godot_pos[0], godot_pos[1] - 0.82, godot_pos[2])),
        0.84,
        0.12,
        mats["wood_dark"],
        collection,
        bevel=0.04,
        vertices=28,
    )
    hero.add_cylinder(
        f"{name}V4TopLid",
        bpos((godot_pos[0], godot_pos[1] + 0.86, godot_pos[2])),
        0.82,
        0.14,
        mats["wood_light"],
        collection,
        bevel=0.05,
        vertices=28,
    )
    hero.add_cylinder(
        f"{name}V4TopPlug",
        bpos((godot_pos[0] + 0.25, godot_pos[1] + 0.96, godot_pos[2] - 0.08)),
        0.10,
        0.10,
        mats["gold_light"],
        collection,
        bevel=0.03,
        vertices=16,
    )
    hero.add_torus(
        f"{name}V5LidInset",
        bpos((godot_pos[0], godot_pos[1] + 0.95, godot_pos[2])),
        0.54,
        0.055,
        mats["wood_dark"],
        collection,
    )
    for band_index, y_offset in enumerate((-0.52, 0.52)):
        hero.add_torus(
            f"{name}Band_{band_index}",
            bpos((godot_pos[0], godot_pos[1] + y_offset, godot_pos[2])),
            0.95,
            0.08,
            mats["tire"],
            collection,
        )
    add_box(
        f"{name}V5LabelFrame",
        (godot_pos[0], godot_pos[1], godot_pos[2] - 0.94),
        (0.72, 0.66, 0.08),
        mats["wood_dark"],
        collection,
        0.10,
    )
    add_box(
        f"{name}V5Label",
        (godot_pos[0], godot_pos[1] + 0.02, godot_pos[2] - 0.99),
        (0.48, 0.36, 0.05),
        mats["cream"],
        collection,
        0.06,
    )


def add_fence_segment(name, center, length, axis, collection, mats):
    x, z = center
    if axis == "x":
        post_positions = ((x - length * 0.5, z), (x, z), (x + length * 0.5, z))
        rail_size = (length, 0.16, 0.18)
    else:
        post_positions = ((x, z - length * 0.5), (x, z), (x, z + length * 0.5))
        rail_size = (0.18, 0.16, length)
    for index, (post_x, post_z) in enumerate(post_positions):
        add_box(f"{name}Post_{index}", (post_x, 0.82, post_z), (0.24, 1.45, 0.24), mats["cream"], collection, 0.08)
    for index, height in enumerate((0.58, 1.05)):
        add_box(f"{name}Rail_{index}", (x, height, z), rail_size, mats["cream"], collection, 0.06)


def add_landmarks(collection, mats):
    add_windmill(collection, mats)
    add_tree("V10NorthHeroTree", (12.0, 0.0, -33.4), 0.70, collection, mats)
    add_toy_duck("V10NorthDuckA", (-3.8, 0.28, -28.4), 0.76, collection, mats)
    add_toy_duck("V10NorthDuckB", (12.5, 0.28, -27.0), 0.66, collection, mats)
    add_tree("V3EastTreeA", (38.5, 0.0, -0.5), 1.0, collection, mats)
    add_tree("V3EastTreeB", (43.0, 0.0, 5.5), 0.82, collection, mats)
    add_production_crate("V10EastBlueCrate", (44.1, 1.35, -3.2), (3.0, 2.30, 3.0), mats["blue"], mats["blue_light"], mats["tire"], collection)
    add_production_crate("V10EastGoldCrate", (44.1, 3.20, -3.2), (2.25, 1.45, 2.25), mats["gold"], mats["gold_light"], mats["gold_dark"], collection)
    add_production_crate("V10EastRedCrate", (46.1, 1.25, 0.2), (2.45, 2.10, 2.45), mats["red"], mats["red_light"], mats["red_dark"], collection)
    add_barrel("V3SouthBarrelRed", (3.8, 1.05, 29.0), mats["red"], collection, mats)
    add_barrel("V3SouthBarrelBlue", (6.0, 1.05, 31.2), mats["blue"], collection, mats)
    add_barrel("V3SouthBarrelGold", (8.2, 1.05, 28.8), mats["gold"], collection, mats)
    add_box("V3SouthBarrelPalletA", (6.0, 0.18, 30.0), (6.4, 0.28, 0.45), mats["wood_dark"], collection, 0.10)
    add_box("V3SouthBarrelPalletB", (6.0, 0.18, 31.1), (6.4, 0.28, 0.45), mats["wood_dark"], collection, 0.10)
    for index, (y, material) in enumerate(((0.68, mats["tire"]), (1.28, mats["red_dark"]), (1.88, mats["tire"]))):
        hero.add_torus(
            f"V3WestTire_{index}",
            bpos((-41.5, y, 0.5)),
            1.05,
            0.30,
            material,
            collection,
        )
        hero.add_torus(
            f"V3WestTireV5Sidewall_{index}",
            bpos((-41.5, y + 0.035, 0.5)),
            1.05,
            0.16,
            mats["gold_dark"] if index == 1 else mats["red_dark"],
            collection,
        )
    add_box("V3WestFlagPole", (-43.0, 2.2, 7.2), (0.20, 4.4, 0.20), mats["cream"], collection, 0.06)
    add_box("V3WestFlagBanner", (-41.7, 3.65, 7.2), (2.5, 1.05, 0.16), mats["blue"], collection, 0.08)
    hero.add_torus("V3WestLifeRing", bpos((-44.0, 1.15, 6.8)), 1.05, 0.28, mats["cream"], collection, rotation=(math.pi / 2.0, 0.0, 0.0))
    add_fence_segment("V3NorthFence", (-1.5, -35.8), 7.0, "x", collection, mats)
    add_fence_segment("V3EastFence", (46.5, 5.5), 6.0, "z", collection, mats)
    add_fence_segment("V3SouthFence", (15.5, 36.0), 7.0, "x", collection, mats)
    add_fence_segment("V3WestFence", (-46.4, -3.0), 6.0, "z", collection, mats)


def add_cloud_cluster(name, center, scale, material, collection):
    offsets = (
        (-1.8, 0.0, 0.0, 1.25),
        (-0.7, 0.1, 0.2, 1.45),
        (0.6, 0.0, 0.3, 1.55),
        (1.8, -0.1, 0.0, 1.20),
        (0.0, 0.35, -0.2, 1.35),
    )
    for index, (offset_x, offset_z, offset_y, puff_scale) in enumerate(offsets):
        godot_pos = (
            center[0] + offset_x * scale,
            center[1] + offset_y * scale,
            center[2] + offset_z * scale,
        )
        godot_scale = (2.6 * scale * puff_scale, 1.15 * scale * puff_scale, 1.65 * scale * puff_scale)
        hero.add_sphere(f"{name}_{index}", bpos(godot_pos), bsize(godot_scale), material, collection, 24, 12)


def add_distant_island(name, center, scale, collection, mats):
    x, y, z = center
    hero.add_rounded_tapered_prism(
        f"{name}Cliff",
        bpos((x, y, z)),
        (7.5 * scale, 5.4 * scale),
        (4.0 * scale, 2.8 * scale),
        6.8 * scale,
        1.25 * scale,
        0.72 * scale,
        mats["distance_cliff"],
        collection,
        0.18,
    )
    add_box(f"{name}Top", (x, y + 3.55 * scale, z), (7.7 * scale, 0.48 * scale, 5.6 * scale), mats["distance_top"], collection, 0.52 * scale)
    add_box(
        f"{name}TopInset",
        (x, y + 3.88 * scale, z),
        (6.45 * scale, 0.22 * scale, 4.45 * scale),
        mats["orange_light"],
        collection,
        0.44 * scale,
    )
    for facet_index, facet_x in enumerate((-2.15, 0.0, 2.15)):
        hero.add_cone(
            f"{name}CliffFacet_{facet_index}",
            bpos((x + facet_x * scale, y - 0.15 * scale, z + 0.30 * scale)),
            1.35 * scale,
            0.62 * scale,
            5.1 * scale,
            mats["cliff_light" if facet_index == 1 else "distance_cliff"],
            collection,
        )
    for tree_index, (tree_x, tree_z, tree_scale) in enumerate(((-1.35, 0.55, 1.0), (1.15, -0.45, 0.72))):
        hero.add_cone(
            f"{name}Tree_{tree_index}",
            bpos((x + tree_x * scale, y + (5.15 if tree_index == 0 else 4.82) * scale, z + tree_z * scale)),
            1.05 * tree_scale * scale,
            0.12 * scale,
            2.9 * tree_scale * scale,
            mats["green_dark" if tree_index == 0 else "green_light"],
            collection,
        )


def add_hot_air_balloon(collection, mats):
    center = (27.0, 9.0, -33.0)
    scale = 0.68
    hero.add_sphere("V3HotAirBalloonBody", bpos(center), bsize((3.8 * scale, 5.0 * scale, 3.8 * scale)), mats["balloon"], collection, 36, 20)
    for index, x_offset in enumerate((-1.45 * scale, 0.0, 1.45 * scale)):
        hero.add_sphere(
            f"V3HotAirBalloonStripe_{index}",
            bpos((center[0] + x_offset, center[1], center[2] - 0.10)),
            bsize((0.48 * scale, 5.05 * scale, 3.86 * scale)),
            mats["balloon_gold"],
            collection,
            24,
            14,
        )
    basket_y = center[1] - 5.6 * scale
    add_box("V3HotAirBalloonBasket", (center[0], basket_y, center[2]), (2.2 * scale, 1.5 * scale, 1.8 * scale), mats["wood_dark"], collection, 0.24 * scale)
    rope_y = center[1] - 3.85 * scale
    for index, (offset_x, offset_z) in enumerate(((-0.8, -0.6), (-0.8, 0.6), (0.8, -0.6), (0.8, 0.6))):
        add_box(
            f"V3HotAirBalloonRope_{index}",
            (center[0] + offset_x * scale, rope_y, center[2] + offset_z * scale),
            (0.10 * scale, 3.4 * scale, 0.10 * scale),
            mats["cream"],
            collection,
            0.03 * scale,
        )


def add_backdrop(collection, mats):
    cloud_specs = (
        ("V3CloudNorthWest", (-58.0, -10.3, -55.0), 2.6, mats["cloud_pink"]),
        ("V3CloudNorth", (0.0, -10.7, -72.0), 3.2, mats["cloud_cream"]),
        ("V3CloudNorthEast", (57.0, -10.4, -58.0), 2.7, mats["cloud_violet"]),
        ("V3CloudSouthWest", (-58.0, -10.5, 58.0), 2.8, mats["cloud_violet"]),
        ("V3CloudSouth", (2.0, -10.2, 74.0), 3.3, mats["cloud_pink"]),
        ("V3CloudSouthEast", (59.0, -10.6, 58.0), 2.7, mats["cloud_cream"]),
        ("V3CloudWest", (-78.0, -10.8, 2.0), 2.9, mats["cloud_cream"]),
        ("V3CloudEast", (80.0, -10.5, 4.0), 2.9, mats["cloud_pink"]),
    )
    for name, center, scale, material in cloud_specs:
        add_cloud_cluster(name, center, scale, material, collection)
    add_distant_island("V3DistantIslandNW", (-17.0, -7.5, -20.0), 0.66, collection, mats)
    add_distant_island("V3DistantIslandNE", (31.0, -8.0, -27.0), 0.58, collection, mats)
    add_distant_island("V3DistantIslandSouth", (30.0, -8.2, 37.0), 0.62, collection, mats)
    add_hot_air_balloon(collection, mats)


def add_segmented_bumper(name, godot_pos, length, radius, body_mat, light_mat, dark_mat, collection):
    for foot_index, offset in enumerate((-0.28, 0.28)):
        add_box(
            f"{name}V5Foot_{foot_index}",
            (godot_pos[0] + length * offset, godot_pos[1] - radius * 0.70, godot_pos[2]),
            (length * 0.20, 0.30, radius * 1.16),
            dark_mat,
            collection,
            0.15,
        )
    hero.add_capsule(name, bpos(godot_pos), length, radius, body_mat, collection)

    segment_count = max(2, int(round(length / 3.1)))
    segment_length = length / float(segment_count)
    for segment_index in range(segment_count):
        segment_x = godot_pos[0] - length * 0.5 + segment_length * (float(segment_index) + 0.5)
        add_box(
            f"{name}V5TopPad_{segment_index}",
            (segment_x, godot_pos[1] + radius * 0.57, godot_pos[2]),
            (segment_length * 0.52, 0.08, radius * 0.34),
            light_mat,
            collection,
            0.06,
        )
    collar_positions = [
        godot_pos[0] - length * 0.5 + length * float(index) / float(segment_count)
        for index in range(1, segment_count)
    ]
    collar_positions.extend((godot_pos[0] - length * 0.5 + radius, godot_pos[0] + length * 0.5 - radius))
    for collar_index, x in enumerate(collar_positions):
        hero.add_torus(
            f"{name}Collar_{collar_index}",
            bpos((x, godot_pos[1], godot_pos[2])),
            radius * 1.01,
            0.075,
            dark_mat,
            collection,
            rotation=(0.0, math.pi / 2.0, 0.0),
        )
    for end_index, direction in enumerate((-1.0, 1.0)):
        hero.add_cylinder(
            f"{name}V5EndPlate_{end_index}",
            bpos((godot_pos[0] + direction * (length * 0.5 - 0.08), godot_pos[1], godot_pos[2])),
            radius * 0.68,
            0.12,
            light_mat,
            collection,
            rotation=(0.0, math.pi / 2.0, 0.0),
            bevel=0.04,
            vertices=24,
        )


def add_production_crate(name, godot_pos, godot_size, body_mat, light_mat, dark_mat, collection):
    sx, sy, sz = godot_size
    x, y, z = godot_pos
    add_box(f"{name}Body", godot_pos, godot_size, body_mat, collection, min(sx, sy, sz) * 0.16)
    add_box(
        f"{name}TopPlate",
        (x, y + sy * 0.5 + 0.035, z),
        (sx * 0.72, 0.10, sz * 0.72),
        light_mat,
        collection,
        0.10,
    )
    for rail_index, (offset_x, offset_z) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        add_box(
            f"{name}CornerRail_{rail_index}",
            (x + offset_x * (sx * 0.5 - 0.15), y, z + offset_z * (sz * 0.5 - 0.15)),
            (0.27, sy + 0.14, 0.27),
            dark_mat,
            collection,
            0.08,
        )
    add_box(
        f"{name}TopBandX",
        (x, y + sy * 0.5 + 0.095, z),
        (sx * 0.86, 0.10, 0.20),
        dark_mat,
        collection,
        0.05,
    )
    add_box(
        f"{name}TopBandZ",
        (x, y + sy * 0.5 + 0.095, z),
        (0.20, 0.10, sz * 0.86),
        dark_mat,
        collection,
        0.05,
    )
    for face_index, face_z in enumerate((z - sz * 0.5 - 0.025, z + sz * 0.5 + 0.025)):
        add_box(
            f"{name}V5SideInsetFrame_{face_index}",
            (x, y, face_z),
            (sx * 0.56, sy * 0.52, 0.065),
            dark_mat,
            collection,
            0.09,
        )
        add_box(
            f"{name}V5SideInsetPanel_{face_index}",
            (x, y, face_z + (-0.045 if face_index == 0 else 0.045)),
            (sx * 0.43, sy * 0.36, 0.045),
            light_mat,
            collection,
            0.08,
        )
        add_box(
            f"{name}V5SideLatch_{face_index}",
            (x, y, face_z + (-0.08 if face_index == 0 else 0.08)),
            (sx * 0.13, sy * 0.11, 0.045),
            dark_mat,
            collection,
            0.04,
        )
    for cap_index, (offset_x, offset_z) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        add_box(
            f"{name}V5CornerCap_{cap_index}",
            (x + offset_x * (sx * 0.5 - 0.16), y + sy * 0.5 + 0.09, z + offset_z * (sz * 0.5 - 0.16)),
            (0.36, 0.15, 0.36),
            light_mat,
            collection,
            0.08,
        )


def add_west_barricade(collection, mats):
    add_box("V3WestBarricadeBody", (-13.85, 1.70, 5.60), (7.75, 1.72, 3.05), mats["gold"], collection, 0.46)
    add_box("V3WestBarricadeTop", (-13.85, 2.60, 5.60), (5.15, 0.18, 2.18), mats["gold_light"], collection, 0.18)
    add_box("V3WestBarricadeBase", (-13.85, 0.80, 5.60), (7.95, 0.34, 3.18), mats["gold_dark"], collection, 0.18)
    for index, x in enumerate((-17.25, -10.45)):
        add_box(f"V3WestBarricadeCushion_{index}", (x, 1.72, 5.60), (1.18, 1.56, 2.48), mats["orange"], collection, 0.36)
    for index, x in enumerate((-15.95, -13.85, -11.75)):
        add_box(f"V3WestBarricadeStrap_{index}", (x, 1.72, 5.60), (0.26, 1.88, 3.18), mats["gold_dark"], collection, 0.08)
    for index, x in enumerate((-16.65, -13.85, -11.05)):
        add_box(f"V3WestBarricadeV5Panel_{index}", (x, 1.78, 4.02), (1.58, 0.72, 0.10), mats["gold_light"], collection, 0.14)


def add_gameplay_props(collection, mats):
    add_segmented_bumper("V3BumperNorth", (-13.0, 1.75, -16.8), 9.0, 0.92, mats["red"], mats["red_light"], mats["red_dark"], collection)
    add_segmented_bumper("V3BumperCenterNorth", (5.0, 1.75, -13.5), 7.0, 0.92, mats["red"], mats["red_light"], mats["red_dark"], collection)
    add_segmented_bumper("V3BumperCenter", (7.0, 1.75, -1.5), 8.0, 1.05, mats["red"], mats["red_light"], mats["red_dark"], collection)
    add_segmented_bumper("V3BumperSouth", (-4.0, 1.75, 16.7), 13.0, 0.88, mats["red"], mats["red_light"], mats["red_dark"], collection)
    add_west_barricade(collection, mats)
    add_production_crate("V3WoodCrate", (-6.0, 1.68, 12.0), (5.0, 1.9, 2.8), mats["wood"], mats["wood_light"], mats["wood_dark"], collection)
    add_production_crate("V3OrangeCrate", (16.5, 1.72, -13.5), (3.4, 2.5, 3.4), mats["orange"], mats["orange_light"], mats["orange_dark"], collection)
    add_production_crate("V3TanCrate", (19.0, 1.66, 2.0), (5.2, 2.0, 4.0), mats["gold"], mats["gold_light"], mats["gold_dark"], collection)


def p26_required_export_names():
    source = INTEGRATION_VERIFIER_PATH.read_text(encoding="utf-8")
    try:
        block = source.split("const REQUIRED_V2_NODES := [", 1)[1].split("]", 1)[0]
    except IndexError as exc:
        raise RuntimeError("Could not read the Sunset V2 integration node contract") from exc
    return set(re.findall(r'"([^"]+)"', block))


def p26_should_preserve_export_object(obj, required_names):
    return (
        obj.name in required_names
        or obj.name in P26_EXPORT_PRESERVE_EXACT
        or "EdgeGem_" in obj.name
        or obj.name.startswith(P26_EXPORT_PRESERVE_PREFIXES)
    )


def p26_batch_static_meshes_for_export():
    required_names = p26_required_export_names()
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    groups = {}
    preserved = []
    unbatchable = []

    for obj in mesh_objects:
        if p26_should_preserve_export_object(obj, required_names):
            preserved.append(obj)
            continue
        if obj.parent is not None or len(obj.data.materials) != 1 or obj.data.materials[0] is None:
            unbatchable.append(obj)
            continue
        material = obj.data.materials[0]
        groups.setdefault(material.name_full, []).append(obj)

    batch_count = 0
    source_count = 0
    for material_name, objects in sorted(groups.items()):
        if not objects:
            continue
        source_count += len(objects)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        active = objects[0]
        bpy.context.view_layer.objects.active = active
        if len(objects) > 1:
            bpy.ops.object.join()

        material = bpy.data.materials.get(material_name)
        for polygon in active.data.polygons:
            polygon.material_index = 0
        active.data.materials.clear()
        active.data.materials.append(material)
        safe_material_name = re.sub(r"[^A-Za-z0-9_]+", "_", material_name).strip("_")
        active.name = f"P26Batch_{batch_count:02d}_{safe_material_name}"
        active.data.name = f"{active.name}Mesh"
        active["p26_source_mesh_count"] = len(objects)
        batch_count += 1

    bpy.ops.object.select_all(action="DESELECT")
    final_mesh_count = sum(1 for obj in bpy.context.scene.objects if obj.type == "MESH")
    report = {
        "source_meshes": len(mesh_objects),
        "batched_source_meshes": source_count,
        "batches": batch_count,
        "preserved_meshes": len(preserved),
        "unbatchable_meshes": len(unbatchable),
        "export_meshes": final_mesh_count,
    }
    print(f"P26 static export batching: {report}")
    return report


def build():
    hero.clear_scene()
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    collection = hero.make_collection("SUNSET_OPEN_RINGOUT_V2_GAMEPLAY")
    mats = materials()
    add_central_platform(collection, mats)
    add_outer_islands(collection, mats)
    add_all_bridges(collection, mats)
    add_gameplay_props(collection, mats)
    add_landmarks(collection, mats)
    add_backdrop(collection, mats)

    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
    p26_batch_static_meshes_for_export()
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    print(f"Saved gameplay-aligned source: {SOURCE_PATH}")
    print(f"Exported gameplay-aligned GLB: {GLB_PATH}")


if __name__ == "__main__":
    build()
