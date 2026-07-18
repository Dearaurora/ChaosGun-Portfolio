from math import radians
from pathlib import Path
import sys

import bpy
from mathutils import Quaternion, Vector


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import build_hero_character_rig_v1 as base
import hero_character_p29_geometry as p29_geometry


SOURCE = ROOT / "assets/source/characters/hero_character_rig_v2.blend"
RUNTIME = ROOT / "assets/models/generated/characters/hero_character_rig_v2.glb"
OUT_NEUTRAL = ROOT / "reports/hero_character_rig_v2_neutral.png"
OUT_TURNAROUND = {
    "front": ROOT / "reports/hero_character_p29_front.png",
    "side": ROOT / "reports/hero_character_p29_side.png",
    "back": ROOT / "reports/hero_character_p29_back.png",
    "three_quarter": ROOT / "reports/hero_character_p29_three_quarter.png",
}
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


def import_character():
    return p29_geometry.build_character()


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


def configure_base_module():
    base.SOURCE = SOURCE
    base.RUNTIME = RUNTIME
    base.POSES = POSES
    base.import_character = import_character
    base.assign_manual_weights = p29_geometry.assign_continuous_shell_weights
    base.bake_pose_action = bake_pose_action


def aim_preview_camera(camera, location, target, ortho_scale=3.25):
    camera.location = Vector(location)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho_scale
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def setup_p29_render():
    scene = base.setup_render()
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.view_settings.look = "AgX - Medium High Contrast"
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.76, 0.72, 0.72, 1.0)
    background.inputs["Strength"].default_value = 0.72
    floor = bpy.data.objects.get("Plane")
    if floor is not None:
        floor.scale = (4.0, 4.0, 4.0)
        if floor.data.materials:
            floor.data.materials[0].diffuse_color = (0.70, 0.66, 0.65, 1.0)
    lights = [obj for obj in scene.objects if obj.type == "LIGHT"]
    if lights:
        lights[0].data.energy = 920
        lights[0].data.color = (1.0, 0.74, 0.58)
        lights[0].location = (-4.5, -5.5, 7.0)
    if len(lights) > 1:
        lights[1].data.energy = 540
        lights[1].data.color = (0.50, 0.64, 1.0)
        lights[1].location = (4.5, 1.5, 4.5)
    return scene


def render_turnaround(scene, armature):
    armature.animation_data.action = bpy.data.actions["neutral"]
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    camera = scene.camera
    views = {
        "front": ((0.0, -8.0, 1.58), (0.0, 0.0, 1.42)),
        "side": ((8.0, 0.0, 1.58), (0.0, 0.0, 1.42)),
        "back": ((0.0, 8.0, 1.58), (0.0, 0.0, 1.42)),
        "three_quarter": ((5.2, -8.2, 2.35), (0.0, 0.0, 1.42)),
    }
    for view_name, (location, target) in views.items():
        aim_preview_camera(camera, location, target)
        base.render(scene, OUT_TURNAROUND[view_name])
    aim_preview_camera(camera, views["three_quarter"][0], views["three_quarter"][1])
    base.render(scene, OUT_NEUTRAL)


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

    scene = setup_p29_render()
    detached_constraints = base.detach_ik_constraints(armature)
    try:
        render_turnaround(scene, armature)
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
