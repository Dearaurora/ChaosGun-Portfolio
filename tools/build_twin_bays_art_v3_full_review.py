"""Build the approved Art V3 modules as an isolated full-map candidate.

The production Blend, GLBs, manifest, previews and Golden evidence are protected
until the project owner approves the full-map Godot captures.
"""

from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_twin_bays_splash_arena as base  # noqa: E402


REVIEW_ROOT = ROOT / "assets" / "review" / "twin_bays_art_v3" / "full_map"
SOURCE_ROOT = ROOT / "_art_source_review" / "twin_bays_art_v3_full"
PREVIEW_ROOT = ROOT / "docs" / "art-direction" / "previews"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else "missing"


def protected_paths() -> list[Path]:
    return [
        ROOT / "assets/source/twin_bays_splash_arena/twin_bays_splash_arena.blend",
        ROOT / "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_hero_kit.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_foreground.glb",
        ROOT / "assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_manifest.json",
        ROOT / "docs/art-direction/previews/twin_bays_splash_arena_hero_kit.png",
        ROOT / "docs/art-direction/previews/twin_bays_splash_arena_foreground.png",
    ]


def configure_review_outputs() -> None:
    base.SOURCE_DIR = SOURCE_ROOT
    base.GENERATED_DIR = REVIEW_ROOT
    base.PREVIEW_DIR = PREVIEW_ROOT
    base.TEXTURE_DIR = REVIEW_ROOT / "textures"
    base.BLEND_PATH = SOURCE_ROOT / "twin_bays_art_v3_full_review.blend"
    base.HERO_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v3_full_hero_kit.glb"
    base.FOREGROUND_GLB_PATH = REVIEW_ROOT / "twin_bays_art_v3_full_foreground.glb"
    base.HERO_PREVIEW_PATH = PREVIEW_ROOT / "twin_bays_art_v3_full_hero_kit.png"
    base.FOREGROUND_PREVIEW_PATH = PREVIEW_ROOT / "twin_bays_art_v3_full_foreground.png"
    base.MANIFEST_PATH = REVIEW_ROOT / "twin_bays_art_v3_full_manifest.json"


def build() -> None:
    before = {
        str(path.relative_to(ROOT)).replace("\\", "/"): digest(path)
        for path in protected_paths()
    }
    configure_review_outputs()
    base.build()
    after = {
        str(path.relative_to(ROOT)).replace("\\", "/"): digest(path)
        for path in protected_paths()
    }
    if before != after:
        changed = [path for path in before if before[path] != after[path]]
        raise RuntimeError(f"Full-map review changed protected production outputs: {changed}")

    manifest = json.loads(base.MANIFEST_PATH.read_text(encoding="utf-8"))
    runtime_shaders = {
        "shallow_water": ROOT / "assets/shaders/twin_bays_water_master.gdshader",
        "backdrop_water": ROOT / "assets/shaders/twin_bays_backdrop_water.gdshader",
    }
    manifest["runtime_shaders"] = {
        name: {
            "path": str(path.relative_to(ROOT)).replace("\\", "/"),
            "sha256": digest(path),
            "precompiled_project_resource": True,
        }
        for name, path in runtime_shaders.items()
    }
    manifest["review"] = {
        "schema": "chaos_gun.twin_bays_art_v3_full_review",
        "version": 1,
        "status": "candidate_pending_human_approval",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "hero_gate_status": "approved",
        "production_protection": {
            "before": before,
            "after": after,
            "byte_identical": True,
        },
        "golden_update_allowed": False,
        "production_foreground_overwritten": False,
    }
    base.MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Art V3 full review Blend: {base.BLEND_PATH}")
    print(f"Art V3 full review foreground: {base.FOREGROUND_GLB_PATH}")
    print(f"Art V3 full review manifest: {base.MANIFEST_PATH}")


if __name__ == "__main__":
    build()
