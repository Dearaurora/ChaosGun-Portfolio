from pathlib import Path
import math
import sys

import bpy


TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import build_sunset_toy_sky_islands_hero as hero


SOURCE_PATH = ROOT / "assets" / "source" / "sunset_toy_sky_islands" / "open_ringout_v2_preview.blend"
GLB_PATH = ROOT / "assets" / "models" / "generated" / "sunset_toy_sky_islands" / "open_ringout_v2_preview.glb"
TEXTURE_DIR = ROOT / "assets" / "textures" / "generated" / "sunset_toy_sky_islands"


def bpos(godot_pos):
    x, y, z = godot_pos
    return (x, -z, y)


def bsize(godot_size):
    x, y, z = godot_size
    return (x, z, y)


def scale_outline(points, factor):
    return [(x * factor, z * factor) for x, z in points]


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


def add_box(name, godot_pos, godot_size, material, collection, bevel=0.12):
    return hero.add_rounded_box(name, bpos(godot_pos), bsize(godot_size), material, collection, bevel)


def make_textured_material(name, texture_name, roughness):
    texture_path = TEXTURE_DIR / f"{texture_name}.png"
    if not texture_path.exists():
        raise FileNotFoundError(f"Missing generated texture: {texture_path}")
    image = bpy.data.images.load(str(texture_path), check_existing=True)
    material = hero.make_material(name, "#FFFFFF", roughness)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    material.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    return material


def materials():
    return {
        "deck": hero.make_material("v2_sunset_deck", "#98491B", 0.74),
        "deck_light": hero.make_material("v2_sunset_deck_highlight", "#B98326", 0.78),
        "deck_panel_a": make_textured_material("v3_sunset_deck_panel_a", "deck_wood_light", 0.80),
        "deck_panel_b": make_textured_material("v3_sunset_deck_panel_b", "deck_wood_mid", 0.82),
        "side": hero.make_material("v2_sunset_warm_side", "#8F391C", 0.82),
        "cliff": hero.make_material("v2_sunset_plum_cliff", "#39265F", 0.92),
        "cliff_mid": hero.make_material("v2_sunset_plum_cliff_mid", "#40295F", 0.94),
        "cliff_light": hero.make_material("v2_sunset_plum_cliff_light", "#482C63", 0.92),
        "bridge": make_textured_material("v3_sunset_bridge_wood", "bridge_wood_mid", 0.82),
        "bridge_alt": make_textured_material("v3_sunset_bridge_wood_alt", "bridge_wood_light", 0.82),
        "seam": hero.make_material("v3_sunset_floor_seam", "#95552C", 0.90),
        "rim": hero.make_material("v2_sunset_edge_rim", "#D9902F", 0.68),
        "fastener": hero.make_material("v2_sunset_bridge_fastener", "#493455", 0.68, 0.10),
        "post": hero.make_material("v2_sunset_edge_post", "#493455", 0.72, 0.08),
        "cyan": hero.make_material("v2_sunset_cyan_marker", "#45C9EE", 0.32, emission_hex="#45C9EE", emission_strength=1.45),
        "shadow": hero.make_material("v2_sunset_bridge_shadow", "#281C4C", 0.96),
        "red": hero.make_material("v3_prop_red", "#C94132", 0.66),
        "red_light": hero.make_material("v3_prop_red_light", "#EE6948", 0.60),
        "red_dark": hero.make_material("v3_prop_red_dark", "#772838", 0.78),
        "orange": hero.make_material("v3_prop_orange", "#D96827", 0.68),
        "orange_light": hero.make_material("v3_prop_orange_light", "#F49A3C", 0.62),
        "orange_dark": hero.make_material("v3_prop_orange_dark", "#81372D", 0.80),
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
        (-23.6, -18.0), (23.6, -18.0), (25.6, -16.0),
        (25.6, -14.5), (28.0, -14.5), (30.0, -12.5),
        (30.0, 6.5), (28.0, 8.5), (26.0, 8.5),
        (26.0, 15.8), (23.8, 18.0), (-10.5, 18.0),
        (-12.5, 19.0), (-27.0, 19.0), (-29.0, 17.0),
        (-29.0, 1.0), (-27.0, -1.0), (-26.0, -1.0),
        (-26.0, -16.0), (-23.6, -18.0),
    ]


