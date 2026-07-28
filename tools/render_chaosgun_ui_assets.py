"""Deterministically render UI portraits and weapon thumbnails from game assets.

Run with:
    blender --background assets/source/characters/hero_character_rig_v3.blend \
        --python tools/render_chaosgun_ui_assets.py -- --characters-only
"""

from mathutils import Vector
from pathlib import Path
import sys

import bpy


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "assets" / "ui" / "generated"
PORTRAIT_ROOT = OUTPUT_ROOT / "characters"
WEAPON_ROOT = OUTPUT_ROOT / "weapons"
WEAPON_SOURCE_ROOT = ROOT / "assets" / "models" / "generated" / "weapons"

PLAYER_COLORS = {
    "p1": (0.10, 0.39, 0.95, 1.0),
    "p2": (1.00, 0.25, 0.07, 1.0),
    "p3": (0.72, 0.26, 0.88, 1.0),
    "p4": (0.34, 0.78, 0.34, 1.0),
}

WEAPONS = ("pistol", "smg", "ak_rifle", "sniper", "shotgun", "gatling")


def ensure_output_dirs():
    PORTRAIT_ROOT.mkdir(parents=True, exist_ok=True)
    WEAPON_ROOT.mkdir(parents=True, exist_ok=True)


def set_material_color(material, color):
    material.diffuse_color = color
    if not material.use_nodes or material.node_tree is None:
        return
    for node in material.node_tree.nodes:
        if node.type != "BSDF_PRINCIPLED":
            continue
        base_color = node.inputs.get("Base Color")
        if base_color is not None:
            base_color.default_value = color


def setup_scene():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.resolution_percentage = 100
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.02, 0.012, 0.04, 1.0)
    background.inputs["Strength"].default_value = 0.28

    for obj in list(scene.objects):
        if obj.type in {"LIGHT", "CAMERA"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    bpy.ops.object.light_add(type="AREA", location=(-4.5, -5.5, 7.0))
    key = bpy.context.object
    key.name = "UI_KeyLight"
    key.data.energy = 980
    key.data.color = (1.0, 0.72, 0.54)
    key.data.shape = "DISK"
    key.data.size = 4.6

    bpy.ops.object.light_add(type="AREA", location=(4.5, 0.5, 4.8))
    rim = bpy.context.object
    rim.name = "UI_RimLight"
    rim.data.energy = 650
    rim.data.color = (0.42, 0.58, 1.0)
    rim.data.size = 3.8

    bpy.ops.object.light_add(type="AREA", location=(0.0, -1.5, -0.2))
    fill = bpy.context.object
    fill.name = "UI_FillLight"
    fill.data.energy = 220
    fill.data.color = (1.0, 0.45, 0.25)
    fill.data.size = 2.8

    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.name = "UI_Camera"
    camera.data.type = "ORTHO"
    scene.camera = camera
    return scene, camera


def point_camera(camera, location, target, ortho_scale):
    camera.location = Vector(location)
    camera.data.ortho_scale = ortho_scale
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def remove_ik_constraints(armature):
    for bone in armature.pose.bones:
        for constraint in list(bone.constraints):
            if constraint.type == "IK":
                bone.constraints.remove(constraint)


def import_weapon(name):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(WEAPON_SOURCE_ROOT / f"{name}.glb"))
    imported = [obj for obj in bpy.context.scene.objects if obj not in before]
    root = bpy.data.objects.new(f"UIWeapon_{name}", None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent not in imported:
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world
    return root, imported


def render_to(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    print("UI_ASSET_RENDERED", path)


def render_character_portraits(scene, camera):
    armature = bpy.data.objects.get("HeroRig")
    if armature is None:
        raise RuntimeError("HeroRig was not found in the opened character source blend.")
    remove_ik_constraints(armature)
    armature.animation_data_create()
    armature.animation_data.action = bpy.data.actions.get("hold_pistol")
    scene.frame_set(1)

    weapon_root, _weapon_objects = import_weapon("pistol")
    weapon_root.location = (0.0, -0.72, 1.39)
    weapon_root.scale = (1.0, 1.0, 1.0)

    scene.render.resolution_x = 640
    scene.render.resolution_y = 760
    point_camera(camera, (4.8, -8.3, 3.15), (0.0, -0.10, 1.36), 3.25)

    suit = bpy.data.materials.get("hero_suit_red")
    if suit is None:
        raise RuntimeError("hero_suit_red material was not found.")

    for player_id, color in PLAYER_COLORS.items():
        set_material_color(suit, color)
        bpy.context.view_layer.update()
        render_to(scene, PORTRAIT_ROOT / f"character_{player_id}_pistol.png")

    weapon_root.hide_render = True


def world_bbox(objects):
    corners = []
    for obj in objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        corners.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not corners:
        return Vector((-1.0, -1.0, -1.0)), Vector((1.0, 1.0, 1.0))
    minimum = Vector(tuple(min(point[i] for point in corners) for i in range(3)))
    maximum = Vector(tuple(max(point[i] for point in corners) for i in range(3)))
    return minimum, maximum


def hide_character():
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE", "EMPTY"} and not obj.name.startswith("UIWeapon_"):
            obj.hide_render = True


def render_weapon_thumbnails(scene, camera):
    hide_character()
    scene.render.resolution_x = 512
    scene.render.resolution_y = 192

    for weapon_name in WEAPONS:
        root, imported = import_weapon(weapon_name)
        bpy.context.view_layer.update()
        minimum, maximum = world_bbox(imported)
        center = (minimum + maximum) * 0.5
        extent = maximum - minimum
        root.location -= center
        bpy.context.view_layer.update()

        span = max(extent.x, extent.y, extent.z, 0.5)
        # Keep generous transparent breathing room: several source weapons use
        # angled stocks whose projected width is larger than their world X span.
        point_camera(camera, (4.6, -8.0, 3.2), (0.0, 0.0, 0.0), span * 2.15)
        render_to(scene, WEAPON_ROOT / f"{weapon_name}.png")
        root.hide_render = True


def main():
    ensure_output_dirs()
    scene, camera = setup_scene()
    render_character_portraits(scene, camera)
    if "--characters-only" not in sys.argv:
        render_weapon_thumbnails(scene, camera)
    print("CHAOSGUN_UI_ASSETS_COMPLETE", OUTPUT_ROOT)


if __name__ == "__main__":
    main()
