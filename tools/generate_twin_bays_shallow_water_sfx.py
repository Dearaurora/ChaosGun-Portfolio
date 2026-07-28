#!/usr/bin/env python3
"""Generate deterministic, short Twin Bays shallow-water one-shot SFX."""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 44_100


def _write_wav(path: Path, samples: list[float]) -> None:
    peak = max(1.0, max(abs(value) for value in samples) * 1.02)
    pcm = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, value / peak)) * 32767.0))
        for value in samples
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(SAMPLE_RATE)
        stream.writeframes(pcm)


def _filtered_noise(rng: random.Random, count: int, smoothing: float) -> list[float]:
    value = 0.0
    result: list[float] = []
    for _ in range(count):
        value = value * smoothing + rng.uniform(-1.0, 1.0) * (1.0 - smoothing)
        result.append(value)
    return result


def _step(seed: int, duration: float, pitch: float) -> list[float]:
    rng = random.Random(seed)
    count = int(duration * SAMPLE_RATE)
    noise = _filtered_noise(rng, count, 0.86)
    result: list[float] = []
    for index in range(count):
        t = index / SAMPLE_RATE
        x = t / duration
        attack = min(1.0, t / 0.010)
        envelope = attack * math.exp(-5.9 * x) * (1.0 - x) ** 0.7
        plop = math.sin(2.0 * math.pi * (118.0 * pitch - 58.0 * x) * t) * math.exp(-11.0 * x)
        sparkle = math.sin(2.0 * math.pi * (760.0 * pitch + 130.0 * x) * t) * math.exp(-18.0 * x)
        result.append((noise[index] * 1.7 + plop * 0.52 + sparkle * 0.10) * envelope * 0.78)
    return result


def _landing(seed: int) -> list[float]:
    duration = 0.42
    rng = random.Random(seed)
    count = int(duration * SAMPLE_RATE)
    noise = _filtered_noise(rng, count, 0.91)
    result: list[float] = []
    for index in range(count):
        t = index / SAMPLE_RATE
        x = t / duration
        attack = min(1.0, t / 0.014)
        envelope = attack * math.exp(-4.2 * x) * (1.0 - x)
        body = math.sin(2.0 * math.pi * (82.0 - 34.0 * x) * t) * math.exp(-6.5 * x)
        wash = noise[index] * (1.35 + 0.45 * math.sin(2.0 * math.pi * 7.0 * t))
        result.append((body * 0.62 + wash) * envelope * 0.82)
    return result


def _bullet(seed: int) -> list[float]:
    duration = 0.13
    rng = random.Random(seed)
    count = int(duration * SAMPLE_RATE)
    noise = _filtered_noise(rng, count, 0.72)
    result: list[float] = []
    for index in range(count):
        t = index / SAMPLE_RATE
        x = t / duration
        envelope = min(1.0, t / 0.0025) * math.exp(-9.0 * x) * (1.0 - x)
        plip = math.sin(2.0 * math.pi * (410.0 - 190.0 * x) * t)
        result.append((plip * 0.48 + noise[index] * 1.75) * envelope * 0.78)
    return result


def _tide_warning(seed: int) -> list[float]:
    duration = 0.48
    rng = random.Random(seed)
    count = int(duration * SAMPLE_RATE)
    noise = _filtered_noise(rng, count, 0.95)
    result: list[float] = []
    for index in range(count):
        t = index / SAMPLE_RATE
        x = t / duration
        envelope = min(1.0, t / 0.018) * (1.0 - x) ** 1.35
        tone = math.sin(2.0 * math.pi * (360.0 + 210.0 * x) * t)
        chime = math.sin(2.0 * math.pi * (720.0 + 420.0 * x) * t) * 0.32
        result.append((tone * 0.54 + chime + noise[index] * 0.20) * envelope * 0.64)
    return result


def _tide_arrival(seed: int) -> list[float]:
    duration = 0.72
    rng = random.Random(seed)
    count = int(duration * SAMPLE_RATE)
    noise = _filtered_noise(rng, count, 0.93)
    result: list[float] = []
    for index in range(count):
        t = index / SAMPLE_RATE
        x = t / duration
        attack = min(1.0, t / 0.025)
        envelope = attack * (1.0 - x) ** 1.7
        wash = noise[index] * (1.1 + 0.35 * math.sin(2.0 * math.pi * 5.0 * t))
        body = math.sin(2.0 * math.pi * (74.0 - 22.0 * x) * t) * math.exp(-4.0 * x)
        result.append((wash + body * 0.42) * envelope * 0.76)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        default="assets/audio/generated/maps/twin_bays",
        type=Path,
    )
    args = parser.parse_args()
    output_dir: Path = args.output_dir
    for index, pitch in enumerate((0.94, 1.0, 1.06), start=1):
        _write_wav(output_dir / f"shallow_step_{index:02d}.wav", _step(9100 + index, 0.23, pitch))
    _write_wav(output_dir / "shallow_land.wav", _landing(9201))
    _write_wav(output_dir / "shallow_bullet.wav", _bullet(9301))
    _write_wav(output_dir / "tide_warning.wav", _tide_warning(9401))
    _write_wav(output_dir / "tide_arrival.wav", _tide_arrival(9501))
    print(f"TWIN_BAYS_SHALLOW_WATER_SFX_PASS files=7 output={output_dir.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
