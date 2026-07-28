"""Promote the approved Twin Bays Art V4 review candidate to production.

The promotion is intentionally versioned. Art V3 remains byte-identical for
rollback evidence, while the production scene switches to the V4 directory.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE_PATH = ROOT / "resources/maps/twin_bays_art_v4.json"
TIDE_PATH = ROOT / "resources/maps/twin_bays_tide_v1.json"
CANDIDATE_ROOT = ROOT / "assets/review/twin_bays_art_v4/candidate"
CANDIDATE_MANIFEST_PATH = CANDIDATE_ROOT / "twin_bays_art_v4_manifest.json"
CANDIDATE_SOURCE = ROOT / "_art_source_review/twin_bays_art_v4/twin_bays_art_v4_review.blend"
PRODUCTION_ROOT = ROOT / "assets/models/generated/twin_bays_splash_arena_v4"
PRODUCTION_SOURCE_ROOT = ROOT / "assets/source/twin_bays_splash_arena_v4"
PRODUCTION_TEXTURE_ROOT = PRODUCTION_SOURCE_ROOT / "textures"
PRODUCTION_MANIFEST_PATH = PRODUCTION_ROOT / "twin_bays_splash_arena_v4_manifest.json"

FILE_MAP = {
    "hero_glb": (
        CANDIDATE_ROOT / "twin_bays_art_v4_hero_kit.glb",
        PRODUCTION_ROOT / "twin_bays_splash_arena_v4_hero_kit.glb",
    ),
    "foreground_glb": (
        CANDIDATE_ROOT / "twin_bays_art_v4_foreground.glb",
        PRODUCTION_ROOT / "twin_bays_splash_arena_v4_foreground.glb",
    ),
    "hero_preview": (
        CANDIDATE_ROOT / "twin_bays_art_v4_hero_kit.png",
        PRODUCTION_ROOT / "twin_bays_splash_arena_v4_hero_kit.png",
    ),
    "foreground_preview": (
        CANDIDATE_ROOT / "twin_bays_art_v4_foreground.png",
        PRODUCTION_ROOT / "twin_bays_splash_arena_v4_foreground.png",
    ),
    "blend": (
        CANDIDATE_SOURCE,
        PRODUCTION_SOURCE_ROOT / "twin_bays_splash_arena_v4.blend",
    ),
}


def digest(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError(path)
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def verify_candidate(profile: dict, manifest: dict) -> None:
    if profile.get("version") != 4:
        raise RuntimeError("Twin Bays Art V4 profile version is not 4")
    review = profile.get("review", {})
    manifest_review = manifest.get("review", {})
    if review.get("candidate_id") != manifest_review.get("candidate_id"):
        raise RuntimeError("Art V4 candidate id does not match its manifest")
    if not manifest_review.get("production_protection", {}).get("byte_identical", False):
        raise RuntimeError("Art V4 candidate did not preserve the Art V3 production assets")

    protected = manifest_review["production_protection"]["before"]
    for relative_path, expected_sha in protected.items():
        current_sha = digest(ROOT / relative_path)
        if current_sha != expected_sha:
            raise RuntimeError(
                f"Protected Art V3 production input changed: {relative_path}"
            )

    expected_outputs = manifest.get("output_sha256", {})
    for key in ("hero_glb", "foreground_glb"):
        source = FILE_MAP[key][0]
        expected = expected_outputs.get(key)
        if not expected or digest(source) != expected:
            raise RuntimeError(f"Art V4 candidate output hash mismatch: {key}")

    layout_path = ROOT / profile["authority"]["structure"]
    if digest(layout_path) != profile.get("layout_sha256"):
        raise RuntimeError("Art V4 profile is stale for the current Twin Bays layout")
    if digest(TIDE_PATH) != profile.get("tide_sha256"):
        raise RuntimeError("Art V4 profile is stale for the current Tide V1 data")


def copy_outputs() -> None:
    PRODUCTION_ROOT.mkdir(parents=True, exist_ok=True)
    PRODUCTION_SOURCE_ROOT.mkdir(parents=True, exist_ok=True)
    for source, target in FILE_MAP.values():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)

    candidate_textures = CANDIDATE_ROOT / "textures"
    if PRODUCTION_TEXTURE_ROOT.exists():
        shutil.rmtree(PRODUCTION_TEXTURE_ROOT)
    shutil.copytree(
        candidate_textures,
        PRODUCTION_TEXTURE_ROOT,
        ignore=shutil.ignore_patterns("*.import", "*.uid"),
    )

    # Embedded images are kept inside the production GLB. Remove loose images
    # extracted by an earlier Godot import mode so they cannot be imported or
    # packaged as a second copy of the same texture set.
    for pattern in (
        "twin_bays_splash_arena_v4_*_tbsa_*.png",
        "twin_bays_splash_arena_v4_*_tbsa_*.png.import",
    ):
        for extracted in PRODUCTION_ROOT.glob(pattern):
            extracted.unlink()
    legacy_runtime_textures = PRODUCTION_ROOT / "textures"
    if legacy_runtime_textures.exists():
        shutil.rmtree(legacy_runtime_textures)


def write_manifest(profile: dict, candidate: dict) -> None:
    outputs = {key: relative(target) for key, (_, target) in FILE_MAP.items()}
    output_hashes = {key: digest(target) for key, (_, target) in FILE_MAP.items()}
    shader_entries = {}
    for key, entry in candidate.get("runtime_shaders", {}).items():
        shader_path = ROOT / entry["path"]
        shader_entries[key] = {
            "path": entry["path"],
            "sha256": digest(shader_path),
        }

    # Promotion must not discard the candidate's geometry audit, semantic
    # anchors, PBR contract, or export-consolidation evidence.  Those fields are
    # what the runtime release gates independently validate.
    manifest = json.loads(json.dumps(candidate))
    manifest.update(
        {
            "generated_at_utc": "approved-art-v4-production-promotion",
            "generator": relative(Path(__file__)),
            "generator_sha256": digest(Path(__file__)),
            "status": "approved_production",
            "art_release_version": 4,
            "candidate_id": profile["review"]["candidate_id"],
            "layout": profile["authority"]["structure"],
            "layout_sha256": profile["layout_sha256"],
            "art_profile": relative(PROFILE_PATH),
            "art_profile_sha256": digest(PROFILE_PATH),
            "tide_profile": relative(TIDE_PATH),
            "tide_profile_sha256": digest(TIDE_PATH),
            "outputs": outputs,
            "output_sha256": output_hashes,
            "runtime_shaders": shader_entries,
            "approval": {
                "reviewer": "project_owner",
                "reviewed_at": "2026-07-24",
                "candidate_id": profile["review"]["candidate_id"],
                "art_score": 38,
                "golden_updated": False,
                "evidence": [
                    "reports/twin_bays_art_v4/candidate/v4_dry_1536x1024.png",
                    "reports/twin_bays_art_v4/candidate/v4_high_1536x1024.png",
                    "reports/twin_bays_art_v4/candidate/v4_drain_0_1536x1024.png",
                    "reports/twin_bays_art_v4/candidate/v4_drain_9_1536x1024.png",
                    "reports/twin_bays_art_v4/candidate/v4_battle_1920x1080.png",
                    "reports/twin_bays_art_v4/candidate/v4_portal_1920x1080.png",
                    "reports/twin_bays_art_v4/candidate/v4_mobile_1280x720.png",
                ],
            },
            "legacy_art_v3_loaded": False,
        }
    )
    manifest.pop("review", None)

    for texture_set in manifest.get("pbr_texture_sets", {}).values():
        maps = texture_set.get("maps", {})
        hashes = texture_set.setdefault("sha256", {})
        for map_name, old_path in list(maps.items()):
            production_path = PRODUCTION_TEXTURE_ROOT / Path(old_path).name
            maps[map_name] = relative(production_path)
            hashes[map_name] = digest(production_path)

    PRODUCTION_MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def main() -> None:
    profile = load_json(PROFILE_PATH)
    candidate = load_json(CANDIDATE_MANIFEST_PATH)
    verify_candidate(profile, candidate)
    copy_outputs()
    write_manifest(profile, candidate)

    production_manifest = load_json(PRODUCTION_MANIFEST_PATH)
    for key, path in production_manifest["outputs"].items():
        expected = production_manifest["output_sha256"][key]
        if digest(ROOT / path) != expected:
            raise RuntimeError(f"Promoted output failed its final hash check: {key}")

    print(f"Production manifest: {PRODUCTION_MANIFEST_PATH}")
    print("TWIN_BAYS_ART_V4_PROMOTION_PASS")


if __name__ == "__main__":
    main()
