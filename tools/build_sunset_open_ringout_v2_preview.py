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


def add_east_bridge(collection, mats):
    add_box("V2EastBridgeShadow", (31.8, -0.72, -1.15), (7.4, 0.58, 0.72), mats["shadow"], collection, 0.24)
    add_box("V2EastBridgeSupportB", (31.8, -0.72, 5.15), (7.4, 0.58, 0.72), mats["shadow"], collection, 0.24)
    for index in range(6):
        x = 28.9 + index * 1.16
        material = mats["bridge_alt"] if index % 3 == 1 else mats["bridge"]
        add_box(f"V2EastBridgePlank_{index}", (x, -0.17, 2.0), (1.02, 0.70, 7.55), material, collection, 0.16)
        for side_index, z in enumerate((-1.18, 5.18)):
            hero.add_cylinder(
                f"V2EastBridgeFastener_{index}_{side_index}",
                bpos((x, 0.225, z)),
                0.11,
                0.065,
                mats["fastener"],
                collection,
                bevel=0.025,
                vertices=18,
            )
    for index, (x, z) in enumerate(((28.25, -2.0), (28.25, 6.0), (35.35, -2.0), (35.35, 6.0))):
        add_box(f"V2EastBridgePost_{index}", (x, 0.52, z), (0.68, 1.02, 0.68), mats["post"], collection, 0.18)
        add_box(f"V2EastBridgeGem_{index}", (x, 1.08, z), (0.34, 0.12, 0.34), mats["cyan"], collection, 0.08)


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
    add_east_bridge(collection, mats)
    add_gameplay_props(collection, mats)

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
