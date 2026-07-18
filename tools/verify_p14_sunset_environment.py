from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parent.parent
SOURCE_PATH = ROOT / "assets" / "source" / "sunset_toy_sky_islands" / "p14_sunset_environment.blend"


def material_roughness(obj):
    if not obj.data.materials:
        return None
    material = obj.data.materials[0]
    if not material or material.node_tree is None:
        return None
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if not bsdf:
        return None
    return float(bsdf.inputs["Roughness"].default_value)


def main():
    if not SOURCE_PATH.exists():
        raise SystemExit(f"Missing P14 source: {SOURCE_PATH}")
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE_PATH))

    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    clouds = [obj for obj in meshes if obj.name.startswith("P14CloudBank")]
    island_cliffs = [
        obj
        for obj in meshes
        if obj.name.startswith("P14DistantIsland") and obj.name.endswith("Cliff")
    ]
    island_tops = [
        obj
        for obj in meshes
        if obj.name.startswith("P14DistantIsland") and obj.name.endswith("Top")
    ]
    balloon_parts = [obj for obj in meshes if obj.name.startswith("P14HotAirBalloon")]
    required_balloon_parts = {
        "P14HotAirBalloonEnvelope",
        "P14HotAirBalloonEnvelopeSeams",
        "P14HotAirBalloonBasket",
        "P14HotAirBalloonBasketRim",
        "P14HotAirBalloonRope0",
        "P14HotAirBalloonRope1",
        "P14HotAirBalloonRope2",
        "P14HotAirBalloonRope3",
    }
    polygon_count = sum(len(obj.data.polygons) for obj in meshes)

    if len(meshes) != 121:
        raise SystemExit(f"Expected 121 optimized P14 meshes, got {len(meshes)}")
    if len(clouds) != 10:
        raise SystemExit(f"Expected 10 joined cloud banks, got {len(clouds)}")
    if len(island_cliffs) != 7 or len(island_tops) != 7:
        raise SystemExit(
            f"Expected seven distant island cliffs/tops, got {len(island_cliffs)}/{len(island_tops)}"
        )
    if polygon_count < 28100 or polygon_count > 29100:
        raise SystemExit(f"P14 polygon budget drifted: {polygon_count}")
    missing_balloon_parts = required_balloon_parts - {obj.name for obj in balloon_parts}
    if missing_balloon_parts:
        raise SystemExit(f"P14 hot-air balloon is incomplete: {sorted(missing_balloon_parts)}")
    envelope = bpy.data.objects.get("P14HotAirBalloonEnvelope")
    if envelope is None or len(envelope.data.materials) != 2:
        raise SystemExit("P14 balloon envelope must use two integrated panel materials")
    for cloud in clouds:
        if len(cloud.data.polygons) != 1080:
            raise SystemExit(
                f"Cloud must use six integrated puffs without a second geometry layer: "
                f"{cloud.name} has {len(cloud.data.polygons)} polygons"
            )
        if len(cloud.data.materials) != 1:
            raise SystemExit(f"Cloud must use exactly one material without an underside layer: {cloud.name}")
        roughness = material_roughness(cloud)
        if roughness is None or roughness < 0.94:
            raise SystemExit(f"Cloud material is not matte PBR: {cloud.name}")

    print("[P14 Sunset Environment Asset Verifier] PASS")
    print(f"Meshes: {len(meshes)}")
    print(f"Cloud banks: {len(clouds)}")
    print("Cloud structure: six puffs with one material and no underside layer")
    print(f"Distant islands: {len(island_cliffs)}")
    print(f"Hot-air balloon parts: {len(balloon_parts)}")
    print(f"Polygons: {polygon_count}")


if __name__ == "__main__":
    main()
