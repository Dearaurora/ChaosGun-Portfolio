#!/usr/bin/env python3
"""Strict, map-specific visual acceptance gate for Momentum Circuit.

The comparison intentionally uses the frozen extraction contract rather than
generic image similarity:

* OpenCV HSV neutral mask with V >= 180 and S <= 50.
* A 17 px elliptical morphological close.
* The largest external contour minus its three largest direct children forms
  the platform bulk mask. Smaller cover/pad children are intentionally ignored.
* The hard geometry gate is bulk-mask IoU >= 0.95 with exact 1-outer/3-hole
  topology. Contour, bounding-box, and centroid values are diagnostics only.
* Four cyan and three amber components are hard-checked separately so a good
  platform silhouette cannot hide misplaced mechanisms.

Images are compared on their original, identical canvas with no registration,
crop, translation, or scale fitting.
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import sys
from pathlib import Path
from typing import Any, Sequence

import cv2
import numpy as np


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE = (
    REPO_ROOT
    / "docs"
    / "art-direction"
    / "references"
    / "map_concepts_round2"
    / "concept_d_folded_ribbon_circuit.png"
)
DEFAULT_CANDIDATE = REPO_ROOT / "reports" / "momentum_circuit_whitebox.png"

NEUTRAL_MIN_VALUE = 180
NEUTRAL_MAX_SATURATION = 50
CLOSE_KERNEL_SIZE = 17
MINIMUM_COLOUR_COMPONENT_AREA_PX = 100

CYAN_HSV_LOWER = (75, 60, 140)
CYAN_HSV_UPPER = (105, 255, 255)
AMBER_HSV_LOWER = (5, 70, 130)
AMBER_HSV_UPPER = (30, 255, 255)

EXPECTED_CYAN_COUNT = 4
EXPECTED_AMBER_COUNT = 3
DEFAULT_THRESHOLD = 0.95
FEATURE_TOLERANCE_SHORT_SIDE_RATIO = 0.012
CONTOUR_TOLERANCE_SHORT_SIDE_RATIO = 0.004


class ComparisonError(RuntimeError):
    """Raised when an input cannot participate in an exact-frame comparison."""


def _load_bgr(path: Path) -> np.ndarray:
    resolved = path.resolve()
    if not resolved.is_file():
        raise ComparisonError(f"image not found: {resolved}")
    image = cv2.imread(str(resolved), cv2.IMREAD_COLOR)
    if image is None:
        raise ComparisonError(f"OpenCV could not decode image: {resolved}")
    return image


def _neutral_closed_mask(hsv: np.ndarray) -> np.ndarray:
    mask = cv2.inRange(
        hsv,
        (0, 0, NEUTRAL_MIN_VALUE),
        (179, NEUTRAL_MAX_SATURATION, 255),
    )
    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE,
        (CLOSE_KERNEL_SIZE, CLOSE_KERNEL_SIZE),
    )
    return cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)


def _mask_topology(mask: np.ndarray) -> dict[str, int]:
    foreground_count, _ = cv2.connectedComponents(
        (mask > 0).astype(np.uint8), connectivity=8
    )
    contours, hierarchy = cv2.findContours(
        mask, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_SIMPLE
    )
    if hierarchy is None or not contours:
        return {"outer_components": max(0, foreground_count - 1), "holes": 0}
    rows = hierarchy[0]
    return {
        "outer_components": sum(1 for row in rows if int(row[3]) == -1),
        "holes": sum(1 for row in rows if int(row[3]) != -1),
    }


def _bulk_platform(hsv: np.ndarray) -> dict[str, Any]:
    neutral = _neutral_closed_mask(hsv)
    contours, hierarchy = cv2.findContours(
        neutral, cv2.RETR_TREE, cv2.CHAIN_APPROX_NONE
    )
    bulk = np.zeros(neutral.shape, dtype=np.uint8)
    if hierarchy is None or not contours:
        return {
            "mask": bulk,
            "neutral_mask": neutral,
            "raw_external_count": 0,
            "direct_child_count": 0,
            "selected_hole_count": 0,
            "selected_hole_areas_px2": [],
            "topology": _mask_topology(bulk),
        }

    tree = hierarchy[0]
    external_indices = [index for index, row in enumerate(tree) if int(row[3]) == -1]
    if not external_indices:
        return {
            "mask": bulk,
            "neutral_mask": neutral,
            "raw_external_count": 0,
            "direct_child_count": 0,
            "selected_hole_count": 0,
            "selected_hole_areas_px2": [],
            "topology": _mask_topology(bulk),
        }

    outer_index = max(
        external_indices, key=lambda index: cv2.contourArea(contours[index])
    )
    direct_children = [
        index for index, row in enumerate(tree) if int(row[3]) == outer_index
    ]
    selected_holes = sorted(
        direct_children,
        key=lambda index: cv2.contourArea(contours[index]),
        reverse=True,
    )[:3]

    cv2.fillPoly(bulk, [contours[outer_index]], 255)
    if selected_holes:
        cv2.fillPoly(bulk, [contours[index] for index in selected_holes], 0)
    return {
        "mask": bulk,
        "neutral_mask": neutral,
        "raw_external_count": len(external_indices),
        "direct_child_count": len(direct_children),
        "selected_hole_count": len(selected_holes),
        "selected_hole_areas_px2": [
            float(cv2.contourArea(contours[index])) for index in selected_holes
        ],
        "topology": _mask_topology(bulk),
    }


def _component_records(
    hsv: np.ndarray,
    lower: tuple[int, int, int],
    upper: tuple[int, int, int],
) -> list[dict[str, Any]]:
    mask = cv2.inRange(hsv, lower, upper)
    count, _, stats, centroids = cv2.connectedComponentsWithStats(
        mask, connectivity=8
    )
    records: list[dict[str, Any]] = []
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        if area < MINIMUM_COLOUR_COMPONENT_AREA_PX:
            continue
        records.append(
            {
                "area_px": area,
                "center_xy_px": [
                    float(centroids[label, 0]),
                    float(centroids[label, 1]),
                ],
                "bounds_xywh_px": [
                    int(stats[label, cv2.CC_STAT_LEFT]),
                    int(stats[label, cv2.CC_STAT_TOP]),
                    int(stats[label, cv2.CC_STAT_WIDTH]),
                    int(stats[label, cv2.CC_STAT_HEIGHT]),
                ],
            }
        )
    records.sort(key=lambda item: (item["center_xy_px"][1], item["center_xy_px"][0]))
    return records


def _optimal_center_match(
    reference: Sequence[dict[str, Any]],
    candidate: Sequence[dict[str, Any]],
) -> dict[str, Any]:
    if len(reference) != len(candidate) or not reference:
        return {"matches": [], "maximum_error_px": None, "mean_error_px": None}

    best_key: tuple[float, float] | None = None
    best_matches: list[dict[str, Any]] = []
    for permutation in itertools.permutations(range(len(candidate))):
        matches: list[dict[str, Any]] = []
        distances: list[float] = []
        for reference_index, candidate_index in enumerate(permutation):
            reference_center = reference[reference_index]["center_xy_px"]
            candidate_center = candidate[candidate_index]["center_xy_px"]
            distance = math.hypot(
                float(reference_center[0]) - float(candidate_center[0]),
                float(reference_center[1]) - float(candidate_center[1]),
            )
            distances.append(distance)
            matches.append(
                {
                    "reference_index": reference_index,
                    "candidate_index": candidate_index,
                    "reference_center_xy_px": list(reference_center),
                    "candidate_center_xy_px": list(candidate_center),
                    "error_px": float(distance),
                }
            )
        key = (max(distances), sum(distances))
        if best_key is None or key < best_key:
            best_key = key
            best_matches = matches

    errors = [float(match["error_px"]) for match in best_matches]
    return {
        "matches": best_matches,
        "maximum_error_px": max(errors),
        "mean_error_px": sum(errors) / len(errors),
    }


def _mask_overlap(reference: np.ndarray, candidate: np.ndarray) -> dict[str, Any]:
    reference_on = reference > 0
    candidate_on = candidate > 0
    intersection = int(np.count_nonzero(reference_on & candidate_on))
    union = int(np.count_nonzero(reference_on | candidate_on))
    reference_pixels = int(np.count_nonzero(reference_on))
    candidate_pixels = int(np.count_nonzero(candidate_on))
    denominator = reference_pixels + candidate_pixels
    return {
        "reference_pixels": reference_pixels,
        "candidate_pixels": candidate_pixels,
        "intersection_pixels": intersection,
        "union_pixels": union,
        "iou": float(intersection / union) if union else 0.0,
        "dice": float(2 * intersection / denominator) if denominator else 0.0,
    }


def _inside_contour(mask: np.ndarray) -> np.ndarray:
    kernel = np.ones((3, 3), dtype=np.uint8)
    eroded = cv2.erode((mask > 0).astype(np.uint8), kernel, iterations=1)
    return (mask > 0) & (eroded == 0)


def _dilate(binary: np.ndarray, radius: int) -> np.ndarray:
    if radius <= 0:
        return binary.copy()
    width = radius * 2 + 1
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (width, width))
    return cv2.dilate(binary.astype(np.uint8), kernel, iterations=1) > 0


def _mean_distance(source: np.ndarray, target: np.ndarray) -> float | None:
    if not np.any(source) or not np.any(target):
        return None
    # distanceTransform returns distance to the nearest zero pixel.
    distance_field = cv2.distanceTransform(
        (~target).astype(np.uint8), cv2.DIST_L2, cv2.DIST_MASK_PRECISE
    )
    return float(distance_field[source].mean())


def _contour_diagnostics(
    reference_mask: np.ndarray,
    candidate_mask: np.ndarray,
    tolerance_px: int,
) -> dict[str, Any]:
    reference = _inside_contour(reference_mask)
    candidate = _inside_contour(candidate_mask)
    reference_count = int(np.count_nonzero(reference))
    candidate_count = int(np.count_nonzero(candidate))
    if reference_count and candidate_count:
        candidate_matches = int(np.count_nonzero(candidate & _dilate(reference, tolerance_px)))
        reference_matches = int(np.count_nonzero(reference & _dilate(candidate, tolerance_px)))
        precision = candidate_matches / candidate_count
        recall = reference_matches / reference_count
        f1 = 2.0 * precision * recall / (precision + recall) if precision + recall else 0.0
    else:
        precision = recall = f1 = 0.0
    ref_to_candidate = _mean_distance(reference, candidate)
    candidate_to_ref = _mean_distance(candidate, reference)
    chamfer = (
        (ref_to_candidate + candidate_to_ref) * 0.5
        if ref_to_candidate is not None and candidate_to_ref is not None
        else None
    )
    return {
        "tolerance_px": tolerance_px,
        "reference_contour_pixels": reference_count,
        "candidate_contour_pixels": candidate_count,
        "precision": float(precision),
        "recall": float(recall),
        "f1": float(f1),
        "symmetric_chamfer_px": float(chamfer) if chamfer is not None else None,
        "gate_role": "diagnostic_only",
    }


def _mask_bounds(mask: np.ndarray) -> list[int] | None:
    y_values, x_values = np.nonzero(mask > 0)
    if not len(x_values):
        return None
    return [
        int(x_values.min()),
        int(y_values.min()),
        int(x_values.max()),
        int(y_values.max()),
    ]


def _bbox_iou(left: Sequence[int] | None, right: Sequence[int] | None) -> float:
    if left is None or right is None:
        return 0.0
    lx0, ly0, lx1, ly1 = left
    rx0, ry0, rx1, ry1 = right
    width = max(0, min(lx1, rx1) - max(lx0, rx0) + 1)
    height = max(0, min(ly1, ry1) - max(ly0, ry0) + 1)
    intersection = width * height
    left_area = (lx1 - lx0 + 1) * (ly1 - ly0 + 1)
    right_area = (rx1 - rx0 + 1) * (ry1 - ry0 + 1)
    union = left_area + right_area - intersection
    return float(intersection / union) if union else 0.0


def _mask_centroid(mask: np.ndarray) -> list[float] | None:
    moments = cv2.moments((mask > 0).astype(np.uint8), binaryImage=True)
    if abs(float(moments["m00"])) < 1e-9:
        return None
    return [
        float(moments["m10"] / moments["m00"]),
        float(moments["m01"] / moments["m00"]),
    ]


def _layout_diagnostics(
    reference_mask: np.ndarray, candidate_mask: np.ndarray
) -> dict[str, Any]:
    reference_bbox = _mask_bounds(reference_mask)
    candidate_bbox = _mask_bounds(candidate_mask)
    reference_center = _mask_centroid(reference_mask)
    candidate_center = _mask_centroid(candidate_mask)
    center_distance = None
    if reference_center is not None and candidate_center is not None:
        center_distance = math.hypot(
            reference_center[0] - candidate_center[0],
            reference_center[1] - candidate_center[1],
        )
    return {
        "reference_bbox_xyxy_inclusive": reference_bbox,
        "candidate_bbox_xyxy_inclusive": candidate_bbox,
        "bbox_iou": _bbox_iou(reference_bbox, candidate_bbox),
        "reference_centroid_xy_px": reference_center,
        "candidate_centroid_xy_px": candidate_center,
        "centroid_error_px": float(center_distance) if center_distance is not None else None,
        "gate_role": "diagnostic_only",
    }


def _topology_pass(extraction: dict[str, Any]) -> bool:
    topology = extraction["topology"]
    return bool(
        extraction["selected_hole_count"] == 3
        and topology["outer_components"] == 1
        and topology["holes"] == 3
    )


def _feature_result(
    reference: list[dict[str, Any]],
    candidate: list[dict[str, Any]],
    expected_count: int,
    tolerance_px: float,
) -> dict[str, Any]:
    matching = _optimal_center_match(reference, candidate)
    count_pass = len(reference) == expected_count and len(candidate) == expected_count
    maximum_error = matching["maximum_error_px"]
    center_pass = bool(maximum_error is not None and maximum_error <= tolerance_px)
    return {
        "expected_count": expected_count,
        "reference_count": len(reference),
        "candidate_count": len(candidate),
        "count_pass": count_pass,
        "center_tolerance_px": tolerance_px,
        "center_tolerance_rule": (
            "1.2% of the canvas short side (12px at 1536x1024, about one third "
            "of the smallest 34px reference component width), unless explicitly overridden"
        ),
        **matching,
        "center_pass": center_pass,
        "passed": bool(count_pass and center_pass),
        "reference_components": reference,
        "candidate_components": candidate,
    }


def _blend_mask(
    image: np.ndarray,
    mask: np.ndarray,
    bgr: tuple[int, int, int],
    alpha: float,
) -> None:
    if not np.any(mask):
        return
    color = np.asarray(bgr, dtype=np.float32)
    pixels = image[mask].astype(np.float32)
    image[mask] = np.clip(pixels * (1.0 - alpha) + color * alpha, 0, 255).astype(
        np.uint8
    )


def _draw_feature_matches(
    overlay: np.ndarray,
    feature: dict[str, Any],
    bgr: tuple[int, int, int],
) -> None:
    for match in feature["matches"]:
        reference_center = tuple(
            int(round(value)) for value in match["reference_center_xy_px"]
        )
        candidate_center = tuple(
            int(round(value)) for value in match["candidate_center_xy_px"]
        )
        cv2.line(overlay, reference_center, candidate_center, bgr, 2, cv2.LINE_AA)
        cv2.drawMarker(
            overlay,
            reference_center,
            (255, 255, 255),
            cv2.MARKER_CROSS,
            13,
            2,
            cv2.LINE_AA,
        )
        cv2.circle(overlay, candidate_center, 7, bgr, 2, cv2.LINE_AA)


def _write_overlay(
    path: Path,
    reference_bgr: np.ndarray,
    candidate_bgr: np.ndarray,
    reference_mask: np.ndarray,
    candidate_mask: np.ndarray,
    cyan: dict[str, Any],
    amber: dict[str, Any],
) -> None:
    base = cv2.addWeighted(reference_bgr, 0.5, candidate_bgr, 0.5, 0.0)
    gray = cv2.cvtColor(base, cv2.COLOR_BGR2GRAY)
    overlay = cv2.cvtColor((gray * 0.42).astype(np.uint8), cv2.COLOR_GRAY2BGR)
    reference_on = reference_mask > 0
    candidate_on = candidate_mask > 0
    _blend_mask(overlay, reference_on & candidate_on, (70, 205, 80), 0.34)
    _blend_mask(overlay, reference_on & ~candidate_on, (45, 45, 255), 0.72)
    _blend_mask(overlay, candidate_on & ~reference_on, (255, 120, 35), 0.72)
    _draw_feature_matches(overlay, cyan, (255, 220, 50))
    _draw_feature_matches(overlay, amber, (40, 180, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    if not cv2.imwrite(str(path), overlay):
        raise ComparisonError(f"could not write overlay: {path}")


def compare(args: argparse.Namespace) -> dict[str, Any]:
    reference_path = args.reference.resolve()
    candidate_path = args.candidate.resolve()
    reference_bgr = _load_bgr(reference_path)
    candidate_bgr = _load_bgr(candidate_path)
    if reference_bgr.shape != candidate_bgr.shape:
        reference_size = [reference_bgr.shape[1], reference_bgr.shape[0]]
        candidate_size = [candidate_bgr.shape[1], candidate_bgr.shape[0]]
        raise ComparisonError(
            "exact-frame comparison requires identical image dimensions: "
            f"reference={reference_size}, candidate={candidate_size}"
        )

    height, width = reference_bgr.shape[:2]
    reference_hsv = cv2.cvtColor(reference_bgr, cv2.COLOR_BGR2HSV)
    candidate_hsv = cv2.cvtColor(candidate_bgr, cv2.COLOR_BGR2HSV)
    reference_bulk = _bulk_platform(reference_hsv)
    candidate_bulk = _bulk_platform(candidate_hsv)
    overlap = _mask_overlap(reference_bulk["mask"], candidate_bulk["mask"])

    contour_tolerance = (
        args.contour_tolerance
        if args.contour_tolerance is not None
        else max(1, round(min(width, height) * CONTOUR_TOLERANCE_SHORT_SIDE_RATIO))
    )
    feature_tolerance = (
        args.feature_center_tolerance
        if args.feature_center_tolerance is not None
        else max(4.0, float(round(min(width, height) * FEATURE_TOLERANCE_SHORT_SIDE_RATIO)))
    )

    reference_cyan = _component_records(
        reference_hsv, CYAN_HSV_LOWER, CYAN_HSV_UPPER
    )
    candidate_cyan = _component_records(
        candidate_hsv, CYAN_HSV_LOWER, CYAN_HSV_UPPER
    )
    reference_amber = _component_records(
        reference_hsv, AMBER_HSV_LOWER, AMBER_HSV_UPPER
    )
    candidate_amber = _component_records(
        candidate_hsv, AMBER_HSV_LOWER, AMBER_HSV_UPPER
    )
    cyan_result = _feature_result(
        reference_cyan,
        candidate_cyan,
        EXPECTED_CYAN_COUNT,
        feature_tolerance,
    )
    amber_result = _feature_result(
        reference_amber,
        candidate_amber,
        EXPECTED_AMBER_COUNT,
        feature_tolerance,
    )

    reference_topology_pass = _topology_pass(reference_bulk)
    candidate_topology_pass = _topology_pass(candidate_bulk)
    hard_checks = {
        "bulk_iou": bool(overlap["iou"] >= args.threshold),
        "reference_topology_1_outer_3_holes": reference_topology_pass,
        "candidate_topology_1_outer_3_holes": candidate_topology_pass,
        "cyan_4_count_and_centers": bool(cyan_result["passed"]),
        "amber_3_count_and_centers": bool(amber_result["passed"]),
    }

    result: dict[str, Any] = {
        "reference": {
            "path": str(reference_path),
            "size_px": [width, height],
        },
        "candidate": {
            "path": str(candidate_path),
            "size_px": [width, height],
        },
        "comparison": {
            "framing_policy": "original identical canvas; no registration, crop, translation, or scale fitting",
            "neutral_hsv": {
                "minimum_value": NEUTRAL_MIN_VALUE,
                "maximum_saturation": NEUTRAL_MAX_SATURATION,
            },
            "morphological_close": {
                "shape": "ellipse",
                "kernel_size_px": [CLOSE_KERNEL_SIZE, CLOSE_KERNEL_SIZE],
            },
            "bulk_mask_rule": "largest external contour minus its three largest direct children",
            "ignored_for_bulk_mask": "smaller cover, portal, and mechanism child holes",
            "colour_component_minimum_area_px": MINIMUM_COLOUR_COMPONENT_AREA_PX,
        },
        "bulk_platform": {
            "overlap": overlap,
            "reference_extraction": {
                key: value
                for key, value in reference_bulk.items()
                if key not in {"mask", "neutral_mask"}
            },
            "candidate_extraction": {
                key: value
                for key, value in candidate_bulk.items()
                if key not in {"mask", "neutral_mask"}
            },
            "threshold": args.threshold,
            "passed": hard_checks["bulk_iou"],
        },
        "features": {
            "cyan_portals": cyan_result,
            "amber_shockwave_nodes": amber_result,
        },
        "diagnostics": {
            "contour": _contour_diagnostics(
                reference_bulk["mask"], candidate_bulk["mask"], contour_tolerance
            ),
            "layout": _layout_diagnostics(
                reference_bulk["mask"], candidate_bulk["mask"]
            ),
        },
        "acceptance_gate": {
            "threshold": args.threshold,
            "hard_checks": hard_checks,
            "passed": bool(all(hard_checks.values())),
            "rule": (
                "non-compensatory: bulk IoU must meet threshold, both bulk masks "
                "must have 1 outer component and 3 holes, and exact cyan/amber "
                "counts and center tolerances must pass"
            ),
        },
    }

    if args.overlay_out is not None:
        overlay_path = args.overlay_out.resolve()
        _write_overlay(
            overlay_path,
            reference_bgr,
            candidate_bgr,
            reference_bulk["mask"],
            candidate_bulk["mask"],
            cyan_result,
            amber_result,
        )
        result["overlay"] = {
            "path": str(overlay_path),
            "legend": {
                "green_fill": "bulk-mask overlap",
                "red_fill": "reference bulk missing from candidate",
                "blue_fill": "candidate bulk extra",
                "white_cross": "reference feature center",
                "colored_circle": "matched candidate feature center",
            },
        }
    return result


def _percent(value: float) -> str:
    return f"{value * 100.0:7.3f}%"


def _feature_text(label: str, feature: dict[str, Any]) -> str:
    maximum_error = feature["maximum_error_px"]
    error_text = f"{maximum_error:.3f}px" if maximum_error is not None else "n/a"
    state = "PASS" if feature["passed"] else "FAIL"
    return (
        f"  {label:<19} {state}  count "
        f"{feature['candidate_count']}/{feature['expected_count']}, "
        f"max center error {error_text} <= {feature['center_tolerance_px']:.3f}px"
    )


def _print_text(result: dict[str, Any]) -> None:
    reference = result["reference"]
    candidate = result["candidate"]
    bulk = result["bulk_platform"]
    overlap = bulk["overlap"]
    reference_extraction = bulk["reference_extraction"]
    candidate_extraction = bulk["candidate_extraction"]
    contour = result["diagnostics"]["contour"]
    layout = result["diagnostics"]["layout"]
    gate = result["acceptance_gate"]

    print("Momentum Circuit reference comparison")
    print(
        f"Reference : {reference['path']} "
        f"({reference['size_px'][0]}x{reference['size_px'][1]})"
    )
    print(
        f"Candidate : {candidate['path']} "
        f"({candidate['size_px'][0]}x{candidate['size_px'][1]})"
    )
    print("Framing   : exact original canvas; no registration or crop")
    if "overlay" in result:
        print(f"Overlay   : {result['overlay']['path']}")
    print()
    print("Hard geometry gate")
    print(f"  Bulk mask IoU       {_percent(overlap['iou'])}  required {_percent(bulk['threshold'])}")
    print(f"  Bulk mask Dice      {_percent(overlap['dice'])}")
    print(
        "  Reference topology  "
        f"outer={reference_extraction['topology']['outer_components']}, "
        f"holes={reference_extraction['topology']['holes']}"
    )
    print(
        "  Candidate topology  "
        f"outer={candidate_extraction['topology']['outer_components']}, "
        f"holes={candidate_extraction['topology']['holes']}"
    )
    print()
    print("Hard feature gate")
    print(_feature_text("Cyan portals", result["features"]["cyan_portals"]))
    print(
        _feature_text(
            "Amber mechanisms",
            result["features"]["amber_shockwave_nodes"],
        )
    )
    print()
    print("Diagnostics only")
    print(
        f"  Contour F1 (+/-{contour['tolerance_px']}px)  "
        f"{_percent(contour['f1'])} "
        f"(P={_percent(contour['precision']).strip()}, "
        f"R={_percent(contour['recall']).strip()})"
    )
    chamfer = contour["symmetric_chamfer_px"]
    print(
        "  Symmetric chamfer   "
        + (f"{chamfer:.3f}px" if chamfer is not None else "n/a")
    )
    print(f"  Bulk bounding box   {_percent(layout['bbox_iou'])}")
    centroid_error = layout["centroid_error_px"]
    print(
        "  Bulk centroid error "
        + (f"{centroid_error:.3f}px" if centroid_error is not None else "n/a")
    )
    print()
    state = "PASS" if gate["passed"] else "FAIL"
    print(f"95% Momentum Circuit acceptance gate: {state}")
    for name, passed in gate["hard_checks"].items():
        print(f"  [{'x' if passed else ' '}] {name}")


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Compare a Momentum Circuit Godot capture to its frozen reference "
            "using a 95% bulk-mask and feature-position acceptance gate."
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
        help=f"frozen reference image (default: {DEFAULT_REFERENCE})",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_THRESHOLD,
        help="required bulk-mask IoU (default: 0.95)",
    )
    parser.add_argument(
        "--feature-center-tolerance",
        type=float,
        default=None,
        help=(
            "maximum feature-center error in pixels; default is 1.2%% of the "
            "canvas short side (12px at 1536x1024)"
        ),
    )
    parser.add_argument(
        "--contour-tolerance",
        type=int,
        default=None,
        help="diagnostic contour radius; default is 0.4%% of the canvas short side",
    )
    parser.add_argument(
        "--overlay-out",
        type=Path,
        default=None,
        metavar="PATH",
        help="write a bulk-mask and feature-center diagnostic overlay",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="emit machine-readable JSON",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="return exit status 1 when any hard acceptance check fails",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    if not 0.0 <= args.threshold <= 1.0:
        parser.error("--threshold must be between 0 and 1")
    if args.feature_center_tolerance is not None and args.feature_center_tolerance < 0.0:
        parser.error("--feature-center-tolerance must be non-negative")
    if args.contour_tolerance is not None and args.contour_tolerance < 0:
        parser.error("--contour-tolerance must be non-negative")

    try:
        result = compare(args)
    except (ComparisonError, OSError, ValueError) as error:
        if args.json:
            print(json.dumps({"error": str(error)}, ensure_ascii=False))
        else:
            print(f"error: {error}", file=sys.stderr)
        return 2

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        _print_text(result)
    if args.strict and not result["acceptance_gate"]["passed"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
