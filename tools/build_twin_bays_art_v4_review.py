"""Build Twin Bays Art V4 as an isolated, deterministic review candidate.

Run through Blender 5.1. The approved Art V3 production Blend, GLBs, manifest,
previews and Golden evidence remain byte-identical during this build.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_twin_bays_splash_arena as base  # noqa: E402


ART_PROFILE = ROOT / "resources" / "maps" / "twin_bays_art_v4.json"
REVIEW_ROOT = ROOT / "assets" / "review" / "twin_bays_art_v4" / "candidate"
SOURCE_ROOT = ROOT / "_art_source_review" / "twin_bays_art_v4"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def protected_paths() -> list[Path]:
    return [
        ROOT / "resources/maps/twin_bays_art_v3.json",
        ROOT / "assets/source/twin_bays_splash_arena/twin_bays_splash_arena.blend",
        ROOT / "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_hero_kit.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_foreground.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_manifest.json",
        ROOT / "docs/art-direction/previews/twin_bays_splash_arena_hero_kit.png",
        ROOT / "docs/art-direction/previews/twin_bays_splash_arena_foreground.png",
    ]


def configure_outputs() -> None:
    base.ART_PROFILE_PATH = ART_PROFILE
    base.ART_SCHEMA_VERSION = 4
    base.SOURCE_DIR = SOURCE_ROOT
    base.GENERATED_DIR = REVIEW_ROOT
    base.PREVIEW_DIR = REVIEW_ROOT
    base.TEXTURE_DIR = REVIEW_ROOT / "textures"
    base.BLEND_PATH = SOURCE_ROOT / "twin_bays_art_v4_review.blend"
    base.HERO_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v4_hero_kit.glb"
    base.FOREGROUND_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v4_foreground.glb"
    base.HERO_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v4_hero_kit.png"
    base.FOREGROUND_PREVIEW_PATH = REVIEW_ROOT / "twin_bays_art_v4_foreground.png"
    base.MANIFEST_PATH = REVIEW_ROOT / "twin_bays_art_v4_manifest.json"


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
        raise RuntimeError(f"Art V4 review changed protected production outputs: {changed}")

    manifest = json.loads(base.MANIFEST_PATH.read_text(encoding="utf-8"))
    profile = json.loads(ART_PROFILE.read_text(encoding="utf-8"))
    manifest["generated_at_utc"] = "deterministic-art-v4-build"
    output_hashes = manifest.get("output_sha256", {})
    manifest["output_sha256"] = {
        "hero_glb": output_hashes.get("hero_glb", "missing"),
        "foreground_glb": output_hashes.get("foreground_glb", "missing"),
    }
    manifest["determinism_scope"] = {
        "byte_identical_required": ["hero_glb", "foreground_glb", "pbr_texture_sets", "manifest"],
        "editable_blend": "excluded_blender_container_metadata",
        "preview_png": "excluded_gpu_render_evidence",
    }
    manifest["review"] = {
        "schema": "chaos_gun.twin_bays_art_v4_review",
        "version": 1,
        "candidate_id": profile["review"]["candidate_id"],
        "status": "candidate_pending_visual_gate",
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
            "path": "assets/shaders/twin_bays_water_master_v4.gdshader",
            "sha256": digest(ROOT / "assets/shaders/twin_bays_water_master_v4.gdshader"),
        },
        "backdrop_water": {
            "path": "assets/shaders/twin_bays_backdrop_water_v4.gdshader",
            "sha256": digest(ROOT / "assets/shaders/twin_bays_backdrop_water_v4.gdshader"),
        },
    }
    base.MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Art V4 review Blend: {base.BLEND_PATH}")
    print(f"Art V4 review foreground: {base.FOREGROUND_GLB_PATH}")
    print(f"Art V4 review manifest: {base.MANIFEST_PATH}")
    print("TWIN_BAYS_ART_V4_REVIEW_BUILD_PASS")


if __name__ == "__main__":
    build()
