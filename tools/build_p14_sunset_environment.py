from pathlib import Path
import math
import sys

import bpy
from mathutils import Vector


TOOLS_DIR = Path(__file__).resolve().parent
ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import build_sunset_toy_sky_islands_hero as hero


SOURCE_PATH = ROOT / "assets" / "source" / "sunset_toy_sky_islands" / "p14_sunset_environment.blend"
GLB_PATH = ROOT / "assets" / "models" / "generated" / "sunset_toy_sky_islands" / "p14_sunset_environment.glb"


def bpos(godot_pos):
    x, y, z = godot_pos
    return (x, -z, y)


def bsize(godot_size):
    x, y, z = godot_size
    return (x, z, y)


def materials():
    return {
        "cloud_cream": hero.make_material("p20_cloud_cream", "#F7D3C9", 0.98),
        "cloud_pink": hero.make_material("p20_cloud_pink", "#E9AEC8", 0.98),
        "cloud_violet": hero.make_material("p20_cloud_violet", "#CBAED9", 0.99),
        "cloud_cool": hero.make_material("p20_cloud_cool", "#BAC5EB", 0.99),
        "cliff": hero.make_material("p14_distance_cliff", "#41365F", 0.96),
        "cliff_light": hero.make_material("p14_distance_cliff_light", "#5A4B78", 0.95),
        "top": hero.make_material("p14_distance_top", "#A96152", 0.91),
        "top_light": hero.make_material("p14_distance_top_light", "#C98066", 0.89),
        "green": hero.make_material("p14_distance_green", "#516A50", 0.94),
        "green_light": hero.make_material("p14_distance_green_light", "#70845D", 0.93),
        "cliff_far": hero.make_material("p17_distance_cliff_far", "#574B73", 0.97),
        "cliff_light_far": hero.make_material("p17_distance_cliff_light_far", "#706489", 0.97),
        "top_far": hero.make_material("p17_distance_top_far", "#A97474", 0.94),
        "top_light_far": hero.make_material("p17_distance_top_light_far", "#C4948B", 0.94),
        "green_far": hero.make_material("p17_distance_green_far", "#657267", 0.96),
        "green_light_far": hero.make_material("p17_distance_green_light_far", "#829083", 0.96),
        "red": hero.make_material("p14_landmark_red", "#B94C43", 0.88),
        "gold": hero.make_material("p14_landmark_gold", "#E39A3D", 0.84),
        "blue": hero.make_material("p14_landmark_blue", "#4D70A7", 0.89),
        "cream": hero.make_material("p14_landmark_cream", "#F2D1AE", 0.92),
        "wood": hero.make_material("p14_landmark_wood", "#76504A", 0.91),
        "balloon_purple": hero.make_material("p14_balloon_purple", "#5B347F", 0.82),
        "balloon_coral": hero.make_material("p14_balloon_coral", "#C95562", 0.84),
        "balloon_gold": hero.make_material("p14_balloon_gold", "#F0A33B", 0.78),
        "balloon_rope": hero.make_material("p14_balloon_rope", "#F0D39B", 0.93),
        "balloon_basket": hero.make_material("p14_balloon_basket", "#8A5538", 0.91),
        "balloon_basket_dark": hero.make_material("p14_balloon_basket_dark", "#4D3544", 0.88),
    }


CLOUD_FORMS = (
    (
        (-1.48, -0.28, -0.08, 0.70),
        (-0.92, 0.30, 0.30, 0.90),
        (-0.18, -0.08, 0.64, 1.10),
        (0.58, 0.38, 0.32, 0.86),
        (1.36, -0.18, 0.06, 0.66),
        (0.08, -0.62, -0.10, 0.76),
    ),
    (
        (-1.42, 0.32, 0.08, 0.72),
        (-0.80, -0.36, 0.52, 1.02),
        (0.02, 0.10, 0.30, 0.88),
        (0.72, 0.46, 0.68, 1.08),
        (1.44, -0.20, 0.08, 0.66),
        (0.24, -0.62, -0.12, 0.74),
    ),
    (
        (-1.38, 0.40, 0.24, 0.82),
        (-0.72, -0.34, 0.02, 0.82),
        (0.00, 0.06, 0.66, 1.12),
        (0.76, 0.42, 0.34, 0.90),
        (1.42, -0.24, 0.00, 0.64),
        (-0.16, -0.66, -0.10, 0.72),
    ),
)


