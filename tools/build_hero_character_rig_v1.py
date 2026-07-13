from pathlib import Path
from math import cos, pi, sin

import bpy
import bmesh
from mathutils import Quaternion, Vector


ROOT = Path(__file__).resolve().parents[1]
CHARACTER = ROOT / "assets/models/generated/characters/hero_character_cloud_v1.glb"
WEAPONS = ROOT / "assets/models/generated/weapons"
SOURCE = ROOT / "assets/source/characters/hero_character_rig_v1.blend"
RUNTIME = ROOT / "assets/models/generated/characters/hero_character_rig_v1.glb"
OUT_NEUTRAL = ROOT / "reports/hero_character_rig_v1_neutral.png"
OUT_PISTOL = ROOT / "reports/hero_character_rig_v1_pistol.png"
OUT_SMG = ROOT / "reports/hero_character_rig_v1_smg.png"
OUT_AK = ROOT / "reports/hero_character_rig_v1_ak.png"
OUT_SNIPER = ROOT / "reports/hero_character_rig_v1_sniper.png"

POSES = {
    "neutral": {
        "left": (-0.98, -0.015, 0.87),
        "right": (0.98, -0.015, 0.87),
        "ik": False,
    },
    "hold_pistol": {
        "left": (-0.11, -0.71, 1.27),
        "right": (0.11, -0.68, 1.24),
        "ik": True,
    },
    "hold_smg": {
        "left": (-0.03, -1.02, 1.38),
        "right": (0.23, -0.83, 1.22),
        "ik": True,
    },
    "hold_ak": {
        "left": (-0.04, -1.26, 1.42),
        "right": (0.25, -1.00, 1.22),
        "ik": True,
    },
    "hold_sniper": {
        "left": (-0.05, -1.36, 1.43),
        "right": (0.24, -1.02, 1.23),
        "ik": True,
    },
}


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def import_character():
    bpy.ops.import_scene.gltf(filepath=str(CHARACTER))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    body = next(obj for obj in meshes if obj.name == "HeroCloudBody")
    details = [obj for obj in meshes if obj is not body]
    remove_reconstructed_sleeves(body)
    suit_material = body.data.materials[0]
    arm_parts = []
    for suffix, sign in (("L", -1.0), ("R", 1.0)):
        arm_parts.append(create_shoulder_socket(suffix, sign, suit_material))
        arm_parts.append(create_clean_sleeve(suffix, sign, suit_material))
    return body, details, arm_parts


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


def smoothstep(edge_start, edge_end, value):
    t = max(0.0, min(1.0, (value - edge_start) / (edge_end - edge_start)))
    return t * t * (3.0 - 2.0 * t)


def remove_reconstructed_sleeves(body):
    mesh = body.data
    components, _neighbors = connected_components(mesh)
    main_component = set(components[0])
    remove_indices = []
    for vertex in mesh.vertices:
        if vertex.index not in main_component:
            continue
        point = vertex.co
        height_blend = smoothstep(1.10, 1.68, point.z)
        inner_limit = 0.69 - 0.21 * height_blend
        cut_padding = 0.06 if point.z > 1.55 else 0.0
        if (
            1.02 < point.z < 1.90
            and abs(point.x) > inner_limit + cut_padding
            and -0.38 < point.y < 0.34
        ):
            remove_indices.append(vertex.index)

    editable = bmesh.new()
    editable.from_mesh(mesh)
    editable.verts.ensure_lookup_table()
    bmesh.ops.delete(
        editable,
        geom=[editable.verts[index] for index in remove_indices],
        context="VERTS",
    )
    editable.to_mesh(mesh)
    editable.free()
    mesh.update()
    print("REMOVED_RECONSTRUCTED_SLEEVES", len(remove_indices), "VERTICES")


def quadratic_point(start, control, end, t):
    return start * ((1.0 - t) ** 2) + control * (2.0 * (1.0 - t) * t) + end * (t ** 2)


def quadratic_tangent(start, control, end, t):
    return (control - start) * (2.0 * (1.0 - t)) + (end - control) * (2.0 * t)


def create_shoulder_socket(suffix, sign, material):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24,
        ring_count=12,
        location=(sign * 0.51, 0.0, 1.65),
    )
    socket = bpy.context.object
    socket.name = "HeroShoulderSocket." + suffix
    socket.data.name = "HeroShoulderSocketMesh." + suffix
    socket.scale = (0.105, 0.32, 0.36)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    socket.data.materials.append(material)
    for polygon in socket.data.polygons:
        polygon.use_smooth = True
    spine_group = socket.vertex_groups.new(name="Spine")
    spine_group.add(
        [vertex.index for vertex in socket.data.vertices],
        1.0,
        "REPLACE",
    )
    return socket


