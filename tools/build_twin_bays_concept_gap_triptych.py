"""Build the Twin Bays concept/current/target comparison at one 16:9 frame."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = (
    ROOT
    / "docs/art-direction/references/twin_bays"
    / "twin_bays_splash_arena_selected_background.png"
)
CURRENT = ROOT / "reports/twin_bays_art_v4/production/battle_1920x1080.png"
TARGET = ROOT / "docs/art-direction/concepts/twin_bays_art_v5_camera_target.png"
OUTPUT = ROOT / "reports/twin_bays_art_v5/concept_gap_triptych.png"
V5_CANDIDATE = (
    ROOT
    / "reports/twin_bays_art_v5/candidate"
    / "v5_drain_9_battle_1920x1080.png"
)
V5_COMPARISON_OUTPUT = ROOT / "reports/twin_bays_art_v5/v4_target_v5_runtime.png"
V6_CANDIDATE = (
    ROOT
    / "reports/twin_bays_art_v6/candidate"
    / "v6_drain_9_battle_1920x1080.png"
)
V6_COMPARISON_OUTPUT = ROOT / "reports/twin_bays_art_v6/v5_target_v6_runtime.png"
V7_CANDIDATE = (
    ROOT
    / "reports/twin_bays_art_v7/candidate"
    / "v7_drain_9_battle_1920x1080.png"
)
V7_COMPARISON_OUTPUT = ROOT / "reports/twin_bays_art_v7/v6_target_v7_runtime.png"
V8_CANDIDATE = (
    ROOT
    / "reports/twin_bays_art_v8/candidate"
    / "v8_drain_9_battle_1920x1080.png"
)
V8_COMPARISON_OUTPUT = ROOT / "reports/twin_bays_art_v8/v7_target_v8_runtime.png"
V9_CANDIDATE = (
    ROOT
    / "reports/twin_bays_art_v9/candidate"
    / "v9_drain_9_battle_1920x1080.png"
)
V9_COMPARISON_OUTPUT = ROOT / "reports/twin_bays_art_v9/v8_target_v9_runtime.png"
V10_CANDIDATE = (
    ROOT
    / "reports/twin_bays_art_v10/candidate"
    / "v10_drain_9_battle_1920x1080.png"
)
V10_COMPARISON_OUTPUT = ROOT / "reports/twin_bays_art_v10/v9_target_v10_runtime.png"
V5_OFFLINE_CANDIDATE = (
    ROOT
    / "assets/review/twin_bays_art_v5/candidate"
    / "twin_bays_art_v5_foreground.png"
)
V5_OFFLINE_COMPARISON_OUTPUT = (
    ROOT / "reports/twin_bays_art_v5/v4_target_v5_offline_candidate.png"
)

BACKGROUND = (11, 27, 42)
INK = (249, 240, 220)
MUTED = (143, 198, 207)
CORAL = (255, 137, 126)
GOLD = (255, 209, 68)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def cover(path: Path, size: tuple[int, int]) -> Image.Image:
    image = Image.open(path).convert("RGB")
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def build_triptych(
    output: Path,
    title: str,
    subtitle: str,
    panels: list[tuple[str, Path, tuple[int, int, int]]],
    notes: list[str],
) -> None:
    cell = (640, 360)
    header = 104
    footer = 66
    canvas = Image.new("RGB", (cell[0] * 3, header + cell[1] + footer), BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    draw.text((30, 17), title, font=font(34, True), fill=INK)
    draw.text(
        (30, 60),
        subtitle,
        font=font(21),
        fill=MUTED,
    )
    for index, (title, path, accent) in enumerate(panels):
        x = index * cell[0]
        canvas.paste(cover(path, cell), (x, header))
        draw.rectangle((x, header, x + cell[0] - 1, header + cell[1] - 1), outline=accent, width=4)
        draw.rounded_rectangle(
            (x + 18, header + 18, x + 360, header + 66),
            radius=12,
            fill=(8, 22, 35),
            outline=accent,
            width=2,
        )
        draw.text((x + 34, header + 29), title, font=font(21, True), fill=INK)

    for index, note in enumerate(notes):
        x = index * cell[0]
        draw.text((x + 24, header + cell[1] + 18), note, font=font(20, True), fill=panels[index][2])

    draw.line((cell[0], header, cell[0], header + cell[1]), fill=CORAL, width=3)
    draw.line((cell[0] * 2, header, cell[0] * 2, header + cell[1]), fill=GOLD, width=3)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=False)
    print(output)


def main() -> None:
    build_triptych(
        OUTPUT,
        "TWIN BAYS - CONCEPT GAP RESET",
        "Original art language vs current production vs camera-matched implementation target",
        [
            ("ORIGINAL CONCEPT", REFERENCE, CORAL),
            ("CURRENT ART V4 - REJECTED", CURRENT, MUTED),
            ("NEW CAMERA TARGET", TARGET, GOLD),
        ],
        ["ART LANGUAGE", "TOO FLAT / TOO THIN", "SAME CAMERA + LAYOUT"],
    )
    if V5_CANDIDATE.is_file():
        build_triptych(
            V5_COMPARISON_OUTPUT,
            "TWIN BAYS - CAMERA TARGET IMPLEMENTATION",
            "Rejected production vs approved target vs isolated Art V5 runtime candidate",
            [
                ("ART V4 - REJECTED", CURRENT, MUTED),
                ("APPROVED TARGET", TARGET, GOLD),
                ("ART V5 - DRAIN 9s BATTLE", V5_CANDIDATE, CORAL),
            ],
            ["BEFORE", "VISUAL AUTHORITY", "CAMERA-MATCHED GODOT FRAME"],
        )
    if V5_CANDIDATE.is_file() and V6_CANDIDATE.is_file():
        build_triptych(
            V6_COMPARISON_OUTPUT,
            "TWIN BAYS - PROFESSIONAL FINISH PASS",
            "Retained Art V5 vs approved target vs isolated Art V6 runtime candidate",
            [
                ("ART V5 - RETAINED", V5_CANDIDATE, MUTED),
                ("APPROVED TARGET", TARGET, GOLD),
                ("ART V6 - FINISH CANDIDATE", V6_CANDIDATE, CORAL),
            ],
            ["CURRENT BEST", "VISUAL AUTHORITY", "NORMAL GAMEPLAY CAMERA"],
        )
    if V6_CANDIDATE.is_file() and V7_CANDIDATE.is_file():
        build_triptych(
            V7_COMPARISON_OUTPUT,
            "TWIN BAYS - BENCHMARK CORNER PASS",
            "Retained Art V6 vs approved target vs isolated Art V7 runtime candidate",
            [
                ("ART V6 - RETAINED", V6_CANDIDATE, MUTED),
                ("APPROVED TARGET", TARGET, GOLD),
                ("ART V7 - PORTAL RETAINED", V7_CANDIDATE, CORAL),
            ],
            ["PREVIOUS BEST", "VISUAL AUTHORITY", "NORMAL GAMEPLAY CAMERA"],
        )
    if V7_CANDIDATE.is_file() and V8_CANDIDATE.is_file():
        build_triptych(
            V8_COMPARISON_OUTPUT,
            "TWIN BAYS - WATER MASS AND LIGHT PASS",
            "Retained Art V7 vs approved target vs isolated Art V8 runtime candidate",
            [
                ("ART V7 - RETAINED", V7_CANDIDATE, MUTED),
                ("APPROVED TARGET", TARGET, GOLD),
                ("ART V8 - LOOK-DEV", V8_CANDIDATE, CORAL),
            ],
            ["CURRENT BEST", "VISUAL AUTHORITY", "NORMAL GAMEPLAY CAMERA"],
        )
    if V8_CANDIDATE.is_file() and V9_CANDIDATE.is_file():
        build_triptych(
            V9_COMPARISON_OUTPUT,
            "TWIN BAYS - SOFT CAP MODULE PASS",
            "Retained Art V8 vs approved target vs isolated Art V9 runtime candidate",
            [
                ("ART V8 - RETAINED", V8_CANDIDATE, MUTED),
                ("APPROVED TARGET", TARGET, GOLD),
                ("ART V9 - CURRENT BEST", V9_CANDIDATE, CORAL),
            ],
            ["PREVIOUS BEST", "VISUAL AUTHORITY", "NORMAL GAMEPLAY CAMERA"],
        )
    if V9_CANDIDATE.is_file() and V10_CANDIDATE.is_file():
        build_triptych(
            V10_COMPARISON_OUTPUT,
            "TWIN BAYS - MARGINAL RETURN STOP",
            "Retained Art V9 vs approved target vs isolated Art V10 final candidate",
            [
                ("ART V9 - RETAINED", V9_CANDIDATE, MUTED),
                ("APPROVED TARGET", TARGET, GOLD),
                ("ART V10 - FINAL CANDIDATE", V10_CANDIDATE, CORAL),
            ],
            ["PREVIOUS BEST", "VISUAL AUTHORITY", "NORMAL GAMEPLAY CAMERA"],
        )
    if V5_OFFLINE_CANDIDATE.is_file():
        build_triptych(
            V5_OFFLINE_COMPARISON_OUTPUT,
            "TWIN BAYS - ART V5 OFFLINE CANDIDATE",
            "Rejected production vs approved target vs latest deterministic Blender candidate",
            [
                ("ART V4 - REJECTED", CURRENT, MUTED),
                ("APPROVED TARGET", TARGET, GOLD),
                ("ART V5 - LATEST OFFLINE", V5_OFFLINE_CANDIDATE, CORAL),
            ],
            ["BEFORE", "VISUAL AUTHORITY", "LATEST CANDIDATE"],
        )
    print("TWIN_BAYS_CONCEPT_GAP_TRIPTYCH_PASS")


if __name__ == "__main__":
    main()
