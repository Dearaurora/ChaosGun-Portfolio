from pathlib import Path
import math

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "textures" / "generated" / "sunset_toy_sky_islands"
SIZE = 512

TEXTURES = {
    "deck_wood_light": ("#C57927", "#EDB352", 0.92),
    "deck_wood_mid": ("#B96722", "#DD943B", 1.05),
    "deck_wood_gold": ("#CA7022", "#F0A946", 0.84),
    "bridge_wood_mid": ("#8E4925", "#C67C3A", 1.12),
    "bridge_wood_light": ("#A85B28", "#D99848", 0.98),
}


def rgb(hex_color):
    value = hex_color.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def generate_texture(name, base_hex, highlight_hex, grain_scale):
    base = rgb(base_hex)
    highlight = rgb(highlight_hex)
    pixels = []
    for y in range(SIZE):
        v = float(y) / float(SIZE - 1)
        for x in range(SIZE):
            u = float(x) / float(SIZE - 1)
            broad = math.sin(math.tau * (v * 5.2 * grain_scale + math.sin(u * math.tau * 1.8) * 0.18))
            fine = math.sin(math.tau * (v * 15.0 * grain_scale + math.sin(u * math.tau * 3.2) * 0.09))
            sweep = math.sin(math.tau * (u * 0.72 + v * 0.16))
            factor = 0.50 + broad * 0.075 + fine * 0.026 + sweep * 0.018
            factor = max(0.34, min(0.66, factor))
            pixels.append(
                tuple(
                    round(base[channel] * (1.0 - factor) + highlight[channel] * factor)
                    for channel in range(3)
                )
            )
    image = Image.new("RGB", (SIZE, SIZE))
    image.putdata(pixels)
    output_path = OUTPUT_DIR / f"{name}.png"
    image.save(output_path, optimize=True)
    print(f"Generated {output_path}")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, spec in TEXTURES.items():
        generate_texture(name, *spec)


if __name__ == "__main__":
    main()
