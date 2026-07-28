"""Build Twin Bays Art V5 as an isolated, deterministic camera-target candidate."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_twin_bays_splash_arena as base  # noqa: E402


ART_PROFILE = ROOT / "resources/maps/twin_bays_art_v5.json"
REVIEW_ROOT = ROOT / "assets/review/twin_bays_art_v5/candidate"
SOURCE_ROOT = ROOT / "_art_source_review/twin_bays_art_v5"
CAUSTIC_TEXTURE = ROOT / "assets/textures/generated/twin_bays_v5_caustics.png"
CAUSTIC_REPORT = ROOT / "reports/twin_bays_art_v5/twin_bays_v5_caustics_manifest.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def protected_paths() -> list[Path]:
    return [
        ROOT / "resources/maps/twin_bays_art_v4.json",
        ROOT / "assets/source/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4.blend",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_hero_kit.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_foreground.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_manifest.json",
    ]


def configure_outputs() -> None:
    base.ART_PROFILE_PATH = ART_PROFILE
    base.ART_SCHEMA_VERSION = 5
    base.SOURCE_DIR = SOURCE_ROOT
    base.GENERATED_DIR = REVIEW_ROOT
    base.PREVIEW_DIR = REVIEW_ROOT
    base.TEXTURE_DIR = REVIEW_ROOT / "textures"
    base.BLEND_PATH = SOURCE_ROOT / "twin_bays_art_v5_review.blend"
    base.HERO_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v5_hero_kit.glb"
    base.FOREGROUND_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v5_foreground.glb"
    base.HERO_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v5_hero_kit.png"
    base.FOREGROUND_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v5_foreground.png"
    base.MANIFEST_PATH = REVIEW_ROOT / "twin_bays_art_v5_manifest.json"


def build() -> None:
    before = {
        str(path.relative_to(ROOT)).replace("\\", "/"): digest(path)
        for path in protected_paths()
    }
    configure_outputs()
    base.build()
    after = {
        str(path.relative_to(ROOT)).replace("\\", "/"): digest(path)
        for path in protected_paths()
    }
    if before != after:
        changed = [path for path in before if before[path] != after[path]]
        raise RuntimeError(f"Art V5 review changed protected Art V4 production outputs: {changed}")

    manifest = json.loads(base.MANIFEST_PATH.read_text(encoding="utf-8"))
    profile = json.loads(ART_PROFILE.read_text(encoding="utf-8"))
    manifest["generated_at_utc"] = "deterministic-art-v5-camera-target-build"
    output_hashes = manifest.get("output_sha256", {})
    manifest["output_sha256"] = {
        "hero_glb": output_hashes.get("hero_glb", "missing"),
        "foreground_glb": output_hashes.get("foreground_glb", "missing"),
    }
    manifest["determinism_scope"] = {
        "byte_identical_required": [
            "hero_glb",
            "foreground_glb",
            "pbr_texture_sets",
            "runtime_textures",
            "manifest",
        ],
        "editable_blend": "excluded_blender_container_metadata",
        "preview_png": "excluded_gpu_render_evidence",
    }
    manifest["review"] = {
        "schema": "chaos_gun.twin_bays_art_v5_review",
        "version": 1,
        "candidate_id": profile["review"]["candidate_id"],
        "status": "candidate_pending_camera_fidelity_gate",
        "camera_target": profile["camera_target"],
        "production_protection": {
            "before": before,
            "after": after,
            "byte_identical": True,
        },
        "golden_update_allowed": False,
        "production_foreground_overwritten": False,
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
    caustic_report = json.loads(CAUSTIC_REPORT.read_text(encoding="utf-8"))
    expected_texture_path = str(
        profile.get("backdrop", {}).get("caustic_texture", "")
    ).removeprefix("res://")
    actual_texture_path = str(CAUSTIC_TEXTURE.relative_to(ROOT)).replace("\\", "/")
    if expected_texture_path != actual_texture_path:
        raise RuntimeError(
            "Art V5 profile caustic texture does not match the deterministic build output"
        )
    if caustic_report.get("sha256") != digest(CAUSTIC_TEXTURE):
        raise RuntimeError("Art V5 caustic report does not bind the generated texture")
    manifest["runtime_textures"] = {
        "backdrop_caustics": {
            "path": actual_texture_path,
            "sha256": digest(CAUSTIC_TEXTURE),
            "width": int(caustic_report["width"]),
            "height": int(caustic_report["height"]),
            "algorithm": str(caustic_report["algorithm"]),
            "seed": int(caustic_report["seed"]),
            "material_batch_growth": 0,
        }
    }
    base.MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Art V5 review Blend: {base.BLEND_PATH}")
    print(f"Art V5 review foreground: {base.FOREGROUND_GLB_PATH}")
    print(f"Art V5 review manifest: {base.MANIFEST_PATH}")
    print("TWIN_BAYS_ART_V5_REVIEW_BUILD_PASS")


if __name__ == "__main__":
    build()
