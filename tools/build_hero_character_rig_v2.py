from math import radians
from pathlib import Path
import sys

import bpy
from mathutils import Quaternion, Vector


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_hero_character_rig_v1 as base


SOURCE = ROOT / "assets/source/characters/hero_character_rig_v2.blend"
RUNTIME = ROOT / "assets/models/generated/characters/hero_character_rig_v2.glb"
OUT_NEUTRAL = ROOT / "reports/hero_character_rig_v2_neutral.png"
OUT_POSES = {
    "pistol": ROOT / "reports/hero_character_rig_v2_pistol.png",
    "smg": ROOT / "reports/hero_character_rig_v2_smg.png",
    "ak_rifle": ROOT / "reports/hero_character_rig_v2_ak.png",
    "sniper": ROOT / "reports/hero_character_rig_v2_sniper.png",
    "shotgun": ROOT / "reports/hero_character_rig_v2_shotgun.png",
    "gatling": ROOT / "reports/hero_character_rig_v2_gatling.png",
}

POSES = {
    "neutral": {
        "left": (-0.98, -0.015, 0.87),
        "right": (0.98, -0.015, 0.87),
        "ik": False,
        "spine_pitch": 0.0,
        "left_hand_scale": 1.0,
        "right_hand_scale": 1.0,
    },
    "hold_pistol": {
        "left": (-0.10, -0.76, 1.29),
        "right": (0.12, -0.70, 1.24),
        "ik": True,
        "spine_pitch": 2.5,
        "left_hand_scale": 0.92,
        "right_hand_scale": 0.92,
    },
    "hold_smg": {
        "left": (-0.03, -1.24, 1.24),
        "right": (0.22, -0.86, 1.18),
        "ik": True,
        "spine_pitch": 3.5,
        "left_hand_scale": 0.82,
        "right_hand_scale": 0.90,
    },
    "hold_ak": {
        "left": (-0.03, -1.40, 1.24),
        "right": (0.24, -1.01, 1.17),
        "ik": True,
        "spine_pitch": 4.5,
        "left_hand_scale": 0.80,
        "right_hand_scale": 0.90,
    },
    "hold_sniper": {
        "left": (-0.04, -1.38, 1.22),
        "right": (0.24, -1.02, 1.17),
        "ik": True,
        "spine_pitch": 5.0,
        "left_hand_scale": 0.80,
        "right_hand_scale": 0.90,
    },
    "hold_shotgun": {
        "left": (-0.03, -1.42, 1.20),
        "right": (0.23, -0.96, 1.15),
        "ik": True,
        "spine_pitch": 5.0,
        "left_hand_scale": 0.82,
        "right_hand_scale": 0.90,
    },
    "hold_gatling": {
        "left": (-0.06, -1.30, 1.12),
        "right": (0.20, -0.91, 1.10),
        "ik": True,
        "spine_pitch": 6.5,
        "left_hand_scale": 0.84,
        "right_hand_scale": 0.90,
    },
}

WEAPON_PREVIEWS = {
    "pistol": ((0.0, -0.72, 1.39), 1.0, "hold_pistol"),
    "smg": ((0.12, -0.83, 1.35), 0.84, "hold_smg"),
    "ak_rifle": ((0.18, -0.92, 1.34), 0.74, "hold_ak"),
    "sniper": ((0.18, -0.96, 1.35), 0.68, "hold_sniper"),
    "shotgun": ((0.14, -0.90, 1.31), 0.72, "hold_shotgun"),
    "gatling": ((0.10, -0.88, 1.27), 0.66, "hold_gatling"),
}

MOTION_FPS = 30
MOTION_PROFILES = {
    "pistol": {"pose": "hold_pistol", "stride": 19.0, "brace": 1.00},
    "smg": {"pose": "hold_smg", "stride": 17.5, "brace": 1.04},
    "ak": {"pose": "hold_ak", "stride": 16.0, "brace": 1.08},
    "sniper": {"pose": "hold_sniper", "stride": 13.5, "brace": 1.14},
    "shotgun": {"pose": "hold_shotgun", "stride": 15.0, "brace": 1.12},
    "gatling": {"pose": "hold_gatling", "stride": 11.5, "brace": 1.20},
}


