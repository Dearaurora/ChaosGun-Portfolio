import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


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


def add_limb_segment(name, start, end, radius, material):
    start_vec = Vector(start)
    end_vec = Vector(end)
    direction = end_vec - start_vec
    midpoint = (start_vec + end_vec) * 0.5
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius, depth=direction.length, location=midpoint)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    obj.data.materials.append(material)
    bevel = obj.modifiers.new(name="limb_rounding", type="BEVEL")
    bevel.width = radius * 0.48
    bevel.segments = 5
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def add_segmented_arm(name, shoulder, elbow, wrist, radius, material):
    add_uv_sphere(name + "Shoulder", shoulder, (radius * 1.08,) * 3, material, 16, 10)
    add_limb_segment(name + "Upper", shoulder, elbow, radius, material)
    add_uv_sphere(name + "Elbow", elbow, (radius * 1.02,) * 3, material, 16, 10)
    add_limb_segment(name + "Fore", elbow, wrist, radius * 0.94, material)


def add_grip_hand(name, palm, palm_size, material, thumb_offset, rotation=(0.0, 0.0, 0.0)):
    add_cube(name + "Palm", palm, palm_size, material, bevel=0.10, rot=rotation)
    thumb = tuple(palm[index] + thumb_offset[index] for index in range(3))
    add_uv_sphere(name + "Thumb", thumb, (0.105, 0.14, 0.10), material, 14, 8)


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


def add_tapered_torso(name, loc, top_size, bottom_size, height, material, bevel=0.18):
    top_x, top_y = top_size
    bottom_x, bottom_y = bottom_size
    bottom_z = -height * 0.5
    top_z = height * 0.5
    vertices = [
        (-bottom_x * 0.5, -bottom_y * 0.5, bottom_z),
        (bottom_x * 0.5, -bottom_y * 0.5, bottom_z),
        (bottom_x * 0.5, bottom_y * 0.5, bottom_z),
        (-bottom_x * 0.5, bottom_y * 0.5, bottom_z),
        (-top_x * 0.5, -top_y * 0.5, top_z),
        (top_x * 0.5, -top_y * 0.5, top_z),
        (top_x * 0.5, top_y * 0.5, top_z),
        (-top_x * 0.5, top_y * 0.5, top_z),
    ]
    faces = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    bevel_mod = obj.modifiers.new(name="toy_bevel", type="BEVEL")
    bevel_mod.width = bevel
    bevel_mod.segments = 6
    bevel_mod.affect = "EDGES"
    normal = obj.modifiers.new(name="weighted_normals", type="WEIGHTED_NORMAL")
    normal.keep_sharp = True
    return obj


def add_marker(name, loc):
    marker = bpy.data.objects.new(name, None)
    marker.location = loc
    bpy.context.collection.objects.link(marker)
    return marker


def build_character():
    # Blender +Y maps to Godot -Z during glTF Y-up conversion.
    # The model deliberately uses a small set of broad forms so it remains readable
    # at the gameplay camera distance and can be reposed without retopology.
    add_tapered_torso("Body", (0.0, -0.01, 1.10), (1.66, 1.16), (1.46, 1.02), 1.30, MAT_BODY, 0.23)
    add_rounded_box("BodyLowerHem", (0.0, 0.0, 0.51), (1.52, 1.08, 0.20), MAT_BODY, 0.10)
    add_uv_sphere("HelmetCollar", (0.0, 0.02, 1.72), (0.91, 0.67, 0.15), MAT_BODY, 24, 10)
    add_uv_sphere("HelmetShell", (0.0, -0.02, 2.15), (0.86, 0.72, 0.70), MAT_BODY, 28, 14)

    # A shallow red frame makes the dark face read as an inset visor instead of
    # a card floating in front of a sphere.
    add_rounded_box("FaceOpening", (0.0, 0.705, 2.12), (1.04, 0.085, 0.49), MAT_FACE, 0.15)
    add_rounded_box("HelmetVisorTop", (0.0, 0.725, 2.43), (1.20, 0.16, 0.15), MAT_BODY, 0.07)
    add_rounded_box("HelmetVisorLeft", (-0.60, 0.72, 2.12), (0.14, 0.16, 0.50), MAT_BODY, 0.06)
    add_rounded_box("HelmetVisorRight", (0.60, 0.72, 2.12), (0.14, 0.16, 0.50), MAT_BODY, 0.06)
    add_uv_sphere("EyeLeft", (-0.20, 0.765, 2.12), (0.070, 0.026, 0.13), MAT_EYE, 12, 8)
    add_uv_sphere("EyeRight", (0.20, 0.765, 2.12), (0.070, 0.026, 0.13), MAT_EYE, 12, 8)

    left_shoulder = (-0.78, 0.05, 1.46)
    right_shoulder = (0.78, 0.05, 1.46)

    pistol_left_elbow = (-0.66, 0.55, 1.27)
    pistol_left_glove = (-0.13, 1.12, 1.20)
    pistol_right_elbow = (0.66, 0.50, 1.24)
    pistol_right_glove = (0.13, 1.08, 1.16)
    add_segmented_arm("BodyPosePistolArmLeft", left_shoulder, pistol_left_elbow, pistol_left_glove, 0.17, MAT_BODY)
    add_segmented_arm("BodyPosePistolArmRight", right_shoulder, pistol_right_elbow, pistol_right_glove, 0.17, MAT_BODY)
    add_grip_hand("PosePistolGloveLeft", pistol_left_glove, (0.28, 0.30, 0.32), MAT_GLOVE, (0.13, 0.08, -0.05))
    add_grip_hand("PosePistolGloveRight", pistol_right_glove, (0.28, 0.30, 0.32), MAT_GLOVE, (-0.13, 0.08, -0.05))

    # Long weapons use a low-ready two-point pose: trigger hand near the chest,
    # support hand pushed forward along the fore-end, with clear torso clearance.
    long_left_elbow = (-0.70, 0.76, 1.05)
    long_left_glove = (-0.09, 2.02, 1.23)
    long_right_elbow = (0.72, 0.38, 0.98)
    long_right_glove = (0.14, 1.12, 1.23)
    add_segmented_arm("BodyPoseLongArmLeft", left_shoulder, long_left_elbow, long_left_glove, 0.18, MAT_BODY)
    add_segmented_arm("BodyPoseLongArmRight", right_shoulder, long_right_elbow, long_right_glove, 0.18, MAT_BODY)
    # The support palm is broad horizontally and sits below the fore-end. The
    # trigger palm is vertical so it reads as wrapping the pistol grip.
    add_grip_hand("PoseLongGloveLeft", long_left_glove, (0.38, 0.38, 0.22), MAT_GLOVE, (0.16, 0.02, 0.02))
    add_grip_hand("PoseLongGloveRight", long_right_glove, (0.30, 0.26, 0.38), MAT_GLOVE, (-0.13, 0.06, -0.04))
    add_marker("LeftHandGrip", long_left_glove)
    add_marker("RightHandGrip", long_right_glove)

    add_uv_sphere("LeftLeg", (-0.39, 0.0, 0.49), (0.31, 0.31, 0.42), MAT_BODY, 20, 10)
    add_uv_sphere("RightLeg", (0.39, 0.0, 0.49), (0.31, 0.31, 0.42), MAT_BODY, 20, 10)
    add_rounded_box("LeftBoot", (-0.39, 0.13, 0.20), (0.58, 0.74, 0.40), MAT_BOOT, 0.17)
    add_rounded_box("RightBoot", (0.39, 0.13, 0.20), (0.58, 0.74, 0.40), MAT_BOOT, 0.17)


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
