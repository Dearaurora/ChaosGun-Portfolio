import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/characters/hero_character_v2.blend"
RUNTIME = ROOT / "assets/models/generated/characters/hero_character_v2.glb"
PREVIEW = ROOT / "reports/hero_character_v2_preview.png"


def material(name, color, roughness=0.68):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


RED = material("hero_suit_red", (0.88, 0.055, 0.035, 1.0), 0.58)
RED_DARK = material("hero_suit_seam", (0.62, 0.025, 0.02, 1.0), 0.64)
PURPLE = material("hero_rubber_purple", (0.16, 0.065, 0.20, 1.0), 0.62)
FACE = material("hero_face_recess", (0.035, 0.018, 0.055, 1.0), 0.48)
EYE = material("hero_eye_emission", (1.0, 0.46, 0.035, 1.0), 0.32)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def loft(name, rings, depth_scale, mat, segments=32, bevel=0.0):
    vertices = []
    for z, width, depth in rings:
        for i in range(segments):
            angle = math.tau * i / segments
            # Slightly square the ellipse without introducing hard corners.
            c = math.cos(angle)
            s = math.sin(angle)
            x = math.copysign(abs(c) ** 0.78, c) * width * 0.5
            y = math.copysign(abs(s) ** 0.78, s) * depth * depth_scale * 0.5
            vertices.append((x, y, z))
    faces = []
    for ring in range(len(rings) - 1):
        for i in range(segments):
            a = ring * segments + i
            b = ring * segments + (i + 1) % segments
            c = (ring + 1) * segments + (i + 1) % segments
            d = (ring + 1) * segments + i
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(segments))))
    top = (len(rings) - 1) * segments
    faces.append(tuple(top + i for i in range(segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if bevel:
        mod = obj.modifiers.new("edge_softening", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    return obj


def rounded_box(name, location, dimensions, mat, bevel=0.08, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    mod = obj.modifiers.new("form_bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 6
    return obj


def capsule(name, start, end, radius_start, radius_end, mat, segments=24):
    start = Vector(start)
    end = Vector(end)
    axis = end - start
    length = axis.length
    basis = axis.normalized()
    helper = basis.cross(Vector((0, 0, 1)))
    if helper.length < 0.01:
        helper = basis.cross(Vector((0, 1, 0)))
    side = helper.normalized()
    up = basis.cross(side).normalized()
    vertices = []
    ring_count = 8
    for ring in range(ring_count):
        t = ring / (ring_count - 1)
        eased = 0.5 - 0.5 * math.cos(math.pi * t)
        center = start.lerp(end, t)
        radius = radius_start * (1 - eased) + radius_end * eased
        cap_scale = math.sin(math.pi * min(1.0, max(0.0, t * 1.35))) if t < 0.5 else math.sin(math.pi * min(1.0, max(0.0, (1 - t) * 1.35)))
        radius *= max(0.35, cap_scale)
        for i in range(segments):
            angle = math.tau * i / segments
            vertices.append(center + side * math.cos(angle) * radius + up * math.sin(angle) * radius)
    faces = []
    for ring in range(ring_count - 1):
        for i in range(segments):
            a = ring * segments + i
            b = ring * segments + (i + 1) % segments
            c = (ring + 1) * segments + (i + 1) % segments
            d = (ring + 1) * segments + i
            faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def bent_arm(name, shoulder, elbow, wrist, radii, mat, segments=24, path_rings=13):
    shoulder = Vector(shoulder)
    elbow = Vector(elbow)
    wrist = Vector(wrist)
    vertices = []
    centers = []
    for ring in range(path_rings):
        t = ring / (path_rings - 1)
        center = (1 - t) ** 2 * shoulder + 2 * (1 - t) * t * elbow + t ** 2 * wrist
        centers.append(center)
    for ring, center in enumerate(centers):
        t = ring / (path_rings - 1)
        tangent = (centers[min(ring + 1, path_rings - 1)] - centers[max(ring - 1, 0)]).normalized()
        side = tangent.cross(Vector((0, 1, 0)))
        if side.length < 0.01:
            side = tangent.cross(Vector((0, 0, 1)))
        side.normalize()
        depth = tangent.cross(side).normalized()
        if t < 0.55:
            local_t = t / 0.55
            radius = radii[0] * (1 - local_t) + radii[1] * local_t
        else:
            local_t = (t - 0.55) / 0.45
            radius = radii[1] * (1 - local_t) + radii[2] * local_t
        for i in range(segments):
            angle = math.tau * i / segments
            vertices.append(center + side * math.cos(angle) * radius + depth * math.sin(angle) * radius * 0.94)
    faces = []
    for ring in range(path_rings - 1):
        for i in range(segments):
            a = ring * segments + i
            b = ring * segments + (i + 1) % segments
            c = (ring + 1) * segments + (i + 1) % segments
            d = (ring + 1) * segments + i
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(segments))))
    top = (path_rings - 1) * segments
    faces.append(tuple(top + i for i in range(segments)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def sphere(name, location, scale, mat, segments=32, rings=18):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def build_character():
    parts = []
    torso = loft("Torso", [
        (0.78, 1.52, 1.02), (0.88, 1.62, 1.08), (1.25, 1.70, 1.12),
        (1.72, 1.66, 1.12), (1.92, 1.54, 1.04),
    ], 1.0, RED)
    parts.append(torso)

    # Helmet uses overlapping custom volumes to create a hood, brow, cheek walls,
    # and a deep face opening instead of a visor card attached to a sphere.
    parts.append(sphere("HelmetCrown", (0, -0.02, 2.36), (0.90, 0.72, 0.78), RED, 40, 24))
    parts.append(rounded_box("HelmetBrow", (0, 0.665, 2.46), (1.35, 0.22, 0.22), RED, 0.10))
    parts.append(rounded_box("HelmetCheekL", (-0.64, 0.62, 2.12), (0.22, 0.26, 0.66), RED, 0.10))
    parts.append(rounded_box("HelmetCheekR", (0.64, 0.62, 2.12), (0.22, 0.26, 0.66), RED, 0.10))
    parts.append(rounded_box("FaceRecess", (0, 0.705, 2.16), (1.12, 0.15, 0.60), FACE, 0.18))
    parts.append(rounded_box("NeckGuard", (0, 0.02, 1.88), (1.56, 1.10, 0.30), RED, 0.13))
    for x in (-0.22, 0.22):
        parts.append(rounded_box("EyeL" if x < 0 else "EyeR", (x, 0.805, 2.17), (0.105, 0.06, 0.30), EYE, 0.05))

    # Neutral arms have visible shoulder, elbow, wrist, and cuff transitions.
    for side, sign in (("L", -1), ("R", 1)):
        shoulder = (sign * 0.78, 0.0, 1.67)
        elbow = (sign * 1.02, 0.01, 1.22)
        wrist = (sign * 1.10, 0.10, 0.92)
        parts.append(bent_arm("Arm" + side, shoulder, elbow, wrist, (0.27, 0.225, 0.18), RED))
        parts.append(rounded_box("Cuff" + side, wrist, (0.42, 0.42, 0.18), PURPLE, 0.08, (0, sign * 0.10, 0)))
        palm = (sign * 1.12, 0.12, 0.72)
        parts.append(sphere("GlovePalm" + side, palm, (0.25, 0.22, 0.31), PURPLE, 24, 14))
        parts.append(sphere("GloveThumb" + side, (sign * 0.96, 0.28, 0.72), (0.13, 0.12, 0.20), PURPLE, 20, 12))

    for side, sign in (("L", -1), ("R", 1)):
        parts.append(capsule("Leg" + side, (sign * 0.37, 0, 0.77), (sign * 0.37, 0.02, 0.35), 0.27, 0.25, RED))
        parts.append(rounded_box("BootShaft" + side, (sign * 0.37, 0.02, 0.31), (0.57, 0.68, 0.50), PURPLE, 0.14))
        parts.append(rounded_box("BootToe" + side, (sign * 0.37, 0.23, 0.16), (0.60, 0.86, 0.30), PURPLE, 0.14))
        parts.append(rounded_box("BootSole" + side, (sign * 0.37, 0.24, 0.055), (0.62, 0.90, 0.11), FACE, 0.045))
    return parts


def export(parts):
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(RUNTIME), export_format="GLB", use_selection=True, export_apply=True, export_yup=True)


def preview(parts):
    for part in parts:
        part.select_set(False)
    original = list(parts)
    for column, angle in ((-2.7, math.radians(-55)), (0.0, 0.0), (2.7, math.radians(35))):
        for source in original:
            obj = source.copy()
            obj.data = source.data.copy()
            obj.location.x += column
            obj.rotation_euler.z = angle
            bpy.context.collection.objects.link(obj)
    for source in original:
        bpy.data.objects.remove(source, do_unlink=True)

    floor = rounded_box("PreviewFloor", (0, 0, -0.08), (9.5, 4.5, 0.16), material("floor", (0.70, 0.45, 0.30, 1)), 0.04)
    bpy.ops.object.light_add(type="AREA", location=(-4, 5, 7))
    bpy.context.object.data.energy = 1050
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 5
    bpy.ops.object.light_add(type="AREA", location=(5, 2, 4))
    bpy.context.object.data.energy = 700
    bpy.context.object.data.color = (0.55, 0.70, 1.0)
    bpy.context.object.data.size = 4
    bpy.ops.object.camera_add(location=(0, 10.5, 3.4))
    camera = bpy.context.object
    direction = Vector((0, 0, 1.35)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 5.8
    bpy.context.scene.camera = camera
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1536
    scene.render.resolution_y = 800
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW)
    scene.render.film_transparent = False
    scene.world.color = (0.82, 0.82, 0.82)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    os.chdir(ROOT)
    clear()
    character_parts = build_character()
    export(character_parts)
    preview(character_parts)
    print("Built", RUNTIME)
    print("Rendered", PREVIEW)