def add_authored_cloud(name, center, scale, material, collection, variant=0, yaw=0.0):
    angle = math.radians(yaw)
    created = []
    for index, (offset_x, offset_z, offset_y, radius) in enumerate(CLOUD_FORMS[variant % len(CLOUD_FORMS)]):
        rotated_x = (offset_x * math.cos(angle) - offset_z * math.sin(angle)) * 0.82
        rotated_z = (offset_x * math.sin(angle) + offset_z * math.cos(angle)) * 0.82
        puff_position = (
            center[0] + rotated_x * scale,
            center[1] + offset_y * scale * 0.72,
            center[2] + rotated_z * scale,
        )
        puff_scale = (
            1.24 * scale * radius,
            0.66 * scale * radius,
            1.10 * scale * radius,
        )
        blender_scale = bsize(puff_scale)
        puff = hero.add_sphere(
            f"{name}_Puff{index}",
            bpos(puff_position),
            blender_scale,
            material,
            collection,
            18,
            10,
        )
        created.append(puff)
    bpy.ops.object.select_all(action="DESELECT")
    for puff in created:
        puff.select_set(True)
    bpy.context.view_layer.objects.active = created[0]
    bpy.ops.object.join()
    cloud = bpy.context.object
    cloud.name = name
    cloud.data.name = f"{name}Mesh"
    cloud.data.materials.clear()
    cloud.data.materials.append(material)
    for polygon in cloud.data.polygons:
        polygon.material_index = 0
    cloud.data.update()
    return cloud


def add_tree(name, position, scale, collection, mats):
    hero.add_cylinder(
        f"{name}Trunk",
        bpos((position[0], position[1] - 0.55 * scale, position[2])),
        0.24 * scale,
        1.35 * scale,
        mats["wood"],
        collection,
        bevel=0.10 * scale,
        vertices=18,
    )
    for tier, (height, radius) in enumerate(((0.35, 1.20), (1.12, 0.92), (1.78, 0.64))):
        hero.add_cone(
            f"{name}Crown{tier}",
            bpos((position[0], position[1] + height * scale, position[2])),
            radius * scale,
            0.10 * scale,
            1.65 * scale,
            mats["green"] if tier < 2 else mats["green_light"],
            collection,
        )


def add_windmill(name, position, scale, collection, mats):
    x, y, z = position
    hero.add_rounded_box(
        f"{name}Tower",
        bpos((x, y + 1.0 * scale, z)),
        bsize((1.65 * scale, 3.8 * scale, 1.55 * scale)),
        mats["cream"],
        collection,
        0.26 * scale,
    )
    hero.add_cone(
        f"{name}Roof",
        bpos((x, y + 3.3 * scale, z)),
        1.25 * scale,
        0.18 * scale,
        1.55 * scale,
        mats["red"],
        collection,
    )
    hub_pos = (x, y + 2.45 * scale, z - 0.88 * scale)
    hero.add_sphere(f"{name}Hub", bpos(hub_pos), (0.38 * scale,) * 3, mats["gold"], collection, 20, 10)
    for index, angle in enumerate((45.0, 135.0)):
        hero.add_rounded_box(
            f"{name}Blade{index}",
            bpos(hub_pos),
            bsize((0.34 * scale, 4.0 * scale, 0.20 * scale)),
            mats["gold"],
            collection,
            0.10 * scale,
            rotation=(0.0, math.radians(angle), 0.0),
        )


def add_beacon(name, position, scale, collection, mats):
    x, y, z = position
    hero.add_rounded_box(
        f"{name}Base",
        bpos((x, y + 0.45 * scale, z)),
        bsize((1.6 * scale, 0.9 * scale, 1.6 * scale)),
        mats["blue"],
        collection,
        0.22 * scale,
    )
    hero.add_cylinder(
        f"{name}Stem",
        bpos((x, y + 1.85 * scale, z)),
        0.30 * scale,
        2.8 * scale,
        mats["cream"],
        collection,
        bevel=0.12 * scale,
        vertices=20,
    )
    hero.add_sphere(
        f"{name}Lamp",
        bpos((x, y + 3.35 * scale, z)),
        (0.65 * scale, 0.65 * scale, 0.72 * scale),
        mats["gold"],
        collection,
        24,
        12,
    )


