from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "source" / "sunset_toy_sky_islands"
GENERATED_DIR = ROOT / "assets" / "models" / "generated" / "sunset_toy_sky_islands"
PREVIEW_DIR = ROOT / "docs" / "art-direction" / "previews"
BLEND_PATH = SOURCE_DIR / "sunset_hero_slice.blend"
GLB_PATH = GENERATED_DIR / "sunset_hero_slice.glb"
PREVIEW_PATH = PREVIEW_DIR / "sunset_hero_slice_v1.png"


def srgb_channel_to_linear(value):
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def rgba(hex_color, alpha=1.0):
    value = hex_color.lstrip("#")
    srgb = tuple(int(value[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    return tuple(srgb_channel_to_linear(channel) for channel in srgb) + (alpha,)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            datablocks.remove(block)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)


def make_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj, collection):
    for source in list(obj.users_collection):
        source.objects.unlink(obj)
    collection.objects.link(obj)


def make_material(name, base_hex, roughness=0.75, metallic=0.0, emission_hex=None, emission_strength=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(base_hex)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_hex:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = rgba(emission_hex)
        strength_input = bsdf.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = emission_strength
    return material


def apply_material(obj, material):
    obj.data.materials.append(material)


def apply_bevel(obj, width, segments=4):
    if width <= 0:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Soft toy bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.harden_normals = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    try:
        bpy.ops.object.shade_smooth_by_angle()
    except RuntimeError:
        pass


def add_rounded_box(name, location, size, material, collection, bevel=0.25, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    apply_material(obj, material)
    apply_bevel(obj, min(bevel, min(size) * 0.45))
    move_to_collection(obj, collection)
    return obj


def add_tapered_box(name, location, top_size, bottom_size, height, material, collection, bevel=0.3):
    tx, ty = top_size
    bx, by = bottom_size
    z0 = -height * 0.5
    z1 = height * 0.5
    verts = [
        (-bx / 2, -by / 2, z0), (bx / 2, -by / 2, z0),
        (bx / 2, by / 2, z0), (-bx / 2, by / 2, z0),
        (-tx / 2, -ty / 2, z1), (tx / 2, -ty / 2, z1),
        (tx / 2, ty / 2, z1), (-tx / 2, ty / 2, z1),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2),
        (2, 6, 7, 3), (4, 0, 3, 7),
    ]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    collection.objects.link(obj)
    apply_material(obj, material)
    apply_bevel(obj, bevel, 5)
    return obj


def rounded_rect_outline(size, radius, segments=7):
    width, depth = size
    radius = min(radius, width * 0.49, depth * 0.49)
    corners = [
        (width * 0.5 - radius, depth * 0.5 - radius, 0.0),
        (-width * 0.5 + radius, depth * 0.5 - radius, 90.0),
        (-width * 0.5 + radius, -depth * 0.5 + radius, 180.0),
        (width * 0.5 - radius, -depth * 0.5 + radius, 270.0),
    ]
    points = []
    for cx, cy, start_angle in corners:
        for step in range(segments + 1):
            angle = math.radians(start_angle + (90.0 * step / segments))
            points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    return points


def add_rounded_tapered_prism(
    name,
    location,
    top_size,
    bottom_size,
    height,
    top_radius,
    bottom_radius,
    material,
    collection,
    edge_bevel=0.08,
):
    top_outline = rounded_rect_outline(top_size, top_radius)
    bottom_outline = rounded_rect_outline(bottom_size, bottom_radius)
    count = len(top_outline)
    z0 = -height * 0.5
    z1 = height * 0.5
    verts = [(x, y, z0) for x, y in bottom_outline] + [(x, y, z1) for x, y in top_outline]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = location
    collection.objects.link(obj)
    apply_material(obj, material)
    apply_bevel(obj, edge_bevel, 3)
    return obj


def add_sphere(name, location, scale, material, collection, segments=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    move_to_collection(obj, collection)
    return obj


def add_cylinder(name, location, radius, depth, material, collection, rotation=(0.0, 0.0, 0.0), bevel=0.12, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    apply_material(obj, material)
    apply_bevel(obj, min(bevel, radius * 0.45), 3)
    move_to_collection(obj, collection)
    return obj


def add_cone(name, location, radius1, radius2, depth, material, collection, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cone_add(
        vertices=28,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    apply_material(obj, material)
    apply_bevel(obj, min(0.04, radius1 * 0.2), 2)
    move_to_collection(obj, collection)
    return obj


def add_capsule(name, location, length, radius, material, collection, rotation_z=0.0):
    body_length = max(0.1, length - radius * 2.0)
    body = add_cylinder(
        f"{name}Body",
        location,
        radius,
        body_length,
        material,
        collection,
        rotation=(0.0, math.pi / 2.0, rotation_z),
        bevel=radius * 0.18,
    )
    axis = Vector((math.cos(rotation_z), math.sin(rotation_z), 0.0))
    end_offset = axis * (body_length * 0.5)
    add_sphere(f"{name}CapA", Vector(location) - end_offset, (radius, radius, radius), material, collection, 24, 12)
    add_sphere(f"{name}CapB", Vector(location) + end_offset, (radius, radius, radius), material, collection, 24, 12)
    return body


def add_torus(name, location, major_radius, minor_radius, material, collection, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=48,
        minor_segments=12,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    apply_material(obj, material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    move_to_collection(obj, collection)
    return obj


def add_platform(environment, materials):
    add_rounded_tapered_prism(
        "HeroPlatformCliff",
        (0.0, 0.0, -1.8),
        (17.2, 13.2),
        (13.9, 10.3),
        5.0,
        2.25,
        1.55,
        materials["cliff"],
        environment,
        0.12,
    )
    add_rounded_tapered_prism(
        "HeroPlatformWarmBand",
        (0.0, 0.0, 0.35),
        (17.5, 13.5),
        (17.2, 13.2),
        1.25,
        2.30,
        2.15,
        materials["side"],
        environment,
        0.10,
    )
    add_rounded_tapered_prism(
        "HeroPlatformTop",
        (0.0, 0.0, 1.12),
        (17.1, 13.1),
        (16.9, 12.9),
        1.05,
        2.20,
        2.08,
        materials["deck"],
        environment,
        0.08,
    )
    add_rounded_tapered_prism(
        "HeroPlatformTopInset",
        (0.0, 0.0, 1.67),
        (15.8, 11.8),
        (15.8, 11.8),
        0.10,
        1.72,
        1.72,
        materials["deck_light"],
        environment,
        0.025,
    )

    for index, x in enumerate((-4.2, 0.0, 4.2)):
        add_rounded_box(f"HeroFloorSeamX_{index}", (x, 0.0, 1.74), (0.055, 10.4, 0.025), materials["seam"], environment, 0.01)
    for index, y in enumerate((-3.4, 0.0, 3.4)):
        add_rounded_box(f"HeroFloorSeamY_{index}", (0.0, y, 1.745), (14.4, 0.055, 0.025), materials["seam"], environment, 0.01)

    for index, (x, y) in enumerate(((-7.65, -5.65), (-7.65, 5.65), (7.65, -5.65), (7.65, 5.65))):
        add_rounded_box(f"HeroEdgePost_{index}", (x, y, 2.0), (0.58, 0.58, 0.72), materials["edge_post"], environment, 0.18)
        add_rounded_box(f"HeroEdgeGem_{index}", (x, y, 2.39), (0.30, 0.30, 0.12), materials["cyan_glow"], environment, 0.08)


def add_bridge(environment, materials):
    add_rounded_box("HeroBridgeShadow", (12.0, 0.0, -0.45), (7.8, 5.2, 1.9), materials["cliff"], environment, 0.55)
    for index in range(6):
        x = 8.9 + index * 1.18
        add_rounded_box(f"HeroBridgePlank_{index}", (x, 0.0, 1.38), (1.04, 4.75, 0.58), materials["bridge"], environment, 0.16)
    for index, (x, y) in enumerate(((8.45, -2.38), (8.45, 2.38), (15.25, -2.38), (15.25, 2.38))):
        add_rounded_box(f"HeroBridgePost_{index}", (x, y, 1.85), (0.62, 0.62, 1.18), materials["edge_post"], environment, 0.18)
        add_rounded_box(f"HeroBridgeGem_{index}", (x, y, 2.48), (0.30, 0.30, 0.13), materials["cyan_glow"], environment, 0.08)


def add_bumper(props, materials):
    add_capsule("HeroRedBumper", (-1.8, 3.0, 2.65), 5.4, 0.78, materials["red"], props, rotation_z=0.02)
    for index, x in enumerate((-3.55, -0.05)):
        add_torus(
            f"HeroRedBumperBand_{index}",
            (x, 3.0, 2.65),
            0.79,
            0.07,
            materials["red_light"],
            props,
            rotation=(0.0, math.pi / 2.0, 0.0),
        )


def add_crate(props, materials):
    add_rounded_box("HeroGoldenCrate", (3.4, -2.7, 2.75), (2.55, 2.55, 2.25), materials["gold"], props, 0.34, (0.0, 0.0, -0.08))
    add_rounded_box("HeroGoldenCrateBandX", (3.4, -2.7, 2.76), (2.68, 0.28, 2.30), materials["gold_dark"], props, 0.07, (0.0, 0.0, -0.08))
    add_rounded_box("HeroGoldenCrateBandY", (3.4, -2.7, 2.76), (0.28, 2.68, 2.30), materials["gold_dark"], props, 0.07, (0.0, 0.0, -0.08))


def add_pickup(props, materials):
    add_cylinder("HeroPickupBase", (1.8, 1.2, 1.93), 1.55, 0.34, materials["edge_post"], props, bevel=0.12, vertices=48)
    add_torus("HeroPickupGoldRing", (1.8, 1.2, 2.16), 1.08, 0.17, materials["gold_glow"], props)
    add_cylinder("HeroPickupCore", (1.8, 1.2, 2.15), 0.55, 0.25, materials["gold"], props, bevel=0.10, vertices=36)


def add_character(character, fx, materials):
    body_center = Vector((-4.2, -2.1, 3.0))
    add_sphere("HeroCharacterBody", body_center, (0.92, 0.78, 1.16), materials["character"], character)
    add_sphere("HeroCharacterVisor", body_center + Vector((0.72, -0.02, 0.18)), (0.34, 0.57, 0.46), materials["visor"], character, 32, 16)
    add_sphere("HeroCharacterVisorGlint", body_center + Vector((0.99, -0.19, 0.34)), (0.06, 0.12, 0.10), materials["visor_glint"], character, 16, 8)
    add_sphere("HeroCharacterFootL", (-4.38, -2.58, 2.05), (0.40, 0.48, 0.30), materials["character_dark"], character, 24, 12)
    add_sphere("HeroCharacterFootR", (-3.75, -1.68, 2.05), (0.40, 0.48, 0.30), materials["character_dark"], character, 24, 12)
    add_sphere("HeroCharacterHandL", (-3.35, -2.42, 2.82), (0.24, 0.24, 0.24), materials["character"], character, 20, 10)
    add_sphere("HeroCharacterHandR", (-3.18, -1.86, 2.84), (0.24, 0.24, 0.24), materials["character"], character, 20, 10)

    add_rounded_box("HeroPistolBody", (-2.35, -2.10, 2.92), (1.70, 0.48, 0.55), materials["gun"], character, 0.15, (0.0, -0.04, 0.02))
    add_rounded_box("HeroPistolColorBlock", (-2.62, -2.10, 3.08), (0.75, 0.53, 0.24), materials["character_light"], character, 0.08)
    add_rounded_box("HeroPistolGrip", (-2.78, -2.10, 2.48), (0.42, 0.45, 0.92), materials["gun_dark"], character, 0.12, (0.0, -0.22, 0.0))
    add_cylinder("HeroPistolMuzzle", (-1.42, -2.10, 2.94), 0.20, 0.44, materials["gun_dark"], character, rotation=(0.0, math.pi / 2.0, 0.0), bevel=0.05, vertices=24)

    add_sphere("HeroMuzzleCore", (-1.12, -2.10, 2.94), (0.18, 0.18, 0.18), materials["muzzle_glow"], fx, 20, 10)
    add_cone(
        "HeroMuzzleFlash",
        (-0.82, -2.10, 2.94),
        0.24,
        0.03,
        0.62,
        materials["muzzle_glow"],
        fx,
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    for index, x in enumerate((0.0, 1.0, 2.0, 3.0)):
        add_capsule(f"HeroProjectile_{index}", (x, -2.10, 2.94), 0.52, 0.09, materials["cyan_glow"], fx)


def add_cloud_cluster(name, center, scale, material, backdrop):
    offsets = [
        (-1.7, 0.0, -0.15, 1.45),
        (-0.65, -0.15, 0.20, 1.65),
        (0.55, 0.05, 0.34, 1.80),
        (1.70, 0.0, -0.08, 1.40),
        (0.0, 0.38, -0.22, 1.55),
    ]
    for index, (ox, oy, oz, puff_scale) in enumerate(offsets):
        add_sphere(
            f"{name}_{index}",
            Vector(center) + Vector((ox * scale, oy * scale, oz * scale)),
            (1.35 * scale * puff_scale, 0.78 * scale * puff_scale, 0.72 * scale * puff_scale),
            material,
            backdrop,
            28,
            14,
        )


def add_backdrop(backdrop, materials):
    cloud_specs = [
        ("HeroCloudPinkNorth", (-8.0, 11.5, -4.8), 1.35, "cloud_pink"),
        ("HeroCloudCreamNorth", (4.0, 13.5, -5.1), 1.65, "cloud_cream"),
        ("HeroCloudPinkEast", (15.0, 8.5, -5.0), 1.20, "cloud_pink"),
        ("HeroCloudVioletWest", (-13.0, -8.0, -6.1), 1.55, "cloud_violet"),
        ("HeroCloudVioletSouth", (7.0, -11.0, -6.3), 1.85, "cloud_violet"),
    ]
    for name, center, scale, material_key in cloud_specs:
        add_cloud_cluster(name, center, scale, materials[material_key], backdrop)

    for index, (x, y, scale) in enumerate(((-10.0, 15.5, 0.55), (4.0, 17.0, 0.65), (14.0, 14.0, 0.45))):
        height = 5.5 * scale
        center_z = -4.0
        top_z = center_z + height * 0.5 + 0.22
        add_tapered_box(f"HeroDistantIslandCliff_{index}", (x, y, center_z), (4.8 * scale, 3.8 * scale), (2.4 * scale, 1.9 * scale), height, materials["cliff"], backdrop, 0.35)
        add_rounded_box(f"HeroDistantIslandTop_{index}", (x, y, top_z), (5.0 * scale, 4.0 * scale, 0.55 * scale), materials["deck"], backdrop, 0.24)
        add_sphere(f"HeroDistantIslandTree_{index}", (x, y, top_z + 0.55 * scale), (0.52 * scale, 0.52 * scale, 0.82 * scale), materials["tree"], backdrop, 20, 10)


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def configure_render(materials):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_percentage = 100

    world = bpy.data.worlds.new("Sunset Toy Sky World")
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = rgba("#5968C5")
    background.inputs["Strength"].default_value = 0.52
    scene.world = world

    camera_data = bpy.data.cameras.new("HeroSliceCamera")
    camera = bpy.data.objects.new("HeroSliceCamera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = (24.0, -28.0, 24.0)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 31.5
    look_at(camera, (2.4, 0.0, -0.3))
    scene.camera = camera

    def area_light(name, location, color, energy, size):
        light_data = bpy.data.lights.new(name, type="AREA")
        light_data.color = rgba(color)[:3]
        light_data.energy = energy
        light_data.use_shadow = True
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        scene.collection.objects.link(light)
        light.location = location
        look_at(light, (0.0, 0.0, 0.0))

    sun_data = bpy.data.lights.new("SunsetDirection", type="SUN")
    sun_data.color = rgba("#FFD0A4")[:3]
    sun_data.energy = 2.4
    sun_data.angle = math.radians(18.0)
    sun = bpy.data.objects.new("SunsetDirection", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(38.0), math.radians(-22.0), math.radians(-42.0))

    area_light("SunsetKey", (-13.0, -14.0, 25.0), "#FFD0A4", 3000.0, 10.0)
    area_light("CoolFill", (16.0, 8.0, 16.0), "#8FA8FF", 1100.0, 12.0)
    area_light("WarmRim", (8.0, 14.0, 18.0), "#FF9F73", 1450.0, 8.0)

    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0.70


def build_scene():
    clear_scene()
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)

    environment = make_collection("SUNSET_HERO_ENVIRONMENT")
    props = make_collection("SUNSET_HERO_PROPS")
    character = make_collection("SUNSET_HERO_CHARACTER")
    fx = make_collection("SUNSET_HERO_FX")
    backdrop = make_collection("SUNSET_HERO_BACKDROP")

    materials = {
        "deck": make_material("sunset_deck", "#B85818", 0.72),
        "deck_light": make_material("sunset_deck_highlight", "#CD7024", 0.78),
        "side": make_material("sunset_warm_side", "#8F391C", 0.82),
        "cliff": make_material("sunset_plum_cliff", "#39265F", 0.92),
        "bridge": make_material("sunset_bridge_wood", "#98461F", 0.82),
        "seam": make_material("sunset_floor_seam", "#713317", 0.92),
        "edge_post": make_material("sunset_edge_post", "#64465B", 0.72, 0.10),
        "red": make_material("sunset_soft_red", "#ED432E", 0.62),
        "red_light": make_material("sunset_soft_red_highlight", "#FF6A43", 0.58),
        "gold": make_material("sunset_toy_gold", "#E9A631", 0.64),
        "gold_dark": make_material("sunset_toy_gold_band", "#B76B24", 0.72),
        "character": make_material("sunset_character_cyan", "#31BDE2", 0.56),
        "character_light": make_material("sunset_character_cyan_light", "#8DE9FF", 0.48),
        "character_dark": make_material("sunset_character_cyan_shadow", "#14779B", 0.70),
        "visor": make_material("sunset_character_visor", "#17203B", 0.28, 0.05),
        "visor_glint": make_material("sunset_character_visor_glint", "#E8FBFF", 0.20, emission_hex="#C7F8FF", emission_strength=1.1),
        "gun": make_material("sunset_toy_gun", "#3A4053", 0.50, 0.18),
        "gun_dark": make_material("sunset_toy_gun_dark", "#1D2437", 0.58, 0.12),
        "cyan_glow": make_material("sunset_cyan_glow", "#45C9EE", 0.30, emission_hex="#45C9EE", emission_strength=2.2),
        "gold_glow": make_material("sunset_gold_glow", "#FFD05A", 0.28, emission_hex="#FFB52E", emission_strength=2.6),
        "muzzle_glow": make_material("sunset_muzzle_glow", "#FF8C24", 0.30, emission_hex="#FF7A16", emission_strength=1.45),
        "cloud_pink": make_material("sunset_cloud_pink", "#E8A3B1", 0.98),
        "cloud_cream": make_material("sunset_cloud_cream", "#F5C5B0", 0.98),
        "cloud_violet": make_material("sunset_cloud_violet", "#7165B5", 0.98),
        "tree": make_material("sunset_distant_tree", "#5C7849", 0.90),
    }

    add_platform(environment, materials)
    add_bridge(environment, materials)
    add_bumper(props, materials)
    add_crate(props, materials)
    add_pickup(props, materials)
    add_character(character, fx, materials)
    add_backdrop(backdrop, materials)
    configure_render(materials)


def save_render_export():
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.context.scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)

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
    print(f"Saved Blender source: {BLEND_PATH}")
    print(f"Rendered preview: {PREVIEW_PATH}")
    print(f"Exported GLB: {GLB_PATH}")


if __name__ == "__main__":
    build_scene()
    save_render_export()
