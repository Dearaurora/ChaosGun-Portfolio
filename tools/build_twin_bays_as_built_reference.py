#!/usr/bin/env python3
"""Build the Twin Bays dual-authority as-built reference sheet.

The production Godot capture owns structure, camera, and composition. The
original concept is shown only as a small mood sample and never drives map
geometry. The generated JSON manifest binds the sheet to the canonical layout
and records the source hashes used to create it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LAYOUT = REPO_ROOT / "resources/maps/twin_bays_layout_v1.json"
DEFAULT_CAPTURE = REPO_ROOT / "reports/twin_bays_splash_arena_empty_1536x1024.png"
DEFAULT_MOOD = (
    REPO_ROOT
    / "docs/art-direction/references/twin_bays"
    / "twin_bays_splash_arena_selected_background.png"
)
DEFAULT_OUTPUT = (
    REPO_ROOT
    / "docs/art-direction/references/twin_bays"
    / "twin_bays_as_built_reference_v1.png"
)
DEFAULT_SOURCE_ARCHIVE = (
    REPO_ROOT
    / "docs/art-direction/references/twin_bays"
    / "twin_bays_as_built_source_empty_v1.png"
)
DEFAULT_MANIFEST = (
    REPO_ROOT
    / "docs/art-direction/references/twin_bays"
    / "twin_bays_as_built_reference_v1.json"
)

EXPECTED_COUNTS = {
    "covers": 10,
    "spawns": 4,
    "pickup_markers": 4,
    "portals": 2,
    "portal_pipes": 2,
}

VISUAL_TOKENS = [
    ("DRY FLOOR", "#F4EFE7"),
    ("AQUA WALL", "#4FC5D8"),
    ("CORAL CAP", "#FF8F82"),
    ("HAZARD EDGE", "#FFD54A"),
    ("PICKUP PAD", "#FF8A3D"),
    ("PORTAL", "#36D9FF"),
]

PROHIBITED_RESTORATIONS = [
    "corner towers / pillars",
    "legacy wall-mounted portals",
    "retired covers or south walls",
    "zig-zag portal walls",
    "floor wet marks or puddles",
    "legacy pickup rules",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_layout(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "chaos_gun.twin_bays_layout":
        raise ValueError("Unexpected Twin Bays layout schema")
    for key, expected in EXPECTED_COUNTS.items():
        actual = len(data.get(key, []))
        if actual != expected:
            raise ValueError(f"Layout {key} count is {actual}; expected {expected}")
    if not isinstance(data.get("special_pickup_marker"), dict):
        raise ValueError("Layout must contain exactly one center-special pickup marker")
    return data


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    # Pillow's bundled default font keeps this builder self-contained and
    # deterministic without relying on a workstation font installation.
    return ImageFont.load_default(size=size)


def contain(image: Image.Image, width: int, height: int) -> Image.Image:
    ratio = min(width / image.width, height / image.height)
    size = (max(1, round(image.width * ratio)), max(1, round(image.height * ratio)))
    return image.resize(size, Image.Resampling.LANCZOS)


def draw_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    size: int,
    fill: str = "#EAF8FC",
) -> None:
    draw.text(xy, text, font=font(size), fill=fill)


def build_sheet(capture_path: Path, mood_path: Path, layout_sha: str) -> Image.Image:
    canvas = Image.new("RGB", (1920, 1080), "#0D2836")
    draw = ImageDraw.Draw(canvas)

    draw.rectangle((0, 0, 1920, 78), fill="#123B4C")
    draw_text(draw, (42, 18), "TWIN BAYS  |  AS-BUILT REFERENCE V1", 34)
    draw_text(
        draw,
        (42, 54),
        "STRUCTURE + CAMERA AUTHORITY  /  generated from the approved Godot scene",
        16,
        "#8DDDEB",
    )

    main_box = (30, 98, 1450, 1048)
    draw.rounded_rectangle(main_box, radius=22, fill="#173F50", outline="#4FC5D8", width=3)
    with Image.open(capture_path) as source:
        capture = contain(source.convert("RGB"), 1380, 920)
    capture_x = main_box[0] + (main_box[2] - main_box[0] - capture.width) // 2
    capture_y = main_box[1] + (main_box[3] - main_box[1] - capture.height) // 2
    canvas.paste(capture, (capture_x, capture_y))

    panel = (1470, 98, 1890, 1048)
    draw.rounded_rectangle(panel, radius=22, fill="#153746", outline="#FFD54A", width=3)
    draw_text(draw, (1494, 120), "MOOD REFERENCE ONLY", 23, "#FFD54A")
    draw_text(draw, (1494, 150), "Never infer geometry from this image.", 15, "#F6B8AF")

    with Image.open(mood_path) as source:
        mood = contain(source.convert("RGB"), 372, 248)
    canvas.paste(mood, (1494, 180))
    draw.rectangle((1494, 180, 1494 + mood.width - 1, 180 + mood.height - 1), outline="#D8F5FA", width=2)

    draw_text(draw, (1494, 446), "VISUAL TOKENS", 20, "#8DDDEB")
    for index, (label, color) in enumerate(VISUAL_TOKENS):
        col = index % 2
        row = index // 2
        x = 1494 + col * 194
        y = 478 + row * 60
        draw.rounded_rectangle((x, y, x + 48, y + 42), radius=8, fill=color, outline="#FFFFFF", width=1)
        draw_text(draw, (x + 58, y + 4), label, 13)
        draw_text(draw, (x + 58, y + 23), color, 12, "#A7CAD4")

    draw_text(draw, (1494, 670), "FROZEN AS-BUILT CONTRACT", 20, "#8DDDEB")
    contract_lines = [
        "10 covers  /  4 spawns",
        "4 ordinary pads  /  1 center special",
        "2 portal pipes  /  fixed production camera",
        f"LAYOUT SHA  {layout_sha[:16]}...",
    ]
    for index, line in enumerate(contract_lines):
        draw_text(draw, (1494, 704 + index * 25), line, 14)

    draw_text(draw, (1494, 822), "DO NOT RESTORE FROM MOOD ART", 18, "#FF8F82")
    for index, item in enumerate(PROHIBITED_RESTORATIONS):
        draw_text(draw, (1496, 852 + index * 27), f"- {item}", 14, "#F4EFE7")

    draw_text(
        draw,
        (40, 1056),
        "Conflict rule: canonical layout JSON and current Godot production scene always win.",
        14,
        "#8DDDEB",
    )
    return canvas


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, default=DEFAULT_LAYOUT)
    parser.add_argument("--capture", type=Path, default=DEFAULT_CAPTURE)
    parser.add_argument("--mood", type=Path, default=DEFAULT_MOOD)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--source-archive", type=Path, default=DEFAULT_SOURCE_ARCHIVE)
    parser.add_argument(
        "--refresh-source",
        action="store_true",
        help="Explicitly replace the frozen Godot source capture before rebuilding.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    for path in (args.layout, args.capture, args.mood):
        if not path.is_file():
            raise FileNotFoundError(path)

    layout = load_layout(args.layout)
    layout_sha = sha256(args.layout)
    args.source_archive.parent.mkdir(parents=True, exist_ok=True)
    if args.refresh_source or not args.source_archive.is_file():
        shutil.copyfile(args.capture, args.source_archive)
    sheet = build_sheet(args.source_archive, args.mood, layout_sha)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, format="PNG", optimize=True, compress_level=9)

    manifest = {
        "schema": "chaos_gun.twin_bays_as_built_reference",
        "version": 1,
        "authority": {
            "structure_camera": [
                "resources/maps/twin_bays_layout_v1.json",
                "scenes/maps/twin_bays_splash_arena.tscn",
                "docs/art-direction/references/twin_bays/twin_bays_as_built_source_empty_v1.png",
            ],
            "mood_only": "docs/art-direction/references/twin_bays/twin_bays_splash_arena_selected_background.png",
            "conflict_rule": "Canonical layout JSON and current Godot production scene always win.",
        },
        "layout": {
            "path": "resources/maps/twin_bays_layout_v1.json",
            "sha256": layout_sha,
            "schema": layout["schema"],
            "version": layout["version"],
            "counts": {
                **EXPECTED_COUNTS,
                "special_pickup_markers": 1,
            },
        },
        "sources": {
            "godot_empty_capture": {
                "path": "docs/art-direction/references/twin_bays/twin_bays_as_built_source_empty_v1.png",
                "capture_origin": "reports/twin_bays_splash_arena_empty_1536x1024.png",
                "sha256": sha256(args.source_archive),
            },
            "mood_reference_only": {
                "path": "docs/art-direction/references/twin_bays/twin_bays_splash_arena_selected_background.png",
                "sha256": sha256(args.mood),
            },
        },
        "output": {
            "path": "docs/art-direction/references/twin_bays/twin_bays_as_built_reference_v1.png",
            "sha256": sha256(args.output),
            "size": [1920, 1080],
        },
        "visual_tokens": {label.lower().replace(" ", "_"): value for label, value in VISUAL_TOKENS},
        "prohibited_restorations": PROHIBITED_RESTORATIONS,
    }
    args.manifest.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Twin Bays as-built reference: {args.output}")
    print(f"Twin Bays reference manifest: {args.manifest}")
    print(f"Layout SHA-256: {layout_sha}")
    print(f"Reference SHA-256: {manifest['output']['sha256']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
