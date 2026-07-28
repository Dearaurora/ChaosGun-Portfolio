"""Build Twin Bays Art V6 as an isolated professional-finish candidate."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_twin_bays_splash_arena as base  # noqa: E402


BASE_PROFILE = ROOT / "resources/maps/twin_bays_art_v5.json"
ART_PROFILE = ROOT / "resources/maps/twin_bays_art_v6.json"
TIDE_PROFILE = ROOT / "resources/maps/twin_bays_tide_v1.json"
REVIEW_ROOT = ROOT / "assets/review/twin_bays_art_v6/candidate"
SOURCE_ROOT = ROOT / "_art_source_review/twin_bays_art_v6"
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
    parent = json.loads(BASE_PROFILE.read_text(encoding="utf-8"))
    override = json.loads(ART_PROFILE.read_text(encoding="utf-8"))
    tide = json.loads(TIDE_PROFILE.read_text(encoding="utf-8"))
    if override.get("base_profile_sha256") != digest(BASE_PROFILE):
        raise RuntimeError("Art V6 base-profile hash is stale")
    resolved = deep_merge(parent, override)
    if resolved.get("schema") != base.ART_SCHEMA or int(resolved.get("version", 0)) != 6:
        raise RuntimeError("Art V6 resolved profile has an invalid schema/version")
    layout_hash = digest(base.LAYOUT_PATH)
    tide_hash = digest(TIDE_PROFILE)
    if resolved.get("layout_sha256") != layout_hash or resolved.get("tide_sha256") != tide_hash:
        raise RuntimeError("Art V6 is not bound to the current layout/tide")
    return resolved, tide


def protected_paths() -> list[Path]:
    fixed = [
        ROOT / "resources/maps/twin_bays_art_v4.json",
        ROOT / "assets/source/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4.blend",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_hero_kit.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_foreground.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_manifest.json",
        BASE_PROFILE,
        ROOT / "_art_source_review/twin_bays_art_v5/twin_bays_art_v5_review.blend",
        CAUSTIC_TEXTURE,
    ]
    v5_candidate = ROOT / "assets/review/twin_bays_art_v5/candidate"
    return fixed + sorted(path for path in v5_candidate.rglob("*") if path.is_file())


def configure_outputs() -> None:
    base.ART_PROFILE_PATH = ART_PROFILE
    base.ART_SCHEMA_VERSION = 6
    base.SOURCE_DIR = SOURCE_ROOT
    base.GENERATED_DIR = REVIEW_ROOT
    base.PREVIEW_DIR = REVIEW_ROOT
    base.TEXTURE_DIR = REVIEW_ROOT / "textures"
    base.BLEND_PATH = SOURCE_ROOT / "twin_bays_art_v6_review.blend"
    base.HERO_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v6_hero_kit.glb"
    base.FOREGROUND_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v6_foreground.glb"
    base.HERO_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v6_hero_kit.png"
    base.FOREGROUND_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v6_foreground.png"
    base.MANIFEST_PATH = REVIEW_ROOT / "twin_bays_art_v6_manifest.json"
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
        raise RuntimeError(f"Art V6 changed protected Art V4/V5 outputs: {changed}")

    manifest = json.loads(base.MANIFEST_PATH.read_text(encoding="utf-8"))
    override = json.loads(ART_PROFILE.read_text(encoding="utf-8"))
    resolved, _ = load_resolved_profiles()
    manifest["generated_at_utc"] = "deterministic-art-v6-professional-finish-build"
    # Blender container metadata and GPU preview pixels are intentionally
    # outside the release determinism contract. Keeping their changing hashes
    # inside an otherwise deterministic manifest made the manifest itself
    # change on every clean build, so publish hashes only for the runtime GLBs.
    output_hashes = manifest.get("output_sha256", {})
    for excluded_role in ("blend", "hero_preview", "foreground_preview"):
        output_hashes.pop(excluded_role, None)
    manifest["output_sha256"] = output_hashes
    manifest["profile_inheritance"] = {
        "base_profile": str(BASE_PROFILE.relative_to(ROOT)).replace("\\", "/"),
        "base_profile_sha256": digest(BASE_PROFILE),
        "override_profile": str(ART_PROFILE.relative_to(ROOT)).replace("\\", "/"),
        "override_profile_sha256": digest(ART_PROFILE),
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
        "schema": "chaos_gun.twin_bays_art_v6_review",
        "version": 1,
        "candidate_id": override["review"]["candidate_id"],
        "base_candidate_id": override["review"]["base_candidate_id"],
        "status": "candidate_pending_camera_fidelity_gate",
        "camera_target": override["camera_target"],
        "protected_file_count": len(protected),
        "production_and_v5_protection": {
            "before": before,
            "after": after,
            "byte_identical": True,
        },
        "golden_update_allowed": False,
        "production_foreground_overwritten": False,
        "art_v5_foreground_overwritten": False,
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
    print(f"Art V6 review Blend: {base.BLEND_PATH}")
    print(f"Art V6 review foreground: {base.FOREGROUND_GLB_PATH}")
    print(f"Art V6 review manifest: {base.MANIFEST_PATH}")
    print("TWIN_BAYS_ART_V6_REVIEW_BUILD_PASS")


if __name__ == "__main__":
    build()
