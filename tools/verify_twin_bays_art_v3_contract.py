"""Validate the approved Twin Bays Art V3 production authority contract."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / "resources/maps/twin_bays_layout_v1.json"
ART = ROOT / "resources/maps/twin_bays_art_v3.json"
TIDE = ROOT / "resources/maps/twin_bays_tide_v1.json"
POLICY = ROOT / "resources/validation/twin_bays_verification_policy_v1.json"
REFERENCE = ROOT / "docs/art-direction/references/twin_bays/twin_bays_as_built_reference_v1.json"
RUNNER = ROOT / "scripts/tests/run_twin_bays_release_validation.ps1"
WATER_SHADER = ROOT / "assets/shaders/twin_bays_water_master.gdshader"
WATER_MATERIALS = ROOT / "scripts/maps/twin_bays_water_materials.gd"
TIDE_CONTROLLER = ROOT / "scripts/maps/twin_bays_tide_controller.gd"
SHALLOW_WATER = ROOT / "scripts/maps/twin_bays_shallow_water.gd"
BACKDROP_SHADER = ROOT / "assets/shaders/twin_bays_backdrop_water.gdshader"
BACKDROP_LEGACY_SHADER = ROOT / "assets/shaders/twin_bays_backdrop_water_legacy.gdshader"
BACKDROP_SCRIPT = ROOT / "scripts/maps/twin_bays_splash_backdrop.gd"
ARENA_SCRIPT = ROOT / "scripts/maps/twin_bays_splash_arena.gd"
PRODUCTION_MANIFEST = ROOT / "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_manifest.json"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"TWIN_BAYS_ART_V3_CONTRACT_FAIL: {message}")


def main() -> None:
    layout, art, tide = load(LAYOUT), load(ART), load(TIDE)
    policy, reference = load(POLICY), load(REFERENCE)
    production_manifest = load(PRODUCTION_MANIFEST)
    layout_sha, art_sha, tide_sha = sha(LAYOUT), sha(ART), sha(TIDE)

    require(layout.get("schema") == "chaos_gun.twin_bays_layout", "layout schema")
    require(art.get("schema") == "chaos_gun.twin_bays_art" and art.get("version") == 3, "Art V3 schema")
    require(tide.get("schema") == "chaos_gun.twin_bays_tide" and tide.get("version") == 1, "Tide V1 schema")
    require(art.get("layout_sha256") == layout_sha, "Art V3 layout binding")
    require(art.get("tide_sha256") == tide_sha, "Art V3 tide binding")
    require(tide.get("layout_sha256") == layout_sha, "Tide V1 layout binding")
    require(reference["layout"]["sha256"] == layout_sha, "as-built layout binding")

    serialized_art = json.dumps(art, sort_keys=True).lower()
    require("clusters" not in art and "droplets" not in art, "legacy static puddle data returned")
    require("static_ellipse_puddles" in art["forbidden"], "ellipse puddle veto missing")
    topology = art["tide_art"].get("residue_topology", {})
    require(topology.get("style") == "concept_aligned_area_puddles", "Art V3 must use concept-aligned area puddles")
    require(bool(topology.get("parallel_ribbon_edges_forbidden")), "parallel ribbon-edge veto missing")
    require(bool(topology.get("sharp_tips_forbidden")), "sharp puddle-tip veto missing")
    require(bool(topology.get("topology_changes_during_drain")), "drain topology-change contract missing")
    require(float(topology.get("max_aspect_ratio", 99.0)) <= 2.2, "residual-water aspect ratio exceeds concept contract")
    require(art["tide_art"]["transparent_batch_limit"] <= 3, "transparent batch budget")
    require(not art["tide_art"]["screen_reflection"] and not art["tide_art"]["screen_refraction"], "screen water effects")
    require("layout_coordinates" in serialized_art, "Art profile scope veto missing")
    require(tide["gameplay"]["speed_multiplier"] == 0.90, "high-tide speed changed")
    require(tide["gameplay"]["horizontal_damp_multiplier"] == 1.25, "high-tide damping changed")

    for path in (
        WATER_SHADER,
        WATER_MATERIALS,
        TIDE_CONTROLLER,
        SHALLOW_WATER,
        BACKDROP_SHADER,
        BACKDROP_LEGACY_SHADER,
        BACKDROP_SCRIPT,
        ARENA_SCRIPT,
        PRODUCTION_MANIFEST,
    ):
        require(path.is_file(), f"shared water authority missing: {path.relative_to(ROOT)}")
    water_shader = WATER_SHADER.read_text(encoding="utf-8")
    water_materials = WATER_MATERIALS.read_text(encoding="utf-8")
    tide_controller = TIDE_CONTROLLER.read_text(encoding="utf-8")
    shallow_water = SHALLOW_WATER.read_text(encoding="utf-8")
    for token in (
        "depth_prepass_alpha",
        "diffuse_burley",
        "specular_schlick_ggx",
        "NORMAL_MAP",
        "ROUGHNESS",
        "SPECULAR",
    ):
        require(token in water_shader, f"shared water shader missing {token}")
    require("unshaded" not in water_shader, "shared water shader regressed to unshaded")
    require("preload(MASTER_SHADER_PATH)" in water_materials, "water shader is not precompiled")
    require("Shader.new(" not in water_materials, "water material factory compiles runtime shader text")
    for controller_name, controller in (
        ("tide", tide_controller),
        ("shallow-water", shallow_water),
    ):
        require(
            'preload("res://scripts/maps/twin_bays_water_materials.gd")' in controller,
            f"{controller_name} controller bypasses shared water materials",
        )
    require("_flowing_water_material" not in tide_controller, "legacy tide water material returned")
    require("_flat_water_material" not in tide_controller, "legacy flat water material returned")
    require(
        "WaterMaterials.surface_from_config" in shallow_water,
        "interactive shallow water bypasses shared surface material",
    )
    backdrop_shader = BACKDROP_SHADER.read_text(encoding="utf-8")
    backdrop_script = BACKDROP_SCRIPT.read_text(encoding="utf-8")
    arena_script = ARENA_SCRIPT.read_text(encoding="utf-8")
    require("caustic_strength" in backdrop_shader and "warped_line" in backdrop_shader, "backdrop caustic layers missing")
    require("preload(\"res://assets/shaders/twin_bays_backdrop_water.gdshader\")" in backdrop_script, "Art V3 backdrop shader is not precompiled")
    require("preload(\"res://assets/shaders/twin_bays_backdrop_water_legacy.gdshader\")" in backdrop_script, "legacy rollback backdrop shader is not precompiled")
    require("ART_V3_BACKDROP_WATER_SHADER" in backdrop_script and "LEGACY_BACKDROP_WATER_SHADER" in backdrop_script, "backdrop production/rollback shader isolation missing")
    require("shader.code =" not in backdrop_script, "backdrop returned to runtime shader-source compilation")
    require("backdrop.apply_art_profile(art_profile)" in arena_script, "production arena does not activate the approved backdrop profile")
    require("_tide_controller.apply_art_profile(art_profile)" in arena_script, "production arena does not activate the approved tide profile")

    hero = policy["human_approval_gates"]["art_v3_hero_candidate"]
    full = policy["human_approval_gates"]["art_v3_full_map"]
    require(hero["status"] == "approved" and full["status"] == "approved", "Hero/full-map approval sequence is invalid")
    for gate_name, gate in (("Hero", hero), ("full-map", full)):
        require(gate["reviewed_layout_sha256"] == layout_sha, f"{gate_name} approval layout SHA")
        require(gate["reviewed_art_sha256"] == art_sha, f"{gate_name} approval Art SHA")
        require(gate["reviewed_tide_sha256"] == tide_sha, f"{gate_name} approval Tide SHA")
    require(int(full.get("art_score", 0)) >= int(full["minimum_art_score"]), "approved full-map art score is below policy")
    require(
        full.get("reviewed_foreground_sha256")
        == "fd2e41a75263973cdfcfc446ded480af9d6c48606b697dd4420061b0070851f8",
        "full-map approval does not bind the reviewed foreground",
    )
    require(production_manifest["layout_sha256"] == layout_sha, "production manifest layout SHA")
    require(production_manifest["art_profile_sha256"] == art_sha, "production manifest Art SHA")
    require(production_manifest["tide_profile_sha256"] == tide_sha, "production manifest Tide SHA")
    runtime_shaders = production_manifest.get("runtime_shaders", {})
    require(runtime_shaders.get("shallow_water", {}).get("sha256") == sha(WATER_SHADER), "production water shader SHA")
    require(runtime_shaders.get("backdrop_water", {}).get("sha256") == sha(BACKDROP_SHADER), "production backdrop shader SHA")
    runner = RUNNER.read_text(encoding="utf-8")
    for token in ("twin_bays_art_v3.json", "art_v3_hero_candidate", "art_v3_full_map", "art_profile_sha256", "tide_profile_sha256"):
        require(token in runner, f"release runner missing {token}")

    print("TWIN_BAYS_ART_V3_CONTRACT_PASS")
    print(f"layout_sha256={layout_sha}")
    print(f"art_sha256={art_sha}")
    print(f"tide_sha256={tide_sha}")
    print(f"production_manifest_sha256={sha(PRODUCTION_MANIFEST)}")
    print("production_manifest_status=approved_art_v3")


if __name__ == "__main__":
    main()
