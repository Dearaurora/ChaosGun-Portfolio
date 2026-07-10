from pathlib import Path
import sys

import bpy


TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import build_sunset_toy_sky_islands_hero as hero


SOURCE_PATH = ROOT / "assets" / "source" / "sunset_toy_sky_islands" / "open_ringout_v2_preview.blend"
GLB_PATH = ROOT / "assets" / "models" / "generated" / "sunset_toy_sky_islands" / "open_ringout_v2_preview.glb"


def bpos(godot_pos):
    x, y, z = godot_pos
    return (x, -z, y)


def bsize(godot_size):
    x, y, z = godot_size
    return (x, z, y)


def scale_outline(points, factor):
    return [(x * factor, z * factor) for x, z in points]


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


def materials():
    return {
        "deck": hero.make_material("v2_sunset_deck", "#98491B", 0.74),
        "deck_light": hero.make_material("v2_sunset_deck_highlight", "#B98326", 0.78),
        "deck_panel_a": hero.make_material("v2_sunset_deck_panel_a", "#D0912F", 0.80),
        "deck_panel_b": hero.make_material("v2_sunset_deck_panel_b", "#C47E25", 0.82),
        "side": hero.make_material("v2_sunset_warm_side", "#8F391C", 0.82),
        "cliff": hero.make_material("v2_sunset_plum_cliff", "#39265F", 0.92),
        "bridge": hero.make_material("v2_sunset_bridge_wood", "#B46F32", 0.82),
        "bridge_alt": hero.make_material("v2_sunset_bridge_wood_alt", "#CF9142", 0.82),
        "seam": hero.make_material("v2_sunset_floor_seam", "#713317", 0.92),
        "post": hero.make_material("v2_sunset_edge_post", "#493455", 0.72, 0.08),
        "cyan": hero.make_material("v2_sunset_cyan_marker", "#45C9EE", 0.32, emission_hex="#45C9EE", emission_strength=1.45),
        "shadow": hero.make_material("v2_sunset_bridge_shadow", "#281C4C", 0.96),
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
    outline = central_outline()
    add_tapered_polygon("V2CentralCliff", scale_outline(outline, 0.98), scale_outline(outline, 0.80), -4.6, 6.4, mats["cliff"], collection, 0.16)
    add_tapered_polygon("V2CentralWarmBand", scale_outline(outline, 1.018), scale_outline(outline, 0.995), -1.20, 0.95, mats["side"], collection, 0.12)
    add_tapered_polygon("V2CentralTop", outline, scale_outline(outline, 0.992), -0.31, 0.92, mats["deck"], collection, 0.10)
    add_tapered_polygon("V2CentralTopInset", scale_outline(outline, 0.958), scale_outline(outline, 0.958), 0.165, 0.04, mats["deck_light"], collection, 0.025)

    panel_centers_x = (-13.5, -4.5, 4.5, 13.5)
    panel_centers_z = (-8.0, 0.0, 8.0)
    for z_index, z in enumerate(panel_centers_z):
        for x_index, x in enumerate(panel_centers_x):
            material = mats["deck_panel_a"] if (x_index + z_index) % 3 == 0 else mats["deck_panel_b"]
            add_box(
                f"V2CentralPanel_{z_index}_{x_index}",
                (x, 0.191, z),
                (8.68, 0.012, 7.68),
                material,
                collection,
                0.08,
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
    add_box("V2EastBridgeShadow", (31.8, -2.55, 2.0), (7.2, 5.2, 8.0), mats["shadow"], collection, 0.55)
    for index in range(6):
        x = 28.9 + index * 1.16
        material = mats["bridge_alt"] if index % 3 == 1 else mats["bridge"]
        add_box(f"V2EastBridgePlank_{index}", (x, -0.17, 2.0), (1.02, 0.70, 7.55), material, collection, 0.16)
    for index, (x, z) in enumerate(((28.25, -2.0), (28.25, 6.0), (35.35, -2.0), (35.35, 6.0))):
        add_box(f"V2EastBridgePost_{index}", (x, 0.52, z), (0.68, 1.02, 0.68), mats["post"], collection, 0.18)
        add_box(f"V2EastBridgeGem_{index}", (x, 1.08, z), (0.34, 0.12, 0.34), mats["cyan"], collection, 0.08)


def build():
    hero.clear_scene()
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    collection = hero.make_collection("SUNSET_OPEN_RINGOUT_V2_GAMEPLAY")
    mats = materials()
    add_central_platform(collection, mats)
    add_east_bridge(collection, mats)

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
