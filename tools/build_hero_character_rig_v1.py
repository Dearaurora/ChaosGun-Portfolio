from pathlib import Path
import heapq

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
CHARACTER = ROOT / "assets/models/generated/characters/hero_character_cloud_v1.glb"
WEAPONS = ROOT / "assets/models/generated/weapons"
SOURCE = ROOT / "assets/source/characters/hero_character_rig_v1.blend"
RUNTIME = ROOT / "assets/models/generated/characters/hero_character_rig_v1.glb"
OUT_NEUTRAL = ROOT / "reports/hero_character_rig_v1_neutral.png"
OUT_PISTOL = ROOT / "reports/hero_character_rig_v1_pistol.png"
OUT_AK = ROOT / "reports/hero_character_rig_v1_ak.png"
OUT_SNIPER = ROOT / "reports/hero_character_rig_v1_sniper.png"


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_character():
    bpy.ops.import_scene.gltf(filepath=str(CHARACTER))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    body = next(obj for obj in meshes if obj.name == "HeroCloudBody")
    details = [obj for obj in meshes if obj is not body]
    return body, details


def add_bone(armature, name, head, tail, parent=None, connected=False):
    bone = armature.data.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.parent = parent
    bone.use_connect = connected
    return bone


def connected_components(mesh):
    neighbors = [set() for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        neighbors[a].add(b)
        neighbors[b].add(a)
    unvisited = set(range(len(mesh.vertices)))
    components = []
    while unvisited:
        seed = unvisited.pop()
        stack = [seed]
        component = [seed]
        while stack:
            current = stack.pop()
            for neighbor in neighbors[current]:
                if neighbor in unvisited:
                    unvisited.remove(neighbor)
                    stack.append(neighbor)
                    component.append(neighbor)
        components.append(component)
    components.sort(key=len, reverse=True)
    return components, neighbors


def component_bounds(mesh, component):
    points = [mesh.vertices[index].co for index in component]
    return (
        Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points))),
        Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points))),
    )


def segment_distance(point, start, end):
    axis = end - start
    t = max(0.0, min(1.0, (point - start).dot(axis) / axis.length_squared))
    return (point - start.lerp(end, t)).length


def sleeve_vertices(mesh, neighbors, sign, main_component):
    main_vertices = set(main_component)
    allowed = {
        vertex.index
        for vertex in mesh.vertices
        if vertex.index in main_vertices
        and sign * vertex.co.x > 0.48
        and 0.82 < vertex.co.z < 1.90
        and -0.36 < vertex.co.y < 0.30
        and (sign * vertex.co.x > 0.66 or vertex.co.z > 1.36)
    }
    seeds = [
        vertex.index
        for vertex in mesh.vertices
        if vertex.index in allowed
        and sign * vertex.co.x > 0.84
        and 0.96 < vertex.co.z < 1.36
    ]
    distances = {index: 0.0 for index in seeds}
    queue = [(0.0, index) for index in seeds]
    heapq.heapify(queue)
    while queue:
        distance, current = heapq.heappop(queue)
        if distance != distances[current]:
            continue
        for neighbor in neighbors[current]:
            if neighbor not in allowed:
                continue
            edge_length = (mesh.vertices[current].co - mesh.vertices[neighbor].co).length
            candidate = distance + edge_length
            if candidate > 0.62 or candidate >= distances.get(neighbor, float("inf")):
                continue
            distances[neighbor] = candidate
            heapq.heappush(queue, (candidate, neighbor))
    return set(distances)


