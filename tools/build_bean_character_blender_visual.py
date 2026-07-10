import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


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


def add_pear_body(name, loc, scale, material):
    obj = add_uv_sphere(name, loc, scale, material, 40, 24)
    for vertex in obj.data.vertices:
        normalized_z = max(-1.0, min(1.0, vertex.co.z))
        lower_weight = (1.0 - normalized_z) * 0.5
        crown_weight = (normalized_z + 1.0) * 0.5
        width_factor = 0.90 + lower_weight * 0.22 - crown_weight * 0.04
        vertex.co.x *= width_factor
        vertex.co.y *= 0.96 + lower_weight * 0.10
    return obj


def add_soft_limb(name, start, end, radius, material):
    start_v = Vector(start)
    end_v = Vector(end)
    direction = end_v - start_v
    obj = add_uv_sphere(name, (start_v + end_v) * 0.5, (radius, radius, direction.length * 0.56), material, 24, 14)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
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
    add_pear_body("Body", (0, 0.02, 1.22), (0.98, 0.82, 1.06), MAT_BODY)

    add_uv_sphere("FaceOpening", (0, 1.00, 1.54), (0.52, 0.115, 0.29), MAT_FACE, 32, 16)
    add_uv_sphere("EyeLeft", (-0.19, 1.11, 1.54), (0.07, 0.028, 0.13), MAT_EYE, 16, 10)
    add_uv_sphere("EyeRight", (0.19, 1.11, 1.54), (0.07, 0.028, 0.13), MAT_EYE, 16, 10)

    left_shoulder = (-0.84, 0.42, 1.30)
    left_elbow = (-0.80, 1.14, 1.08)
    left_hand = (-0.20, 1.48, 1.13)
    right_shoulder = (0.84, 0.42, 1.30)
    right_elbow = (0.80, 1.12, 1.00)
    right_hand = (0.20, 1.42, 0.98)
    add_soft_limb("BodyArmLeftUpper", left_shoulder, left_elbow, 0.22, MAT_BODY)
    add_soft_limb("BodyArmLeftFore", left_elbow, left_hand, 0.20, MAT_BODY)
    add_soft_limb("BodyArmRightUpper", right_shoulder, right_elbow, 0.22, MAT_BODY)
    add_soft_limb("BodyArmRightFore", right_elbow, right_hand, 0.20, MAT_BODY)
    add_uv_sphere("LeftHandGrip", left_hand, (0.22, 0.18, 0.22), MAT_BODY, 22, 12)
    add_uv_sphere("RightHandGrip", right_hand, (0.22, 0.18, 0.22), MAT_BODY, 22, 12)

    add_uv_sphere("LeftFoot", (-0.39, 0.16, 0.18), (0.38, 0.45, 0.19), MAT_FOOT, 24, 10)
    add_uv_sphere("RightFoot", (0.39, 0.16, 0.18), (0.38, 0.45, 0.19), MAT_FOOT, 24, 10)


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
