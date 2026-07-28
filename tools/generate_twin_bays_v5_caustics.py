#!/usr/bin/env python3
"""Build the deterministic, tileable Art V5 pool-caustic authority texture.

The texture is an offline procedural source, not generated art. Runtime motion,
depth tinting and tide response remain shader-owned. Keeping the cell field in a
single reviewable texture makes the silhouette stable across renderers while
avoiding the straight polygon edges and long sine ribbons rejected in the first
two industrial water passes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


DEFAULT_OUTPUT = Path("assets/textures/generated/twin_bays_v5_caustics.png")
DEFAULT_REPORT = Path("reports/twin_bays_art_v5/twin_bays_v5_caustics_manifest.json")


def _periodic_delta(values: np.ndarray, center: float) -> np.ndarray:
    delta = np.abs(values - center)
    return np.minimum(delta, 1.0 - delta)


def build_caustics(size: int, seed: int, cells: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    axis = (np.arange(size, dtype=np.float32) + 0.5) / float(size)
    x, y = np.meshgrid(axis, axis)
    tau = np.float32(np.pi * 2.0)

    # Periodic domain warping bends cell borders while preserving exact tiling.
    warped_x = np.mod(
        x
        + 0.026 * np.sin(tau * (y * 2.0 + 0.11))
        + 0.013 * np.sin(tau * (y * 5.0 - 0.23)),
        1.0,
    )
    warped_y = np.mod(
        y
        + 0.024 * np.sin(tau * (x * 2.0 - 0.17))
        + 0.012 * np.sin(tau * (x * 4.0 + 0.31)),
        1.0,
    )

    nearest = np.full((size, size), np.inf, dtype=np.float32)
    second = np.full((size, size), np.inf, dtype=np.float32)
    for row in range(cells):
        for column in range(cells):
            jitter = rng.uniform(-0.31, 0.31, size=2)
            seed_x = ((column + 0.5 + jitter[0]) / cells) % 1.0
            seed_y = ((row + 0.5 + jitter[1]) / cells) % 1.0
            dx = _periodic_delta(warped_x, float(seed_x))
            dy = _periodic_delta(warped_y, float(seed_y))
            distance = np.sqrt(dx * dx + dy * dy)
            replace_nearest = distance < nearest
            second = np.where(replace_nearest, nearest, np.minimum(second, distance))
            nearest = np.where(replace_nearest, distance, nearest)

    boundary = np.maximum(second - nearest, 0.0)
    line_width = 0.0105
    caustics = np.exp(-np.square(boundary / line_width))
    # A restrained secondary shoulder creates the soft luminous falloff present
    # in the camera target without turning every line into an emissive outline.
    shoulder = np.exp(-np.square(boundary / 0.023))
    caustics = np.clip(caustics * 0.78 + shoulder * 0.22, 0.0, 1.0)
    caustics = np.power(caustics, 0.78)

    pixels = np.round(caustics * 255.0).astype(np.uint8)
    image = Image.fromarray(pixels, mode="L")
    return image.filter(ImageFilter.GaussianBlur(radius=max(0.8, size / 1024.0)))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--size", type=int, default=1024)
    parser.add_argument("--seed", type=int, default=20260727)
    parser.add_argument("--cells", type=int, default=11)
    args = parser.parse_args()
    if args.size < 256 or args.size > 2048:
        raise SystemExit("size must stay within the 256..2048 art budget")
    if args.cells < 4 or args.cells > 24:
        raise SystemExit("cells must stay within 4..24")

    image = build_caustics(args.size, args.seed, args.cells)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output, optimize=True)

    report = {
        "schema": "chaos_gun.twin_bays_caustics",
        "version": 1,
        "algorithm": "periodic_domain_warped_voronoi_boundary",
        "seed": args.seed,
        "cells": args.cells,
        "width": image.width,
        "height": image.height,
        "mode": image.mode,
        "sha256": sha256(args.output),
        "runtime_role": "single_tiled_backdrop_mask",
        "runtime_asset": args.output.as_posix(),
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
