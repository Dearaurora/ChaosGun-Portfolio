"""Build Twin Bays Art V7 as an isolated Benchmark Corner candidate."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_twin_bays_splash_arena as base  # noqa: E402


BASE_V5_PROFILE = ROOT / "resources/maps/twin_bays_art_v5.json"
BASE_V6_PROFILE = ROOT / "resources/maps/twin_bays_art_v6.json"
ART_PROFILE = ROOT / "resources/maps/twin_bays_art_v7.json"
TIDE_PROFILE = ROOT / "resources/maps/twin_bays_tide_v1.json"
REVIEW_ROOT = ROOT / "assets/review/twin_bays_art_v7/candidate"
SOURCE_ROOT = ROOT / "_art_source_review/twin_bays_art_v7"
CAUSTIC_TEXTURE = ROOT / "assets/textures/generated/twin_bays_v5_caustics.png"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def deep_merge(parent: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = json.loads(json.dumps(parent))
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_resolved_profiles() -> tuple[dict[str, Any], dict[str, Any]]:
    v5 = json.loads(BASE_V5_PROFILE.read_text(encoding="utf-8"))
    v6 = json.loads(BASE_V6_PROFILE.read_text(encoding="utf-8"))
    v7 = json.loads(ART_PROFILE.read_text(encoding="utf-8"))
    tide = json.loads(TIDE_PROFILE.read_text(encoding="utf-8"))
    if v6.get("base_profile_sha256") != digest(BASE_V5_PROFILE):
        raise RuntimeError("Art V6 base-profile hash is stale")
    if v7.get("base_profile_sha256") != digest(BASE_V6_PROFILE):
        raise RuntimeError("Art V7 base-profile hash is stale")
    resolved = deep_merge(deep_merge(v5, v6), v7)
    if resolved.get("schema") != base.ART_SCHEMA or int(resolved.get("version", 0)) != 7:
        raise RuntimeError("Art V7 resolved profile has an invalid schema/version")
    if resolved.get("layout_sha256") != digest(base.LAYOUT_PATH):
        raise RuntimeError("Art V7 is not bound to the current layout")
    if resolved.get("tide_sha256") != digest(TIDE_PROFILE):
        raise RuntimeError("Art V7 is not bound to the current tide profile")
    return resolved, tide


def protected_paths() -> list[Path]:
    fixed = [
        ROOT / "resources/maps/twin_bays_art_v4.json",
        ROOT / "assets/source/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4.blend",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_hero_kit.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_foreground.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_manifest.json",
        BASE_V5_PROFILE,
        ROOT / "_art_source_review/twin_bays_art_v5/twin_bays_art_v5_review.blend",
        BASE_V6_PROFILE,
        ROOT / "_art_source_review/twin_bays_art_v6/twin_bays_art_v6_review.blend",
        CAUSTIC_TEXTURE,
    ]
    candidate_files: list[Path] = []
    for version in ("v5", "v6"):
        candidate_root = ROOT / f"assets/review/twin_bays_art_{version}/candidate"
        candidate_files.extend(
            sorted(path for path in candidate_root.rglob("*") if path.is_file())
        )
    return fixed + candidate_files


def configure_outputs() -> None:
    base.ART_PROFILE_PATH = ART_PROFILE
    base.ART_SCHEMA_VERSION = 7
    base.SOURCE_DIR = SOURCE_ROOT
    base.GENERATED_DIR = REVIEW_ROOT
    base.PREVIEW_DIR = REVIEW_ROOT
    base.TEXTURE_DIR = REVIEW_ROOT / "textures"
    base.BLEND_PATH = SOURCE_ROOT / "twin_bays_art_v7_benchmark.blend"
    base.HERO_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v7_hero_kit.glb"
    base.FOREGROUND_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v7_foreground.glb"
    base.HERO_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v7_hero_kit.png"
    base.FOREGROUND_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v7_foreground.png"
    base.MANIFEST_PATH = REVIEW_ROOT / "twin_bays_art_v7_manifest.json"
    base.load_art_and_tide_profiles = load_resolved_profiles


def build() -> None:
    protected = protected_paths()
    before = {
        str(path.relative_to(ROOT)).replace("\\", "/"): digest(path)
        for path in protected
    }
    configure_outputs()
    base.build()
    after = {
        str(path.relative_to(ROOT)).replace("\\", "/"): digest(path)
        for path in protected
    }
    if before != after:
        changed = [path for path in before if before[path] != after[path]]
        raise RuntimeError(f"Art V7 changed protected Art V4/V5/V6 outputs: {changed}")

    manifest = json.loads(base.MANIFEST_PATH.read_text(encoding="utf-8"))
    v7 = json.loads(ART_PROFILE.read_text(encoding="utf-8"))
    resolved, _ = load_resolved_profiles()
    manifest["generated_at_utc"] = "deterministic-art-v7-benchmark-corner-build"
    output_hashes = manifest.get("output_sha256", {})
    for excluded_role in ("blend", "hero_preview", "foreground_preview"):
        output_hashes.pop(excluded_role, None)
    manifest["output_sha256"] = output_hashes
    manifest["profile_inheritance"] = {
        "chain": [
            {
                "path": str(BASE_V5_PROFILE.relative_to(ROOT)).replace("\\", "/"),
                "sha256": digest(BASE_V5_PROFILE),
            },
            {
                "path": str(BASE_V6_PROFILE.relative_to(ROOT)).replace("\\", "/"),
                "sha256": digest(BASE_V6_PROFILE),
            },
            {
                "path": str(ART_PROFILE.relative_to(ROOT)).replace("\\", "/"),
                "sha256": digest(ART_PROFILE),
            },
        ],
        "resolved_profile_sha256": hashlib.sha256(
            json.dumps(resolved, ensure_ascii=False, sort_keys=True).encode("utf-8")
        ).hexdigest(),
    }
    manifest["determinism_scope"] = {
        "byte_identical_required": [
            "hero_glb",
            "foreground_glb",
            "pbr_texture_sets",
            "manifest",
        ],
        "editable_blend": "excluded_blender_container_metadata",
        "preview_png": "excluded_gpu_render_evidence",
        "excluded_output_hash_roles": [
            "blend",
            "hero_preview",
            "foreground_preview",
        ],
    }
    manifest["review"] = {
        "schema": "chaos_gun.twin_bays_art_v7_benchmark_review",
        "version": 1,
        "candidate_id": v7["review"]["candidate_id"],
        "base_candidate_id": v7["review"]["base_candidate_id"],
        "status": "candidate_pending_weighted_visual_gate",
        "camera_target": v7["camera_target"],
        "weighted_regions": v7["review"]["weighted_regions"],
        "minimum_normal_camera_gain_percent": v7["review"]["minimum_normal_camera_gain_percent"],
        "protected_file_count": len(protected),
        "production_v5_v6_protection": {
            "before": before,
            "after": after,
            "byte_identical": True,
        },
        "golden_update_allowed": False,
    }
    manifest["runtime_shaders"] = {
        "shallow_water": {
            "path": "assets/shaders/twin_bays_water_master_v5.gdshader",
            "sha256": digest(ROOT / "assets/shaders/twin_bays_water_master_v5.gdshader"),
        },
        "backdrop_water": {
            "path": "assets/shaders/twin_bays_backdrop_water_v5.gdshader",
            "sha256": digest(ROOT / "assets/shaders/twin_bays_backdrop_water_v5.gdshader"),
        },
        "portal_water": {
            "path": "assets/shaders/twin_bays_portal_water_v5.gdshader",
            "sha256": digest(ROOT / "assets/shaders/twin_bays_portal_water_v5.gdshader"),
        },
    }
    manifest["runtime_textures"] = {
        "backdrop_caustics": {
            "path": str(CAUSTIC_TEXTURE.relative_to(ROOT)).replace("\\", "/"),
            "sha256": digest(CAUSTIC_TEXTURE),
            "width": 1024,
            "height": 1024,
            "material_batch_growth": 0,
        }
    }
    base.MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Art V7 Benchmark Blend: {base.BLEND_PATH}")
    print(f"Art V7 Benchmark foreground: {base.FOREGROUND_GLB_PATH}")
    print(f"Art V7 Benchmark manifest: {base.MANIFEST_PATH}")
    print("TWIN_BAYS_ART_V7_BENCHMARK_BUILD_PASS")


if __name__ == "__main__":
    build()
