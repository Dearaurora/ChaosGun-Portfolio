import math
import os
from pathlib import Path

import bpy


OUT_PATH = Path("assets/models/generated/open_ringout_slice/open_ringout_visuals.glb")


def srgb(hex_color, alpha=1.0):
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16) / 255.0
    g = int(hex_color[2:4], 16) / 255.0
    b = int(hex_color[4:6], 16) / 255.0
    return (srgb_channel_to_linear(r), srgb_channel_to_linear(g), srgb_channel_to_linear(b), alpha)


def srgb_channel_to_linear(value):
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, roughness=0.9, alpha_blend=False):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    if "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = color[3]
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    if alpha_blend or color[3] < 1.0:
        if hasattr(material, "blend_method"):
            material.blend_method = "BLEND"
        if hasattr(material, "show_transparent_back"):
            material.show_transparent_back = True
    return material


def emissive_mat(name, color, emission_color, strength=1.0, alpha_blend=False):
    material = mat(name, color, 0.74, alpha_blend)
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = emission_color
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = strength
    return material


MAT_DECK = mat("open_ringout_warm_deck", srgb("#c7a47a"), 0.86)
MAT_DECK_LIGHT = mat("open_ringout_light_deck", srgb("#d7c094"), 0.88)
MAT_SIDE = mat("open_ringout_chunky_side", srgb("#5d4b58"), 0.95)
MAT_SIDE_DARK = mat("open_ringout_deep_side", srgb("#35384f"), 0.96)
MAT_BRIDGE = mat("open_ringout_bridge_orange", srgb("#ad7b57"), 0.84)
MAT_EDGE = emissive_mat("open_ringout_soft_edge_glow", srgb("#f26f2f"), srgb("#f26f2f"), 0.85)
MAT_EDGE_GLOW = emissive_mat("open_ringout_outer_edge_glow", srgb("#ff7d2a", 0.72), srgb("#ff7d2a"), 1.45, True)
MAT_RED = mat("open_ringout_toy_red", srgb("#dd4534"), 0.72)
MAT_ORANGE = mat("open_ringout_toy_orange", srgb("#dc7a2c"), 0.72)
MAT_YELLOW = mat("open_ringout_toy_yellow", srgb("#d2b34d"), 0.78)
MAT_TAN = mat("open_ringout_toy_tan", srgb("#d1a970"), 0.82)
MAT_LINE = mat("open_ringout_tile_groove", srgb("#7d6049"), 0.96)
MAT_METAL = mat("open_ringout_soft_metal", srgb("#8f9690"), 0.58)
MAT_BLUE = mat("open_ringout_blue_insert", srgb("#3aa6d4"), 0.58)
MAT_BRIDGE_PLATE = mat("open_ringout_bridge_transition_reinforcement", srgb("#a97855"), 0.68)
MAT_WHITE = mat("open_ringout_warm_white", srgb("#ffe8a8"), 0.72)
MAT_CLOUD_CREAM = mat("open_ringout_warm_cloud_cream", srgb("#f2ad91", 0.11), 0.98, True)
MAT_CLOUD_PINK = mat("open_ringout_warm_cloud_pink", srgb("#b77495", 0.09), 0.98, True)
MAT_CLOUD_BLUE = mat("open_ringout_cool_cloud_blue", srgb("#7692d8", 0.08), 0.98, True)
MAT_CLOUD_SHADOW = mat("open_ringout_depth_cloud_shadow", srgb("#28385f", 0.10), 0.99, True)
MAT_DISTANCE_CLIFF = mat("open_ringout_distance_cliff", srgb("#4d426b", 0.86), 0.96, True)
MAT_DISTANCE_GRASS = mat("open_ringout_distance_grass", srgb("#536f58", 0.70), 0.92, True)
MAT_ABYSS_GLOW_BLUE = emissive_mat("open_ringout_abyss_glow_blue", srgb("#9fdcff", 0.72), srgb("#9fdcff"), 1.6, True)
MAT_ABYSS_GLOW_WARM = emissive_mat("open_ringout_abyss_glow_warm", srgb("#ffd36a", 0.68), srgb("#ffd36a"), 1.35, True)
MAT_A1_EDGE_BEACON = emissive_mat("a1_edge_beacon_warm", srgb("#ffb347", 0.86), srgb("#ff8a2a"), 1.55, True)
MAT_A1_RIM_BLUE = emissive_mat("a1_abyss_rim_blue", srgb("#82ccff", 0.62), srgb("#82ccff"), 1.25, True)
MAT_A1_PANEL_SHADE = mat("a1_surface_panel_shade", srgb("#aa8a68", 0.42), 0.93, True)
MAT_A1_PANEL_HIGHLIGHT = mat("a1_surface_panel_highlight", srgb("#f2d5a2", 0.52), 0.86, True)
MAT_A1_CANDY_BLUE = mat("a1_toy_candy_blue", srgb("#35a7d6"), 0.62)
MAT_A1_CANDY_GREEN = mat("a1_toy_candy_green", srgb("#77b96a"), 0.70)
MAT_A1_CANDY_PURPLE = mat("a1_toy_candy_purple", srgb("#8f72d6"), 0.72)
MAT_A1_SOFT_SHADOW = mat("a1_soft_contact_shadow", srgb("#3b3150", 0.22), 0.98, True)
MAT_A1_FLAG_RED = mat("a1_toy_flag_red", srgb("#e34e47"), 0.68)
MAT_A1_FLAG_WHITE = mat("a1_toy_flag_white", srgb("#ffe9bd"), 0.74)


