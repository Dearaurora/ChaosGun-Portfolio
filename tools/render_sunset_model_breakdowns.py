from pathlib import Path
import math

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "assets" / "source" / "sunset_toy_sky_islands" / "sunset_hero_slice.blend"
OUTPUT_DIR = ROOT / "docs" / "art-direction" / "model-breakdowns"

GROUPS = {
    "sunset_platform_module": (
        "HeroPlatform",
        "HeroFloorSeam",
        "HeroEdgePost",
        "HeroEdgeGem",
    ),
    "sunset_bridge_module": (
        "HeroBridge",
    ),
    "sunset_red_bumper": (
        "HeroRedBumper",
    ),
    "sunset_golden_crate": (
        "HeroGoldenCrate",
    ),
}


def srgb_channel_to_linear(value):
    if value <= 0.04045:
        return value / 12.92
    return ((value + 0.055) / 1.055) ** 2.4


def rgba(hex_color, alpha=1.0):
    value = hex_color.lstrip("#")
    srgb = tuple(int(value[index : index + 2], 16) / 255.0 for index in (0, 2, 4))
    return tuple(srgb_channel_to_linear(channel) for channel in srgb) + (alpha,)


def make_material(name, color, roughness=0.9):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba(color)
    bsdf.inputs["Roughness"].default_value = roughness
    return material


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def add_area_light(name, location, target, color, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.color = color
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    light = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(light)
    light.location = location
    look_at(light, target)
    return light


def selected_objects(prefixes):
    return [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and any(obj.name.startswith(prefix) for prefix in prefixes)
    ]


def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return minimum, maximum


def configure_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.resolution_percentage = 100

    world = scene.world or bpy.data.worlds.new("Model Breakdown World")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = rgba("#343244")
    background.inputs["Strength"].default_value = 0.20

    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)


def render_group(output_name, prefixes):
    scene = bpy.context.scene
    members = selected_objects(prefixes)
    if not members:
        raise RuntimeError(f"No objects matched {prefixes}")

    for obj in scene.objects:
        if obj.type == "MESH":
            obj.hide_render = obj not in members

    minimum, maximum = bounds(members)
    center = (minimum + maximum) * 0.5
    size = maximum - minimum
    radius = max(size.x, size.y, size.z) * 0.5

    floor_mesh = bpy.data.meshes.new(f"{output_name}_FloorMesh")
    floor = bpy.data.objects.new(f"{output_name}_Floor", floor_mesh)
    scene.collection.objects.link(floor)
    floor_size = max(size.x, size.y) * 2.2
    half = floor_size * 0.5
    floor_mesh.from_pydata(
        [(-half, -half, 0.0), (half, -half, 0.0), (half, half, 0.0), (-half, half, 0.0)],
        [],
        [(0, 1, 2, 3)],
    )
    floor.location = Vector((center.x, center.y, minimum.z - max(radius * 0.015, 0.04)))
    floor.data.materials.append(make_material("breakdown_floor", "#4A4658", 0.96))
    floor.hide_render = False

    camera_data = bpy.data.cameras.new(f"{output_name}_CameraData")
    camera = bpy.data.objects.new(f"{output_name}_Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 55
    camera.data.sensor_width = 36
    camera.data.dof.use_dof = False
    direction = Vector((1.18, -1.36, 0.96)).normalized()
    distance = max(radius * 4.15, 8.0)
    camera.location = center + direction * distance
    look_at(camera, center + Vector((0.0, 0.0, size.z * 0.03)))

    light_scale = max(radius, 2.0)
    energy_scale = max(light_scale / 3.0, 1.0)
    lights = [
        add_area_light(
            f"{output_name}_Key",
            center + Vector((-0.9, -1.0, 1.6)) * light_scale,
            center,
            (1.0, 0.72, 0.55),
            430.0 * energy_scale,
            light_scale * 1.4,
        ),
        add_area_light(
            f"{output_name}_Fill",
            center + Vector((1.2, -0.4, 0.8)) * light_scale,
            center,
            (0.58, 0.72, 1.0),
            280.0 * energy_scale,
            light_scale * 1.2,
        ),
        add_area_light(
            f"{output_name}_Rim",
            center + Vector((0.2, 1.3, 1.2)) * light_scale,
            center,
            (0.78, 0.62, 1.0),
            340.0 * energy_scale,
            light_scale,
        ),
    ]

    scene.render.filepath = str(OUTPUT_DIR / f"{output_name}.png")
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {scene.render.filepath}")

    bpy.data.objects.remove(floor, do_unlink=True)
    bpy.data.objects.remove(camera, do_unlink=True)
    for light in lights:
        bpy.data.objects.remove(light, do_unlink=True)


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE_PATH))
    configure_scene()
    for output_name, prefixes in GROUPS.items():
        render_group(output_name, prefixes)


if __name__ == "__main__":
    main()