def assign_rigid_weight(obj, bone_name):
    group = obj.vertex_groups.new(name=bone_name)
    group.add([vertex.index for vertex in obj.data.vertices], 1.0, "REPLACE")


def create_wrist_cuff(suffix, sign, material):
    forearm_axis = Vector((sign * 0.26, 0.0, -0.48)).normalized()
    center = Vector((sign * 0.90, -0.006, 1.13))
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=16,
        location=center,
    )
    cuff = bpy.context.object
    cuff.name = "HeroWristCuff." + suffix
    cuff.data.name = "HeroWristCuffMesh." + suffix
    cuff.rotation_mode = "QUATERNION"
    cuff.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(forearm_axis)
    cuff.scale = (0.190, 0.180, 0.110)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    cuff.data.materials.append(material)
    for polygon in cuff.data.polygons:
        polygon.use_smooth = True
    assign_rigid_weight(cuff, "Forearm." + suffix)
    return cuff


def import_character():
    body, details, deform_parts = original_import_character()
    rubber_material = body.data.materials[1]
    for suffix, sign in (("L", -1.0), ("R", 1.0)):
        deform_parts.append(create_wrist_cuff(suffix, sign, rubber_material))
    return body, details, deform_parts


def configure_ik_stretch(armature):
    for suffix in ("L", "R"):
        armature.data.bones["Hand." + suffix].inherit_scale = "NONE"
        for bone_name, stretch in (
            ("UpperArm." + suffix, 0.42 if suffix == "L" else 0.08),
            ("Forearm." + suffix, 0.50 if suffix == "L" else 0.10),
            ("Hand." + suffix, 0.0),
        ):
            armature.pose.bones[bone_name].ik_stretch = stretch


def configure_elbow_poles(poles):
    poles["L"].location = (-1.10, -0.50, 0.72)
    poles["R"].location = (1.10, -0.40, 1.18)


def refine_baked_contact_pose(armature, pose, frame):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    for suffix in ("L", "R"):
        for bone_name in ("UpperArm." + suffix, "Forearm." + suffix):
            bone = armature.pose.bones[bone_name]
            length_scale = max(bone.scale)
            bone.scale = Vector((1.0, length_scale, 1.0))
            bone.keyframe_insert(data_path="scale", frame=frame, group=bone.name)
        hand = armature.pose.bones["Hand." + suffix]
        hand_scale = float(pose[("left" if suffix == "L" else "right") + "_hand_scale"])
        hand.scale = Vector((hand_scale, hand_scale, hand_scale))
        hand.keyframe_insert(data_path="scale", frame=frame, group=hand.name)


def bake_pose_action(armature, targets, action_name, pose):
    base.reset_pose(armature)
    spine = armature.pose.bones.get("Spine")
    if spine is not None:
        spine.rotation_mode = "QUATERNION"
        spine.rotation_quaternion = Quaternion(
            Vector((1.0, 0.0, 0.0)),
            radians(float(pose.get("spine_pitch", 0.0))),
        )
    base.set_ik(
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
    refine_baked_contact_pose(armature, pose, 1)
    refine_baked_contact_pose(armature, pose, 2)
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


def apply_preview_pose(armature, targets, pose):
    base.reset_pose(armature)
    spine = armature.pose.bones.get("Spine")
    if spine is not None:
        spine.rotation_mode = "QUATERNION"
        spine.rotation_quaternion = Quaternion(
            Vector((1.0, 0.0, 0.0)),
            radians(float(pose.get("spine_pitch", 0.0))),
        )
    base.set_ik(armature, targets, pose["left"], pose["right"], pose["ik"])


def capture_action_pose(armature, action_name):
    armature.animation_data_create()
    armature.animation_data.action = bpy.data.actions[action_name]
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    snapshot = {}
    for bone in armature.pose.bones:
        bone.rotation_mode = "QUATERNION"
        snapshot[bone.name] = {
            "location": bone.location.copy(),
            "rotation": bone.rotation_quaternion.copy(),
            "scale": bone.scale.copy(),
        }
    armature.animation_data.action = None
    return snapshot


def restore_pose_snapshot(armature, snapshot):
    for bone in armature.pose.bones:
        values = snapshot[bone.name]
        bone.location = values["location"].copy()
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = values["rotation"].copy()
        bone.scale = values["scale"].copy()


def rotate_bone(armature, snapshot, bone_name, pitch=0.0, yaw=0.0, roll=0.0):
    bone = armature.pose.bones.get(bone_name)
    if bone is None:
        return
    offset = (
        Quaternion(Vector((0.0, 0.0, 1.0)), radians(roll))
        @ Quaternion(Vector((0.0, 1.0, 0.0)), radians(yaw))
        @ Quaternion(Vector((1.0, 0.0, 0.0)), radians(pitch))
    )
    bone.rotation_quaternion = (snapshot[bone_name]["rotation"] @ offset).normalized()


def keyframe_full_pose(armature, frame):
    for bone in armature.pose.bones:
        bone.keyframe_insert(data_path="location", frame=frame, group=bone.name)
        bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone.name)
        bone.keyframe_insert(data_path="scale", frame=frame, group=bone.name)


