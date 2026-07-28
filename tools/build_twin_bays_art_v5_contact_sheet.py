"""Build the final Twin Bays Art V5 runtime evidence contact sheet."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CAPTURE_ROOT = ROOT / "reports/twin_bays_art_v5/candidate"
OUTPUT = ROOT / "reports/twin_bays_art_v5/final_contact_sheet.png"
ITERATION_OUTPUT = ROOT / "reports/twin_bays_art_v5/industrial_iteration_review.png"

CAPTURES = [
    ("DRY", "v5_dry_1536x1024.png"),
    ("HIGH TIDE", "v5_high_1536x1024.png"),
    ("DRAIN 0s", "v5_drain_0_1536x1024.png"),
    ("DRAIN 9s", "v5_drain_9_1536x1024.png"),
    ("DRY BATTLE", "v5_dry_battle_1920x1080.png"),
    ("DRAIN 9s BATTLE", "v5_drain_9_battle_1920x1080.png"),
    ("HIGH-TIDE BATTLE", "v5_battle_1920x1080.png"),
    ("MOBILE / HUD SAFE", "v5_mobile_1280x720.png"),
    ("PORTAL OVERVIEW", "v5_portal_1920x1080.png"),
    ("PORTAL DETAIL", "v5_portal_close_1920x1080.png"),
]

ITERATIONS = [
    (
        "00  BEFORE",
        ROOT
        / "reports/twin_bays_art_v5/industrial_pass_00_before"
        / "v5_drain_9_battle_1920x1080.png",
        "FROZEN BASELINE",
        (139, 202, 211),
    ),
    (
        "01  LARGE CELLS",
        ROOT
        / "reports/twin_bays_art_v5/industrial_pass_01_water"
        / "v5_drain_9_battle_1920x1080.png",
        "REJECT: CRACKED-ICE SHAPE",
        (255, 110, 105),
    ),
    (
        "02  FLOW LINES",
        ROOT
        / "reports/twin_bays_art_v5/industrial_pass_02_flowing_water"
        / "v5_drain_9_battle_1920x1080.png",
        "REJECT: NOODLE-LIKE FLOW",
        (255, 110, 105),
    ),
    (
        "03  AUTHORED CAUSTICS",
        ROOT
        / "reports/twin_bays_art_v5/industrial_pass_03_authored_caustics"
        / "v5_drain_9_battle_final_1920x1080.png",
        "KEEP: READS AT MATCH SCALE",
        (104, 224, 166),
    ),
    (
        "05  SOFT LIGHTING",
        ROOT
        / "reports/twin_bays_art_v5/industrial_pass_05_soft_lighting"
        / "v5_drain_9_battle_1920x1080.png",
        "REJECT: FLATTENS CONTACT",
        (255, 110, 105),
    ),
    (
        "FINAL  CURRENT BEST",
        ROOT
        / "reports/twin_bays_art_v5/candidate"
        / "v5_drain_9_battle_1920x1080.png",
        "KEEP: WATER + PORTAL CONTACT",
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


def main() -> None:
    missing = [name for _, name in CAPTURES if not (CAPTURE_ROOT / name).is_file()]
    if missing:
        raise FileNotFoundError("Missing Art V5 captures: " + ", ".join(missing))

    columns = 4
    rows = 3
    cell = (480, 270)
    header = 82
    canvas = Image.new("RGB", (columns * cell[0], header + rows * cell[1]), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    draw.text((28, 14), "TWIN BAYS ART V5 - FINAL RUNTIME MATRIX", font=font(31, True), fill=INK)
    draw.text(
        (28, 51),
        "Hidden host window / real Forward+ renderer / off-screen evidence",
        font=font(18),
        fill=MUTED,
    )

    for index, (label, filename) in enumerate(CAPTURES):
        column = index % columns
        row = index // columns
        x = column * cell[0]
        y = header + row * cell[1]
        canvas.paste(cover(CAPTURE_ROOT / filename, cell), (x, y))
        draw.rectangle((x, y, x + cell[0] - 1, y + cell[1] - 1), outline=CORAL, width=2)
        label_width = max(180, min(350, 28 + draw.textlength(label, font=font(17, True))))
        draw.rounded_rectangle(
            (x + 12, y + 12, x + label_width, y + 48),
            radius=9,
            fill=BACKGROUND,
            outline=CORAL,
            width=1,
        )
        draw.text((x + 24, y + 20), label, font=font(17, True), fill=INK)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUTPUT, optimize=False)
    print(OUTPUT)

    iteration_missing = [str(path) for _, path, _, _ in ITERATIONS if not path.is_file()]
    if iteration_missing:
        raise FileNotFoundError("Missing Art V5 iteration evidence: " + ", ".join(iteration_missing))
    iteration_columns = 3
    iteration_rows = 2
    iteration_cell = (640, 360)
    iteration_header = 86
    iteration_canvas = Image.new(
        "RGB",
        (
            iteration_columns * iteration_cell[0],
            iteration_header + iteration_rows * iteration_cell[1],
        ),
        BACKGROUND,
    )
    iteration_draw = ImageDraw.Draw(iteration_canvas)
    iteration_draw.text(
        (28, 13),
        "TWIN BAYS ART V5 - INDUSTRIAL ITERATION REVIEW",
        font=font(30, True),
        fill=INK,
    )
    iteration_draw.text(
        (28, 49),
        "Keep only changes visible at normal gameplay scale; preserve rejected evidence",
        font=font(17),
        fill=MUTED,
    )
    for index, (label, path, decision, accent) in enumerate(ITERATIONS):
        column = index % iteration_columns
        row = index // iteration_columns
        x = column * iteration_cell[0]
        y = iteration_header + row * iteration_cell[1]
        iteration_canvas.paste(cover(path, iteration_cell), (x, y))
        iteration_draw.rectangle(
            (x, y, x + iteration_cell[0] - 1, y + iteration_cell[1] - 1),
            outline=accent,
            width=4,
        )
        iteration_draw.rounded_rectangle(
            (x + 14, y + 14, x + 350, y + 54),
            radius=9,
            fill=BACKGROUND,
            outline=accent,
            width=2,
        )
        iteration_draw.text((x + 27, y + 23), label, font=font(17, True), fill=INK)
        decision_width = int(iteration_draw.textlength(decision, font=font(15, True))) + 28
        iteration_draw.rounded_rectangle(
            (
                x + 14,
                y + iteration_cell[1] - 52,
                x + 14 + decision_width,
                y + iteration_cell[1] - 14,
            ),
            radius=9,
            fill=BACKGROUND,
            outline=accent,
            width=2,
        )
        iteration_draw.text(
            (x + 27, y + iteration_cell[1] - 43),
            decision,
            font=font(15, True),
            fill=accent,
        )
    iteration_canvas.save(ITERATION_OUTPUT, optimize=False)
    print(ITERATION_OUTPUT)
    print("TWIN_BAYS_ART_V5_CONTACT_SHEET_PASS")


if __name__ == "__main__":
    main()
