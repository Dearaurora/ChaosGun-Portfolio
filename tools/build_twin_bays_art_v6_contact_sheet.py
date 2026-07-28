"""Build Art V6 runtime and iteration evidence boards."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "reports/twin_bays_art_v6"
CANDIDATE = REPORT / "candidate"
TARGET = ROOT / "docs/art-direction/concepts/twin_bays_art_v5_camera_target.png"
V5 = ROOT / "reports/twin_bays_art_v5/candidate/v5_drain_9_battle_1920x1080.png"
OUTPUT = REPORT / "final_contact_sheet.png"
ITERATION_OUTPUT = REPORT / "industrial_iteration_review.png"

CAPTURES = [
    ("DRY", CANDIDATE / "v6_dry_1536x1024.png"),
    ("HIGH TIDE", CANDIDATE / "v6_high_1536x1024.png"),
    ("DRAIN 9s BATTLE", CANDIDATE / "v6_drain_9_battle_1920x1080.png"),
    ("PORTAL OVERVIEW", CANDIDATE / "v6_portal_1920x1080.png"),
    ("PORTAL DETAIL", CANDIDATE / "v6_portal_close_1920x1080.png"),
    ("1280x720 HUD SAFE", CANDIDATE / "v6_mobile_1280x720.png"),
]

ITERATIONS = [
    ("ART V5 BASELINE", V5, "RETAINED BASE", (139, 202, 211)),
    (
        "V6 PASS 01 - PROP HEAVY",
        REPORT / "rejected/pass01_prop_heavy/v6_drain_9_battle_1920x1080.png",
        "REJECT: DISC / FLOAT CLUTTER",
        (255, 110, 105),
    ),
    (
        "V6 PASS 02 - MATERIAL MASS",
        REPORT / "passes/pass02_material_mass/v6_drain_9_battle_1920x1080.png",
        "KEEP: MATCH-SCALE GAIN",
        (104, 224, 166),
    ),
    (
        "V6 PASS 03 - BAY FOAM",
        REPORT / "rejected/pass03_bay_foam_scallops/v6_drain_9_battle_1920x1080.png",
        "REJECT: WHITE WORM SHAPES",
        (255, 110, 105),
    ),
    (
        "APPROVED TARGET",
        TARGET,
        "VISUAL AUTHORITY",
        (255, 209, 68),
    ),
    (
        "V6 CURRENT BEST",
        CANDIDATE / "v6_drain_9_battle_1920x1080.png",
        "KEEP: PROFESSIONAL FINISH",
        (255, 209, 68),
    ),
]

BACKGROUND = (8, 25, 39)
INK = (250, 239, 218)
MUTED = (139, 202, 211)
CORAL = (255, 137, 126)


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


def build_board(
    output: Path,
    title: str,
    subtitle: str,
    panels: list[tuple[str, Path, str, tuple[int, int, int]]],
) -> None:
    missing = [str(path) for _, path, _, _ in panels if not path.is_file()]
    if missing:
        raise FileNotFoundError("Missing Art V6 evidence: " + ", ".join(missing))
    columns = 3
    rows = 2
    cell = (640, 360)
    header = 86
    canvas = Image.new("RGB", (columns * cell[0], header + rows * cell[1]), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    draw.text((28, 13), title, font=font(30, True), fill=INK)
    draw.text((28, 49), subtitle, font=font(17), fill=MUTED)
    for index, (label, path, decision, accent) in enumerate(panels):
        x = (index % columns) * cell[0]
        y = header + (index // columns) * cell[1]
        canvas.paste(cover(path, cell), (x, y))
        draw.rectangle((x, y, x + cell[0] - 1, y + cell[1] - 1), outline=accent, width=4)
        draw.rounded_rectangle(
            (x + 14, y + 14, x + 378, y + 54),
            radius=9,
            fill=BACKGROUND,
            outline=accent,
            width=2,
        )
        draw.text((x + 27, y + 23), label, font=font(16, True), fill=INK)
        decision_width = int(draw.textlength(decision, font=font(14, True))) + 28
        draw.rounded_rectangle(
            (x + 14, y + cell[1] - 50, x + 14 + decision_width, y + cell[1] - 14),
            radius=9,
            fill=BACKGROUND,
            outline=accent,
            width=2,
        )
        draw.text(
            (x + 27, y + cell[1] - 42),
            decision,
            font=font(14, True),
            fill=accent,
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=False)
    print(output)


def main() -> None:
    runtime_panels = [(label, path, "HIDDEN FORWARD+ CAPTURE", CORAL) for label, path in CAPTURES]
    build_board(
        OUTPUT,
        "TWIN BAYS ART V6 - RUNTIME MATRIX",
        "Hidden 960x540 host / off-screen production-resolution evidence",
        runtime_panels,
    )
    build_board(
        ITERATION_OUTPUT,
        "TWIN BAYS ART V6 - INDUSTRIAL ITERATION REVIEW",
        "Normal-camera gain decides; rejected versions remain reproducible evidence",
        ITERATIONS,
    )
    print("TWIN_BAYS_ART_V6_CONTACT_SHEETS_PASS")


if __name__ == "__main__":
    main()