def assign_manual_weights(body):
    mesh = body.data
    body.vertex_groups.clear()
    groups = {
        name: body.vertex_groups.new(name=name)
        for name in [
            "Root", "Spine", "Head",
            "UpperArm.L", "Forearm.L", "Hand.L",
            "UpperArm.R", "Forearm.R", "Hand.R",
            "Thigh.L", "Shin.L", "Foot.L",
            "Thigh.R", "Shin.R", "Foot.R",
        ]
    }
    all_vertices = [vertex.index for vertex in mesh.vertices]
    groups["Spine"].add(all_vertices, 1.0, "REPLACE")

    components, neighbors = connected_components(mesh)
    for component in components[1:]:
        minimum, maximum = component_bounds(mesh, component)
        if minimum.z > 0.60 and maximum.z < 1.40:
            suffix = "L" if maximum.x < 0.0 else "R"
            groups["Spine"].remove(component)
            groups["Hand." + suffix].add(component, 1.0, "REPLACE")
        elif maximum.z < 0.60:
            suffix = "L" if maximum.x < 0.0 else "R"
            groups["Spine"].remove(component)
            groups["Foot." + suffix].add(component, 1.0, "REPLACE")

    arm_values = {}
    for suffix, sign in (("L", -1.0), ("R", 1.0)):
        selected = sleeve_vertices(mesh, neighbors, sign, components[0])
        upper_values = [0.0] * len(mesh.vertices)
        forearm_values = [0.0] * len(mesh.vertices)
        shoulder = Vector((sign * 0.56, 0.0, 1.72))
        elbow = Vector((sign * 0.76, 0.0, 1.39))
        wrist = Vector((sign * 0.89, -0.005, 1.14))
        for vertex_index in selected:
            point = mesh.vertices[vertex_index].co
            upper_distance = segment_distance(point, shoulder, elbow)
            forearm_distance = segment_distance(point, elbow, wrist)
            upper_weight = 1.0 / max(0.02, upper_distance) ** 2
            forearm_weight = 1.0 / max(0.02, forearm_distance) ** 2
            total = upper_weight + forearm_weight
            upper_weight /= total
            forearm_weight /= total
            shoulder_blend = max(0.0, 1.0 - (point - shoulder).length / 0.24) * 0.55
            arm_scale = 1.0 - shoulder_blend
            upper_values[vertex_index] = upper_weight * arm_scale
            forearm_values[vertex_index] = forearm_weight * arm_scale

        arm_values[suffix] = [upper_values, forearm_values]

        points = [mesh.vertices[index].co for index in selected]
        minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
        maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
        print("SLEEVE", suffix, "VERTICES", len(selected), "BOUNDS", tuple(minimum), tuple(maximum))

    main_vertices = components[0]
    main_set = set(main_vertices)
    for suffix in ("L", "R"):
        for value_index in (0, 1):
            values = arm_values[suffix][value_index]
            for _ in range(10):
                smoothed = values.copy()
                for vertex_index in main_vertices:
                    adjacent = [index for index in neighbors[vertex_index] if index in main_set]
                    if not adjacent:
                        continue
                    average = sum(values[index] for index in adjacent) / len(adjacent)
                    smoothed[vertex_index] = values[vertex_index] * 0.45 + average * 0.55
                values = smoothed
            arm_values[suffix][value_index] = values

    groups["Spine"].remove(main_vertices)
    for suffix in ("L", "R"):
        groups["UpperArm." + suffix].remove(main_vertices)
        groups["Forearm." + suffix].remove(main_vertices)
    for vertex_index in main_vertices:
        weights = {
            "UpperArm.L": arm_values["L"][0][vertex_index],
            "Forearm.L": arm_values["L"][1][vertex_index],
            "UpperArm.R": arm_values["R"][0][vertex_index],
            "Forearm.R": arm_values["R"][1][vertex_index],
        }
        arm_total = sum(weights.values())
        if arm_total > 1.0:
            weights = {name: value / arm_total for name, value in weights.items()}
            arm_total = 1.0
        spine_weight = 1.0 - arm_total
        if spine_weight > 0.0001:
            groups["Spine"].add([vertex_index], spine_weight, "REPLACE")
        for name, value in weights.items():
            if value > 0.0001:
                groups[name].add([vertex_index], value, "REPLACE")


