import math
import os
from pathlib import Path

import bpy


OUT_PATH = Path("assets/models/generated/characters/bean_character.glb")
SOURCE_PATH = Path("assets/source/characters/bean_character.blend")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def mat(name, color, roughness=0.82, metallic=0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return material


MAT_BODY = mat("character_body_recolor", (0.95, 0.18, 0.18, 1.0), 0.78)
MAT_BOOT = mat("character_boot_rubber", (0.12, 0.07, 0.17, 1.0), 0.72)
MAT_GLOVE = mat("character_glove_rubber", (0.18, 0.10, 0.22, 1.0), 0.76)
MAT_FACE = mat("character_recessed_face", (0.075, 0.045, 0.085, 1.0), 0.70)
MAT_EYE = mat("character_warm_eyes", (1.0, 0.57, 0.12, 1.0), 0.40)
_eye_bsdf = MAT_EYE.node_tree.nodes.get("Principled BSDF")
if "Emission Color" in _eye_bsdf.inputs:
    _eye_bsdf.inputs["Emission Color"].default_value = (1.0, 0.30, 0.035, 1.0)
    _eye_bsdf.inputs["Emission Strength"].default_value = 0.45


def add_uv_sphere(name, loc, scale, material, segments=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def add_profile_body(name, material, segments=40):
    profile = [
        (0.31, 0.50),
        (0.39, 0.70),
        (0.48, 0.88),
        (0.78, 0.99),
        (1.14, 1.03),
        (1.52, 0.99),
        (1.86, 0.84),
        (2.10, 0.70),
        (2.27, 0.49),
        (2.36, 0.27),
        (2.42, 0.08),
    ]
    depth_ratio = 0.82
    vertices = []
    for z, radius in profile:
        for index in range(segments):
            angle = math.tau * index / segments
            vertices.append((math.cos(angle) * radius, math.sin(angle) * radius * depth_ratio, z))
    faces = []
    for ring in range(len(profile) - 1):
        for index in range(segments):
            next_index = (index + 1) % segments
            a = ring * segments + index
            b = ring * segments + next_index
            c = (ring + 1) * segments + next_index
            d = (ring + 1) * segments + index
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(segments))))
    top_start = (len(profile) - 1) * segments
    faces.append(tuple(top_start + index for index in range(segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    subdivision = obj.modifiers.new(name="body_surface", type="SUBSURF")
    subdivision.levels = 2
    subdivision.render_levels = 2
    return obj


def add_curved_arm(name, shoulder, elbow, wrist, radius, material):
    curve_data = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 12
    curve_data.bevel_depth = radius
    curve_data.bevel_resolution = 5
    curve_data.resolution_u = 16
    curve_data.materials.append(material)
    spline = curve_data.splines.new(type="BEZIER")
    spline.bezier_points.add(2)
    for point, coordinate in zip(spline.bezier_points, (shoulder, elbow, wrist)):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj.select_set(False)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_cube(name, loc, scale, material, bevel=0.08, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0.0:
        mod = obj.modifiers.new(name="toy_bevel", type="BEVEL")
        mod.width = bevel
        mod.segments = 5
        mod.affect = "EDGES"
        normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
        normal.keep_sharp = True
    return obj


def add_rounded_box(name, loc, scale, material, bevel=0.16):
    return add_cube(name, loc, scale, material, bevel)


def add_marker(name, loc):
    marker = bpy.data.objects.new(name, None)
    marker.location = loc
    bpy.context.collection.objects.link(marker)
    return marker


def build_character():
    # Blender +Y maps to Godot -Z during glTF Y-up conversion.
    # The model deliberately uses a small set of broad forms so it remains readable
    # at the gameplay camera distance and can be reposed without retopology.
    add_rounded_box("Body", (0.0, 0.0, 1.06), (1.66, 1.28, 1.46), MAT_BODY, 0.25)
    add_uv_sphere("HelmetCollar", (0.0, 0.02, 1.69), (0.90, 0.72, 0.16), MAT_BODY, 24, 10)
    add_uv_sphere("HelmetShell", (0.0, 0.02, 2.12), (0.84, 0.70, 0.68), MAT_BODY, 24, 12)
    add_rounded_box("FaceOpening", (0.0, 0.71, 2.10), (1.02, 0.10, 0.50), MAT_FACE, 0.15)
    add_uv_sphere("EyeLeft", (-0.20, 0.78, 2.10), (0.070, 0.030, 0.13), MAT_EYE, 12, 8)
    add_uv_sphere("EyeRight", (0.20, 0.78, 2.10), (0.070, 0.030, 0.13), MAT_EYE, 12, 8)

    left_shoulder = (-0.80, 0.08, 1.34)
    right_shoulder = (0.80, 0.08, 1.34)

    pistol_left_elbow = (-0.78, 0.74, 1.23)
    pistol_left_glove = (-0.18, 1.20, 1.22)
    pistol_right_elbow = (0.78, 0.70, 1.18)
    pistol_right_glove = (0.18, 1.16, 1.16)
    add_curved_arm("BodyPosePistolArmLeft", left_shoulder, pistol_left_elbow, pistol_left_glove, 0.16, MAT_BODY)
    add_curved_arm("BodyPosePistolArmRight", right_shoulder, pistol_right_elbow, pistol_right_glove, 0.16, MAT_BODY)
    add_uv_sphere("PosePistolGloveLeft", pistol_left_glove, (0.20, 0.18, 0.19), MAT_GLOVE, 16, 10)
    add_uv_sphere("PosePistolGloveRight", pistol_right_glove, (0.20, 0.18, 0.19), MAT_GLOVE, 16, 10)

    # Long weapons use a low-ready two-point pose: trigger hand near the chest,
    # support hand pushed forward along the fore-end, with clear torso clearance.
    long_left_elbow = (-0.88, 0.78, 1.24)
    long_left_glove = (-0.46, 1.42, 1.29)
    long_right_elbow = (0.72, 0.52, 1.24)
    long_right_glove = (0.20, 1.08, 1.28)
    add_curved_arm("BodyPoseLongArmLeft", left_shoulder, long_left_elbow, long_left_glove, 0.17, MAT_BODY)
    add_curved_arm("BodyPoseLongArmRight", right_shoulder, long_right_elbow, long_right_glove, 0.17, MAT_BODY)
    add_uv_sphere("PoseLongGloveLeft", long_left_glove, (0.21, 0.19, 0.20), MAT_GLOVE, 16, 10)
    add_uv_sphere("PoseLongGloveRight", long_right_glove, (0.21, 0.19, 0.20), MAT_GLOVE, 16, 10)
    add_marker("LeftHandGrip", long_left_glove)
    add_marker("RightHandGrip", long_right_glove)

    add_uv_sphere("LeftLeg", (-0.42, 0.0, 0.46), (0.37, 0.37, 0.45), MAT_BODY, 20, 10)
    add_uv_sphere("RightLeg", (0.42, 0.0, 0.46), (0.37, 0.37, 0.45), MAT_BODY, 20, 10)
    add_rounded_box("LeftBoot", (-0.42, 0.12, 0.19), (0.56, 0.72, 0.36), MAT_BOOT, 0.16)
    add_rounded_box("RightBoot", (0.42, 0.12, 0.19), (0.56, 0.72, 0.36), MAT_BOOT, 0.16)


def export_glb():
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
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
    build_character()
    export_glb()
    print(f"Exported {OUT_PATH}")
