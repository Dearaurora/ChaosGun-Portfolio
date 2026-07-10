import math
import os
from pathlib import Path

import bpy


MAP_SCALE = 1.25
OUT_PATH = Path("assets/models/generated/commercial_slice_a/commercial_slice_a_visuals.glb")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, roughness=0.95):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    return material


MAT_GRASS_TOP = mat("toy_grass_top", (0.73, 0.90, 0.42, 1.0))
MAT_GRASS_SIDE = mat("toy_grass_side", (0.48, 0.66, 0.30, 1.0))
MAT_EDGE = mat("soft_lime_edge_trim", (0.82, 0.96, 0.52, 1.0))
MAT_BRIDGE = mat("warm_wood_bridge", (0.70, 0.51, 0.25, 1.0))
MAT_BRIDGE_DARK = mat("bridge_side_shadow", (0.48, 0.34, 0.18, 1.0))
MAT_WALL = mat("lavender_blue_wall", (0.60, 0.63, 0.95, 1.0))
MAT_WALL_LIGHT = mat("wall_highlight_cap", (0.77, 0.80, 1.00, 1.0))
MAT_GROUND = mat("pastel_backdrop_grass", (0.63, 0.80, 0.37, 1.0))
MAT_PATH = mat("soft_worn_path", (0.88, 0.74, 0.37, 1.0))
MAT_ROCK = mat("warm_gray_rock", (0.55, 0.55, 0.50, 1.0))
MAT_TRUNK = mat("soft_tree_trunk", (0.45, 0.30, 0.16, 1.0))
MAT_LEAF = mat("tree_leaf_mass", (0.34, 0.66, 0.34, 1.0))


def gpos(x, y, z):
    return (x * MAP_SCALE, y, z * MAP_SCALE)


def bpos(pos):
    # Godot is Y-up. Blender is Z-up. The glTF exporter converts Blender Z-up to
    # glTF/Godot Y-up, so use -Godot Z as Blender Y to preserve forward direction.
    x, y, z = pos
    return (x, -z, y)


def bscale(size):
    x, y, z = size
    return (x, z, y)


def add_cube_obj(name, pos, size, material, bevel=0.0, yaw_deg=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=bpos(pos), rotation=(0, 0, math.radians(-yaw_deg)))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = bscale(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0.0:
        modifier = obj.modifiers.new(name="soft_bevel", type="BEVEL")
        modifier.width = bevel
        modifier.segments = 4
        modifier.affect = "EDGES"
        obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    return obj


def add_cylinder_obj(name, pos, radius, depth, material, vertices=16, scale=(1.0, 1.0, 1.0), yaw_deg=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=bpos(pos),
        rotation=(0, 0, math.radians(-yaw_deg)),
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0], scale[1], scale[2])
    obj.data.materials.append(material)
    obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    return obj


def add_island(name, center, size):
    x, y, z = center
    sx, sy, sz = size
    add_cube_obj(f"{name}_skirt", (x, y - 0.18, z), (sx, sy + 0.52, sz), MAT_GRASS_SIDE, bevel=0.75)
    add_cube_obj(f"{name}_top", (x, y + 1.03, z), (sx * 0.96, 0.22, sz * 0.96), MAT_GRASS_TOP, bevel=0.95)
    add_cube_obj(f"{name}_inner_soft_lip", (x, y + 1.22, z), (sx * 0.82, 0.12, sz * 0.82), MAT_EDGE, bevel=0.55)


