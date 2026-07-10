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
    # Blender export uses Y-up conversion. Model front is -Y in Blender so it lands on -Z in Godot.
    add_uv_sphere("Body", (0, 0, 1.28), (1.08, 0.96, 0.98), MAT_BODY, 36, 18)
    add_uv_sphere("BellyLower", (0, 0.02, 0.68), (0.86, 0.78, 0.48), MAT_BODY, 32, 12)

    add_uv_sphere("FaceVisorRim", (0, -0.86, 1.42), (0.68, 0.17, 0.34), MAT_VISOR_RIM, 28, 12)
    add_uv_sphere("FaceVisorGlass", (0, -0.96, 1.42), (0.55, 0.07, 0.24), MAT_VISOR_GLASS, 28, 10)
    add_uv_sphere("FaceVisorHighlight", (-0.24, -1.01, 1.52), (0.14, 0.025, 0.045), MAT_HIGHLIGHT, 16, 6)

    add_uv_sphere("LeftHand", (-0.88, -0.47, 0.98), (0.24, 0.21, 0.27), MAT_BODY, 20, 10)
    add_uv_sphere("RightHand", (0.88, -0.47, 0.98), (0.24, 0.21, 0.27), MAT_BODY, 20, 10)
    add_uv_sphere("LeftHandGrip", (0.38, -0.90, 0.96), (0.18, 0.14, 0.22), MAT_BODY, 20, 10)
    add_uv_sphere("RightHandGrip", (0.78, -0.86, 0.98), (0.20, 0.15, 0.24), MAT_BODY, 20, 10)
    add_uv_sphere("LeftFoot", (-0.42, -0.20, 0.20), (0.36, 0.43, 0.18), MAT_FOOT, 20, 8)
    add_uv_sphere("RightFoot", (0.42, -0.20, 0.20), (0.36, 0.43, 0.18), MAT_FOOT, 20, 8)

    add_cube("ToyShadowSoftener", (0, 0.12, 0.08), (1.36, 0.86, 0.05), MAT_FOOT, 0.12, (0, 0, math.radians(0)))


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
