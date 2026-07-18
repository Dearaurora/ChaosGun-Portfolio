from collections import Counter
import json
from pathlib import Path
import re

import bpy


ROOT = Path(__file__).resolve().parent.parent
INTEGRATION_VERIFIER = ROOT / "scripts" / "tests" / "sunset_open_ringout_v2_integration_verifier.gd"

PRESERVE_EXACT = {
    "V3NorthWindmillHub",
    "V10CentralFloorTile_2",
    "V3SouthBarrelBlue",
    "V3SouthBarrelGold",
    "V3EastTreeBTrunk",
}
PRESERVE_PREFIXES = (
    "V3NorthWindmillBlade_",
    "V4NorthWindmillBladeTip_",
    "V3Cloud",
    "V3DistantIsland",
    "V3HotAirBalloon",
    "V10CentralSouthCliffFacet_",
    "V10CentralEastCliffFacet_",
    "V10NorthIslandFrontCliffFacet_",
)


def required_integration_nodes():
    source = INTEGRATION_VERIFIER.read_text(encoding="utf-8")
    block = source.split("const REQUIRED_V2_NODES := [", 1)[1].split("]", 1)[0]
    return set(re.findall(r'"([^"]+)"', block))


def is_preserved(obj, required):
    return (
        obj.name in required
        or obj.name in PRESERVE_EXACT
        or "EdgeGem_" in obj.name
        or obj.name.startswith(PRESERVE_PREFIXES)
    )


def main():
    required = required_integration_nodes()
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    preserved = [obj for obj in mesh_objects if is_preserved(obj, required)]
    candidates = [
        obj
        for obj in mesh_objects
        if obj not in preserved
        and obj.parent is None
        and len(obj.data.materials) == 1
        and obj.data.materials[0] is not None
    ]
    unbatchable = [obj for obj in mesh_objects if obj not in preserved and obj not in candidates]
    material_groups = Counter(obj.data.materials[0].name for obj in candidates)
    report = {
        "total_meshes": len(mesh_objects),
        "required_names": len(required),
        "preserved_meshes": len(preserved),
        "batch_candidates": len(candidates),
        "unbatchable_meshes": len(unbatchable),
        "candidate_material_groups": len(material_groups),
        "projected_meshes": len(preserved) + len(unbatchable) + len(material_groups),
        "top_material_groups": material_groups.most_common(20),
        "unbatchable_names": [obj.name for obj in unbatchable],
        "parented_names": [obj.name for obj in mesh_objects if obj.parent is not None],
    }
    print("P26_BATCH_AUDIT=" + json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