def bpos(pos):
    x, y, z = pos
    return (x, -z, y)


def bscale(size):
    x, y, z = size
    return (x, z, y)


def add_cube(name, pos, size, material, bevel=0.0, yaw_deg=0.0):
    bpy.ops.mesh.primitive_cube_add(
        size=1.0,
        location=bpos(pos),
        rotation=(0.0, 0.0, math.radians(-yaw_deg)),
    )
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = bscale(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0.0:
        modifier = obj.modifiers.new(name="toy_bevel", type="BEVEL")
        modifier.width = bevel
        modifier.segments = 5
        modifier.affect = "EDGES"
        normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return obj


def add_cylinder(name, pos, radius, depth, material, vertices=24, scale=(1.0, 1.0, 1.0), yaw_deg=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=bpos(pos),
        rotation=(math.radians(90), 0.0, math.radians(-yaw_deg)),
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    return obj


def add_vertical_cylinder(name, pos, radius, depth, material, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=depth,
        location=bpos(pos),
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(material)
    obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    return obj


def add_warning_cone(name, ground_pos, yaw_deg=0.0):
    x, y, z = ground_pos
    body_depth = 1.14
    body_center = (x, y + body_depth * 0.5, z)
    bpy.ops.mesh.primitive_cone_add(
        vertices=18,
        radius1=0.54,
        radius2=0.16,
        depth=body_depth,
        location=bpos(body_center),
        rotation=(0.0, 0.0, math.radians(-yaw_deg)),
    )
    body = bpy.context.object
    body.name = f"{name}_body"
    body.data.materials.append(MAT_RED)
    body.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    add_vertical_cylinder(f"{name}_stripe", (x, y + 0.44, z), 0.42, 0.12, MAT_WHITE, 18)
    add_vertical_cylinder(f"{name}_base", (x, y + 0.05, z), 0.64, 0.10, MAT_TAN, 18)
    return body


def add_bridge_transition_plate(name, pos, size, stripe_size):
    add_cube(f"{name}_body", pos, size, MAT_BRIDGE_PLATE, bevel=0.006)


def add_bridge_connector(name, pos, size, axis):
    x, y, z = pos
    sx, _sy, sz = size
    trim_height = 0.04
    if axis == "x":
        add_cube(f"{name}_body", (x, y, z), (sx * 0.78, trim_height, 0.32), MAT_BRIDGE_PLATE, bevel=0.006)
        add_cube(f"{name}_side_a", (x, y, z - sz * 0.42), (sx * 0.82, trim_height, 0.20), MAT_BRIDGE_PLATE, bevel=0.006)
        add_cube(f"{name}_side_b", (x, y, z + sz * 0.42), (sx * 0.82, trim_height, 0.20), MAT_BRIDGE_PLATE, bevel=0.006)
    else:
        add_cube(f"{name}_body", (x, y, z), (0.32, trim_height, sz * 0.78), MAT_BRIDGE_PLATE, bevel=0.006)
        add_cube(f"{name}_side_a", (x - sx * 0.42, y, z), (0.20, trim_height, sz * 0.82), MAT_BRIDGE_PLATE, bevel=0.006)
        add_cube(f"{name}_side_b", (x + sx * 0.42, y, z), (0.20, trim_height, sz * 0.82), MAT_BRIDGE_PLATE, bevel=0.006)


def add_ellipsoid(name, pos, size, material, segments=32, rings=12, yaw_deg=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        location=bpos(pos),
        rotation=(0.0, 0.0, math.radians(-yaw_deg)),
    )
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = bscale(size)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def _chamfered_rect_points(cx, cz, sx, sz, cut):
    hx = sx * 0.5
    hz = sz * 0.5
    c = min(cut, hx * 0.48, hz * 0.48)
    return [
        (cx - hx + c, cz - hz),
        (cx + hx - c, cz - hz),
        (cx + hx, cz - hz + c),
        (cx + hx, cz + hz - c),
        (cx + hx - c, cz + hz),
        (cx - hx + c, cz + hz),
        (cx - hx, cz + hz - c),
        (cx - hx, cz - hz + c),
    ]


def add_prism(name, points_xz, center_y, height, material, bevel=0.0):
    bottom_y = center_y - height * 0.5
    top_y = center_y + height * 0.5
    vertices = []
    for x, z in points_xz:
        vertices.append((x, -z, bottom_y))
    for x, z in points_xz:
        vertices.append((x, -z, top_y))

    count = len(points_xz)
    faces = [list(reversed(range(count))), list(range(count, count * 2))]
    for i in range(count):
        j = (i + 1) % count
        faces.append([i, j, j + count, i + count])

    mesh = bpy.data.meshes.new(f"{name}_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    if bevel > 0.0:
        modifier = obj.modifiers.new(name="toy_bevel", type="BEVEL")
        modifier.width = bevel
        modifier.segments = 5
        modifier.affect = "EDGES"
    normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def add_platform_inset_glow(name, pos, size):
    x, y, z = pos
    sx, sy, sz = size
    y_top = y + sy * 0.5 + 0.24
    inset_z = min(2.4, sz * 0.20)
    segment_len = min(max(sx * 0.18, 3.2), 7.2)
    segment_offset = min(sx * 0.23, sx * 0.5 - segment_len * 0.62)
    strip_width = 0.28

    for suffix, z_pos in [
        ("north", z - sz * 0.5 + inset_z),
        ("south", z + sz * 0.5 - inset_z),
    ]:
        add_cube(
            f"{name}_inset_glow_{suffix}_a",
            (x - segment_offset, y_top, z_pos),
            (segment_len, 0.16, strip_width),
            MAT_EDGE,
            bevel=0.08,
        )
        add_cube(
            f"{name}_inset_glow_{suffix}_b",
            (x + segment_offset, y_top, z_pos),
            (segment_len, 0.16, strip_width),
            MAT_EDGE,
            bevel=0.08,
        )


def add_platform_outer_edge_glow(name, pos, size):
    x, y, z = pos
    sx, sy, sz = size
    y_top = y + sy * 0.5 + 0.36
    strip_width = 0.24
    strip_height = 0.12
    long_segment = max(min(sx * 0.28, 9.2), min(sx * 0.38, 5.0))
    short_segment = max(min(sz * 0.28, 7.2), min(sz * 0.38, 4.0))
    x_offset = sx * 0.24
    z_offset = sz * 0.24
    edge_inset = 0.18

    for suffix, z_pos in [
        ("north_a", z - sz * 0.5 + edge_inset),
        ("south_a", z + sz * 0.5 - edge_inset),
    ]:
        add_cube(
            f"{name}_outer_edge_glow_{suffix}",
            (x - x_offset, y_top, z_pos),
            (long_segment, strip_height, strip_width),
            MAT_EDGE_GLOW,
            bevel=0.08,
        )
        add_cube(
            f"{name}_outer_edge_glow_{suffix.replace('_a', '_b')}",
            (x + x_offset, y_top, z_pos),
            (long_segment, strip_height, strip_width),
            MAT_EDGE_GLOW,
            bevel=0.08,
        )

    for suffix, x_pos in [
        ("west_a", x - sx * 0.5 + edge_inset),
        ("east_a", x + sx * 0.5 - edge_inset),
    ]:
        add_cube(
            f"{name}_outer_edge_glow_{suffix}",
            (x_pos, y_top, z - z_offset),
            (strip_width, strip_height, short_segment),
            MAT_EDGE_GLOW,
            bevel=0.08,
        )
        add_cube(
            f"{name}_outer_edge_glow_{suffix.replace('_a', '_b')}",
            (x_pos, y_top, z + z_offset),
            (strip_width, strip_height, short_segment),
            MAT_EDGE_GLOW,
            bevel=0.08,
        )


def add_platform_cliff_blocks(name, pos, size, side_mat):
    if "bridge" in name:
        return

    x, y, z = pos
    sx, _sy, sz = size
    front_z = z + sz * 0.48
    back_z = z - sz * 0.48
    west_x = x - sx * 0.48
    east_x = x + sx * 0.48
    front_width = max(2.4, sx * 0.12)
    side_width = max(2.2, sz * 0.13)

    for i, frac in enumerate([-0.34, -0.18, 0.02, 0.22, 0.38]):
        block_height = 3.6 + (i % 3) * 0.55
        block_z = front_z + (0.18 if i % 2 == 0 else -0.02)
        add_cube(
            f"{name}_cliff_block_south_{i}",
            (x + sx * frac, y - 2.45 - block_height * 0.34, block_z),
            (front_width, block_height, 1.65),
            side_mat,
            bevel=0.32,
        )

    for i, frac in enumerate([-0.30, 0.02, 0.31]):
        block_height = 3.0 + (i % 2) * 0.65
        add_cube(
            f"{name}_cliff_block_north_{i}",
            (x + sx * frac, y - 2.70 - block_height * 0.30, back_z - 0.08),
            (front_width * 0.86, block_height, 1.35),
            side_mat,
            bevel=0.28,
        )

    for i, frac in enumerate([-0.28, 0.10, 0.34]):
        block_height = 3.4 + (i % 2) * 0.55
        add_cube(
            f"{name}_cliff_block_west_{i}",
            (west_x - 0.08, y - 2.55 - block_height * 0.32, z + sz * frac),
            (1.35, block_height, side_width),
            side_mat,
            bevel=0.28,
        )
        add_cube(
            f"{name}_cliff_block_east_{i}",
            (east_x + 0.08, y - 2.55 - block_height * 0.32, z + sz * frac),
            (1.35, block_height, side_width),
            side_mat,
            bevel=0.28,
        )


def add_concept_outer_edge_glows():
    for name, pos, size in [
        ("concept_outer_edge_glow_main_south_a", (-14.0, 0.36, 18.05), (10.5, 0.12, 0.24)),
        ("concept_outer_edge_glow_main_south_b", (12.0, 0.36, 18.05), (12.0, 0.12, 0.24)),
        ("concept_outer_edge_glow_north_a", (-1.2, 0.36, -37.30), (8.6, 0.12, 0.24)),
        ("concept_outer_edge_glow_north_b", (9.3, 0.36, -37.30), (8.6, 0.12, 0.24)),
        ("concept_outer_edge_glow_east_north", (38.0, 0.36, -5.80), (8.8, 0.12, 0.24)),
        ("concept_outer_edge_glow_east_south", (38.0, 0.36, 11.80), (8.8, 0.12, 0.24)),
        ("concept_outer_edge_glow_south_a", (3.2, 0.36, 37.80), (9.4, 0.12, 0.24)),
        ("concept_outer_edge_glow_south_b", (14.8, 0.36, 37.80), (9.4, 0.12, 0.24)),
        ("concept_outer_edge_glow_west_north", (-39.0, 0.36, -7.80), (7.6, 0.12, 0.24)),
        ("concept_outer_edge_glow_west_south", (-39.0, 0.36, 11.80), (7.6, 0.12, 0.24)),
    ]:
        add_cube(name, pos, size, MAT_EDGE_GLOW, bevel=0.08)


def add_capsule_like(name, pos, length, radius, material, yaw_deg=0.0, y_scale=1.0):
    add_cube(f"{name}_body", pos, (length, radius * 2.0 * y_scale, radius * 2.0), material, bevel=radius * 0.7, yaw_deg=yaw_deg)
    offset = length * 0.5 - radius
    dx = math.cos(math.radians(yaw_deg)) * offset
    dz = math.sin(math.radians(yaw_deg)) * offset
    add_cylinder(f"{name}_cap_a", (pos[0] - dx, pos[1], pos[2] - dz), radius, radius * 2.0 * y_scale, material, 24, (1, 1, 1), yaw_deg)
    add_cylinder(f"{name}_cap_b", (pos[0] + dx, pos[1], pos[2] + dz), radius, radius * 2.0 * y_scale, material, 24, (1, 1, 1), yaw_deg)


def add_platform(name, pos, size, top_mat, side_mat, inset_glow=True):
    x, y, z = pos
    sx, sy, sz = size
    cut = min(sx, sz) * 0.18
    side_points = _chamfered_rect_points(x, z, sx * 0.96, sz * 0.96, cut * 0.82)
    top_points = _chamfered_rect_points(x, z, sx, sz, cut)
    add_prism(f"{name}_irregular_side_mass", side_points, y - 3.8, 6.2, side_mat, bevel=min(sx, sz) * 0.055)
    add_prism(f"{name}_irregular_top_slab", top_points, y + 0.15, sy, top_mat, bevel=min(sx, sz) * 0.075)
    add_platform_cliff_blocks(name, pos, size, side_mat)
    if inset_glow:
        add_platform_inset_glow(name, pos, size)


def add_bridge_platform(name, pos, size, top_mat, side_mat):
    x, y, z = pos
    sx, _sy, sz = size
    top_y = 0.18
    top_thickness = 0.82
    add_cube(
        f"{name}_irregular_side_mass",
        (x, -2.50, z),
        (sx * 0.92, 5.15, sz * 0.92),
        side_mat,
        bevel=min(sx, sz) * 0.045,
    )
    add_cube(
        f"{name}_irregular_top_slab",
        (x, top_y - top_thickness * 0.5, z),
        (sx, top_thickness, sz),
        top_mat,
        bevel=0.12,
    )


def add_tile_lines():
    for x in [-18, -9, 0, 9, 18]:
        add_cube(f"tile_line_x_{x}", (x, 1.35, 0), (0.08, 0.035, 30), MAT_LINE, bevel=0.03)
    for z in [-12, -4, 4, 12]:
        add_cube(f"tile_line_z_{z}", (0, 1.36, z), (45, 0.035, 0.08), MAT_LINE, bevel=0.03)


def add_center_pickup_pad():
    add_cylinder("center_pickup_base", (0, 1.55, 0), 2.85, 0.38, MAT_METAL, 32)
    add_cylinder("center_pickup_glow_disc", (0, 1.83, 0), 1.92, 0.12, MAT_EDGE, 32)
    add_cube("center_pickup_gun_body", (0, 2.05, 0), (1.85, 0.30, 0.48), MAT_BLUE, bevel=0.10)
    add_cube("center_pickup_gun_grip", (-0.48, 1.83, 0.22), (0.32, 0.46, 0.22), MAT_RED, bevel=0.06)
    add_cube("center_pickup_gun_barrel", (1.02, 2.05, 0), (0.66, 0.16, 0.24), MAT_WHITE, bevel=0.05)


def add_props():
    for name, pos, length, radius, material, yaw in [
        ("bumper_north", (-13, 1.75, -16.8), 9.0, 0.92, MAT_RED, 0),
        ("bumper_center_north", (5, 1.75, -13.5), 7.0, 0.92, MAT_RED, 0),
        ("bumper_center", (7, 1.75, -1.5), 8.0, 1.05, MAT_ORANGE, 0),
        ("bumper_south", (-4, 1.75, 16.7), 13.0, 0.88, MAT_ORANGE, 0),
    ]:
        add_capsule_like(name, pos, length, radius, material, yaw)

    for name, pos, size, material, yaw in [
        ("crate_left_a", (-17, 1.70, 6), (2.8, 2.0, 2.8), MAT_YELLOW, 0),
        ("crate_left_b", (-14.2, 1.70, 6), (2.8, 2.0, 2.8), MAT_YELLOW, 0),
        ("crate_wood", (-6, 1.68, 12), (5.0, 1.9, 2.8), MAT_TAN, 2),
        ("orange_block", (16.5, 1.72, -13.5), (3.4, 2.5, 3.4), MAT_ORANGE, 8),
        ("tan_block", (19, 1.66, 2), (5.2, 2.0, 4.0), MAT_TAN, -4),
    ]:
        add_cube(name, pos, size, material, bevel=min(size[0], size[2]) * 0.14, yaw_deg=yaw)

    for name, pos, yaw in [
        ("BridgeWarningConeNorthL", (-1.2, 0.15, -24.5), 180),
        ("BridgeWarningConeNorthR", (9.2, 0.15, -24.5), 180),
        ("BridgeWarningConeEastT", (35.4, 0.15, -3.6), -90),
        ("BridgeWarningConeEastB", (35.4, 0.15, 7.6), -90),
        ("BridgeWarningConeSouthL", (1.5, 0.15, 25.0), 0),
        ("BridgeWarningConeSouthR", (12.5, 0.15, 25.0), 0),
        ("BridgeWarningConeWestT", (-34.2, 0.15, -3.6), 90),
        ("BridgeWarningConeWestB", (-34.2, 0.15, 7.6), 90),
    ]:
        add_warning_cone(name, pos, yaw)

    for i, (x, z) in enumerate([
        (-23, -15), (23, -15), (-23, 15), (23, 15), (-44, -4), (-44, 8),
        (43, -5), (43, 10), (0, -35), (10, -35), (2, 35), (16, 35),
    ]):
        add_cylinder(f"gold_bolt_{i}", (x, 1.58, z), 0.42, 0.18, MAT_YELLOW, 12)


def add_chunky_cover_clusters():
    add_cube("EastCombatLaneFloorInset", (22.0, 1.50, 10.5), (12.5, 0.08, 4.0), MAT_DECK, bevel=0.28, yaw_deg=-8)

    add_cube("ChunkyCoverClusterWest", (-13.3, 1.70, 5.6), (4.8, 1.62, 2.9), MAT_YELLOW, bevel=0.50, yaw_deg=5)
    add_cube("ChunkyCoverClusterWest_CushionA", (-15.7, 1.78, 5.7), (1.40, 1.46, 2.25), MAT_ORANGE, bevel=0.38, yaw_deg=5)
    add_cube("ChunkyCoverClusterWest_CushionB", (-11.0, 1.78, 5.4), (1.35, 1.46, 2.25), MAT_ORANGE, bevel=0.38, yaw_deg=5)
    add_cylinder("ChunkyCoverClusterWest_RoundCap", (-13.3, 2.60, 5.6), 1.22, 0.30, MAT_YELLOW, 24)


def add_background_depth():
    for name, pos, size, mat_cloud, yaw in [
        ("WarmCloudBankNorth", (8, -10.95, -61), (48, 1.05, 12.0), MAT_CLOUD_CREAM, -4),
        ("WarmCloudBankSouth", (-5, -10.92, 61), (54, 1.05, 12.5), MAT_CLOUD_PINK, 4),
        ("CoolCloudBankLeft", (-61, -11.02, 0), (15, 0.88, 40.0), MAT_CLOUD_BLUE, -8),
        ("CoolCloudBankRight", (62, -11.02, 5), (15, 0.88, 42.0), MAT_CLOUD_BLUE, 9),
    ]:
        add_ellipsoid(name, pos, size, mat_cloud, 32, 12, yaw)

    for i, (x, y, z, sx, sz, mat_cloud) in enumerate([
        (-31, -10.78, -58, 17, 6, MAT_CLOUD_PINK),
        (37, -10.80, -60, 18, 6, MAT_CLOUD_CREAM),
        (-38, -10.78, 55, 19, 6, MAT_CLOUD_CREAM),
        (38, -10.80, 57, 17, 6, MAT_CLOUD_PINK),
        (-54, -10.74, -28, 15, 5, MAT_CLOUD_BLUE),
        (55, -10.76, -25, 16, 5, MAT_CLOUD_CREAM),
        (-50, -10.72, 35, 16, 5, MAT_CLOUD_PINK),
        (51, -10.75, 37, 15, 5, MAT_CLOUD_BLUE),
        (-12, -10.70, -66, 16, 5, MAT_CLOUD_CREAM),
        (17, -10.72, 66, 17, 5, MAT_CLOUD_PINK),
    ]):
        add_ellipsoid(f"FarAbyssCloudPuff_{i}", (x, y, z), (sx, 1.0, sz), mat_cloud, 24, 10, i * 9)

    for name, pos, size, yaw in [
        ("DistantToyIslandNE", (78, -11.4, -54), (12, 4.8, 8), -8),
        ("DistantToyIslandSW", (-76, -11.5, 64), (12, 4.6, 8), 10),
    ]:
        add_cube(name, pos, size, MAT_DISTANCE_CLIFF, bevel=1.2, yaw_deg=yaw)
        add_cube(f"{name}_GrassTop", (pos[0], pos[1] + size[1] * 0.52, pos[2]), (size[0] * 0.82, 0.34, size[2] * 0.78), MAT_DISTANCE_GRASS, bevel=0.8, yaw_deg=yaw)
        add_cylinder(f"{name}_ToyPropA", (pos[0] - size[0] * 0.20, pos[1] + size[1] * 0.72, pos[2] - size[2] * 0.08), 0.70, 1.15, MAT_RED, 16)
        add_cube(f"{name}_ChunkPropB", (pos[0] + size[0] * 0.18, pos[1] + size[1] * 0.70, pos[2] + size[2] * 0.12), (1.7, 1.3, 1.7), MAT_ORANGE, bevel=0.28, yaw_deg=-yaw)

    for name, pos, size, yaw in [
        ("FarFloatingIslandLeft", (-78, -11.0, -55), (13, 5.0, 8), -7),
        ("FarFloatingIslandRight", (80, -11.0, -53), (14, 5.1, 9), 8),
        ("FarFloatingIslandLowerLeft", (-72, -11.2, 65), (12, 4.7, 8), 11),
        ("FarFloatingIslandLowerRight", (75, -11.2, 64), (12, 4.7, 8), -10),
    ]:
        add_cube(f"{name}_cliff", pos, size, MAT_DISTANCE_CLIFF, bevel=1.15, yaw_deg=yaw)
        add_cube(
            f"{name}_grass",
            (pos[0], pos[1] + size[1] * 0.52, pos[2]),
            (size[0] * 0.82, 0.34, size[2] * 0.72),
            MAT_DISTANCE_GRASS,
            bevel=0.78,
            yaw_deg=yaw,
        )
        add_cube(
            f"{name}_ledge",
            (pos[0], pos[1] + size[1] * 0.18, pos[2] - size[2] * 0.24),
            (size[0] * 0.48, 0.36, 1.2),
            MAT_BRIDGE_PLATE,
            bevel=0.22,
            yaw_deg=yaw,
        )

    for i, (x, y, z, mat_glow) in enumerate([
        (-58, -9.7, -8, MAT_ABYSS_GLOW_BLUE),
        (-44, -9.4, 26, MAT_ABYSS_GLOW_WARM),
        (-22, -9.9, -48, MAT_ABYSS_GLOW_BLUE),
        (6, -9.7, 49, MAT_ABYSS_GLOW_WARM),
        (28, -9.5, -45, MAT_ABYSS_GLOW_BLUE),
        (47, -9.8, 28, MAT_ABYSS_GLOW_WARM),
        (61, -9.6, -9, MAT_ABYSS_GLOW_BLUE),
        (-7, -9.5, -57, MAT_ABYSS_GLOW_WARM),
    ]):
        add_ellipsoid(f"FarAbyssGlowMote_{i}", (x, y, z), (0.72, 0.72, 0.72), mat_glow, 16, 8, i * 19)


A1_PLATFORM_SPECS = [
    {"name": "main_deck", "title": "MainDeck", "pos": (0, -1, 0), "size": (52, 2, 36), "top": MAT_DECK, "side": MAT_SIDE, "inset": False},
    {"name": "main_west_lip", "title": "MainWestLip", "pos": (-20, -0.98, 9), "size": (18, 2, 20), "top": MAT_DECK, "side": MAT_SIDE, "inset": False},
    {"name": "main_east_lip", "title": "MainEastLip", "pos": (21, -0.98, -3), "size": (18, 2, 23), "top": MAT_DECK, "side": MAT_SIDE, "inset": False},
    {"name": "north_deck", "title": "NorthDeck", "pos": (4, -1, -30), "size": (22, 2, 15), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
    {"name": "east_deck", "title": "EastDeck", "pos": (38, -1, 3), "size": (20, 2, 18), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
    {"name": "south_deck", "title": "SouthDeck", "pos": (9, -1, 30), "size": (24, 2, 16), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
    {"name": "west_deck", "title": "WestDeck", "pos": (-39, -1, 2), "size": (18, 2, 20), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
]

A1_BRIDGE_SPECS = [
    {"name": "north_bridge", "title": "NorthBridge", "pos": (4, -0.65, -20.2), "size": (11, 1.3, 5.2), "axis": "x"},
    {"name": "east_bridge", "title": "EastBridge", "pos": (31.8, -0.65, 2), "size": (7.0, 1.3, 8.0), "axis": "z"},
    {"name": "south_bridge", "title": "SouthBridge", "pos": (7, -0.65, 20.0), "size": (11, 1.3, 5.0), "axis": "x"},
    {"name": "west_bridge", "title": "WestBridge", "pos": (-31.8, -0.65, 2), "size": (6.6, 1.3, 9.0), "axis": "z"},
]


def a1_title(spec):
    return spec["title"]


def build_scene():
    for spec in [
        ("main_deck", (0, -1, 0), (52, 2, 36), MAT_DECK, MAT_SIDE, False),
        ("main_west_lip", (-20, -0.98, 9), (18, 2, 20), MAT_DECK, MAT_SIDE, False),
        ("main_east_lip", (21, -0.98, -3), (18, 2, 23), MAT_DECK, MAT_SIDE, False),
        ("north_deck", (4, -1, -30), (22, 2, 15), MAT_DECK_LIGHT, MAT_SIDE_DARK),
        ("east_deck", (38, -1, 3), (20, 2, 18), MAT_DECK_LIGHT, MAT_SIDE_DARK),
        ("south_deck", (9, -1, 30), (24, 2, 16), MAT_DECK_LIGHT, MAT_SIDE_DARK),
        ("west_deck", (-39, -1, 2), (18, 2, 20), MAT_DECK_LIGHT, MAT_SIDE_DARK),
    ]:
        add_platform(*spec)

    for spec in [
        ("north_bridge", (4, -0.65, -20.2), (11, 1.3, 5.2), MAT_BRIDGE, MAT_SIDE),
        ("east_bridge", (31.8, -0.65, 2), (7.0, 1.3, 8.0), MAT_BRIDGE, MAT_SIDE),
        ("south_bridge", (7, -0.65, 20.0), (11, 1.3, 5.0), MAT_BRIDGE, MAT_SIDE),
        ("west_bridge", (-31.8, -0.65, 2), (6.6, 1.3, 9.0), MAT_BRIDGE, MAT_SIDE),
    ]:
        add_bridge_platform(*spec)

    add_concept_outer_edge_glows()
    add_tile_lines()
    add_props()
    add_chunky_cover_clusters()
    add_background_depth()


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