def add_distant_island(name, center, scale, landmark, collection, mats):
    x, y, z = center
    hero.add_rounded_tapered_prism(
        f"{name}Cliff",
        bpos((x, y, z)),
        (9.6 * scale, 7.0 * scale),
        (4.2 * scale, 3.0 * scale),
        8.4 * scale,
        1.55 * scale,
        0.70 * scale,
        mats["cliff"],
        collection,
        0.20 * scale,
    )
    top_y = y + 4.35 * scale
    hero.add_rounded_tapered_prism(
        f"{name}Top",
        bpos((x, top_y, z)),
        (9.9 * scale, 7.3 * scale),
        (9.1 * scale, 6.5 * scale),
        0.62 * scale,
        2.25 * scale,
        1.95 * scale,
        mats["top"],
        collection,
        0.12 * scale,
    )
    hero.add_rounded_tapered_prism(
        f"{name}TopInset",
        bpos((x, top_y + 0.40 * scale, z)),
        (8.2 * scale, 5.8 * scale),
        (7.8 * scale, 5.4 * scale),
        0.22 * scale,
        1.85 * scale,
        1.65 * scale,
        mats["top_light"],
        collection,
        0.08 * scale,
    )
    for index, offset_x in enumerate((-2.4, 0.0, 2.4)):
        hero.add_cone(
            f"{name}CliffFacet{index}",
            bpos((x + offset_x * scale, y - 0.55 * scale, z + 0.35 * scale)),
            1.55 * scale,
            0.48 * scale,
            6.0 * scale,
            mats["cliff_light"] if index == 1 else mats["cliff"],
            collection,
        )
    landmark_y = top_y + 0.58 * scale
    if landmark == "windmill":
        add_windmill(f"{name}Windmill", (x, landmark_y, z), scale, collection, mats)
        add_tree(f"{name}Tree", (x - 2.8 * scale, landmark_y, z + 1.0 * scale), 0.75 * scale, collection, mats)
    elif landmark == "beacon":
        add_beacon(f"{name}Beacon", (x, landmark_y, z), scale, collection, mats)
        add_tree(f"{name}Tree", (x + 2.6 * scale, landmark_y, z - 0.6 * scale), 0.68 * scale, collection, mats)
    else:
        add_tree(f"{name}TreeA", (x - 1.8 * scale, landmark_y, z + 0.6 * scale), 1.0 * scale, collection, mats)
        add_tree(f"{name}TreeB", (x + 1.8 * scale, landmark_y, z - 0.8 * scale), 0.72 * scale, collection, mats)


