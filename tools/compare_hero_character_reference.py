from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "assets/source/characters/reference/character_turnaround_v1.png"
CURRENT = ROOT / "reports/hero_character_rig_v3_front.png"
OUTPUT = ROOT / "reports/hero_character_rig_v3_reference_comparison.png"

CANVAS_SIZE = (480, 760)


def foreground_mask(image):
    rgb = np.asarray(image.convert("RGB"), dtype=np.int16)
    maximum = rgb.max(axis=2)
    minimum = rgb.min(axis=2)
    saturation_span = maximum - minimum
    mask = (saturation_span > 34) & (maximum > 58)
    return Image.fromarray(np.where(mask, 255, 0).astype(np.uint8), mode="L")


def content_bounds(mask):
    bounds = mask.getbbox()
    if bounds is None:
        raise RuntimeError("comparison image has no detectable character foreground")
    left, top, right, bottom = bounds
    pad_x = max(8, int((right - left) * 0.035))
    pad_y = max(8, int((bottom - top) * 0.025))
    return (
        max(0, left - pad_x),
        max(0, top - pad_y),
        min(mask.width, right + pad_x),
        min(mask.height, bottom + pad_y),
    )


def fit_crop(image, mask, bounds):
    image = image.crop(bounds)
    mask = mask.crop(bounds)
    available_width = CANVAS_SIZE[0] - 28
    available_height = CANVAS_SIZE[1] - 28
    scale = min(available_width / image.width, available_height / image.height)
    size = (
        max(1, int(round(image.width * scale))),
        max(1, int(round(image.height * scale))),
    )
    image = image.resize(size, Image.Resampling.LANCZOS)
    mask = mask.resize(size, Image.Resampling.NEAREST)
    offset = (
        (CANVAS_SIZE[0] - size[0]) // 2,
        (CANVAS_SIZE[1] - size[1]) // 2,
    )
    return image, mask, offset


def normalized_panel(image, mask):
    bounds = content_bounds(mask)
    image, mask, offset = fit_crop(image, mask, bounds)
    panel = Image.new("RGB", CANVAS_SIZE, (224, 224, 226))
    panel.paste(image, offset)
    normalized_mask = Image.new("L", CANVAS_SIZE, 0)
    normalized_mask.paste(mask, offset)
    return panel, normalized_mask


def outline(mask, width=5):
    eroded = mask.filter(ImageFilter.MinFilter(width))
    mask_values = np.asarray(mask, dtype=np.int16)
    eroded_values = np.asarray(eroded, dtype=np.int16)
    edge = np.clip(mask_values - eroded_values, 0, 255).astype(np.uint8)
    return Image.fromarray(edge, mode="L")


def main():
    reference_sheet = Image.open(REFERENCE).convert("RGB")
    reference = reference_sheet.crop((0, 0, 520, reference_sheet.height))
    current = Image.open(CURRENT).convert("RGB")

    reference_panel, reference_mask = normalized_panel(reference, foreground_mask(reference))
    current_panel, current_mask = normalized_panel(current, foreground_mask(current))

    output = Image.new("RGB", (1600, 900), (32, 31, 38))
    output.paste(reference_panel, (40, 100))
    output.paste(current_panel, (560, 100))

    overlay = Image.new("RGB", CANVAS_SIZE, (42, 41, 48))
    reference_fill = Image.new("RGB", CANVAS_SIZE, (57, 211, 224))
    current_fill = Image.new("RGB", CANVAS_SIZE, (255, 83, 134))
    overlay.paste(reference_fill, mask=reference_mask.point(lambda value: value // 5))
    overlay.paste(current_fill, mask=current_mask.point(lambda value: value // 5))
    overlay.paste(
        Image.new("RGB", CANVAS_SIZE, (78, 231, 242)),
        mask=outline(reference_mask),
    )
    overlay.paste(
        Image.new("RGB", CANVAS_SIZE, (255, 92, 145)),
        mask=outline(current_mask),
    )
    output.paste(overlay, (1080, 100))

    draw = ImageDraw.Draw(output)
    draw.text((40, 54), "APPROVED REFERENCE", fill=(242, 242, 246))
    draw.text((560, 54), "RIG V3 FRONT", fill=(242, 242, 246))
    draw.text((1080, 54), "NORMALIZED SILHOUETTE OVERLAY", fill=(242, 242, 246))
    draw.text((1080, 830), "CYAN: reference   PINK: rig v3", fill=(218, 218, 224))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT)
    print("HERO_REFERENCE_COMPARISON_WRITTEN", OUTPUT)


if __name__ == "__main__":
    main()
