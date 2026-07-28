"""Build an isolated Art V3 Hero asset without touching production outputs."""

from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build_twin_bays_splash_arena as base  # noqa: E402


REVIEW_DIR = ROOT / "assets" / "review" / "twin_bays_art_v3"
SOURCE_DIR = ROOT / "_art_source_review" / "twin_bays_art_v3"
TEXTURE_DIR = REVIEW_DIR / "textures"
BLEND_PATH = SOURCE_DIR / "twin_bays_art_v3_hero_review.blend"
GLB_PATH = REVIEW_DIR / "twin_bays_art_v3_hero_review.glb"
MANIFEST_PATH = REVIEW_DIR / "twin_bays_art_v3_hero_review_manifest.json"
PREVIEW_PATH = ROOT / "docs" / "art-direction" / "previews" / "twin_bays_art_v3_hero_review.png"
POLICY_PATH = ROOT / "resources" / "validation" / "twin_bays_verification_policy_v1.json"


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


def render_hero(hero: bpy.types.Collection, preview: bpy.types.Collection, art: dict) -> None:
    camera = base.configure_preview_scene(preview)
    scene = bpy.context.scene
    lighting = art["lighting"]
    scene.view_settings.exposure = float(lighting["exposure"])
    hero.hide_render = False
    camera.location = (20.0, -24.0, 20.0)
    camera.data.ortho_scale = 24.5
    base.look_at(camera, (0.0, 0.0, 2.1))
    scene.render.filepath = str(PREVIEW_PATH)
    bpy.ops.render.render(write_still=True)


def build() -> None:
    before = {str(path.relative_to(ROOT)).replace("\\", "/"): digest(path) for path in protected_paths()}
    layout = base.load_layout()
    art, tide = base.load_art_and_tide_profiles()
    base.configure_from_art_profile(art)
    base.TEXTURE_DIR = TEXTURE_DIR
    for directory in (REVIEW_DIR, SOURCE_DIR, TEXTURE_DIR, PREVIEW_PATH.parent):
        directory.mkdir(parents=True, exist_ok=True)

    base.clear_scene()
    texture_sets = base.generate_pbr_texture_sets()
    materials = base.create_materials(texture_sets)
    hero = base.make_collection("TBSA_ART_V3_HERO_REVIEW")
    empty_foreground = base.make_collection("TBSA_ART_V3_EMPTY_FOREGROUND")
    preview = base.make_collection("TBSA_ART_V3_PREVIEW_ONLY")
    base.build_hero_kit(layout, materials, hero)
    base.validate_scene(hero, empty_foreground)
    editable_stats = base.collection_stats(hero)

    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    backup = BLEND_PATH.with_name(BLEND_PATH.name + "1")
    if backup.exists():
        backup.unlink()

    base.join_meshes_by_material(hero, "ArtV3Hero")
    base.add_world_projected_uvs(hero)
    base.validate_scene(hero, empty_foreground)
    render_hero(hero, preview, art)
    base.export_collection(hero, GLB_PATH)

    after = {str(path.relative_to(ROOT)).replace("\\", "/"): digest(path) for path in protected_paths()}
    if before != after:
        changed = [path for path in before if before[path] != after[path]]
        raise RuntimeError(f"Art V3 Hero review changed protected production outputs: {changed}")

    texture_manifest = {}
    for role, texture_set in texture_sets.items():
        texture_manifest[role] = {
            "resolution": int(texture_set["resolution"]),
            "style": str(texture_set["surface_style"]),
            "maps": {
                name: {
                    "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                    "sha256": digest(path),
                }
                for name, path in texture_set["paths"].items()
            },
        }
    policy = json.loads(POLICY_PATH.read_text(encoding="utf-8")) if POLICY_PATH.is_file() else {}
    hero_gate = policy.get("human_approval_gates", {}).get("art_v3_hero_candidate", {})
    hero_approved = (
        hero_gate.get("status") == "approved"
        and hero_gate.get("reviewed_layout_sha256") == digest(base.LAYOUT_PATH)
        and hero_gate.get("reviewed_art_sha256") == digest(base.ART_PROFILE_PATH)
        and hero_gate.get("reviewed_tide_sha256") == digest(base.TIDE_PROFILE_PATH)
    )
    manifest = {
        "schema": "chaos_gun.twin_bays_art_v3_hero_review",
        "version": 1,
        "status": "hero_approved_full_map_pending" if hero_approved else "candidate_pending_human_approval",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "layout_sha256": digest(base.LAYOUT_PATH),
        "art_profile_sha256": digest(base.ART_PROFILE_PATH),
        "tide_profile_sha256": digest(base.TIDE_PROFILE_PATH),
        "outputs": {
            "blend": str(BLEND_PATH.relative_to(ROOT)).replace("\\", "/"),
            "glb": str(GLB_PATH.relative_to(ROOT)).replace("\\", "/"),
            "preview": str(PREVIEW_PATH.relative_to(ROOT)).replace("\\", "/"),
        },
        "output_sha256": {"blend": digest(BLEND_PATH), "glb": digest(GLB_PATH), "preview": digest(PREVIEW_PATH)},
        "editable": editable_stats,
        "exported": base.collection_stats(hero),
        "textures": texture_manifest,
        "production_protection": {"before": before, "after": after, "byte_identical": True},
        "contracts": {
            "visual_only": True,
            "collision_in_glb": False,
            "camera_in_glb": False,
            "light_in_glb": False,
            "golden_update_allowed": False,
            "production_foreground_overwritten": False,
        },
    }
    if hero_approved:
        manifest["approval"] = {
            "reviewer": hero_gate.get("reviewer", "project_owner"),
            "reviewed_at": hero_gate.get("reviewed_at", ""),
            "layout_sha256": hero_gate["reviewed_layout_sha256"],
            "art_profile_sha256": hero_gate["reviewed_art_sha256"],
            "tide_profile_sha256": hero_gate["reviewed_tide_sha256"],
        }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Art V3 Hero GLB: {GLB_PATH}")
    print(f"Art V3 Hero preview: {PREVIEW_PATH}")
    print(f"Art V3 Hero manifest: {MANIFEST_PATH}")


if __name__ == "__main__":
    build()
