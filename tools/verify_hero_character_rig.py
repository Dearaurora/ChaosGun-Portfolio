from pathlib import Path
import sys

import bpy


ROOT = Path(__file__).resolve().parents[1]
ASSET = ROOT / "assets/models/generated/characters/hero_character_rig_v1.glb"
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


def fail(message):
    print("HERO_RIG_VERIFY_FAIL", message)
    sys.exit(1)


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

    polygons = sum(len(mesh.data.polygons) for mesh in meshes)
    print(
        "HERO_RIG_VERIFY_PASS",
        f"armature={armature.name}",
        f"bones={len(bones)}",
        f"meshes={len(meshes)}",
        f"skinned={len(skinned)}",
        f"polygons={polygons}",
    )


if __name__ == "__main__":
    main()