def build_rig(body, details):
    armature_data = bpy.data.armatures.new("HeroRig")
    armature = bpy.data.objects.new("HeroRig", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    root = add_bone(armature, "Root", (0, 0, 0.02), (0, 0, 0.32))
    spine = add_bone(armature, "Spine", (0, 0, 0.62), (0, 0, 1.78), root)
    add_bone(armature, "Head", (0, 0, 1.78), (0, 0, 2.72), spine)

    for suffix, sign in (("L", -1.0), ("R", 1.0)):
        upper = add_bone(
            armature,
            "UpperArm." + suffix,
            (sign * 0.56, 0.0, 1.72),
            (sign * 0.76, 0.0, 1.39),
            spine,
        )
        forearm = add_bone(
            armature,
            "Forearm." + suffix,
            upper.tail,
            (sign * 0.89, -0.005, 1.14),
            upper,
            True,
        )
        add_bone(
            armature,
            "Hand." + suffix,
            forearm.tail,
            (sign * 0.98, -0.015, 0.87),
            forearm,
            True,
        )
        thigh = add_bone(
            armature,
            "Thigh." + suffix,
            (sign * 0.31, 0.0, 0.92),
            (sign * 0.31, 0.0, 0.54),
            root,
        )
        shin = add_bone(
            armature,
            "Shin." + suffix,
            thigh.tail,
            (sign * 0.31, -0.015, 0.20),
            thigh,
            True,
        )
        add_bone(
            armature,
            "Foot." + suffix,
            shin.tail,
            (sign * 0.31, -0.28, 0.13),
            shin,
        )

    bpy.ops.object.mode_set(mode="OBJECT")
    assign_manual_weights(body)
    body.parent = armature
    modifier = body.modifiers.new("HeroRigDeform", "ARMATURE")
    modifier.object = armature

    for detail in details:
        world = detail.matrix_world.copy()
        detail.parent = armature
        detail.parent_type = "BONE"
        detail.parent_bone = "Head"
        detail.matrix_world = world

    targets = {}
    poles = {}
    for suffix, sign in (("L", -1.0), ("R", 1.0)):
        target = bpy.data.objects.new("IK_Hand." + suffix, None)
        target.empty_display_type = "SPHERE"
        target.empty_display_size = 0.08
        bpy.context.collection.objects.link(target)
        targets[suffix] = target

        pole = bpy.data.objects.new("Pole_Elbow." + suffix, None)
        pole.empty_display_type = "CUBE"
        pole.empty_display_size = 0.10
        pole.location = (sign * 1.25, -0.35, 1.34)
        bpy.context.collection.objects.link(pole)
        poles[suffix] = pole

        hand = armature.pose.bones["Hand." + suffix]
        constraint = hand.constraints.new("IK")
        constraint.name = "HandIK"
        constraint.target = target
        constraint.pole_target = pole
        constraint.chain_count = 3
        constraint.use_rotation = False
        constraint.influence = 0.0

    return armature, targets, poles


def set_ik(armature, targets, left, right, enabled=True):
    targets["L"].location = left
    targets["R"].location = right
    for suffix in ("L", "R"):
        armature.pose.bones["Hand." + suffix].constraints["HandIK"].influence = 1.0 if enabled else 0.0
    bpy.context.view_layer.update()


def import_weapon(name, location, scale):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(WEAPONS / (name + ".glb")))
    imported = [obj for obj in bpy.context.scene.objects if obj not in before]
    root = bpy.data.objects.new("Weapon_" + name, None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent not in imported:
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world
    root.location = location
    root.scale = Vector((scale, scale, scale))
    return root


def setup_render():
    floor_mat = bpy.data.materials.new("Floor")
    floor_mat.diffuse_color = (0.26, 0.22, 0.26, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, -0.015))
    bpy.context.object.data.materials.append(floor_mat)

    bpy.ops.object.light_add(type="AREA", location=(-4, -4, 7))
    bpy.context.object.data.energy = 1050
    bpy.context.object.data.size = 5
    bpy.ops.object.light_add(type="AREA", location=(4, 1, 4))
    bpy.context.object.data.energy = 650
    bpy.context.object.data.color = (0.55, 0.67, 1.0)
    bpy.context.object.data.size = 4

    bpy.ops.object.camera_add(location=(6.8, -4.3, 3.5))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 4.0
    camera.rotation_euler = (Vector((0, -0.38, 1.45)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.045, 0.045, 0.06, 1.0)
    background.inputs["Strength"].default_value = 0.38
    return scene


def render(scene, path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def save_and_export_runtime(armature, body, details):
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in [armature, body, *details]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(
        filepath=str(RUNTIME),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_animations=False,
    )
    print("SAVED_SOURCE", SOURCE)
    print("EXPORTED_RUNTIME", RUNTIME)


def main():
    clear_scene()
    hero_body, hero_details = import_character()
    hero_rig, hand_targets, _elbow_poles = build_rig(hero_body, hero_details)

    rest_left = (-0.98, -0.015, 0.87)
    rest_right = (0.98, -0.015, 0.87)
    set_ik(hero_rig, hand_targets, rest_left, rest_right, False)
    save_and_export_runtime(hero_rig, hero_body, hero_details)

    scene = setup_render()
    render(scene, OUT_NEUTRAL)

    pistol = import_weapon("pistol", (0.0, -0.72, 1.39), 1.0)
    set_ik(hero_rig, hand_targets, (-0.11, -0.71, 1.27), (0.11, -0.68, 1.24))
    render(scene, OUT_PISTOL)
    pistol.hide_render = True

    ak = import_weapon("ak_rifle", (0.18, -0.92, 1.34), 0.74)
    set_ik(hero_rig, hand_targets, (-0.04, -1.26, 1.42), (0.25, -1.00, 1.22))
    render(scene, OUT_AK)
    ak.hide_render = True

    sniper = import_weapon("sniper", (0.18, -0.96, 1.35), 0.68)
    set_ik(hero_rig, hand_targets, (-0.05, -1.36, 1.43), (0.24, -1.02, 1.23))
    render(scene, OUT_SNIPER)
    print("RENDERED", OUT_NEUTRAL, OUT_PISTOL, OUT_AK, OUT_SNIPER)


if __name__ == "__main__":
    main()