def add_bridge(name, center, size, yaw_deg=0.0):
    x, y, z = center
    sx, sy, sz = size
    add_cube_obj(f"{name}_underside", (x, y - 0.14, z), (sx, sy + 0.18, sz), MAT_BRIDGE_DARK, bevel=0.28, yaw_deg=yaw_deg)
    add_cube_obj(f"{name}_deck", (x, y + 0.54, z), (sx * 0.96, 0.18, sz * 0.94), MAT_BRIDGE, bevel=0.18, yaw_deg=yaw_deg)
    plank_count = 5 if sz >= sx else 4
    long_axis = sz if sz >= sx else sx
    step = long_axis / float(plank_count + 1)
    for i in range(plank_count):
        offset = -long_axis * 0.5 + step * (i + 1)
        local_x = 0.0 if sz >= sx else offset
        local_z = offset if sz >= sx else 0.0
        rad = math.radians(yaw_deg)
        wx = local_x * math.cos(rad) - local_z * math.sin(rad)
        wz = local_x * math.sin(rad) + local_z * math.cos(rad)
        plank_size = (sx * 1.03, 0.10, 0.18) if sz >= sx else (0.18, 0.10, sz * 1.03)
        add_cube_obj(f"{name}_plank_{i+1}", (x + wx, y + 0.72, z + wz), plank_size, MAT_BRIDGE_DARK, bevel=0.06, yaw_deg=yaw_deg)


def add_wall(name, pos, size, yaw_deg=0.0):
    add_cube_obj(f"{name}_body", pos, size, MAT_WALL, bevel=0.45, yaw_deg=yaw_deg)
    x, y, z = pos
    sx, sy, sz = size
    add_cube_obj(f"{name}_top_cap", (x, y + sy * 0.48, z), (sx * 0.86, 0.16, sz * 0.86), MAT_WALL_LIGHT, bevel=0.32, yaw_deg=yaw_deg)


def add_ground_patch(name, pos, size, material, yaw_deg=0.0):
    sx, sz = size
    add_cylinder_obj(name, pos, 0.5, 0.06, material, vertices=14, scale=(sx, sz, 1.0), yaw_deg=yaw_deg)


def add_tree(name, pos, scale=1.0):
    x, y, z = pos
    add_cylinder_obj(f"{name}_trunk", (x, y + 0.55 * scale, z), 0.22 * scale, 1.1 * scale, MAT_TRUNK, vertices=8)
    add_cylinder_obj(f"{name}_leaf_low", (x, y + 1.35 * scale, z), 0.75 * scale, 0.9 * scale, MAT_LEAF, vertices=7, scale=(1.0, 1.0, 1.0))
    add_cylinder_obj(f"{name}_leaf_high", (x, y + 2.05 * scale, z), 0.55 * scale, 0.75 * scale, MAT_LEAF, vertices=7, scale=(1.0, 1.0, 1.0))


def add_rock(name, pos, scale=1.0, yaw_deg=0.0):
    add_cube_obj(f"{name}_rock_a", pos, (1.15 * scale, 0.55 * scale, 0.9 * scale), MAT_ROCK, bevel=0.22, yaw_deg=yaw_deg)
    x, y, z = pos
    add_cube_obj(f"{name}_rock_b", (x + 0.45 * scale, y + 0.12 * scale, z - 0.22 * scale), (0.75 * scale, 0.42 * scale, 0.65 * scale), MAT_ROCK, bevel=0.18, yaw_deg=yaw_deg + 18)