def locomotion_keys(kind, stride, brace):
    contact = {
        "left_thigh": stride,
        "right_thigh": -stride,
        "left_shin": -5.0,
        "right_shin": 11.0,
        "left_foot": -7.0,
        "right_foot": 5.0,
        "splay": 1.8 * brace,
    }
    neutral = {
        "left_thigh": 0.0,
        "right_thigh": 0.0,
        "left_shin": 0.0,
        "right_shin": 0.0,
        "left_foot": 0.0,
        "right_foot": 0.0,
        "splay": 0.0,
    }
    if kind == "start":
        return [
            (1, neutral),
            (4, {
                "left_thigh": 4.0, "right_thigh": 4.0,
                "left_shin": 8.0, "right_shin": 8.0,
                "left_foot": -3.0, "right_foot": -3.0,
                "splay": 2.8 * brace,
            }),
            (7, {
                "left_thigh": stride * 0.58, "right_thigh": -stride * 0.42,
                "left_shin": -2.0, "right_shin": 9.0,
                "left_foot": -5.0, "right_foot": 3.0,
                "splay": 2.2 * brace,
            }),
            (10, contact),
        ]
    if kind == "stop":
        return [
            (1, contact),
            (4, {
                "left_thigh": -stride * 0.38, "right_thigh": stride * 0.28,
                "left_shin": 12.0, "right_shin": 7.0,
                "left_foot": 5.0, "right_foot": -2.0,
                "splay": 3.6 * brace,
            }),
            (7, {
                "left_thigh": 3.0, "right_thigh": 3.0,
                "left_shin": 7.0, "right_shin": 7.0,
                "left_foot": -2.0, "right_foot": -2.0,
                "splay": 2.4 * brace,
            }),
            (10, neutral),
        ]
    if kind == "hit":
        return [
            (1, neutral),
            (3, {
                "left_thigh": -5.0 * brace, "right_thigh": 7.0 * brace,
                "left_shin": 8.0, "right_shin": 10.0,
                "left_foot": 4.0, "right_foot": -4.0,
                "splay": 5.2 * brace,
            }),
            (6, neutral),
        ]
    return [
        (1, contact),
        (4, {
            "left_thigh": stride * 0.56, "right_thigh": -stride * 0.34,
            "left_shin": 4.0, "right_shin": 15.0,
            "left_foot": -3.0, "right_foot": 7.0,
            "splay": 2.4 * brace,
        }),
        (7, {
            "left_thigh": -stride * 0.14, "right_thigh": stride * 0.12,
            "left_shin": 17.0, "right_shin": 3.0,
            "left_foot": 6.0, "right_foot": -4.0,
            "splay": 1.4 * brace,
        }),
        (10, {
            "left_thigh": -stride, "right_thigh": stride,
            "left_shin": 11.0, "right_shin": -5.0,
            "left_foot": 5.0, "right_foot": -7.0,
            "splay": 1.8 * brace,
        }),
        (13, {
            "left_thigh": -stride * 0.34, "right_thigh": stride * 0.56,
            "left_shin": 15.0, "right_shin": 4.0,
            "left_foot": 7.0, "right_foot": -3.0,
            "splay": 2.4 * brace,
        }),
        (16, {
            "left_thigh": stride * 0.12, "right_thigh": -stride * 0.14,
            "left_shin": 3.0, "right_shin": 17.0,
            "left_foot": -4.0, "right_foot": 6.0,
            "splay": 1.4 * brace,
        }),
        (19, contact),
    ]


