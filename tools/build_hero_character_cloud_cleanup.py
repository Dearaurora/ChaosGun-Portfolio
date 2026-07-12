import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "assets/source/characters/cloud_reconstruction_mv_v1/hero_multiview_candidate.glb"
SOURCE = ROOT / "assets/source/characters/hero_character_cloud_v1.blend"
RUNTIME = ROOT / "assets/models/generated/characters/hero_character_cloud_v1.glb"
PREVIEW_FRONT = ROOT / "reports/hero_character_cloud_v1_front.png"
PREVIEW_THREE_QUARTER = ROOT / "reports/hero_character_cloud_v1_three_quarter.png"
TARGET_HEIGHT = 3.0
TARGET_FACE_COUNT = 45000


def material(name, color, roughness=0.65, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    if emission_strength:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = emission_strength
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = color
    return mat


SUIT_RED = material("hero_suit_red", (0.88, 0.055, 0.035, 1.0), 0.58)
RUBBER_PURPLE = material("hero_rubber_purple", (0.16, 0.065, 0.20, 1.0), 0.62)
FACE_PURPLE = material("hero_face_recess", (0.035, 0.018, 0.055, 1.0), 0.46)
EYE_GOLD = material("hero_eye_emission", (1.0, 0.46, 0.035, 1.0), 0.30, 2.5)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def object_bounds(objects):
    minimum = Vector((float("inf"),) * 3)
    maximum = Vector((float("-inf"),) * 3)
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            minimum.x = min(minimum.x, point.x)
            minimum.y = min(minimum.y, point.y)
            minimum.z = min(minimum.z, point.z)
            maximum.x = max(maximum.x, point.x)
            maximum.y = max(maximum.y, point.y)
            maximum.z = max(maximum.z, point.z)
    return minimum, maximum


def import_body():
    bpy.ops.import_scene.gltf(filepath=str(INPUT))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found in {INPUT}")

    for obj in meshes:
        world_transform = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world_transform
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    if len(meshes) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in meshes:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.join()
        meshes = [bpy.context.object]

    body = meshes[0]
    body.name = "HeroCloudBody"
    minimum, maximum = object_bounds([body])
    center = (minimum + maximum) * 0.5
    scale = TARGET_HEIGHT / (maximum.z - minimum.z)
    body.location = Vector((-center.x * scale, -center.y * scale, -minimum.z * scale))
    body.scale *= scale
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return body


def clean_body(body):
    initial_faces = len(body.data.polygons)
    if initial_faces > TARGET_FACE_COUNT:
        modifier = body.modifiers.new("production_decimation", "DECIMATE")
        modifier.decimate_type = "COLLAPSE"
        modifier.ratio = TARGET_FACE_COUNT / initial_faces
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.modifier_apply(modifier=modifier.name)

    body.data.validate(clean_customdata=False)
    body.data.update()
    body.data.materials.clear()
    body.data.materials.append(SUIT_RED)
    body.data.materials.append(RUBBER_PURPLE)

    edge_polygons = {}
    for polygon in body.data.polygons:
        for edge_key in polygon.edge_keys:
            edge_polygons.setdefault(edge_key, []).append(polygon.index)
    neighbors = [set() for _ in body.data.polygons]
    for attached in edge_polygons.values():
        if len(attached) != 2:
            continue
        a, b = attached
        neighbors[a].add(b)
        neighbors[b].add(a)

    glove_polygons = set()
    for hand_sign in (-1.0, 1.0):
        cuff_center = Vector((hand_sign * 0.87, -0.005, 1.18))
        forearm_axis = Vector((hand_sign * 0.48, 0.0, -0.88)).normalized()
        allowed = {
            polygon.index
            for polygon in body.data.polygons
            if (polygon.center - cuff_center).dot(forearm_axis) > 0.0
            and hand_sign * polygon.center.x > 0.55
            and polygon.center.z < 1.40
        }
        stack = [
            polygon.index
            for polygon in body.data.polygons
            if polygon.index in allowed
            and hand_sign * polygon.center.x > 0.94
            and polygon.center.z < 1.15
        ]
        visited = set(stack)
        while stack:
            current = stack.pop()
            for neighbor in neighbors[current]:
                if neighbor in allowed and neighbor not in visited:
                    visited.add(neighbor)
                    stack.append(neighbor)
        glove_polygons.update(visited)

    for polygon in body.data.polygons:
        center = polygon.center
        is_boot = center.z < 0.50
        is_glove = polygon.index in glove_polygons
        polygon.material_index = 1 if is_boot or is_glove else 0
        polygon.use_smooth = True
    return initial_faces, len(body.data.polygons)


def rounded_box(name, location, dimensions, mat, bevel):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new("rounded_form", "BEVEL")
    modifier.width = bevel
    modifier.segments = 6
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def build_face(body):
    cutter = rounded_box(
        "FaceOpeningCutter",
        (0.0, -0.44, 2.13),
        (0.78, 0.45, 0.40),
        SUIT_RED,
        0.075,
    )
    bpy.context.view_layer.objects.active = cutter
    for modifier in list(cutter.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active = body
    boolean = body.modifiers.new("clean_face_opening", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.object = cutter
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

    panel_y = -0.245
    panel = rounded_box(
        "FacePanel",
        (0.0, panel_y, 2.12),
        (0.78, 0.06, 0.40),
        FACE_PURPLE,
        0.09,
    )
    eye_y = panel_y - 0.038
    eyes = []
    for side, x in (("L", -0.18), ("R", 0.18)):
        eyes.append(
            rounded_box(
                "Eye" + side,
                (x, eye_y, 2.12),
                (0.08, 0.027, 0.20),
                EYE_GOLD,
                0.035,
            )
        )
    return [panel, *eyes]


def save_and_export(parts):
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(RUNTIME),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def setup_preview(parts):
    floor_mat = material("preview_floor", (0.34, 0.29, 0.31, 1.0), 0.74)
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, -0.018))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.data.materials.append(floor_mat)

    bpy.ops.object.light_add(type="AREA", location=(-4.0, -4.5, 6.5))
    key = bpy.context.object
    key.data.energy = 1050
    key.data.size = 5.0
    bpy.ops.object.light_add(type="AREA", location=(4.2, 1.5, 4.0))
    fill = bpy.context.object
    fill.data.energy = 700
    fill.data.color = (0.55, 0.68, 1.0)
    fill.data.size = 4.0

    bpy.ops.object.camera_add(location=(0, -8, 1.55))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.75
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.055, 0.052, 0.07, 1.0)
    background.inputs["Strength"].default_value = 0.38

    def render(location, path):
        camera.location = location
        camera.rotation_euler = (Vector((0, 0, 1.43)) - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)

    render((0, -8, 1.55), PREVIEW_FRONT)
    render((5.65, -5.65, 1.55), PREVIEW_THREE_QUARTER)


if __name__ == "__main__":
    os.chdir(ROOT)
    clear_scene()
    hero_body = import_body()
    source_faces, final_faces = clean_body(hero_body)
    hero_parts = [hero_body, *build_face(hero_body)]
    save_and_export(hero_parts)
    setup_preview(hero_parts)
    print("SOURCE_FACES", source_faces)
    print("FINAL_FACES", final_faces)
    print("BUILT", SOURCE)
    print("EXPORTED", RUNTIME)
    print("RENDERED", PREVIEW_FRONT)
    print("RENDERED", PREVIEW_THREE_QUARTER)
