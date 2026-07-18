#!/usr/bin/env python3
"""Objective visual/geometric comparison for the Twin Bays whitebox.

The comparison deliberately does *not* register, crop, or otherwise move the
candidate to fit the reference.  Both images are resampled onto the reference
canvas so camera framing, scale, silhouette, and hole placement all count.

Only Pillow and NumPy are required.  The 98% gate is strict: every geometric
criterion must reach the requested threshold, rather than a high score in one
criterion compensating for a low score in another.

Examples::

    python tools/compare_twin_bays_reference.py
    python tools/compare_twin_bays_reference.py --json
    python tools/compare_twin_bays_reference.py --strict
    python tools/compare_twin_bays_reference.py other_render.png --strict
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable

import numpy as np
from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE = Path(
    r"C:\Users\Administrator\AppData\Local\Temp\codex-clipboard-871f120c-e463-4725-ae86-30b24fd7a6fd.png"
)
DEFAULT_CANDIDATE = REPO_ROOT / "reports" / "twin_bays_whitebox.png"


def _load_rgb(path: Path) -> tuple[np.ndarray, tuple[int, int]]:
    if not path.is_file():
        raise FileNotFoundError(f"Image not found: {path}")
    with Image.open(path) as image:
        size = image.size
        rgb = np.asarray(image.convert("RGB"), dtype=np.uint8)
    return rgb, size


def _comparison_size(
    reference_size: tuple[int, int], max_dimension: int
) -> tuple[int, int]:
    width, height = reference_size
    if max_dimension <= 0 or max(width, height) <= max_dimension:
        return width, height
    scale = max_dimension / float(max(width, height))
    return max(1, round(width * scale)), max(1, round(height * scale))


def _resize_rgb(rgb: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    image = Image.fromarray(rgb, mode="RGB")
    if image.size != size:
        image = image.resize(size, Image.Resampling.LANCZOS)
    return np.asarray(image, dtype=np.uint8)


def _luminance(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.float32)
    return (
        values[..., 0] * np.float32(0.2126)
        + values[..., 1] * np.float32(0.7152)
        + values[..., 2] * np.float32(0.0722)
    )


def _saturation(rgb: np.ndarray) -> np.ndarray:
    values = rgb.astype(np.float32) / np.float32(255.0)
    high = values.max(axis=2)
    low = values.min(axis=2)
    return np.divide(
        high - low,
        high,
        out=np.zeros_like(high),
        where=high > np.float32(1e-6),
    )


def _otsu_threshold(gray: np.ndarray) -> int:
    samples = np.clip(np.rint(gray), 0, 255).astype(np.uint8)
    histogram = np.bincount(samples.ravel(), minlength=256).astype(np.float64)
    total = histogram.sum()
    if total <= 0:
        return 255

    levels = np.arange(256, dtype=np.float64)
    class_weight = np.cumsum(histogram)
    class_sum = np.cumsum(histogram * levels)
    total_sum = class_sum[-1]
    denominator = class_weight * (total - class_weight)
    between = np.zeros(256, dtype=np.float64)
    valid = denominator > 0
    between[valid] = (
        (total_sum * class_weight[valid] - total * class_sum[valid]) ** 2
        / denominator[valid]
    )
    if not np.any(between > 0):
        return min(255, int(round(float(gray.mean()))) + 1)
    return int(np.argmax(between))


def _find(parent: list[int], item: int) -> int:
    while parent[item] != item:
        parent[item] = parent[parent[item]]
        item = parent[item]
    return item


def _union(parent: list[int], rank: list[int], left: int, right: int) -> None:
    left_root = _find(parent, left)
    right_root = _find(parent, right)
    if left_root == right_root:
        return
    if rank[left_root] < rank[right_root]:
        left_root, right_root = right_root, left_root
    parent[right_root] = left_root
    if rank[left_root] == rank[right_root]:
        rank[left_root] += 1


def _component_dict(
    aggregate: list[float], width: int, height: int, bright_area: int
) -> dict[str, Any]:
    area, sum_x, sum_y, x0, y0, x1, y1 = aggregate
    centroid_x = sum_x / area
    centroid_y = sum_y / area
    return {
        "area_pixels": int(area),
        "area_ratio": float(area / (width * height)),
        "share_of_bright_mask": float(area / max(1, bright_area)),
        "centroid_xy": [float(centroid_x), float(centroid_y)],
        "centroid_normalized": [
            float(centroid_x / max(1, width - 1)),
            float(centroid_y / max(1, height - 1)),
        ],
        # Pixel coordinates are inclusive.  The normalized right/bottom edges
        # are exclusive, which makes area and overlap arithmetic unambiguous.
        "bbox_xyxy_inclusive": [int(x0), int(y0), int(x1), int(y1)],
        "bbox_normalized": [
            float(x0 / width),
            float(y0 / height),
            float((x1 + 1) / width),
            float((y1 + 1) / height),
        ],
    }


def _clean_and_measure_components(
    mask: np.ndarray, minimum_area: int
) -> tuple[np.ndarray, list[dict[str, Any]], int]:
    """Find 8-connected components with a NumPy/run-length fallback.

    A run-length union-find avoids a Python operation for every foreground
    pixel and does not depend on OpenCV, SciPy, or scikit-image.
    """

    height, width = mask.shape
    parent: list[int] = []
    rank: list[int] = []
    # (y, x_start, x_end_inclusive, provisional_label)
    runs: list[tuple[int, int, int, int]] = []
    previous: list[tuple[int, int, int]] = []

    for y in range(height):
        row = mask[y]
        padded = np.empty(width + 2, dtype=np.int8)
        padded[0] = 0
        padded[-1] = 0
        padded[1:-1] = row
        transitions = np.diff(padded)
        starts = np.flatnonzero(transitions == 1)
        ends = np.flatnonzero(transitions == -1) - 1

        current: list[tuple[int, int, int]] = []
        previous_index = 0
        for start, end in zip(starts.tolist(), ends.tolist()):
            label = len(parent)
            parent.append(label)
            rank.append(0)

            # Eight-connectivity: diagonally touching runs overlap after each
            # previous run is expanded by one pixel in x.
            while (
                previous_index < len(previous)
                and previous[previous_index][1] < start - 1
            ):
                previous_index += 1
            overlap_index = previous_index
            while (
                overlap_index < len(previous)
                and previous[overlap_index][0] <= end + 1
            ):
                _union(parent, rank, label, previous[overlap_index][2])
                overlap_index += 1

            current.append((start, end, label))
            runs.append((y, start, end, label))
        previous = current

    # Aggregate as [area, sum_x, sum_y, x0, y0, x1, y1].
    aggregates: dict[int, list[float]] = {}
    for y, start, end, label in runs:
        root = _find(parent, label)
        count = end - start + 1
        sum_x = (start + end) * count / 2.0
        if root not in aggregates:
            aggregates[root] = [
                float(count),
                float(sum_x),
                float(y * count),
                float(start),
                float(y),
                float(end),
                float(y),
            ]
        else:
            item = aggregates[root]
            item[0] += count
            item[1] += sum_x
            item[2] += y * count
            item[3] = min(item[3], start)
            item[4] = min(item[4], y)
            item[5] = max(item[5], end)
            item[6] = max(item[6], y)

    kept_roots = {
        root for root, aggregate in aggregates.items() if aggregate[0] >= minimum_area
    }
    cleaned = np.zeros_like(mask, dtype=bool)
    for y, start, end, label in runs:
        if _find(parent, label) in kept_roots:
            cleaned[y, start : end + 1] = True

    bright_area = int(cleaned.sum())
    kept = [aggregates[root] for root in kept_roots]
    kept.sort(key=lambda item: item[0], reverse=True)
    components = [
        _component_dict(item, width, height, bright_area) for item in kept
    ]
    removed_count = len(aggregates) - len(kept)
    return cleaned, components, removed_count


def _platform_mask(
    rgb: np.ndarray, max_saturation: float, minimum_component_ratio: float
) -> tuple[np.ndarray, int, list[dict[str, Any]], int, int]:
    gray = _luminance(rgb)
    threshold = _otsu_threshold(gray)
    neutral_bright = (gray >= threshold) & (_saturation(rgb) <= max_saturation)
    minimum_area = max(4, int(round(neutral_bright.size * minimum_component_ratio)))
    cleaned, components, removed = _clean_and_measure_components(
        neutral_bright, minimum_area
    )
    return cleaned, threshold, components, removed, minimum_area


def _mask_overlap(reference: np.ndarray, candidate: np.ndarray) -> dict[str, Any]:
    intersection = int(np.logical_and(reference, candidate).sum())
    union = int(np.logical_or(reference, candidate).sum())
    reference_area = int(reference.sum())
    candidate_area = int(candidate.sum())
    iou = intersection / union if union else 0.0
    total_area = reference_area + candidate_area
    dice = 2.0 * intersection / total_area if total_area else 0.0
    return {
        "reference_pixels": reference_area,
        "candidate_pixels": candidate_area,
        "intersection_pixels": intersection,
        "union_pixels": union,
        "iou": float(iou),
        "dice": float(dice),
        "candidate_to_reference_area_ratio": float(
            candidate_area / reference_area if reference_area else 0.0
        ),
    }


def _contour(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    eroded = np.ones_like(mask, dtype=bool)
    for y_offset in range(3):
        for x_offset in range(3):
            eroded &= padded[
                y_offset : y_offset + mask.shape[0],
                x_offset : x_offset + mask.shape[1],
            ]
    return mask & ~eroded


def _dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    result = mask.copy()
    for _ in range(max(0, radius)):
        padded = np.pad(result, 1, mode="constant", constant_values=False)
        expanded = np.zeros_like(result, dtype=bool)
        for y_offset in range(3):
            for x_offset in range(3):
                expanded |= padded[
                    y_offset : y_offset + result.shape[0],
                    x_offset : x_offset + result.shape[1],
                ]
        result = expanded
    return result


def _evenly_subsample(points: np.ndarray, maximum: int) -> np.ndarray:
    if len(points) <= maximum:
        return points
    indices = np.linspace(0, len(points) - 1, maximum, dtype=np.int64)
    return points[indices]


def _mean_nearest_distance(
    source_contour: np.ndarray,
    target_contour: np.ndarray,
    maximum_points: int = 6000,
    chunk_size: int = 192,
) -> float | None:
    source_points = np.argwhere(source_contour).astype(np.float32)
    target_points = np.argwhere(target_contour).astype(np.float32)
    if not len(source_points) or not len(target_points):
        return None
    source_points = _evenly_subsample(source_points, maximum_points)
    target_points = _evenly_subsample(target_points, maximum_points)

    minimum_squared: list[np.ndarray] = []
    for start in range(0, len(source_points), chunk_size):
        source_chunk = source_points[start : start + chunk_size]
        difference = source_chunk[:, None, :] - target_points[None, :, :]
        distance_squared = np.sum(difference * difference, axis=2)
        minimum_squared.append(np.min(distance_squared, axis=1))
    distances = np.sqrt(np.concatenate(minimum_squared))
    return float(distances.mean())


def _contour_metrics(
    reference_mask: np.ndarray, candidate_mask: np.ndarray, tolerance: int
) -> dict[str, Any]:
    reference = _contour(reference_mask)
    candidate = _contour(candidate_mask)
    reference_count = int(reference.sum())
    candidate_count = int(candidate.sum())

    if reference_count and candidate_count:
        candidate_matches = int((candidate & _dilate(reference, tolerance)).sum())
        reference_matches = int((reference & _dilate(candidate, tolerance)).sum())
        precision = candidate_matches / candidate_count
        recall = reference_matches / reference_count
        f1 = (
            2.0 * precision * recall / (precision + recall)
            if precision + recall
            else 0.0
        )
    else:
        precision = recall = f1 = 0.0

    reference_to_candidate = _mean_nearest_distance(reference, candidate)
    candidate_to_reference = _mean_nearest_distance(candidate, reference)
    if reference_to_candidate is None or candidate_to_reference is None:
        chamfer = None
        chamfer_similarity = 0.0
    else:
        chamfer = (reference_to_candidate + candidate_to_reference) / 2.0
        diagonal = math.hypot(*reference.shape)
        chamfer_similarity = max(0.0, 1.0 - chamfer / max(diagonal, 1.0))

    return {
        "reference_pixels": reference_count,
        "candidate_pixels": candidate_count,
        "tolerance_pixels": tolerance,
        "precision": float(precision),
        "recall": float(recall),
        "f1": float(f1),
        "symmetric_chamfer_pixels": (
            float(chamfer) if chamfer is not None else None
        ),
        "normalized_chamfer_similarity": float(chamfer_similarity),
    }


def _paint_overlay(
    image: np.ndarray,
    mask: np.ndarray,
    color: tuple[int, int, int],
    alpha: float,
) -> None:
    if not np.any(mask):
        return
    tint = np.asarray(color, dtype=np.float32)
    image[mask] = image[mask] * (1.0 - alpha) + tint * alpha


def _write_difference_overlay(
    path: Path,
    reference_rgb: np.ndarray,
    candidate_rgb: np.ndarray,
    reference_mask: np.ndarray,
    candidate_mask: np.ndarray,
    contour_tolerance: int,
) -> None:
    """Write a mask fill plus contour overlay on a dimmed grayscale base."""

    base_gray = (_luminance(reference_rgb) + _luminance(candidate_rgb)) * 0.5
    base_gray = np.clip(base_gray * 0.42 + 8.0, 0.0, 255.0)
    overlay = np.repeat(base_gray[..., None], 3, axis=2).astype(np.float32)

    overlap = reference_mask & candidate_mask
    reference_missing = reference_mask & ~candidate_mask
    candidate_extra = candidate_mask & ~reference_mask
    green = (35, 225, 95)
    red = (255, 55, 55)
    blue = (45, 125, 255)
    _paint_overlay(overlay, overlap, green, 0.32)
    _paint_overlay(overlay, reference_missing, red, 0.62)
    _paint_overlay(overlay, candidate_extra, blue, 0.62)

    # A contour is considered matching when the other contour falls within the
    # exact same tolerance used by the numeric F1 metric.  Drawing both matched
    # edge positions in green keeps small anti-alias offsets visible without
    # falsely labelling them as geometry failures.
    reference_contour = _contour(reference_mask)
    candidate_contour = _contour(candidate_mask)
    reference_near_candidate = _dilate(candidate_contour, contour_tolerance)
    candidate_near_reference = _dilate(reference_contour, contour_tolerance)
    matching_contour = (
        (reference_contour & reference_near_candidate)
        | (candidate_contour & candidate_near_reference)
    )
    missing_contour = reference_contour & ~reference_near_candidate
    extra_contour = candidate_contour & ~candidate_near_reference

    # One-pixel dilation makes the diagnostic legible at normal UI zoom.  The
    # matching contour is painted last so overlap remains unambiguously green.
    _paint_overlay(overlay, _dilate(missing_contour, 1), red, 0.98)
    _paint_overlay(overlay, _dilate(extra_contour, 1), blue, 0.98)
    _paint_overlay(overlay, _dilate(matching_contour, 1), green, 0.98)

    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(np.rint(overlay), 0, 255).astype(np.uint8), mode="RGB").save(
        path
    )


def _bbox_iou(
    left: Iterable[int] | None, right: Iterable[int] | None
) -> float:
    if left is None or right is None:
        return 0.0
    lx0, ly0, lx1, ly1 = list(left)
    rx0, ry0, rx1, ry1 = list(right)
    intersection_width = max(0, min(lx1, rx1) - max(lx0, rx0) + 1)
    intersection_height = max(0, min(ly1, ry1) - max(ly0, ry0) + 1)
    intersection = intersection_width * intersection_height
    left_area = max(0, lx1 - lx0 + 1) * max(0, ly1 - ly0 + 1)
    right_area = max(0, rx1 - rx0 + 1) * max(0, ry1 - ry0 + 1)
    union = left_area + right_area - intersection
    return float(intersection / union if union else 0.0)


def _component_layout(
    reference: list[dict[str, Any]],
    candidate: list[dict[str, Any]],
    size: tuple[int, int],
) -> dict[str, Any]:
    if not reference or not candidate:
        return {
            "largest_bbox_iou": 0.0,
            "largest_centroid_distance_pixels": None,
            "largest_centroid_similarity": 0.0,
            "component_count_difference": abs(len(reference) - len(candidate)),
        }

    reference_main = reference[0]
    candidate_main = candidate[0]
    bbox_iou = _bbox_iou(
        reference_main["bbox_xyxy_inclusive"],
        candidate_main["bbox_xyxy_inclusive"],
    )
    rx, ry = reference_main["centroid_xy"]
    cx, cy = candidate_main["centroid_xy"]
    centroid_distance = math.hypot(rx - cx, ry - cy)
    diagonal = math.hypot(size[0], size[1])
    centroid_similarity = max(0.0, 1.0 - centroid_distance / max(diagonal, 1.0))
    return {
        "largest_bbox_iou": float(bbox_iou),
        "largest_centroid_distance_pixels": float(centroid_distance),
        "largest_centroid_similarity": float(centroid_similarity),
        "component_count_difference": abs(len(reference) - len(candidate)),
    }


def _robust_normalize(gray: np.ndarray) -> np.ndarray:
    low, high = np.percentile(gray, [1.0, 99.0])
    if high - low < 1e-6:
        return np.zeros_like(gray, dtype=np.float32)
    return np.clip((gray - low) / (high - low), 0.0, 1.0).astype(np.float32)


def _box_mean(values: np.ndarray, radius: int) -> np.ndarray:
    if radius <= 0:
        return values.astype(np.float32, copy=True)
    padded = np.pad(values, radius, mode="reflect")
    integral = np.pad(padded, ((1, 0), (1, 0)), mode="constant")
    integral = np.cumsum(np.cumsum(integral, axis=0), axis=1)
    width = 2 * radius + 1
    summed = (
        integral[width:, width:]
        - integral[:-width, width:]
        - integral[width:, :-width]
        + integral[:-width, :-width]
    )
    return (summed / float(width * width)).astype(np.float32)


def _appearance_metrics(
    reference_rgb: np.ndarray, candidate_rgb: np.ndarray
) -> dict[str, float]:
    reference_raw = _luminance(reference_rgb) / np.float32(255.0)
    candidate_raw = _luminance(candidate_rgb) / np.float32(255.0)
    raw_pixel_similarity = 1.0 - float(np.mean(np.abs(reference_raw - candidate_raw)))

    reference = _robust_normalize(reference_raw)
    candidate = _robust_normalize(candidate_raw)
    normalized_pixel_similarity = 1.0 - float(np.mean(np.abs(reference - candidate)))

    radius = max(1, round(min(reference.shape) * 0.006))
    reference_mean = _box_mean(reference, radius)
    candidate_mean = _box_mean(candidate, radius)
    reference_variance = np.maximum(
        0.0, _box_mean(reference * reference, radius) - reference_mean**2
    )
    candidate_variance = np.maximum(
        0.0, _box_mean(candidate * candidate, radius) - candidate_mean**2
    )
    covariance = (
        _box_mean(reference * candidate, radius)
        - reference_mean * candidate_mean
    )
    c1 = np.float32(0.01**2)
    c2 = np.float32(0.03**2)
    numerator = (2.0 * reference_mean * candidate_mean + c1) * (
        2.0 * covariance + c2
    )
    denominator = (
        reference_mean**2 + candidate_mean**2 + c1
    ) * (reference_variance + candidate_variance + c2)
    ssim_map = np.divide(
        numerator,
        denominator,
        out=np.zeros_like(numerator),
        where=np.abs(denominator) > 1e-12,
    )
    simplified_ssim = float(np.clip(ssim_map.mean(), -1.0, 1.0))
    return {
        "raw_pixel_similarity": float(np.clip(raw_pixel_similarity, 0.0, 1.0)),
        "normalized_pixel_similarity": float(
            np.clip(normalized_pixel_similarity, 0.0, 1.0)
        ),
        "simplified_ssim": simplified_ssim,
        "ssim_window_radius_pixels": radius,
    }


def compare(args: argparse.Namespace) -> dict[str, Any]:
    reference_path = args.reference.resolve()
    candidate_path = args.candidate.resolve()
    reference_original, reference_size = _load_rgb(reference_path)
    candidate_original, candidate_size = _load_rgb(candidate_path)
    size = _comparison_size(reference_size, args.max_dimension)
    reference_rgb = _resize_rgb(reference_original, size)
    candidate_rgb = _resize_rgb(candidate_original, size)

    (
        reference_mask,
        reference_threshold,
        reference_components,
        reference_removed,
        minimum_area,
    ) = _platform_mask(
        reference_rgb, args.max_saturation, args.minimum_component_ratio
    )
    (
        candidate_mask,
        candidate_threshold,
        candidate_components,
        candidate_removed,
        _,
    ) = _platform_mask(
        candidate_rgb, args.max_saturation, args.minimum_component_ratio
    )

    overlap = _mask_overlap(reference_mask, candidate_mask)
    tolerance = (
        args.contour_tolerance
        if args.contour_tolerance is not None
        else max(1, round(min(size) * 0.004))
    )
    contour = _contour_metrics(reference_mask, candidate_mask, tolerance)
    layout = _component_layout(reference_components, candidate_components, size)
    appearance = _appearance_metrics(reference_rgb, candidate_rgb)

    criteria = {
        "platform_mask_iou": float(overlap["iou"]),
        "contour_f1": float(contour["f1"]),
        "largest_component_bbox_iou": float(layout["largest_bbox_iou"]),
        "largest_component_centroid_similarity": float(
            layout["largest_centroid_similarity"]
        ),
    }
    # The minimum makes the gate auditable and non-compensatory.  For example,
    # matching only the bounding box cannot hide an incorrect central opening.
    geometry_score = min(criteria.values())
    criterion_pass = {
        name: score >= args.threshold for name, score in criteria.items()
    }

    result = {
        "reference": {
            "path": str(reference_path),
            "original_size": list(reference_size),
            "platform_otsu_threshold": reference_threshold,
            "bright_component_count": len(reference_components),
            "discarded_tiny_component_count": reference_removed,
        },
        "candidate": {
            "path": str(candidate_path),
            "original_size": list(candidate_size),
            "platform_otsu_threshold": candidate_threshold,
            "bright_component_count": len(candidate_components),
            "discarded_tiny_component_count": candidate_removed,
        },
        "comparison": {
            "size": list(size),
            "resize_policy": "both images resampled directly to the reference canvas; no registration or crop",
            "max_saturation": args.max_saturation,
            "minimum_component_area_pixels": minimum_area,
        },
        "platform_mask": overlap,
        "contour": contour,
        "component_layout": layout,
        "bright_components": {
            "reference": reference_components[: args.max_components],
            "candidate": candidate_components[: args.max_components],
        },
        "appearance": appearance,
        "geometry_gate": {
            "threshold": args.threshold,
            "score": float(geometry_score),
            "passed": bool(all(criterion_pass.values())),
            "rule": "all criteria must meet threshold; score is their minimum",
            "criteria": criteria,
            "criterion_pass": criterion_pass,
        },
        "implementation": {
            "required_dependencies": ["Pillow", "NumPy"],
            "component_backend": "NumPy run-length union-find (8-connected)",
            "contour_backend": "NumPy morphology and chunked nearest-neighbor",
        },
    }
    if args.overlay_out is not None:
        overlay_path = args.overlay_out.resolve()
        _write_difference_overlay(
            overlay_path,
            reference_rgb,
            candidate_rgb,
            reference_mask,
            candidate_mask,
            tolerance,
        )
        result["overlay"] = {
            "path": str(overlay_path),
            "size": list(size),
            "legend": {
                "green": "reference/candidate overlap or contour match",
                "red": "present in reference, missing from candidate",
                "blue": "extra in candidate",
            },
        }
    return result


def _percent(value: float) -> str:
    return f"{value * 100.0:7.3f}%"


def _print_text(result: dict[str, Any]) -> None:
    reference = result["reference"]
    candidate = result["candidate"]
    comparison = result["comparison"]
    overlap = result["platform_mask"]
    contour = result["contour"]
    layout = result["component_layout"]
    appearance = result["appearance"]
    gate = result["geometry_gate"]

    print("Twin Bays reference comparison")
    print(f"Reference : {reference['path']} ({reference['original_size'][0]}x{reference['original_size'][1]})")
    print(f"Candidate : {candidate['path']} ({candidate['original_size'][0]}x{candidate['original_size'][1]})")
    print(f"Canvas    : {comparison['size'][0]}x{comparison['size'][1]} (reference framing; no registration)")
    if "overlay" in result:
        print(f"Overlay   : {result['overlay']['path']}")
    print(
        "Masks     : "
        f"Otsu ref={reference['platform_otsu_threshold']}, "
        f"candidate={candidate['platform_otsu_threshold']}, "
        f"neutral saturation <= {comparison['max_saturation']:.2f}"
    )
    print()
    print("Geometry criteria")
    print(f"  Platform mask IoU       {_percent(overlap['iou'])}")
    print(f"  Platform mask Dice      {_percent(overlap['dice'])}")
    print(
        f"  Contour F1 (+/-{contour['tolerance_pixels']} px)  "
        f"{_percent(contour['f1'])} "
        f"(P={_percent(contour['precision']).strip()}, "
        f"R={_percent(contour['recall']).strip()})"
    )
    chamfer = contour["symmetric_chamfer_pixels"]
    print(
        "  Symmetric chamfer       "
        + (f"{chamfer:7.3f} px" if chamfer is not None else "n/a")
    )
    print(f"  Largest-component bbox  {_percent(layout['largest_bbox_iou'])}")
    print(
        f"  Largest centroid        {_percent(layout['largest_centroid_similarity'])} "
        f"({layout['largest_centroid_distance_pixels']:.3f} px apart)"
        if layout["largest_centroid_distance_pixels"] is not None
        else "  Largest centroid        n/a"
    )
    print()
    print("Appearance diagnostics (not used to rescue the geometry gate)")
    print(f"  Normalized pixel sim.    {_percent(appearance['normalized_pixel_similarity'])}")
    print(f"  Simplified local SSIM    {_percent(max(0.0, appearance['simplified_ssim']))}")
    print(f"  Raw pixel similarity     {_percent(appearance['raw_pixel_similarity'])}")
    print()
    state = "PASS" if gate["passed"] else "FAIL"
    print(
        f"98% geometry gate: {state} -- score {_percent(gate['score'])}, "
        f"required {_percent(gate['threshold'])} for every criterion"
    )


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Compare the Twin Bays Godot render to its reference using a strict "
            "neutral-platform mask and contour geometry gate."
        )
    )
    parser.add_argument(
        "candidate",
        nargs="?",
        type=Path,
        default=DEFAULT_CANDIDATE,
        help=f"candidate screenshot (default: {DEFAULT_CANDIDATE})",
    )
    parser.add_argument(
        "--reference",
        type=Path,
        default=DEFAULT_REFERENCE,
        help=f"reference image (default: {DEFAULT_REFERENCE})",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.98,
        help="required value for every geometry criterion (default: 0.98)",
    )
    parser.add_argument(
        "--max-dimension",
        type=int,
        default=1024,
        help="maximum comparison-canvas dimension; 0 keeps reference size (default: 1024)",
    )
    parser.add_argument(
        "--max-saturation",
        type=float,
        default=0.45,
        help="exclude saturated portal/pad colors from the platform mask (default: 0.45)",
    )
    parser.add_argument(
        "--minimum-component-ratio",
        type=float,
        default=0.00005,
        help="discard bright specks below this canvas-area ratio (default: 0.00005)",
    )
    parser.add_argument(
        "--contour-tolerance",
        type=int,
        default=None,
        help="contour matching radius in pixels (default: 0.4%% of canvas short side)",
    )
    parser.add_argument(
        "--max-components",
        type=int,
        default=12,
        help="maximum bright component descriptors included in output (default: 12)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit machine-readable JSON instead of the text report",
    )
    parser.add_argument(
        "--overlay-out",
        type=Path,
        default=None,
        metavar="PATH",
        help=(
            "write a same-canvas mask/contour overlay: green=match, "
            "red=missing reference geometry, blue=candidate extra"
        ),
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="return exit status 1 when the geometry gate fails (for CI/automation)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    if not 0.0 <= args.threshold <= 1.0:
        parser.error("--threshold must be between 0 and 1")
    if not 0.0 <= args.max_saturation <= 1.0:
        parser.error("--max-saturation must be between 0 and 1")
    if args.max_dimension < 0:
        parser.error("--max-dimension must be non-negative")
    if not 0.0 <= args.minimum_component_ratio <= 1.0:
        parser.error("--minimum-component-ratio must be between 0 and 1")
    if args.contour_tolerance is not None and args.contour_tolerance < 0:
        parser.error("--contour-tolerance must be non-negative")
    if args.max_components <= 0:
        parser.error("--max-components must be positive")

    try:
        result = compare(args)
    except (FileNotFoundError, OSError, ValueError) as error:
        if args.json:
            print(json.dumps({"error": str(error)}, ensure_ascii=False))
        else:
            print(f"error: {error}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        _print_text(result)
    if args.strict and not result["geometry_gate"]["passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
