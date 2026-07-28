"""Build deterministic Art V3 / Art V4 visual comparison sheets."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BEFORE = ROOT / "reports/twin_bays_art_v4/before"
AFTER = ROOT / "reports/twin_bays_art_v4/production"
OUTPUT = ROOT / "reports/twin_bays_art_v4/comparisons"
BG = (10, 28, 43)
INK = (248, 238, 218)
MUTED = (148, 200, 207)
GOLD = (255, 202, 65)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
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


def label(draw: ImageDraw.ImageDraw, xy: tuple[int, int], title: str, accent: tuple[int, int, int]) -> None:
    x, y = xy
    draw.rounded_rectangle((x, y, x + 250, y + 52), radius=14, fill=(8, 24, 38, 230), outline=accent, width=2)
    draw.text((x + 18, y + 11), title, font=font(25, True), fill=INK)


def build_battle() -> None:
    cell = (960, 540)
    header = 78
    canvas = Image.new("RGB", (cell[0] * 2, cell[1] + header), BG)
    canvas.paste(cover(BEFORE / "v3_battle_1920x1080.png", cell), (0, header))
    canvas.paste(cover(AFTER / "battle_1920x1080.png", cell), (cell[0], header))
    draw = ImageDraw.Draw(canvas)
    draw.text((32, 19), "TWIN BAYS — FOUR-PLAYER GAMEPLAY", font=font(32, True), fill=INK)
    draw.text((1460, 24), "same layout • same camera", font=font(20), fill=MUTED)
    label(draw, (24, header + 20), "ART V3  •  BEFORE", MUTED)
    label(draw, (cell[0] + 24, header + 20), "ART V4  •  FINAL", GOLD)
    draw.line((cell[0], header, cell[0], canvas.height), fill=GOLD, width=3)
    canvas.save(OUTPUT / "v3_v4_battle_comparison.png", optimize=False)


def build_states() -> None:
    cell = (768, 512)
    header = 94
    row_label = 44
    rows = [
        ("DRY", "v3_dry_1536x1024.png", "dry_1536x1024.png"),
        ("HIGH TIDE", "v3_high_1536x1024.png", "high_1536x1024.png"),
        ("DRAIN 0 s", "v3_drain_0_1536x1024.png", "drain_0_1536x1024.png"),
        ("DRAIN 9 s", "v3_drain_9_1536x1024.png", "drain_9_1536x1024.png"),
    ]
    canvas = Image.new("RGB", (cell[0] * 2, header + len(rows) * (cell[1] + row_label)), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((30, 18), "TWIN BAYS — TIDE MATERIAL CONVERGENCE", font=font(32, True), fill=INK)
    draw.text((30, 58), "ART V3 BEFORE", font=font(21, True), fill=MUTED)
    draw.text((cell[0] + 30, 58), "ART V4 PRODUCTION", font=font(21, True), fill=GOLD)
    for index, (state, before_name, after_name) in enumerate(rows):
        y = header + index * (cell[1] + row_label)
        canvas.paste(cover(BEFORE / before_name, cell), (0, y))
        canvas.paste(cover(AFTER / after_name, cell), (cell[0], y))
        draw.rectangle((0, y + cell[1], canvas.width, y + cell[1] + row_label), fill=(7, 22, 35))
        draw.text((24, y + cell[1] + 8), state, font=font(21, True), fill=INK)
        draw.line((cell[0], y, cell[0], y + cell[1]), fill=GOLD, width=3)
    canvas.save(OUTPUT / "v3_v4_tide_state_matrix.png", optimize=False)


def build_delivery_sheet() -> None:
    cell = (640, 360)
    header = 86
    items = [
        ("DRY", "dry_1536x1024.png"),
        ("WARNING", "warning_1536x1024.png"),
        ("HIGH TIDE", "high_1536x1024.png"),
        ("DRAIN 0 s", "drain_0_1536x1024.png"),
        ("4P GAMEPLAY", "battle_1920x1080.png"),
        ("PORTAL", "portal_1920x1080.png"),
    ]
    canvas = Image.new("RGB", (cell[0] * 3, header + cell[1] * 2), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((30, 18), "TWIN BAYS ART V4 — PRODUCTION EVIDENCE", font=font(32, True), fill=INK)
    draw.text((1405, 26), "Golden unchanged", font=font(21, True), fill=GOLD)
    for index, (title, filename) in enumerate(items):
        x = (index % 3) * cell[0]
        y = header + (index // 3) * cell[1]
        canvas.paste(cover(AFTER / filename, cell), (x, y))
        label(draw, (x + 18, y + 18), title, GOLD)
    canvas.save(OUTPUT / "v4_production_contact_sheet.png", optimize=False)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    build_battle()
    build_states()
    build_delivery_sheet()
    print(f"Comparison output: {OUTPUT}")
    print("TWIN_BAYS_ART_V4_COMPARISON_BUILD_PASS")


if __name__ == "__main__":
    main()
