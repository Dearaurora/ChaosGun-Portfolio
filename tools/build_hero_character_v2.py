import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/characters/hero_character_v2.blend"
RUNTIME = ROOT / "assets/models/generated/characters/hero_character_v2.glb"
PREVIEW = ROOT / "reports/hero_character_v2_preview.png"
PREVIEW_3Q = ROOT / "reports/hero_character_v2_three_quarter.png"


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
    for ring in rings:
        z, width, depth = ring[:3]
        y_offset = ring[3] if len(ring) > 3 else 0.0
        for i in range(segments):
            angle = math.tau * i / segments
            # Slightly square the ellipse without introducing hard corners.
            c = math.cos(angle)
            s = math.sin(angle)
            x = math.copysign(abs(c) ** 0.78, c) * width * 0.5
            y = y_offset + math.copysign(abs(s) ** 0.78, s) * depth * depth_scale * 0.5
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


def fuse(name, objects, mat, voxel_size=0.045, smooth_iterations=5):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    fused = bpy.context.object
    fused.name = name
    fused.data.remesh_voxel_size = voxel_size
    bpy.ops.object.voxel_remesh()
    fused.data.materials.clear()
    fused.data.materials.append(mat)
    smooth = fused.modifiers.new("sculpt_surface", "SMOOTH")
    smooth.factor = 0.34
    smooth.iterations = smooth_iterations
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    for polygon in fused.data.polygons:
        polygon.use_smooth = True
    return fused


def boolean_cut(target, cutter):
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for modifier in list(target.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    cutter.select_set(True)
    bpy.context.view_layer.objects.active = cutter
    for modifier in list(cutter.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    cutter.select_set(False)
    bpy.context.view_layer.objects.active = target
    boolean = target.modifiers.new("visor_opening", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.solver = "EXACT"
    boolean.object = cutter
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    for polygon in target.data.polygons:
        polygon.use_smooth = True
    return target


def build_character():
    parts = []
    # One continuous red shell runs from the coat hem through the neck pinch and
    # into the helmet crown. This preserves the reference's uninterrupted body
    # curve while a dense ring pair creates the subtle collar crease.
    outer_suit = loft("OuterSuitSculpt", [
        (0.84, 1.40, 0.96, 0.00),
        (0.92, 1.46, 1.01, 0.00),
        (1.30, 1.47, 1.04, 0.00),
        (1.66, 1.40, 1.01, -0.01),
        (1.76, 1.34, 0.97, -0.02),
        (1.82, 1.28, 0.92, -0.03),
        (1.86, 1.39, 1.02, -0.03),
        (1.93, 1.42, 1.05, -0.03),
        (1.99, 1.29, 0.93, -0.04),
        (2.08, 1.46, 1.10, -0.02),
        (2.36, 1.50, 1.18, -0.04),
        (2.60, 1.43, 1.16, -0.08),
        (2.78, 1.22, 1.02, -0.12),
        (2.91, 0.82, 0.72, -0.15),
        (2.98, 0.28, 0.28, -0.16),
    ], 1.0, RED, segments=48)
    subdivision = outer_suit.modifiers.new("outer_suit_surface", "SUBSURF")
    subdivision.levels = 1
    subdivision.render_levels = 1
    visor_cutter = rounded_box("VisorOpeningCutter", (0, 0.58, 2.16), (1.00, 0.52, 0.54), RED, 0.15)
    parts.append(boolean_cut(outer_suit, visor_cutter))
    parts.append(rounded_box("FaceRecess", (0, 0.46, 2.16), (0.90, 0.11, 0.48), FACE, 0.13))
    for x in (-0.18, 0.18):
        parts.append(rounded_box("EyeL" if x < 0 else "EyeR", (x, 0.53, 2.17), (0.095, 0.045, 0.27), EYE, 0.045))

    # Neutral arms have visible shoulder, elbow, wrist, and cuff transitions.
    for side, sign in (("L", -1), ("R", 1)):
        shoulder = (sign * 0.61, 0.0, 1.57)
        elbow = (sign * 0.92, 0.01, 1.23)
        wrist = (sign * 1.04, 0.10, 0.91)
        parts.append(bent_arm("Arm" + side, shoulder, elbow, wrist, (0.25, 0.215, 0.17), RED))
        palm = (sign * 1.05, 0.12, 0.70)
        glove_group = [
            rounded_box("CuffBase" + side, wrist, (0.37, 0.38, 0.17), PURPLE, 0.075, (0, sign * 0.08, 0)),
            sphere("GlovePalmBase" + side, palm, (0.225, 0.20, 0.29), PURPLE, 28, 16),
            sphere("GloveThumbBase" + side, (sign * 0.90, 0.25, 0.72), (0.115, 0.105, 0.18), PURPLE, 22, 14),
        ]
        parts.append(fuse("Glove" + side, glove_group, PURPLE, 0.032, 4))

    for side, sign in (("L", -1), ("R", 1)):
        parts.append(capsule("Leg" + side, (sign * 0.34, 0, 0.88), (sign * 0.34, 0.02, 0.40), 0.245, 0.225, RED))
        boot_group = [
            rounded_box("BootShaftBase" + side, (sign * 0.34, 0.01, 0.32), (0.52, 0.61, 0.47), PURPLE, 0.13),
            rounded_box("BootToeBase" + side, (sign * 0.34, 0.20, 0.17), (0.55, 0.76, 0.28), PURPLE, 0.13),
        ]
        parts.append(fuse("Boot" + side, boot_group, PURPLE, 0.035, 4))
        parts.append(rounded_box("BootSole" + side, (sign * 0.34, 0.21, 0.055), (0.57, 0.79, 0.10), FACE, 0.04))
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
    preview_parts = []
    preview_pivot = bpy.data.objects.new("PreviewTurntable", None)
    bpy.context.collection.objects.link(preview_pivot)
    for column, angle in ((0.0, 0.0),):
        for source in original:
            obj = source.copy()
            obj.data = source.data.copy()
            obj.location.x += column
            obj.rotation_euler.z = angle
            bpy.context.collection.objects.link(obj)
            obj.parent = preview_pivot
            preview_parts.append(obj)
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
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.78, 0.78, 0.78, 1.0)
    background.inputs["Strength"].default_value = 0.75
    bpy.ops.render.render(write_still=True)
    preview_pivot.rotation_euler.z = math.radians(-35)
    scene.render.filepath = str(PREVIEW_3Q)
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    os.chdir(ROOT)
    clear()
    character_parts = build_character()
    export(character_parts)
    preview(character_parts)
    print("Built", RUNTIME)
    print("Rendered", PREVIEW)
    print("Rendered", PREVIEW_3Q)
