"""Validate the selected Twin Bays Art V4 production contract."""

from __future__ import annotations

import hashlib
import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / "resources/maps/twin_bays_layout_v1.json"
ART = ROOT / "resources/maps/twin_bays_art_v4.json"
TIDE = ROOT / "resources/maps/twin_bays_tide_v1.json"
BASELINE = ROOT / "reports/twin_bays_art_v4/before/baseline_manifest.json"
CANDIDATE = ROOT / "assets/review/twin_bays_art_v4/candidate/twin_bays_art_v4_manifest.json"
PRODUCTION = ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_manifest.json"
ARENA = ROOT / "scripts/maps/twin_bays_splash_arena.gd"
WATER_FACTORY = ROOT / "scripts/maps/twin_bays_water_materials.gd"
WATER_V3 = ROOT / "assets/shaders/twin_bays_water_master.gdshader"
WATER_V4 = ROOT / "assets/shaders/twin_bays_water_master_v4.gdshader"
BACKDROP_V4 = ROOT / "assets/shaders/twin_bays_backdrop_water_v4.gdshader"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"TWIN_BAYS_ART_V4_CONTRACT_FAIL: {message}")


def png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()[:24]
    require(data[:8] == b"\x89PNG\r\n\x1a\n", f"not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


def main() -> None:
    layout, art, tide = load(LAYOUT), load(ART), load(TIDE)
    baseline, candidate, production = load(BASELINE), load(CANDIDATE), load(PRODUCTION)
    layout_sha, art_sha, tide_sha = sha(LAYOUT), sha(ART), sha(TIDE)

    require(art.get("schema") == "chaos_gun.twin_bays_art", "Art schema")
    require(art.get("version") == 4, "Art version")
    require(art.get("layout_sha256") == layout_sha, "layout binding")
    require(art.get("tide_sha256") == tide_sha, "tide binding")
    require(tide.get("layout_sha256") == layout_sha, "Tide V1 layout binding")
    require(tide["gameplay"]["speed_multiplier"] == 0.90, "speed multiplier changed")
    require(tide["gameplay"]["horizontal_damp_multiplier"] == 1.25, "damping changed")

    budgets = art.get("budgets", {})
    require(int(budgets.get("primary_material_absolute_max", 99)) <= 12, "material budget")
    require(int(budgets.get("transparent_batch_max", 99)) <= 3, "transparent batch budget")
    require(int(budgets.get("texture_max_dimension", 99999)) <= 2048, "texture budget")
    require(not bool(budgets.get("runtime_node_growth_allowed", True)), "runtime node growth")
    tide_art = art.get("tide_art", {})
    require(tide_art.get("water_shader_variant") == "v4_clear", "V4 clear-water variant")
    require(int(tide_art.get("transparent_batch_limit", 99)) <= 3, "tide transparent batches")
    require(not tide_art.get("screen_reflection") and not tide_art.get("screen_refraction"), "screen-space water")

    review = candidate.get("review", {})
    require(review.get("candidate_id") == art["review"]["candidate_id"], "candidate id")
    require(review.get("production_protection", {}).get("byte_identical"), "V3 production protection")
    require(not review.get("golden_update_allowed", True), "candidate allows Golden update")
    for relative, expected in baseline["assets"].items():
        require(sha(ROOT / relative) == expected, f"frozen V3 changed: {relative}")

    require(
        production.get("schema") in {
            "chaos_gun.generated_environment_manifest",
            "chaos_gun.twin_bays_production_art",
        },
        "production schema",
    )
    require(int(production.get("art_release_version", production.get("version", 0))) == 4, "production version")
    require(
        production.get("status") in {"approved_production", "selected_production_candidate"},
        "production selection status",
    )
    require(production.get("art_profile_sha256") == art_sha, "production Art hash")
    require(production.get("layout_sha256") == layout_sha, "production layout hash")
    require(production.get("tide_profile_sha256") == tide_sha, "production Tide hash")
    selection = production.get("selection", production.get("approval", {}))
    require(not selection.get("golden_updated", True), "Golden was updated automatically")

    for key, relative in production.get("outputs", {}).items():
        output = ROOT / relative
        require(output.is_file(), f"production output missing: {key}")
        require(sha(output) == production["output_sha256"][key], f"production output hash: {key}")
    texture_entries: list[tuple[str, str]] = list(production.get("texture_sha256", {}).items())
    if not texture_entries:
        for texture_set in production.get("pbr_texture_sets", {}).values():
            maps = texture_set.get("maps", {})
            hashes = texture_set.get("sha256", {})
            for role, relative in maps.items():
                texture_entries.append((relative, hashes.get(role, "")))
    require(bool(texture_entries), "production texture hashes")
    for relative, expected in texture_entries:
        texture = ROOT / relative
        require(texture.is_file() and sha(texture) == expected, f"production texture hash: {relative}")
        width, height = png_dimensions(texture)
        require(max(width, height) <= 2048, f"texture exceeds 2048: {relative}")

    require(len(production.get("materials", [])) <= 12, "production material count")
    runtime_shaders = production.get("runtime_shaders", {})
    for name, shader in runtime_shaders.items():
        path = ROOT / shader["path"]
        require(path.is_file() and sha(path) == shader["sha256"], f"runtime shader: {name}")
    require(runtime_shaders["shallow_water"]["path"].endswith("water_master_v4.gdshader"), "V4 water shader")
    require(runtime_shaders["backdrop_water"]["path"].endswith("backdrop_water_v4.gdshader"), "V4 backdrop shader")

    water_factory = WATER_FACTORY.read_text(encoding="utf-8")
    require("preload(MASTER_SHADER_V4_PATH)" in water_factory, "V4 water shader is not precompiled")
    require("Shader.new(" not in water_factory, "runtime water shader compilation")
    water_shader = WATER_V4.read_text(encoding="utf-8")
    backdrop_shader = BACKDROP_V4.read_text(encoding="utf-8")
    require("depth_prepass_alpha" in water_shader, "transparent water depth prepass")
    require("unshaded" not in water_shader, "shallow-water lighting regression")
    require("depth_draw_opaque" in backdrop_shader, "opaque backdrop depth contract")
    require("caustic_strength" in backdrop_shader and "bay_depth_strength" in backdrop_shader, "backdrop depth layers")
    require(sha(WATER_V3) == baseline["assets"]["assets/shaders/twin_bays_water_master.gdshader"], "V3 water shader changed")

    arena = ARENA.read_text(encoding="utf-8")
    require("twin_bays_splash_arena_v4_foreground.glb" in arena, "production foreground is not V4")
    require('ART_PROFILE_PATH := "res://resources/maps/twin_bays_art_v4.json"' in arena, "production profile is not V4")
    require('get("lighting", {})' in arena, "production lighting is not profile-driven")

    foreground = production.get("production_foreground", candidate.get("production_foreground", {}))
    require(int(foreground.get("mesh_objects", 99)) <= 12, "foreground mesh batch count")
    require(int(foreground.get("triangles", 0)) > 0, "foreground triangle count")
    contracts = production.get("contracts", candidate.get("contracts", {}))
    require(contracts.get("visual_only") and not contracts.get("collision_in_glb"), "foreground collision contract")
    require(not contracts.get("static_floor_puddles"), "static dry-floor puddles returned")

    print("TWIN_BAYS_ART_V4_CONTRACT_PASS")
    print(f"layout_sha256={layout_sha}")
    print(f"art_sha256={art_sha}")
    print(f"tide_sha256={tide_sha}")
    print(f"production_manifest_sha256={sha(PRODUCTION)}")
    print(f"foreground_triangles={foreground.get('triangles')}")
    print(f"material_count={len(production.get('materials', []))}")
    print("golden_updated=false")


if __name__ == "__main__":
    main()