def build_scene():
    add_cube_obj("arena_backdrop_visual_plate", gpos(0, -2.86, 0), (130.0, 0.16, 130.0), MAT_GROUND, bevel=0.0)

    for spec in [
        ("path_center_cross_ns", gpos(0, -2.72, 0), (10.4, 0.08, 55.0), 0),
        ("path_center_cross_ew", gpos(0, -2.71, 0), (55.0, 0.08, 10.4), 0),
        ("path_diag_nw_se", gpos(0, -2.70, 0), (8.9, 0.08, 62.0), 45),
        ("path_diag_ne_sw", gpos(0, -2.69, 0), (8.9, 0.08, 62.0), -45),
    ]:
        add_cube_obj(spec[0], spec[1], spec[2], MAT_PATH, bevel=0.45, yaw_deg=spec[3])

    add_island("center_island", gpos(0, -1, 0), (35.0, 2.0, 35.0))
    add_island("north_island", gpos(0, -1, -28), (17.5, 2.0, 17.5))
    add_island("south_island", gpos(0, -1, 28), (17.5, 2.0, 17.5))
    add_island("west_island", gpos(-28, -1, 0), (17.5, 2.0, 17.5))
    add_island("east_island", gpos(28, -1, 0), (17.5, 2.0, 17.5))

    add_bridge("bridge_cn", gpos(0, 0, -17.5), (9.375, 1.0, 9.375))
    add_bridge("bridge_cs", gpos(0, 0, 17.5), (9.375, 1.0, 9.375))
    add_bridge("bridge_cw", gpos(-17.5, 0, 0), (9.375, 1.0, 9.375))
    add_bridge("bridge_ce", gpos(17.5, 0, 0), (9.375, 1.0, 9.375))
    add_bridge("bridge_nw", gpos(-14, 0, -14), (8.125, 1.0, 22.5), -45)
    add_bridge("bridge_ne", gpos(14, 0, -14), (8.125, 1.0, 22.5), 45)
    add_bridge("bridge_sw", gpos(-14, 0, 14), (8.125, 1.0, 22.5), -135)
    add_bridge("bridge_se", gpos(14, 0, 14), (8.125, 1.0, 22.5), 135)

    for name, pos, size in [
        ("cover_north", gpos(0, -0.8, -6.5), (5.6, 1.8, 3.0)),
        ("cover_south", gpos(0, -0.8, 6.5), (5.6, 1.8, 3.0)),
        ("cover_west", gpos(-6.5, -0.8, 0), (3.0, 1.8, 5.6)),
        ("cover_east", gpos(6.5, -0.8, 0), (3.0, 1.8, 5.6)),
        ("spawn_wall_west", gpos(-31, -0.8, 0), (3.5, 1.8, 5.25)),
        ("spawn_wall_east", gpos(31, -0.8, 0), (3.5, 1.8, 5.25)),
        ("spawn_wall_north", gpos(0, -0.8, -31), (5.25, 1.8, 3.5)),
        ("spawn_wall_south", gpos(0, -0.8, 31), (5.25, 1.8, 3.5)),
    ]:
        add_wall(name, pos, size)

    for i, (x, z, scale) in enumerate([
        (-46, -30, 1.65), (-46, 30, 1.65), (46, -30, 1.65), (46, 30, 1.65),
        (-29, -46, 1.5), (29, -46, 1.5), (-29, 46, 1.5), (29, 46, 1.5),
        (-53, -8, 1.35), (-53, 11, 1.45), (53, -11, 1.45), (53, 8, 1.35),
    ]):
        add_tree(f"perimeter_tree_{i+1}", gpos(x, -2.55, z), scale)

    for i, (x, z, scale, yaw) in enumerate([
        (-40, -14, 1.6, 12), (-40, 14, 1.4, -18), (40, -14, 1.4, 20), (40, 14, 1.6, -12),
        (-14, -40, 1.45, 30), (14, -40, 1.4, -26), (-14, 40, 1.4, 26), (14, 40, 1.45, -20),
    ]):
        add_rock(f"perimeter_rock_{i+1}", gpos(x, -2.35, z), scale, yaw)

    for i, (x, z, sx, sz, yaw) in enumerate([
        (-30, -22, 10, 6, 15), (30, -22, 9, 5, -12), (-30, 22, 9, 5, -8), (30, 22, 10, 6, 10),
        (-16, 0, 8, 4, 8), (16, 0, 8, 4, -8), (0, -16, 4, 8, 0), (0, 16, 4, 8, 0),
    ]):
        add_ground_patch(f"authored_ground_patch_{i+1}", gpos(x, -2.50, z), (sx * MAP_SCALE, sz * MAP_SCALE), MAT_PATH, yaw)


def export_glb():
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parents[1])
    clear_scene()
    build_scene()
    export_glb()
    print(f"Exported {OUT_PATH}")
