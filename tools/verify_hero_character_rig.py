from pathlib import Path
import sys

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets/models/generated/characters/hero_character_rig_v2.glb"
EXPECTED_BONES = {
    "Root",
    "Spine",
    "Head",
    "UpperArm.L",
    "Forearm.L",
    "Hand.L",
    "UpperArm.R",
    "Forearm.R",
    "Hand.R",
    "Foot.L",
    "Foot.R",
}
EXPECTED_ACTIONS = {
    "neutral",
    "hold_pistol",
    "hold_smg",
    "hold_ak",
    "hold_sniper",
    "hold_shotgun",
    "hold_gatling",
}
for weapon_suffix in ("pistol", "smg", "ak", "sniper", "shotgun", "gatling"):
    for motion_kind in ("start", "run", "stop", "hit"):
        EXPECTED_ACTIONS.add(f"{motion_kind}_{weapon_suffix}")

WEAPON_ROOT = ROOT / "assets/models/generated/weapons"
CONTACT_CASES = {
    "pistol": {
        "action": "hold_pistol",
        "location": (0.0, -0.72, 1.39),
        "scale": 1.0,
        "support": "Body",
        "trigger": "Grip",
    },
    "smg": {
        "action": "hold_smg",
        "location": (0.12, -0.83, 1.35),
        "scale": 0.84,
        "support": "FrontShroud",
        "trigger": "Grip",
        "stock": "StubStock",
    },
    "ak_rifle": {
        "action": "hold_ak",
        "location": (0.18, -0.92, 1.34),
        "scale": 0.74,
        "support": "Foregrip",
        "trigger": "Grip",
        "stock": "StockPad",
    },
    "sniper": {
        "action": "hold_sniper",
        "location": (0.18, -0.96, 1.35),
        "scale": 0.68,
        "support": "SlimBody",
        "trigger": "Grip",
        "stock": "StockPad",
    },
    "shotgun": {
        "action": "hold_shotgun",
        "location": (0.14, -0.90, 1.31),
        "scale": 0.72,
        "support": "PumpBody",
        "trigger": "Grip",
        "stock": "StockPad",
    },
    "gatling": {
        "action": "hold_gatling",
        "location": (0.10, -0.88, 1.27),
        "scale": 0.66,
        "support": "BarrelDrum",
        "trigger": "RearGrip",
        "stock": "StockPad",
    },
}
SHOULDER_ENVELOPE_MIN = Vector((-0.30, -0.72, 1.25))
SHOULDER_ENVELOPE_MAX = Vector((0.58, -0.34, 1.70))


def fail(message):
    print("HERO_RIG_VERIFY_FAIL", message)
    sys.exit(1)


def object_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return minimum, maximum


def distance_to_bounds(point, minimum, maximum):
    delta = Vector((
        max(minimum.x - point.x, point.x - maximum.x, 0.0),
        max(minimum.y - point.y, point.y - maximum.y, 0.0),
        max(minimum.z - point.z, point.z - maximum.z, 0.0),
    ))
    return delta.length


def bounds_overlap(first_min, first_max, second_min, second_max):
    return all(
        first_min[index] <= second_max[index] and first_max[index] >= second_min[index]
        for index in range(3)
    )


def import_weapon(weapon_id, profile):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(WEAPON_ROOT / f"{weapon_id}.glb"))
    imported = [obj for obj in bpy.context.scene.objects if obj not in before]
    root = bpy.data.objects.new(f"ContactWeapon_{weapon_id}", None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent not in imported:
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world
    root.location = profile["location"]
    root.scale = Vector((profile["scale"],) * 3)
    bpy.context.view_layer.update()
    return root, imported


def find_imported_mesh(imported, requested_name):
    for obj in imported:
        if obj.type == "MESH" and obj.name == requested_name:
            return obj
    return None


def verify_weapon_contacts(armature):
    for weapon_id, profile in CONTACT_CASES.items():
        armature.animation_data.action = bpy.data.actions[profile["action"]]
        bpy.context.scene.frame_set(1)
        bpy.context.view_layer.update()
        support_point = armature.matrix_world @ armature.pose.bones["Hand.L"].tail
        trigger_point = armature.matrix_world @ armature.pose.bones["Hand.R"].tail
        weapon_root, imported = import_weapon(weapon_id, profile)
        support_mesh = find_imported_mesh(imported, profile["support"])
        trigger_mesh = find_imported_mesh(imported, profile["trigger"])
        if support_mesh is None or trigger_mesh is None:
            fail(f"{weapon_id} is missing named contact meshes")
        support_distance = distance_to_bounds(support_point, *object_bounds(support_mesh))
        trigger_distance = distance_to_bounds(trigger_point, *object_bounds(trigger_mesh))
        if support_distance > 0.28:
            fail(f"{weapon_id} support hand misses {profile['support']}: {support_distance:.3f}")
        if trigger_distance > 0.24:
            fail(f"{weapon_id} trigger hand misses {profile['trigger']}: {trigger_distance:.3f}")
        stock_name = profile.get("stock")
        if stock_name:
            stock_mesh = find_imported_mesh(imported, stock_name)
            if stock_mesh is None:
                fail(f"{weapon_id} is missing stock contact mesh {stock_name}")
            if not bounds_overlap(
                *object_bounds(stock_mesh),
                SHOULDER_ENVELOPE_MIN,
                SHOULDER_ENVELOPE_MAX,
            ):
                fail(f"{weapon_id} stock does not seat in the chest-shoulder envelope")
        print(
            "HERO_WEAPON_CONTACT_PASS",
            weapon_id,
            f"support={support_distance:.3f}",
            f"trigger={trigger_distance:.3f}",
            "stock=seated" if stock_name else "stock=n/a",
        )
        for obj in imported:
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.objects.remove(weapon_root, do_unlink=True)
    armature.animation_data.action = None


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    bpy.ops.import_scene.gltf(filepath=str(ASSET))

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(armatures) != 1:
        fail(f"expected one armature, found {len(armatures)}")
    if len(meshes) < 4:
        fail(f"expected at least four meshes, found {len(meshes)}")

    armature = armatures[0]
    bones = {bone.name for bone in armature.data.bones}
    missing = sorted(EXPECTED_BONES - bones)
    if missing:
        fail(f"missing bones: {missing}")

    skinned = [
        mesh
        for mesh in meshes
        if any(
            modifier.type == "ARMATURE" and modifier.object == armature
            for modifier in mesh.modifiers
        )
    ]
    if not skinned:
        fail("no mesh is skinned to the imported armature")

    actions = {action.name for action in bpy.data.actions}
    missing_actions = sorted(EXPECTED_ACTIONS - actions)
    if missing_actions:
        fail(f"missing actions: {missing_actions}")
    for action in bpy.data.actions:
        if action.name.startswith("run_") and action.frame_range[1] - action.frame_range[0] < 12.0:
            fail(f"run action is too short: {action.name} {tuple(action.frame_range)}")

    verify_weapon_contacts(armature)

    mesh_names = {mesh.name for mesh in meshes}
    for required_mesh in {"HeroWristCuff.L", "HeroWristCuff.R"}:
        if required_mesh not in mesh_names:
            fail(f"missing production mesh: {required_mesh}")

    polygons = sum(len(mesh.data.polygons) for mesh in meshes)
    print(
        "HERO_RIG_VERIFY_PASS",
        f"armature={armature.name}",
        f"bones={len(bones)}",
        f"meshes={len(meshes)}",
        f"skinned={len(skinned)}",
        f"polygons={polygons}",
        f"actions={len(actions)}",
    )


if __name__ == "__main__":
    main()
