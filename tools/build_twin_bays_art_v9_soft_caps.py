"""Build Twin Bays Art V9 as an isolated soft-cap module candidate."""

from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_twin_bays_splash_arena as base  # noqa: E402


TARGET_VERSION = int(os.environ.get("TWIN_BAYS_ART_VERSION", "9"))
if TARGET_VERSION < 9:
    raise RuntimeError("Soft-cap builder requires Art V9 or newer")
PROFILE_PATHS = [
    ROOT / f"resources/maps/twin_bays_art_v{version}.json"
    for version in range(5, TARGET_VERSION + 1)
]
ART_PROFILE = PROFILE_PATHS[-1]
TIDE_PROFILE = ROOT / "resources/maps/twin_bays_tide_v1.json"
REVIEW_ROOT = ROOT / f"assets/review/twin_bays_art_v{TARGET_VERSION}/candidate"
SOURCE_ROOT = ROOT / f"_art_source_review/twin_bays_art_v{TARGET_VERSION}"
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
    profiles = [
        json.loads(path.read_text(encoding="utf-8"))
        for path in PROFILE_PATHS
    ]
    for index in range(1, len(profiles)):
        expected = profiles[index].get("base_profile_sha256")
        actual = digest(PROFILE_PATHS[index - 1])
        if expected != actual:
            raise RuntimeError(
                f"Art V{index + 5} base-profile hash is stale"
            )
    resolved: dict[str, Any] = {}
    for profile in profiles:
        resolved = deep_merge(resolved, profile)
    tide = json.loads(TIDE_PROFILE.read_text(encoding="utf-8"))
    if resolved.get("schema") != base.ART_SCHEMA \
            or int(resolved.get("version", 0)) != TARGET_VERSION:
        raise RuntimeError(
            f"Art V{TARGET_VERSION} resolved profile has an invalid schema/version"
        )
    if resolved.get("layout_sha256") != digest(base.LAYOUT_PATH):
        raise RuntimeError(f"Art V{TARGET_VERSION} is not bound to the current layout")
    if resolved.get("tide_sha256") != digest(TIDE_PROFILE):
        raise RuntimeError(
            f"Art V{TARGET_VERSION} is not bound to the current tide profile"
        )
    return resolved, tide


def protected_paths() -> list[Path]:
    protected = [
        ROOT / "resources/maps/twin_bays_art_v4.json",
        ROOT / "assets/source/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4.blend",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_hero_kit.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_foreground.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_manifest.json",
        *PROFILE_PATHS[:-1],
        CAUSTIC_TEXTURE,
    ]
    for version in range(5, TARGET_VERSION):
        candidate_root = ROOT / f"assets/review/twin_bays_art_v{version}/candidate"
        protected.extend(
            sorted(path for path in candidate_root.rglob("*") if path.is_file())
        )
    return protected


def configure_outputs() -> None:
    base.ART_PROFILE_PATH = ART_PROFILE
    base.ART_SCHEMA_VERSION = TARGET_VERSION
    base.SOURCE_DIR = SOURCE_ROOT
    base.GENERATED_DIR = REVIEW_ROOT
    base.PREVIEW_DIR = REVIEW_ROOT
    base.TEXTURE_DIR = REVIEW_ROOT / "textures"
    stem = f"twin_bays_art_v{TARGET_VERSION}"
    base.BLEND_PATH = SOURCE_ROOT / f"{stem}_soft_caps.blend"
    base.HERO_GLB_PATH = REVIEW_ROOT / f"{stem}_hero_kit.glb"
    base.FOREGROUND_GLB_PATH = REVIEW_ROOT / f"{stem}_foreground.glb"
    base.HERO_PREVIEW_PATH = REVIEW_ROOT / f"{stem}_hero_kit.png"
    base.FOREGROUND_PREVIEW_PATH = REVIEW_ROOT / f"{stem}_foreground.png"
    base.MANIFEST_PATH = REVIEW_ROOT / f"{stem}_manifest.json"
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
        raise RuntimeError(
            f"Art V{TARGET_VERSION} changed protected outputs: {changed}"
        )

    manifest = json.loads(base.MANIFEST_PATH.read_text(encoding="utf-8"))
    profile = json.loads(ART_PROFILE.read_text(encoding="utf-8"))
    resolved, _ = load_resolved_profiles()
    manifest["generated_at_utc"] = (
        f"deterministic-art-v{TARGET_VERSION}-soft-cap-build"
    )
    for role in ("blend", "hero_preview", "foreground_preview"):
        manifest.get("output_sha256", {}).pop(role, None)
    manifest["profile_inheritance"] = {
        "chain": [
            {
                "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                "sha256": digest(path),
            }
            for path in PROFILE_PATHS
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
    }
    manifest["review"] = {
        "schema": (
            f"chaos_gun.twin_bays_art_v{TARGET_VERSION}_soft_cap_review"
        ),
        "version": 1,
        "candidate_id": profile["review"]["candidate_id"],
        "base_candidate_id": profile["review"]["base_candidate_id"],
        "status": "candidate_pending_visual_gate",
        "camera_target": profile["camera_target"],
        "minimum_normal_camera_gain_percent": profile["review"][
            "minimum_normal_camera_gain_percent"
        ],
        "protected_file_count": len(protected),
        "protected_outputs": {
            "before": before,
            "after": after,
            "byte_identical": True,
        },
        "golden_update_allowed": False,
    }
    manifest["runtime_shaders"] = {
        "backdrop_water": {
            "path": "assets/shaders/twin_bays_backdrop_water_v5.gdshader",
            "sha256": digest(
                ROOT / "assets/shaders/twin_bays_backdrop_water_v5.gdshader"
            ),
        }
    }
    base.MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Art V{TARGET_VERSION} Blend: {base.BLEND_PATH}")
    print(f"Art V{TARGET_VERSION} foreground: {base.FOREGROUND_GLB_PATH}")
    print(f"Art V{TARGET_VERSION} manifest: {base.MANIFEST_PATH}")
    print(f"TWIN_BAYS_ART_V{TARGET_VERSION}_SOFT_CAP_BUILD_PASS")


if __name__ == "__main__":
    build()