def add_central_platform(collection, mats):
    outline = scale_outline(smooth_closed_outline(central_outline()), 1.018)
    add_tapered_polygon("V2CentralCliff", scale_outline(outline, 0.985), scale_outline(outline, 0.78), -4.6, 6.4, mats["cliff"], collection, 0.18)
    add_tapered_polygon("V2CentralWarmBand", scale_outline(outline, 1.018), scale_outline(outline, 0.995), -1.20, 0.95, mats["side"], collection, 0.12)
    add_tapered_polygon("V2CentralTop", outline, scale_outline(outline, 0.992), -0.31, 0.92, mats["deck"], collection, 0.10)
    add_tapered_polygon("V2CentralTopInset", scale_outline(outline, 0.958), scale_outline(outline, 0.958), 0.165, 0.04, mats["deck_light"], collection, 0.025)

    facet_outline = scale_outline(outline, 0.91)
    facet_step = max(1, len(facet_outline) // 9)
    for facet_index, point_index in enumerate(range(0, len(facet_outline), facet_step)):
        x, z = facet_outline[point_index]
        previous = facet_outline[(point_index - 1) % len(facet_outline)]
        following = facet_outline[(point_index + 1) % len(facet_outline)]
        tangent_x = following[0] - previous[0]
        tangent_z = following[1] - previous[1]
        yaw = math.atan2(-tangent_z, tangent_x)
        material = mats["cliff_light"] if facet_index % 3 == 0 else mats["cliff_mid"]
        facet = hero.add_tapered_box(
            f"V2CentralCliffFacet_{facet_index}",
            (x, -z, -4.45 - float(facet_index % 3) * 0.16),
            (5.2, 2.15),
            (3.8, 1.45),
            4.35 + float(facet_index % 2) * 0.28,
            material,
            collection,
            0.18,
        )
        facet.rotation_euler[2] = yaw

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

    panel_centers_x = (-13.5, -4.5, 4.5, 13.5)
    panel_centers_z = (-8.0, 0.0, 8.0)
    for z_index, z in enumerate(panel_centers_z):
        for x_index, x in enumerate(panel_centers_x):
            material = mats["deck_panel_a"] if (x_index + z_index) % 3 == 0 else mats["deck_panel_b"]
            add_box(
                f"V2CentralPanel_{z_index}_{x_index}",
                (x, 0.199, z),
                (8.68, 0.028, 7.68),
                material,
                collection,
                0.10,
            )

    for index, x in enumerate((-18.0, -9.0, 0.0, 9.0, 18.0)):
        add_box(f"V2CentralSeamX_{index}", (x, 0.205, 0.0), (0.075, 0.025, 30.0), mats["seam"], collection, 0.012)
    for index, z in enumerate((-12.0, -4.0, 4.0, 12.0)):
        add_box(f"V2CentralSeamZ_{index}", (0.0, 0.21, z), (45.0, 0.025, 0.075), mats["seam"], collection, 0.012)

    edge_posts = [
        (-23.0, -16.5), (22.5, -16.5), (28.2, -11.5), (28.2, 6.0),
        (23.5, 16.2), (-9.5, 17.2), (-26.8, 16.5), (-27.2, 1.8),
        (-24.5, -1.8),
    ]
    for index, (x, z) in enumerate(edge_posts):
        add_box(f"V2CentralEdgePost_{index}", (x, 0.55, z), (0.72, 0.82, 0.72), mats["post"], collection, 0.18)
        add_box(f"V2CentralEdgeGem_{index}", (x, 1.00, z), (0.34, 0.12, 0.34), mats["cyan"], collection, 0.08)


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
            add_box(f"{prefix}MouthBeam_{end_index}", (end_x, 0.34, center_z), (0.38, 0.34, width * 0.90), mats["gold_dark"], collection, 0.10)
        for rail_index, rail_z in enumerate((center_z - width * 0.49, center_z + width * 0.49)):
            add_box(f"{prefix}SideRail_{rail_index}", (center_x, 0.72, rail_z), (length * 0.72, 0.18, 0.18), mats["cream"], collection, 0.07)
    else:
        for end_index, end_z in enumerate((center_z - length * 0.5, center_z + length * 0.5)):
            add_box(f"{prefix}MouthBeam_{end_index}", (center_x, 0.34, end_z), (width * 0.90, 0.34, 0.38), mats["gold_dark"], collection, 0.10)
        for rail_index, rail_x in enumerate((center_x - width * 0.49, center_x + width * 0.49)):
            add_box(f"{prefix}SideRail_{rail_index}", (rail_x, 0.72, center_z), (0.18, 0.18, length * 0.72), mats["cream"], collection, 0.07)


def add_all_bridges(collection, mats):
    add_bridge_module("V2EastBridge", (31.8, 2.0), 7.0, 8.0, "x", collection, mats)
    add_bridge_module("V3WestBridge", (-31.8, 2.0), 6.6, 9.0, "x", collection, mats)
    add_bridge_module("V3NorthBridge", (4.0, -20.2), 5.2, 11.0, "z", collection, mats)
    add_bridge_module("V3SouthBridge", (7.0, 20.0), 5.0, 11.0, "z", collection, mats)


def add_side_island(name, center, size, panel_mat, collection, mats):
    x, z = center
    sx, sz = size
    radius = min(sx, sz) * 0.22
    hero.add_rounded_tapered_prism(
        f"{name}Cliff",
        bpos((x, -4.45, z)),
        (sx * 0.95, sz * 0.95),
        (sx * 0.70, sz * 0.70),
        6.2,
        radius,
        radius * 0.68,
        mats["cliff"],
        collection,
        0.16,
    )
    hero.add_rounded_tapered_prism(
        f"{name}WarmBand",
        bpos((x, -1.18, z)),
        (sx * 1.01, sz * 1.01),
        (sx * 0.96, sz * 0.96),
        0.90,
        radius * 1.03,
        radius * 0.96,
        mats["side"],
        collection,
        0.10,
    )
    hero.add_rounded_tapered_prism(
        f"{name}Top",
        bpos((x, -0.30, z)),
        (sx, sz),
        (sx * 0.985, sz * 0.985),
        0.90,
        radius,
        radius * 0.98,
        mats["deck_light"],
        collection,
        0.10,
    )
    add_box(f"{name}TopInset", (x, 0.18, z), (sx * 0.84, 0.045, sz * 0.82), panel_mat, collection, radius * 0.52)

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
    add_side_island("V3NorthIsland", (4.0, -30.0), (22.0, 15.0), mats["deck_panel_a"], collection, mats)
    add_side_island("V3EastIsland", (38.0, 3.0), (20.0, 18.0), mats["deck_panel_b"], collection, mats)
    add_side_island("V3SouthIsland", (9.0, 30.0), (24.0, 16.0), mats["deck_panel_a"], collection, mats)
    add_side_island("V3WestIsland", (-39.0, 2.0), (18.0, 20.0), mats["deck_panel_b"], collection, mats)


def add_windmill(collection, mats):
    x, z = (7.0, -31.0)
    add_box("V3NorthWindmillHouse", (x, 1.25, z), (4.1, 2.5, 3.6), mats["cream"], collection, 0.48)
    add_box("V3NorthWindmillDoor", (x, 1.15, z + 1.84), (1.05, 1.65, 0.16), mats["wood_dark"], collection, 0.14)
    add_box("V3NorthWindmillSill", (x, 2.18, z + 1.88), (1.48, 0.18, 0.18), mats["gold_dark"], collection, 0.06)
    hero.add_cone("V3NorthWindmillTower", bpos((x, 2.0, z)), 1.55, 1.02, 3.6, mats["wood"], collection)
    hero.add_cone("V3NorthWindmillRoof", bpos((x, 4.25, z)), 1.45, 0.18, 1.55, mats["red_dark"], collection)
    blade_center = bpos((x, 4.05, z + 1.18))
    for index, angle in enumerate((45.0, 135.0)):
        hero.add_rounded_box(
            f"V3NorthWindmillBlade_{index}",
            blade_center,
            (4.7, 0.24, 0.52),
            mats["orange_light"],
            collection,
            0.12,
            (0.0, math.radians(angle), 0.0),
        )
    hero.add_cylinder(
        "V3NorthWindmillHub",
        blade_center,
        0.48,
        0.52,
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
    hero.add_sphere(f"{name}Shrub", bpos((x + 1.25 * scale, 0.62 * scale, z + 0.45 * scale)), bsize((0.80 * scale, 0.62 * scale, 0.80 * scale)), mats["green_dark"], collection, 20, 10)


def add_barrel(name, godot_pos, body_mat, collection, mats):
    hero.add_cylinder(name, bpos(godot_pos), 0.95, 1.65, body_mat, collection, bevel=0.16, vertices=28)
    for band_index, y_offset in enumerate((-0.52, 0.52)):
        hero.add_torus(
            f"{name}Band_{band_index}",
            bpos((godot_pos[0], godot_pos[1] + y_offset, godot_pos[2])),
            0.95,
            0.08,
            mats["tire"],
            collection,
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
    add_tree("V3EastTreeA", (36.5, 0.0, -0.5), 1.0, collection, mats)
    add_tree("V3EastTreeB", (42.0, 0.0, 5.5), 0.82, collection, mats)
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
    add_box("V3WestFlagPole", (-35.5, 2.2, 6.8), (0.20, 4.4, 0.20), mats["cream"], collection, 0.06)
    add_box("V3WestFlagBanner", (-34.2, 3.65, 6.8), (2.5, 1.05, 0.16), mats["blue"], collection, 0.08)
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
    add_box(
        f"{name}Underlay",
        (godot_pos[0], godot_pos[1] - radius * 0.62, godot_pos[2]),
        (length * 0.92, 0.34, radius * 1.22),
        dark_mat,
        collection,
        0.16,
    )
    hero.add_capsule(name, bpos(godot_pos), length, radius, body_mat, collection)
    add_box(
        f"{name}TopHighlight",
        (godot_pos[0], godot_pos[1] + radius * 0.56, godot_pos[2]),
        (length * 0.58, 0.10, radius * 0.42),
        light_mat,
        collection,
        0.05,
    )

    segment_count = max(2, int(round(length / 3.1)))
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
            f"{name}SideInset_{face_index}",
            (x, y, face_z),
            (sx * 0.54, sy * 0.48, 0.07),
            light_mat,
            collection,
            0.09,
        )


def add_west_barricade(collection, mats):
    add_box("V3WestBarricadeBody", (-13.85, 1.70, 5.60), (7.75, 1.72, 3.05), mats["gold"], collection, 0.46)
    add_box("V3WestBarricadeTop", (-13.85, 2.60, 5.60), (5.15, 0.18, 2.18), mats["gold_light"], collection, 0.18)
    add_box("V3WestBarricadeBase", (-13.85, 0.80, 5.60), (7.95, 0.34, 3.18), mats["gold_dark"], collection, 0.18)
    for index, x in enumerate((-17.25, -10.45)):
        add_box(f"V3WestBarricadeCushion_{index}", (x, 1.72, 5.60), (1.18, 1.56, 2.48), mats["orange"], collection, 0.36)
    for index, x in enumerate((-15.95, -13.85, -11.75)):
        add_box(f"V3WestBarricadeStrap_{index}", (x, 1.72, 5.60), (0.26, 1.88, 3.18), mats["gold_dark"], collection, 0.08)


def add_gameplay_props(collection, mats):
    add_segmented_bumper("V3BumperNorth", (-13.0, 1.75, -16.8), 9.0, 0.92, mats["red"], mats["red_light"], mats["red_dark"], collection)
    add_segmented_bumper("V3BumperCenterNorth", (5.0, 1.75, -13.5), 7.0, 0.92, mats["red"], mats["red_light"], mats["red_dark"], collection)
    add_segmented_bumper("V3BumperCenter", (7.0, 1.75, -1.5), 8.0, 1.05, mats["orange"], mats["orange_light"], mats["orange_dark"], collection)
    add_segmented_bumper("V3BumperSouth", (-4.0, 1.75, 16.7), 13.0, 0.88, mats["orange"], mats["orange_light"], mats["orange_dark"], collection)
    add_west_barricade(collection, mats)
    add_production_crate("V3WoodCrate", (-6.0, 1.68, 12.0), (5.0, 1.9, 2.8), mats["wood"], mats["wood_light"], mats["wood_dark"], collection)
    add_production_crate("V3OrangeCrate", (16.5, 1.72, -13.5), (3.4, 2.5, 3.4), mats["orange"], mats["orange_light"], mats["orange_dark"], collection)
    add_production_crate("V3TanCrate", (19.0, 1.66, 2.0), (5.2, 2.0, 4.0), mats["gold"], mats["gold_light"], mats["gold_dark"], collection)


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
