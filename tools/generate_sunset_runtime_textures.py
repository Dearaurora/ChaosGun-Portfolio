from pathlib import Path
import math

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "assets" / "textures" / "generated" / "sunset_toy_sky_islands"
SIZE = 512

TEXTURES = {
    "deck_wood_light": ("#B85B28", "#EAA04A", 0.92, 0.72, 18.0),
    "deck_wood_mid": ("#9F4425", "#D57938", 1.05, 0.78, 17.0),
    "deck_wood_gold": ("#C66824", "#F0AD48", 0.84, 0.70, 19.0),
    "bridge_wood_mid": ("#71331F", "#B76232", 1.12, 0.84, 22.0),
    "bridge_wood_light": ("#8B4023", "#D17B3E", 0.98, 0.80, 21.0),
}


def rgb(hex_color):
    value = hex_color.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def _clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def _grain_height(u, v, grain_scale, phase):
    warp = math.sin(math.tau * (u * 1.35 + phase)) * 0.16
    broad = math.sin(math.tau * (v * 3.7 * grain_scale + warp))
    fine = math.sin(math.tau * (v * 9.4 * grain_scale + warp * 0.38 + phase * 0.7))

    knot_u = 0.32 + math.sin(phase * math.tau) * 0.12
    knot_v = 0.54 + math.cos(phase * math.tau) * 0.15
    knot_x = (u - knot_u) * 2.7
    knot_y = (v - knot_v) * 0.78
    knot_radius = math.sqrt(knot_x * knot_x + knot_y * knot_y)
    knot = math.sin(math.tau * (knot_radius * 2.25 - phase * 0.5)) * math.exp(-knot_radius * 4.0)

    sweep = math.sin(math.tau * (u * 0.55 + v * 0.12 + phase))
    return _clamp(0.5 + broad * 0.135 + fine * 0.030 + knot * 0.055 + sweep * 0.018, 0.24, 0.76)


def generate_texture(name, base_hex, highlight_hex, grain_scale, roughness, normal_strength):
    base = rgb(base_hex)
    highlight = rgb(highlight_hex)
    phase = (sum(name.encode("ascii")) % 97) / 97.0
    heights = []
    for y in range(SIZE):
        v = float(y) / float(SIZE - 1)
        row = []
        for x in range(SIZE):
            u = float(x) / float(SIZE - 1)
            row.append(_grain_height(u, v, grain_scale, phase))
        heights.append(row)

    pixels = []
    for y in range(SIZE):
        for x in range(SIZE):
            factor = _clamp(0.48 + (heights[y][x] - 0.5) * 1.25, 0.24, 0.72)
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

    normal_pixels = []
    roughness_pixels = []
    for y in range(SIZE):
        y_before = max(y - 1, 0)
        y_after = min(y + 1, SIZE - 1)
        for x in range(SIZE):
            x_before = max(x - 1, 0)
            x_after = min(x + 1, SIZE - 1)
            dx = (heights[y][x_after] - heights[y][x_before]) * normal_strength
            dy = (heights[y_after][x] - heights[y_before][x]) * normal_strength
            nx, ny, nz = -dx, dy, 1.0
            length = math.sqrt(nx * nx + ny * ny + nz * nz)
            normal_pixels.append(
                (
                    round((nx / length * 0.5 + 0.5) * 255.0),
                    round((ny / length * 0.5 + 0.5) * 255.0),
                    round((nz / length * 0.5 + 0.5) * 255.0),
                )
            )
            roughness_value = round(_clamp(roughness + (0.5 - heights[y][x]) * 0.11, 0.58, 0.92) * 255.0)
            roughness_pixels.append(roughness_value)

    normal_image = Image.new("RGB", (SIZE, SIZE))
    normal_image.putdata(normal_pixels)
    normal_path = OUTPUT_DIR / f"{name}_normal.png"
    normal_image.save(normal_path, optimize=True)
    print(f"Generated {normal_path}")

    roughness_image = Image.new("L", (SIZE, SIZE))
    roughness_image.putdata(roughness_pixels)
    roughness_path = OUTPUT_DIR / f"{name}_roughness.png"
    roughness_image.save(roughness_path, optimize=True)
    print(f"Generated {roughness_path}")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, spec in TEXTURES.items():
        generate_texture(name, *spec)


if __name__ == "__main__":
    main()