def create_clean_sleeve(suffix, sign, material):
    path_ring_count = 13
    radial_segments = 16
    start = Vector((sign * 0.56, -0.005, 1.68))
    control = Vector((sign * 0.79, -0.005, 1.43))
    end = Vector((sign * 0.89, -0.005, 1.14))
    depth_axis = Vector((0.0, 1.0, 0.0))
    vertices = []
    ring_parameters = []
    start_tangent = quadratic_tangent(start, control, end, 0.0).normalized()
    samples = [
        (start - start_tangent * 0.16, 0.0, 0.055),
        (start - start_tangent * 0.09, 0.0, 0.205),
        (start, 0.0, 0.285),
    ]
    for ring_index in range(1, path_ring_count):
        t = ring_index / (path_ring_count - 1)
        center = quadratic_point(start, control, end, t)
        radius = 0.275 * (1.0 - t) + 0.175 * t + sin(pi * t) * 0.010
        samples.append((center, t, radius))

    ring_count = len(samples)
    for center, t, radius in samples:
        tangent = quadratic_tangent(start, control, end, t).normalized()
        side_axis = depth_axis.cross(tangent).normalized()
        for segment_index in range(radial_segments):
            angle = 2.0 * pi * segment_index / radial_segments
            point = (
                center
                + depth_axis * cos(angle) * radius * 0.90
                + side_axis * sin(angle) * radius
            )
            vertices.append(tuple(point))
            ring_parameters.append(t)

    start_cap_index = len(vertices)
    vertices.append(tuple(samples[0][0]))
    ring_parameters.append(0.0)
    end_cap_index = len(vertices)
    vertices.append(tuple(end))
    ring_parameters.append(1.0)

    faces = []
    for ring_index in range(ring_count - 1):
        current = ring_index * radial_segments
        following = (ring_index + 1) * radial_segments
        for segment_index in range(radial_segments):
            next_segment = (segment_index + 1) % radial_segments
            faces.append((
                current + segment_index,
                current + next_segment,
                following + next_segment,
                following + segment_index,
            ))
    for segment_index in range(radial_segments):
        next_segment = (segment_index + 1) % radial_segments
        faces.append((start_cap_index, next_segment, segment_index))
        end_ring = (ring_count - 1) * radial_segments
        faces.append((end_cap_index, end_ring + segment_index, end_ring + next_segment))

    mesh = bpy.data.meshes.new("HeroSleeveMesh." + suffix)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    mesh.validate()
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True

    sleeve = bpy.data.objects.new("HeroSleeve." + suffix, mesh)
    bpy.context.collection.objects.link(sleeve)
    groups = {
        name: sleeve.vertex_groups.new(name=name)
        for name in ["UpperArm." + suffix, "Forearm." + suffix]
    }
    for vertex_index, t in enumerate(ring_parameters):
        elbow_blend = smoothstep(0.45, 0.68, t)
        weights = {
            "UpperArm." + suffix: 1.0 - elbow_blend,
            "Forearm." + suffix: elbow_blend,
        }
        for group_name, weight in weights.items():
            if weight > 0.0001:
                groups[group_name].add([vertex_index], weight, "REPLACE")
    return sleeve


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

    components, _neighbors = connected_components(mesh)
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


def build_rig(body, details, sleeves):
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

    for sleeve in sleeves:
        sleeve.parent = armature
        sleeve_modifier = sleeve.modifiers.new("HeroRigDeform", "ARMATURE")
        sleeve_modifier.object = armature

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


