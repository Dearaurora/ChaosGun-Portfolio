import math
import os
from pathlib import Path

import bpy


OUT_PATH = Path("assets/models/generated/characters/bean_character.glb")


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


MAT_BODY = mat("bean_body_recolor", (0.95, 0.18, 0.18, 1.0), 0.82)
MAT_VISOR_RIM = mat("bean_visor_rim", (0.08, 0.11, 0.16, 1.0), 0.68)
MAT_VISOR_GLASS = mat("bean_visor_glass", (0.74, 0.93, 1.0, 1.0), 0.34)
MAT_HIGHLIGHT = mat("bean_visor_highlight", (1.0, 1.0, 1.0, 1.0), 0.28)
MAT_FOOT = mat("bean_soft_feet", (0.035, 0.045, 0.06, 1.0), 0.76)
MAT_FACE = mat("bean_recessed_face", (0.075, 0.045, 0.085, 1.0), 0.72)
MAT_EYE = mat("bean_warm_eyes", (1.0, 0.57, 0.12, 1.0), 0.40)
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


def build_character():
    # Blender +Y maps to Godot -Z during glTF Y-up conversion.
    add_profile_body("Body", MAT_BODY)

    add_cube("FaceOpening", (0, 0.785, 1.60), (0.96, 0.075, 0.48), MAT_FACE, 0.16)
    add_uv_sphere("EyeLeft", (-0.18, 0.84, 1.60), (0.072, 0.025, 0.13), MAT_EYE, 16, 10)
    add_uv_sphere("EyeRight", (0.18, 0.84, 1.60), (0.072, 0.025, 0.13), MAT_EYE, 16, 10)

    left_shoulder = (-0.86, 0.34, 1.38)
    left_elbow = (-0.90, 1.02, 1.12)
    left_hand = (-0.22, 1.43, 1.15)
    right_shoulder = (0.86, 0.34, 1.38)
    right_elbow = (0.90, 1.00, 1.04)
    right_hand = (0.22, 1.39, 0.99)
    add_curved_arm("BodyArmLeft", left_shoulder, left_elbow, left_hand, 0.18, MAT_BODY)
    add_curved_arm("BodyArmRight", right_shoulder, right_elbow, right_hand, 0.18, MAT_BODY)
    add_uv_sphere("LeftHandGrip", left_hand, (0.21, 0.18, 0.21), MAT_BODY, 22, 12)
    add_uv_sphere("RightHandGrip", right_hand, (0.21, 0.18, 0.21), MAT_BODY, 22, 12)

    add_uv_sphere("BodyFootCuffLeft", (-0.39, 0.10, 0.23), (0.31, 0.33, 0.20), MAT_BODY, 24, 10)
    add_uv_sphere("BodyFootCuffRight", (0.39, 0.10, 0.23), (0.31, 0.33, 0.20), MAT_BODY, 24, 10)
    add_uv_sphere("LeftFoot", (-0.39, 0.20, 0.13), (0.38, 0.43, 0.13), MAT_FOOT, 24, 10)
    add_uv_sphere("RightFoot", (0.39, 0.20, 0.13), (0.38, 0.43, 0.13), MAT_FOOT, 24, 10)


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
    build_character()
    export_glb()
    print(f"Exported {OUT_PATH}")