def add_segmented_balloon_envelope(name, center, size, collection, mats):
    width, height, depth = size
    segments = 32
    panel_span = 4
    ring_profile = (
        (-0.47, 0.14),
        (-0.40, 0.50),
        (-0.24, 0.84),
        (-0.02, 1.00),
        (0.20, 0.94),
        (0.37, 0.67),
        (0.47, 0.24),
    )
    yaw = math.radians(7.0)
    vertices = []
    for y_normalized, radius in ring_profile:
        for segment in range(segments):
            angle = (math.tau * segment / segments) + yaw
            local_godot = (
                math.cos(angle) * width * 0.5 * radius,
                y_normalized * height,
                math.sin(angle) * depth * 0.5 * radius,
            )
            vertices.append(bpos(local_godot))

    faces = []
    material_indices = []
    for ring in range(len(ring_profile) - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            lower = ring * segments + segment
            upper = (ring + 1) * segments + segment
            faces.append((lower, ring * segments + next_segment, (ring + 1) * segments + next_segment, upper))
            material_indices.append((segment // panel_span) % 2)

    bottom_center = len(vertices)
    vertices.append(bpos((0.0, -height * 0.5, 0.0)))
    top_center = len(vertices)
    vertices.append(bpos((0.0, height * 0.5, 0.0)))
    for segment in range(segments):
        next_segment = (segment + 1) % segments
        faces.append((bottom_center, next_segment, segment))
        material_indices.append((segment // panel_span) % 2)
        top_ring = (len(ring_profile) - 1) * segments
        faces.append((top_center, top_ring + segment, top_ring + next_segment))
        material_indices.append((segment // panel_span) % 2)

    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = bpos(center)
    collection.objects.link(obj)
    obj.data.materials.append(mats["balloon_purple"])
    obj.data.materials.append(mats["balloon_coral"])
    for polygon, material_index in zip(obj.data.polygons, material_indices):
        polygon.material_index = material_index
        polygon.use_smooth = True

    seam_vertices = []
    seam_faces = []
    half_seam_angle = math.radians(1.25)
    for seam in range(segments // panel_span):
        seam_angle = (math.tau * seam / (segments // panel_span)) + yaw
        seam_start = len(seam_vertices)
        for y_normalized, radius in ring_profile:
            for angle_offset in (-half_seam_angle, half_seam_angle):
                angle = seam_angle + angle_offset
                expanded_radius = radius + 0.018
                local_godot = (
                    math.cos(angle) * width * 0.5 * expanded_radius,
                    y_normalized * height,
                    math.sin(angle) * depth * 0.5 * expanded_radius,
                )
                seam_vertices.append(bpos(local_godot))
        for ring in range(len(ring_profile) - 1):
            lower = seam_start + ring * 2
            seam_faces.append((lower, lower + 1, lower + 3, lower + 2))
    seam_mesh = bpy.data.meshes.new(f"{name}SeamsMesh")
    seam_mesh.from_pydata(seam_vertices, [], seam_faces)
    seam_mesh.update()
    seams = bpy.data.objects.new(f"{name}Seams", seam_mesh)
    seams.location = bpos(center)
    collection.objects.link(seams)
    hero.apply_material(seams, mats["balloon_gold"])
    for polygon in seams.data.polygons:
        polygon.use_smooth = True
    return obj


def add_cylinder_between(name, start, end, radius, material, collection):
    start_blender = Vector(bpos(start))
    end_blender = Vector(bpos(end))
    direction = end_blender - start_blender
    midpoint = (start_blender + end_blender) * 0.5
    obj = hero.add_cylinder(
        name,
        midpoint,
        radius,
        direction.length,
        material,
        collection,
        bevel=radius * 0.42,
        vertices=14,
    )
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def build_hot_air_balloon(collection, mats):
    center = (27.0, 8.8, -33.0)
    width, height, depth = (6.2, 8.0, 5.6)
    add_segmented_balloon_envelope(
        "P14HotAirBalloonEnvelope",
        center,
        (width, height, depth),
        collection,
        mats,
    )
    hero.add_sphere(
        "P14HotAirBalloonTopCap",
        bpos((center[0], center[1] + height * 0.50, center[2])),
        bsize((0.34, 0.30, 0.34)),
        mats["balloon_gold"],
        collection,
        20,
        10,
    )
    hero.add_cylinder(
        "P14HotAirBalloonLowerCollar",
        bpos((center[0], center[1] - height * 0.49, center[2])),
        0.58,
        0.34,
        mats["balloon_gold"],
        collection,
        bevel=0.10,
        vertices=24,
    )

    basket_center = (center[0], center[1] - 6.95, center[2])
    basket_top_y = basket_center[1] + 0.82
    hero.add_rounded_tapered_prism(
        "P14HotAirBalloonBasket",
        bpos(basket_center),
        (2.65, 2.15),
        (2.05, 1.62),
        1.55,
        0.34,
        0.26,
        mats["balloon_basket"],
        collection,
        0.10,
    )
    hero.add_rounded_box(
        "P14HotAirBalloonBasketRim",
        bpos((center[0], basket_top_y, center[2])),
        bsize((2.86, 0.28, 2.34)),
        mats["balloon_basket_dark"],
        collection,
        0.11,
    )
    hero.add_rounded_box(
        "P14HotAirBalloonBasketBase",
        bpos((center[0], basket_center[1] - 0.82, center[2])),
        bsize((2.15, 0.22, 1.70)),
        mats["balloon_basket_dark"],
        collection,
        0.08,
    )
    for index, offset_x in enumerate((-0.62, 0.62)):
        hero.add_rounded_box(
            f"P14HotAirBalloonBasketBand{index}",
            bpos((center[0] + offset_x, basket_center[1], center[2] + 0.88)),
            bsize((0.18, 1.18, 0.16)),
            mats["balloon_gold"],
            collection,
            0.05,
        )
    hero.add_rounded_box(
        "P14HotAirBalloonBurner",
        bpos((center[0], center[1] - 4.88, center[2])),
        bsize((1.12, 0.62, 0.92)),
        mats["balloon_basket_dark"],
        collection,
        0.16,
    )

    rope_top_y = center[1] - 3.45
    for index, (offset_x, offset_z) in enumerate(((-1.26, -0.92), (-1.26, 0.92), (1.26, -0.92), (1.26, 0.92))):
        add_cylinder_between(
            f"P14HotAirBalloonRope{index}",
            (center[0] + offset_x, rope_top_y, center[2] + offset_z),
            (center[0] + offset_x * 0.78, basket_top_y + 0.05, center[2] + offset_z * 0.78),
            0.065,
            mats["balloon_rope"],
            collection,
        )


def build_cloudscape(collection, mats):
    specs = (
        ("P14CloudBankNorthWest", (-56.56, -19.0, -35.47), 1.25, "cloud_pink", 2, 12.0),
        ("P14CloudBankNorth", (-40.92, -19.0, -45.29), 1.18, "cloud_cream", 1, 4.0),
        ("P14CloudBankNorthEast", (-25.19, -19.0, -57.94), 1.05, "cloud_violet", 2, 11.0),
        ("P14CloudBankWest", (-44.90, -19.3, 5.46), 2.05, "cloud_pink", 1, -18.0),
        ("P14CloudBankEast", (19.88, -19.3, -45.53), 2.05, "cloud_cream", 0, 16.0),
        ("P14CloudBankSouthWest", (-32.23, -19.6, 20.13), 2.20, "cloud_cool", 2, 12.0),
        ("P14CloudBankSouth", (11.00, -19.6, 15.40), 2.35, "cloud_violet", 1, -5.0),
        ("P14CloudBankSouthEast", (33.61, -19.6, -23.45), 2.20, "cloud_pink", 0, -12.0),
        ("P14CloudBankGapNorthWest", (-10.63, -19.0, -64.34), 0.90, "cloud_cool", 2, 18.0),
        ("P14CloudBankGapSouthEast", (-8.15, -19.0, -49.03), 1.08, "cloud_cream", 1, -15.0),
    )
    for name, center, scale, material_key, variant, yaw in specs:
        add_authored_cloud(
            name,
            center,
            scale,
            mats[material_key],
            collection,
            variant,
            yaw,
        )
def build_distant_islands(collection, mats):
    specs = (
        ("P14DistantIslandNorthWest", (-51.21, -14.5, -34.22), 0.42, "windmill", "far"),
        ("P14DistantIslandNorth", (-36.69, -14.0, -41.65), 0.60, "trees", "far"),
        ("P14DistantIslandNorthEastFar", (-25.50, -15.0, -53.71), 0.38, "beacon", "far"),
        ("P14DistantIslandNorthEast", (-9.78, -14.2, -58.49), 0.52, "trees", "far"),
        ("P14DistantIslandWest", (-36.96, -14.8, 12.25), 0.46, "trees", "near"),
        ("P14DistantIslandEast", (32.12, -14.5, -28.80), 0.48, "beacon", "near"),
        ("P14DistantIslandSouth", (30.80, -15.0, 11.79), 0.40, "trees", "near"),
    )
    for name, center, scale, landmark, depth_tier in specs:
        island_mats = dict(mats)
        if depth_tier == "far":
            island_mats.update(
                {
                    "cliff": mats["cliff_far"],
                    "cliff_light": mats["cliff_light_far"],
                    "top": mats["top_far"],
                    "top_light": mats["top_light_far"],
                    "green": mats["green_far"],
                    "green_light": mats["green_light_far"],
                }
            )
        add_distant_island(name, center, scale, landmark, collection, island_mats)


def build():
    hero.clear_scene()
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    collection = hero.make_collection("P14_SUNSET_ENVIRONMENT")
    mats = materials()
    build_cloudscape(collection, mats)
    build_distant_islands(collection, mats)
    build_hot_air_balloon(collection, mats)

    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        if obj.type == "MESH":
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    polygon_count = sum(len(obj.data.polygons) for obj in collection.objects if obj.type == "MESH")
    print(f"Saved P14 environment source: {SOURCE_PATH}")
    print(f"Exported P14 environment GLB: {GLB_PATH}")
    print(f"P14 mesh objects: {sum(1 for obj in collection.objects if obj.type == 'MESH')}")
    print(f"P14 polygons: {polygon_count}")


if __name__ == "__main__":
    build()