def apply_locomotion_key(armature, snapshot, key):
    rotate_bone(armature, snapshot, "Thigh.L", pitch=key["left_thigh"], roll=-key["splay"])
    rotate_bone(armature, snapshot, "Thigh.R", pitch=key["right_thigh"], roll=key["splay"])
    rotate_bone(armature, snapshot, "Shin.L", pitch=key["left_shin"])
    rotate_bone(armature, snapshot, "Shin.R", pitch=key["right_shin"])
    rotate_bone(armature, snapshot, "Foot.L", pitch=key["left_foot"])
    rotate_bone(armature, snapshot, "Foot.R", pitch=key["right_foot"])


def create_motion_action(armature, action_name, snapshot, keys, kind):
    existing = bpy.data.actions.get(action_name)
    if existing is not None:
        bpy.data.actions.remove(existing)
    action = bpy.data.actions.new(action_name)
    action.use_fake_user = True
    action["motion_kind"] = kind
    action["authored_fps"] = MOTION_FPS
    armature.animation_data_create()
    armature.animation_data.action = action
    for frame, key in keys:
        bpy.context.scene.frame_set(frame)
        restore_pose_snapshot(armature, snapshot)
        apply_locomotion_key(armature, snapshot, key)
        keyframe_full_pose(armature, frame)
    armature.animation_data.action = None
    return action


def build_motion_actions(armature):
    bpy.context.scene.render.fps = MOTION_FPS
    actions = []
    for weapon_suffix, profile in MOTION_PROFILES.items():
        snapshot = capture_action_pose(armature, profile["pose"])
        for kind in ("start", "run", "stop", "hit"):
            action_name = f"{kind}_{weapon_suffix}"
            keys = locomotion_keys(kind, profile["stride"], profile["brace"])
            actions.append(create_motion_action(armature, action_name, snapshot, keys, kind))
    base.reset_pose(armature)
    return actions


original_import_character = base.import_character


def configure_base_module():
    base.SOURCE = SOURCE
    base.RUNTIME = RUNTIME
    base.POSES = POSES
    base.import_character = import_character
    base.bake_pose_action = bake_pose_action


def main():
    configure_base_module()
    base.clear_scene()
    body, details, deform_parts = base.import_character()
    armature, hand_targets, elbow_poles = base.build_rig(body, details, deform_parts)
    configure_ik_stretch(armature)
    configure_elbow_poles(elbow_poles)
    base.build_pose_actions(armature, hand_targets)
    build_motion_actions(armature)

    base.save_and_export_runtime(armature, body, details, deform_parts)

    scene = base.setup_render()
    detached_constraints = base.detach_ik_constraints(armature)
    try:
        armature.animation_data.action = bpy.data.actions["neutral"]
        bpy.context.scene.frame_set(1)
        base.render(scene, OUT_NEUTRAL)
        for weapon_name, (location, scale, pose_name) in WEAPON_PREVIEWS.items():
            weapon = base.import_weapon(weapon_name, location, scale)
            armature.animation_data.action = bpy.data.actions[pose_name]
            bpy.context.scene.frame_set(1)
            bpy.context.view_layer.update()
            base.render(scene, OUT_POSES[weapon_name])
            weapon.hide_render = True
    finally:
        base.restore_ik_constraints(detached_constraints)
    print("P12_RIG_V2_EXPORTED", RUNTIME)


if __name__ == "__main__":
    main()