def reset_pose(armature):
    if armature.animation_data is not None:
        armature.animation_data.action = None
    for bone in armature.pose.bones:
        bone.matrix_basis.identity()
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def bake_pose_action(armature, targets, action_name, pose):
    reset_pose(armature)
    set_ik(
        armature,
        targets,
        pose["left"],
        pose["right"],
        pose["ik"],
    )

    action = bpy.data.actions.new(action_name)
    action.use_fake_user = True
    armature.animation_data_create()
    armature.animation_data.action = action

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.nla.bake(
        frame_start=1,
        frame_end=2,
        step=1,
        only_selected=True,
        visual_keying=True,
        clear_constraints=False,
        clear_parents=False,
        use_current_action=True,
        clean_curves=False,
        bake_types={"POSE"},
    )
    bpy.ops.object.mode_set(mode="OBJECT")

    action = armature.animation_data.action
    action.name = action_name
    action.use_fake_user = True

    # Godot removes fully immutable tracks by default. The game always samples
    # frame 1, while this tiny frame-2 delta keeps every bone pose portable.
    bpy.context.scene.frame_set(2)
    for bone in armature.pose.bones:
        bone.rotation_quaternion = (
            Quaternion((0.0, 0.0, 1.0), 0.002) @ bone.rotation_quaternion
        ).normalized()
        bone.keyframe_insert(
            data_path="rotation_quaternion",
            frame=2,
            group=bone.name,
        )
    bpy.context.scene.frame_set(1)
    armature.animation_data.action = None
    return action


def build_pose_actions(armature, targets):
    actions = []
    for action_name, pose in POSES.items():
        actions.append(bake_pose_action(armature, targets, action_name, pose))
    reset_pose(armature)
    return actions


def detach_ik_constraints(armature):
    detached = []
    for suffix in ("L", "R"):
        hand = armature.pose.bones["Hand." + suffix]
        constraint = hand.constraints.get("HandIK")
        if constraint is None:
            continue
        detached.append({
            "bone": hand,
            "target": constraint.target,
            "pole_target": constraint.pole_target,
            "chain_count": constraint.chain_count,
            "use_rotation": constraint.use_rotation,
            "influence": constraint.influence,
        })
        hand.constraints.remove(constraint)
    return detached


def restore_ik_constraints(detached):
    for spec in detached:
        constraint = spec["bone"].constraints.new("IK")
        constraint.name = "HandIK"
        constraint.target = spec["target"]
        constraint.pole_target = spec["pole_target"]
        constraint.chain_count = spec["chain_count"]
        constraint.use_rotation = spec["use_rotation"]
        constraint.influence = spec["influence"]


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


def save_and_export_runtime(armature, body, details, sleeves):
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    RUNTIME.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in [armature, body, *details, *sleeves]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    detached_constraints = detach_ik_constraints(armature)
    try:
        bpy.ops.export_scene.gltf(
            filepath=str(RUNTIME),
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_apply=False,
            export_skins=True,
            export_animations=True,
            export_animation_mode="ACTIONS",
            export_merge_animation="NONE",
        )
    finally:
        restore_ik_constraints(detached_constraints)
    print("SAVED_SOURCE", SOURCE)
    print("EXPORTED_RUNTIME", RUNTIME)


def main():
    clear_scene()
    hero_body, hero_details, hero_sleeves = import_character()
    hero_rig, hand_targets, _elbow_poles = build_rig(hero_body, hero_details, hero_sleeves)
    build_pose_actions(hero_rig, hand_targets)

    neutral_pose = POSES["neutral"]
    set_ik(hero_rig, hand_targets, neutral_pose["left"], neutral_pose["right"], False)
    save_and_export_runtime(hero_rig, hero_body, hero_details, hero_sleeves)

    scene = setup_render()
    render(scene, OUT_NEUTRAL)

    pistol = import_weapon("pistol", (0.0, -0.72, 1.39), 1.0)
    pistol_pose = POSES["hold_pistol"]
    set_ik(hero_rig, hand_targets, pistol_pose["left"], pistol_pose["right"])
    render(scene, OUT_PISTOL)
    pistol.hide_render = True

    smg = import_weapon("smg", (0.12, -0.83, 1.35), 0.84)
    smg_pose = POSES["hold_smg"]
    set_ik(hero_rig, hand_targets, smg_pose["left"], smg_pose["right"])
    render(scene, OUT_SMG)
    smg.hide_render = True

    ak = import_weapon("ak_rifle", (0.18, -0.92, 1.34), 0.74)
    ak_pose = POSES["hold_ak"]
    set_ik(hero_rig, hand_targets, ak_pose["left"], ak_pose["right"])
    render(scene, OUT_AK)
    ak.hide_render = True

    sniper = import_weapon("sniper", (0.18, -0.96, 1.35), 0.68)
    sniper_pose = POSES["hold_sniper"]
    set_ik(hero_rig, hand_targets, sniper_pose["left"], sniper_pose["right"])
    render(scene, OUT_SNIPER)
    print("RENDERED", OUT_NEUTRAL, OUT_PISTOL, OUT_SMG, OUT_AK, OUT_SNIPER)


if __name__ == "__main__":
    main()
