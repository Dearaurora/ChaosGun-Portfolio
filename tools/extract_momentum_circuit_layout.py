#!/usr/bin/env python3
"""Extract the Momentum Circuit whitebox layout from its frozen reference.

The extractor intentionally implements the art-direction contract literally:

* OpenCV HSV neutral mask: V >= 180 and S <= 50.
* 17 px elliptical morphological close.
* Largest external contour, with its three largest direct children as voids.
* Contours simplified at 2.5 px while preserving the extracted topology.
* Cyan/orange pad centres found from HSV connected components.
* Remaining direct children become the nine cover groups.

Running the script with no arguments regenerates
``resources/maps/momentum_circuit_layout_v1.json``.  ``--check`` validates that
the committed JSON is byte-for-byte equivalent to a fresh extraction without
rewriting it.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any, Iterable, Sequence

import cv2
import numpy as np


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = (
    REPO_ROOT
    / "docs"
    / "art-direction"
    / "references"
    / "map_concepts_round2"
    / "concept_d_folded_ribbon_circuit.png"
)
DEFAULT_OUTPUT = REPO_ROOT / "resources" / "maps" / "momentum_circuit_layout_v1.json"

SOURCE_WIDTH = 1536
SOURCE_HEIGHT = 1024
SCREEN_CENTER_X = 768.0
SCREEN_CENTER_Y = 512.0
WORLD_UNITS_PER_PIXEL = 0.08
CAMERA_ELEVATION_DEGREES = 55.0
CAMERA_YAW_DEGREES = 0.0
ELEVATION_SINE = math.sin(math.radians(CAMERA_ELEVATION_DEGREES))
ELEVATION_COSINE = math.cos(math.radians(CAMERA_ELEVATION_DEGREES))
WORLD_Z_PER_PIXEL = WORLD_UNITS_PER_PIXEL / ELEVATION_SINE
PLATFORM_TOP_Y = 1.0
PLATFORM_DEPTH = 4.0
VISUAL_DEPTH_PROJECTION_PX = int(
    round(PLATFORM_DEPTH * ELEVATION_COSINE / WORLD_UNITS_PER_PIXEL)
)
SPAWN_Y = 1.1
SPAWN_INWARD_OFFSET = 7.0

NEUTRAL_MIN_VALUE = 180
NEUTRAL_MAX_SATURATION = 50
CLOSE_KERNEL_SIZE = 17
SIMPLIFY_EPSILON_PX = 2.5
MINIMUM_COLOUR_COMPONENT_AREA_PX = 100
MINIMUM_RECONSTRUCTION_IOU = 0.98
MINIMUM_VISUAL_PROJECTION_IOU = 0.98

CYAN_HSV_LOWER = (75, 60, 140)
CYAN_HSV_UPPER = (105, 255, 255)
ORANGE_HSV_LOWER = (5, 70, 130)
ORANGE_HSV_UPPER = (30, 255, 255)

EXPECTED_COUNTS = {
    "outer_outlines": 1,
    "void_holes": 3,
    "cover_groups": 9,
    "portals": 4,
    "shockwave_nodes": 3,
    "spawns": 4,
}


class ExtractionError(RuntimeError):
    """Raised when the frozen extraction contract cannot be satisfied."""


def _clean_float(value: float, digits: int = 6) -> float:
    rounded = round(float(value), digits)
    return 0.0 if rounded == 0.0 else rounded


def _pixel_to_world_xz(point: Sequence[float]) -> list[float]:
    pixel_x, pixel_y = point
    return [
        _clean_float((float(pixel_x) - SCREEN_CENTER_X) * WORLD_UNITS_PER_PIXEL),
        _clean_float((float(pixel_y) - SCREEN_CENTER_Y) * WORLD_Z_PER_PIXEL),
    ]


def _world_xz_to_pixel(point: Sequence[float]) -> list[int]:
    world_x, world_z = point
    return [
        int(round(float(world_x) / WORLD_UNITS_PER_PIXEL + SCREEN_CENTER_X)),
        int(round(float(world_z) / WORLD_Z_PER_PIXEL + SCREEN_CENTER_Y)),
    ]


def _as_points(contour: np.ndarray) -> np.ndarray:
    return np.asarray(contour, dtype=np.int32).reshape(-1, 2)


def _screen_points(contour: np.ndarray) -> list[list[int]]:
    return [[int(x), int(y)] for x, y in _as_points(contour)]


def _world_points(contour: np.ndarray) -> list[list[float]]:
    return [_pixel_to_world_xz(point) for point in _as_points(contour)]


def _normalise_winding(contour: np.ndarray, *, counter_clockwise: bool) -> np.ndarray:
    result = np.asarray(contour, dtype=np.int32).reshape(-1, 1, 2)
    signed_area = float(cv2.contourArea(result, oriented=True))
    if (signed_area > 0.0) != counter_clockwise:
        result = result[::-1].copy()
    return result


def _simplify(contour: np.ndarray, *, counter_clockwise: bool) -> np.ndarray:
    simplified = cv2.approxPolyDP(contour, SIMPLIFY_EPSILON_PX, True)
    if len(simplified) < 3 or cv2.contourArea(simplified) <= 0.0:
        raise ExtractionError("2.5 px simplification collapsed a required contour")
    return _normalise_winding(simplified, counter_clockwise=counter_clockwise)


def _centroid_px(contour: np.ndarray) -> tuple[float, float]:
    moments = cv2.moments(contour)
    if abs(moments["m00"]) < 1e-9:
        points = _as_points(contour).astype(np.float64)
        return float(points[:, 0].mean()), float(points[:, 1].mean())
    return (
        float(moments["m10"] / moments["m00"]),
        float(moments["m01"] / moments["m00"]),
    )


def _outline_fields(contour: np.ndarray) -> dict[str, Any]:
    return {
        "outline_screen_px": _screen_points(contour),
        "outline_world_xz": _world_points(contour),
    }


def _neutral_mask(hsv: np.ndarray) -> np.ndarray:
    mask = cv2.inRange(
        hsv,
        (0, 0, NEUTRAL_MIN_VALUE),
        (179, NEUTRAL_MAX_SATURATION, 255),
    )
    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE, (CLOSE_KERNEL_SIZE, CLOSE_KERNEL_SIZE)
    )
    return cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)


def _extract_contour_tree(
    mask: np.ndarray,
) -> tuple[list[np.ndarray], np.ndarray, int, list[int]]:
    contours, hierarchy = cv2.findContours(
        mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_NONE
    )
    if hierarchy is None or not contours:
        raise ExtractionError("neutral mask contains no contours")
    tree = hierarchy[0]
    external_indices = [index for index, row in enumerate(tree) if row[3] == -1]
    if not external_indices:
        raise ExtractionError("neutral mask contains no external contour")
    outer_index = max(external_indices, key=lambda index: cv2.contourArea(contours[index]))
    child_indices = [
        index for index, row in enumerate(tree) if int(row[3]) == outer_index
    ]
    return contours, tree, outer_index, child_indices


def _component_records(
    hsv: np.ndarray,
    lower: tuple[int, int, int],
    upper: tuple[int, int, int],
) -> list[dict[str, Any]]:
    colour_mask = cv2.inRange(hsv, lower, upper)
    count, _, stats, centroids = cv2.connectedComponentsWithStats(
        colour_mask, connectivity=8
    )
    records: list[dict[str, Any]] = []
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        if area < MINIMUM_COLOUR_COMPONENT_AREA_PX:
            continue
        x = int(stats[label, cv2.CC_STAT_LEFT])
        y = int(stats[label, cv2.CC_STAT_TOP])
        width = int(stats[label, cv2.CC_STAT_WIDTH])
        height = int(stats[label, cv2.CC_STAT_HEIGHT])
        records.append(
            {
                "area_px": area,
                "centroid_px": (
                    float(centroids[label, 0]),
                    float(centroids[label, 1]),
                ),
                "bounds_xywh_px": [x, y, width, height],
            }
        )
    records.sort(key=lambda item: (item["centroid_px"][1], item["centroid_px"][0]))
    return records


def _match_components_to_children(
    components: list[dict[str, Any]],
    contours: list[np.ndarray],
    eligible_children: Iterable[int],
    label: str,
) -> dict[int, dict[str, Any]]:
    eligible = list(eligible_children)
    matches: dict[int, dict[str, Any]] = {}
    for component in components:
        point = component["centroid_px"]
        containing = [
            index
            for index in eligible
            if cv2.pointPolygonTest(contours[index], point, False) >= 0.0
        ]
        if len(containing) != 1:
            raise ExtractionError(
                f"{label} component at {point!r} matched {len(containing)} neutral children"
            )
        child_index = containing[0]
        if child_index in matches:
            raise ExtractionError(f"multiple {label} components matched child {child_index}")
        matches[child_index] = component
    return matches


def _sort_contours_by_centroid(
    indices: Iterable[int], contours: list[np.ndarray]
) -> list[int]:
    return sorted(indices, key=lambda index: (_centroid_px(contours[index])[1], _centroid_px(contours[index])[0]))


def _build_reference_mask(
    shape: tuple[int, int], outer: np.ndarray, children: Iterable[np.ndarray]
) -> np.ndarray:
    mask = np.zeros(shape, dtype=np.uint8)
    cv2.fillPoly(mask, [outer], 255)
    child_list = list(children)
    if child_list:
        cv2.fillPoly(mask, child_list, 0)
    return mask


def _directional_top_surface_mask(
    projected_mask: np.ndarray, depth_projection_px: int
) -> np.ndarray:
    """Invert the orthographic screen-down sweep caused by slab depth.

    The extracted outer/void contours describe the already-rendered reference
    projection.  Extruding those contours directly would add the visible side
    projection a second time.  A top pixel is therefore retained only when the
    whole screen-down depth segment is present in the target projection.
    """
    source = projected_mask > 0
    result = source.copy()
    for offset in range(1, depth_projection_px + 1):
        shifted = np.zeros_like(source)
        shifted[:-offset] = source[offset:]
        result &= shifted
    return result.astype(np.uint8) * 255


def _project_extruded_top_mask(
    top_mask: np.ndarray, depth_projection_px: int
) -> np.ndarray:
    """Raster approximation of an orthographic slab extrusion."""
    source = top_mask > 0
    result = source.copy()
    for offset in range(1, depth_projection_px + 1):
        shifted = np.zeros_like(source)
        shifted[offset:] = source[:-offset]
        result |= shifted
    return result.astype(np.uint8) * 255


def _topology(mask: np.ndarray) -> dict[str, int]:
    component_count, _ = cv2.connectedComponents((mask > 0).astype(np.uint8), 8)
    contours, hierarchy = cv2.findContours(mask, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    if hierarchy is None:
        return {"foreground_components": component_count - 1, "holes": 0}
    holes = sum(1 for row in hierarchy[0] if int(row[3]) != -1)
    return {"foreground_components": component_count - 1, "holes": holes}


def _fill_world_outline(mask: np.ndarray, outline: Sequence[Sequence[float]], value: int) -> None:
    pixels = np.asarray([_world_xz_to_pixel(point) for point in outline], dtype=np.int32)
    cv2.fillPoly(mask, [pixels.reshape(-1, 1, 2)], value)


def _reconstruct_from_layout(layout: dict[str, Any]) -> np.ndarray:
    width, height = layout["source_size_px"]
    mask = np.zeros((height, width), dtype=np.uint8)
    _fill_world_outline(mask, layout["platform"]["outline_world_xz"], 255)
    for hole in layout["holes"]:
        _fill_world_outline(mask, hole["outline_world_xz"], 0)
    for cover in layout["covers"]:
        _fill_world_outline(mask, cover["footprint_world_xz"], 0)
    for portal in layout["portals"]:
        _fill_world_outline(mask, portal["footprint_world_xz"], 0)
    for node in layout["shockwave_nodes"]:
        _fill_world_outline(mask, node["footprint_world_xz"], 0)
    return mask


def _mask_iou(left: np.ndarray, right: np.ndarray) -> float:
    left_on = left > 0
    right_on = right > 0
    intersection = int(np.count_nonzero(left_on & right_on))
    union = int(np.count_nonzero(left_on | right_on))
    return float(intersection / union) if union else 0.0


def _cover_geometry(contour: np.ndarray) -> dict[str, float | list[float]]:
    pixel_points = _as_points(contour).astype(np.float32)
    world_points = np.empty_like(pixel_points)
    world_points[:, 0] = (pixel_points[:, 0] - SCREEN_CENTER_X) * WORLD_UNITS_PER_PIXEL
    world_points[:, 1] = (pixel_points[:, 1] - SCREEN_CENTER_Y) * WORLD_Z_PER_PIXEL
    (center_x, center_z), (side_a, side_b), angle = cv2.minAreaRect(
        world_points.reshape(-1, 1, 2)
    )
    if side_a >= side_b:
        length = float(side_a)
        raw_thickness = float(side_b)
        yaw = float(angle)
    else:
        length = float(side_b)
        raw_thickness = float(side_a)
        yaw = float(angle + 90.0)
    while yaw >= 90.0:
        yaw -= 180.0
    while yaw < -90.0:
        yaw += 180.0
    thickness = min(2.6, max(2.0, raw_thickness))
    return {
        "center_world_xz": [_clean_float(center_x), _clean_float(center_z)],
        "length_world": _clean_float(length),
        "raw_thickness_world": _clean_float(raw_thickness),
        "thickness_world": _clean_float(thickness),
        "yaw_degrees": _clean_float(yaw),
    }


def _source_label(source: Path) -> str:
    resolved = source.resolve()
    try:
        return resolved.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return str(resolved)


def _assert_count(name: str, actual: int) -> None:
    expected = EXPECTED_COUNTS[name]
    if actual != expected:
        raise ExtractionError(f"expected {expected} {name}, extracted {actual}")


def extract_layout(source: Path) -> dict[str, Any]:
    source = source.resolve()
    if not source.is_file():
        raise ExtractionError(f"source image not found: {source}")
    image = cv2.imread(str(source), cv2.IMREAD_COLOR)
    if image is None:
        raise ExtractionError(f"OpenCV could not decode source image: {source}")
    height, width = image.shape[:2]
    if (width, height) != (SOURCE_WIDTH, SOURCE_HEIGHT):
        raise ExtractionError(
            f"expected {SOURCE_WIDTH}x{SOURCE_HEIGHT} source, got {width}x{height}"
        )

    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    closed_neutral = _neutral_mask(hsv)
    contours, _, outer_index, child_indices = _extract_contour_tree(closed_neutral)
    _assert_count("outer_outlines", 1)

    if len(child_indices) < 3:
        raise ExtractionError(f"outer contour has only {len(child_indices)} direct children")
    hole_indices = sorted(
        child_indices, key=lambda index: cv2.contourArea(contours[index]), reverse=True
    )[:3]
    _assert_count("void_holes", len(hole_indices))

    non_hole_children = [index for index in child_indices if index not in hole_indices]
    cyan_components = _component_records(hsv, CYAN_HSV_LOWER, CYAN_HSV_UPPER)
    orange_components = _component_records(hsv, ORANGE_HSV_LOWER, ORANGE_HSV_UPPER)
    _assert_count("portals", len(cyan_components))
    _assert_count("shockwave_nodes", len(orange_components))

    cyan_matches = _match_components_to_children(
        cyan_components, contours, non_hole_children, "cyan"
    )
    orange_matches = _match_components_to_children(
        orange_components, contours, non_hole_children, "orange"
    )
    if set(cyan_matches) & set(orange_matches):
        raise ExtractionError("a neutral child was classified as both cyan and orange")
    cover_indices = [
        index
        for index in non_hole_children
        if index not in cyan_matches and index not in orange_matches
    ]
    _assert_count("cover_groups", len(cover_indices))
    if (
        set(hole_indices)
        | set(cover_indices)
        | set(cyan_matches)
        | set(orange_matches)
    ) != set(child_indices):
        raise ExtractionError("neutral child contour partition is incomplete")

    outer = _simplify(contours[outer_index], counter_clockwise=True)
    simplified_children = {
        index: _simplify(contours[index], counter_clockwise=False)
        for index in child_indices
    }
    sorted_holes = _sort_contours_by_centroid(hole_indices, contours)
    sorted_covers = _sort_contours_by_centroid(cover_indices, contours)
    sorted_portals = _sort_contours_by_centroid(cyan_matches, contours)
    sorted_nodes = _sort_contours_by_centroid(orange_matches, contours)

    # The neutral contour is the reference's final 2D slab projection, not the
    # physical top footprint.  Recover a visual top footprint whose 4-unit
    # extrusion projects back onto that contour instead of double-counting the
    # visible side wall.
    platform_projection_mask = _build_reference_mask(
        (height, width),
        contours[outer_index],
        (contours[index] for index in hole_indices),
    )
    visual_top_mask = _directional_top_surface_mask(
        platform_projection_mask, VISUAL_DEPTH_PROJECTION_PX
    )
    (
        visual_contours,
        _,
        visual_outer_index,
        visual_child_indices,
    ) = _extract_contour_tree(visual_top_mask)
    if len(visual_child_indices) != EXPECTED_COUNTS["void_holes"]:
        raise ExtractionError(
            "visual top deprojection changed the void topology: "
            f"expected 3 holes, got {len(visual_child_indices)}"
        )
    visual_outer = _simplify(
        visual_contours[visual_outer_index], counter_clockwise=True
    )
    sorted_visual_holes = _sort_contours_by_centroid(
        visual_child_indices, visual_contours
    )
    simplified_visual_holes = [
        _simplify(visual_contours[index], counter_clockwise=False)
        for index in sorted_visual_holes
    ]

    simplified_visual_top_mask = _build_reference_mask(
        (height, width), visual_outer, simplified_visual_holes
    )
    projected_visual_top_mask = _project_extruded_top_mask(
        simplified_visual_top_mask, VISUAL_DEPTH_PROJECTION_PX
    )
    visual_projection_iou = _mask_iou(
        platform_projection_mask, projected_visual_top_mask
    )
    if visual_projection_iou < MINIMUM_VISUAL_PROJECTION_IOU:
        raise ExtractionError(
            f"visual slab projection IoU {visual_projection_iou:.6f} is below "
            f"{MINIMUM_VISUAL_PROJECTION_IOU:.2f}"
        )

    outer_world = np.asarray(_world_points(outer), dtype=np.float64)
    min_x, min_z = outer_world.min(axis=0)
    max_x, max_z = outer_world.max(axis=0)
    outer_center_px = _centroid_px(contours[outer_index])
    outer_center_world = _pixel_to_world_xz(outer_center_px)

    holes: list[dict[str, Any]] = []
    for ordinal, index in enumerate(sorted_holes, start=1):
        center_px = _centroid_px(contours[index])
        visual_hole = simplified_visual_holes[ordinal - 1]
        holes.append(
            {
                "id": f"void_hole_{ordinal:02d}",
                "center_screen_px": [_clean_float(center_px[0]), _clean_float(center_px[1])],
                "center_world_xz": _pixel_to_world_xz(center_px),
                "source_area_px2": _clean_float(cv2.contourArea(contours[index]), 1),
                "visual_top_outline_screen_px": _screen_points(visual_hole),
                "visual_top_outline_world_xz": _world_points(visual_hole),
                **_outline_fields(simplified_children[index]),
            }
        )

    covers: list[dict[str, Any]] = []
    for ordinal, index in enumerate(sorted_covers, start=1):
        geometry = _cover_geometry(contours[index])
        center_px = _centroid_px(contours[index])
        footprint = simplified_children[index]
        covers.append(
            {
                "id": f"cover_{ordinal:02d}",
                "position_world": [
                    geometry["center_world_xz"][0],
                    PLATFORM_TOP_Y,
                    geometry["center_world_xz"][1],
                ],
                "center_screen_px": [_clean_float(center_px[0]), _clean_float(center_px[1])],
                "length_world": geometry["length_world"],
                "raw_thickness_world": geometry["raw_thickness_world"],
                "thickness_world": geometry["thickness_world"],
                "yaw_degrees": geometry["yaw_degrees"],
                "source_area_px2": _clean_float(cv2.contourArea(contours[index]), 1),
                "footprint_screen_px": _screen_points(footprint),
                "footprint_world_xz": _world_points(footprint),
            }
        )

    portals: list[dict[str, Any]] = []
    portal_index_to_id = {
        index: f"portal_{ordinal:02d}"
        for ordinal, index in enumerate(sorted_portals, start=1)
    }
    diagonal_pairs = {0: 3, 3: 0, 1: 2, 2: 1}
    for ordinal, index in enumerate(sorted_portals, start=1):
        component = cyan_matches[index]
        center_px = component["centroid_px"]
        center_world = _pixel_to_world_xz(center_px)
        footprint = simplified_children[index]
        paired_index = sorted_portals[diagonal_pairs[ordinal - 1]]
        portals.append(
            {
                "id": portal_index_to_id[index],
                "paired_portal_id": portal_index_to_id[paired_index],
                "position_world": [center_world[0], PLATFORM_TOP_Y, center_world[1]],
                "center_screen_px": [_clean_float(center_px[0]), _clean_float(center_px[1])],
                "component_area_px": component["area_px"],
                "component_bounds_xywh_px": component["bounds_xywh_px"],
                "source_neutral_child_area_px2": _clean_float(
                    cv2.contourArea(contours[index]), 1
                ),
                "footprint_screen_px": _screen_points(footprint),
                "footprint_world_xz": _world_points(footprint),
            }
        )

    shockwave_nodes: list[dict[str, Any]] = []
    for ordinal, index in enumerate(sorted_nodes, start=1):
        component = orange_matches[index]
        center_px = component["centroid_px"]
        center_world = _pixel_to_world_xz(center_px)
        footprint = simplified_children[index]
        shockwave_nodes.append(
            {
                "id": f"shockwave_node_{ordinal:02d}",
                "position_world": [center_world[0], PLATFORM_TOP_Y, center_world[1]],
                "center_screen_px": [_clean_float(center_px[0]), _clean_float(center_px[1])],
                "component_area_px": component["area_px"],
                "component_bounds_xywh_px": component["bounds_xywh_px"],
                "source_neutral_child_area_px2": _clean_float(
                    cv2.contourArea(contours[index]), 1
                ),
                "footprint_screen_px": _screen_points(footprint),
                "footprint_world_xz": _world_points(footprint),
            }
        )

    reference_mask = _build_reference_mask(
        (height, width),
        contours[outer_index],
        (contours[index] for index in child_indices),
    )
    spawns: list[dict[str, Any]] = []
    for ordinal, portal in enumerate(portals, start=1):
        portal_x = float(portal["position_world"][0])
        portal_z = float(portal["position_world"][2])
        direction_x = outer_center_world[0] - portal_x
        direction_z = outer_center_world[1] - portal_z
        direction_length = math.hypot(direction_x, direction_z)
        if direction_length <= 1e-9:
            raise ExtractionError(f"cannot derive inward direction for {portal['id']}")
        direction_x /= direction_length
        direction_z /= direction_length
        spawn_x = portal_x + direction_x * SPAWN_INWARD_OFFSET
        spawn_z = portal_z + direction_z * SPAWN_INWARD_OFFSET
        spawn_pixel = _world_xz_to_pixel((spawn_x, spawn_z))
        pixel_x, pixel_y = spawn_pixel
        if not (0 <= pixel_x < width and 0 <= pixel_y < height):
            raise ExtractionError(f"spawn {ordinal} falls outside the source canvas")
        if reference_mask[pixel_y, pixel_x] == 0:
            raise ExtractionError(f"spawn {ordinal} is not on extracted walkable platform")
        spawns.append(
            {
                "id": f"spawn_{ordinal:02d}",
                "source_portal_id": portal["id"],
                "position_world": [
                    _clean_float(spawn_x),
                    SPAWN_Y,
                    _clean_float(spawn_z),
                ],
                "screen_position_px": spawn_pixel,
                "inward_direction_world_xz": [
                    _clean_float(direction_x),
                    _clean_float(direction_z),
                ],
                "inward_offset_world": SPAWN_INWARD_OFFSET,
            }
        )
    _assert_count("spawns", len(spawns))

    layout: dict[str, Any] = {
        "schema": "chaos_gun.momentum_circuit_layout",
        "version": 1,
        "source_image": _source_label(source),
        "source_size_px": [width, height],
        "units": {
            "distance": "godot_world_units",
            "plane": "xz",
            "rotation": "yaw_degrees",
        },
        "projection": {
            "type": "orthographic_ground_plane",
            "screen_center_px": [SCREEN_CENTER_X, SCREEN_CENTER_Y],
            "world_units_per_pixel_x": WORLD_UNITS_PER_PIXEL,
            "world_units_per_pixel_z": _clean_float(WORLD_Z_PER_PIXEL, 9),
            "screen_to_world_x": "(pixel_x - 768) * 0.08",
            "screen_to_world_z": "(pixel_y - 512) * 0.08 / sin(55 degrees)",
            "world_y_for_layout": PLATFORM_TOP_Y,
        },
        "camera": {
            "projection": "orthographic",
            "yaw_degrees": CAMERA_YAW_DEGREES,
            "elevation_degrees": CAMERA_ELEVATION_DEGREES,
            "orthographic_size_world": _clean_float(SOURCE_HEIGHT * WORLD_UNITS_PER_PIXEL),
            "viewport_size_px": [width, height],
            "framing_origin_world_xz": [0.0, 0.0],
        },
        "extraction": {
            "hsv_encoding": "OpenCV H:0-179 S:0-255 V:0-255",
            "neutral_mask": {
                "minimum_value": NEUTRAL_MIN_VALUE,
                "maximum_saturation": NEUTRAL_MAX_SATURATION,
            },
            "morphological_close": {
                "shape": "ellipse",
                "kernel_size_px": [CLOSE_KERNEL_SIZE, CLOSE_KERNEL_SIZE],
            },
            "contour_simplification_epsilon_px": SIMPLIFY_EPSILON_PX,
            "visual_top_deprojection": {
                "method": "directional_screen_down_erosion",
                "slab_depth_world": PLATFORM_DEPTH,
                "depth_projection_pixels": VISUAL_DEPTH_PROJECTION_PX,
                "continuous_depth_projection_pixels": _clean_float(
                    PLATFORM_DEPTH * ELEVATION_COSINE / WORLD_UNITS_PER_PIXEL,
                    9,
                ),
                "minimum_projection_iou": MINIMUM_VISUAL_PROJECTION_IOU,
            },
            "cyan_hsv_lower": list(CYAN_HSV_LOWER),
            "cyan_hsv_upper": list(CYAN_HSV_UPPER),
            "orange_hsv_lower": list(ORANGE_HSV_LOWER),
            "orange_hsv_upper": list(ORANGE_HSV_UPPER),
            "minimum_colour_component_area_px": MINIMUM_COLOUR_COMPONENT_AREA_PX,
        },
        "platform": {
            "top_y": PLATFORM_TOP_Y,
            "depth": PLATFORM_DEPTH,
            "bottom_y": _clean_float(PLATFORM_TOP_Y - PLATFORM_DEPTH),
            "center_world_xz": outer_center_world,
            "bounds_world_xz": {
                "minimum": [_clean_float(min_x), _clean_float(min_z)],
                "maximum": [_clean_float(max_x), _clean_float(max_z)],
            },
            "dimensions_world": {
                "span_x": _clean_float(max_x - min_x),
                "span_z": _clean_float(max_z - min_z),
                "depth_y": PLATFORM_DEPTH,
            },
            "source_area_px2": _clean_float(cv2.contourArea(contours[outer_index]), 1),
            "visual_top_outline_screen_px": _screen_points(visual_outer),
            "visual_top_outline_world_xz": _world_points(visual_outer),
            **_outline_fields(outer),
        },
        "holes": holes,
        "covers": covers,
        "portals": portals,
        "shockwave_nodes": shockwave_nodes,
        "spawns": spawns,
    }

    reconstructed = _reconstruct_from_layout(layout)
    reference_topology = _topology(reference_mask)
    reconstructed_topology = _topology(reconstructed)
    if reference_topology != reconstructed_topology:
        raise ExtractionError(
            "2.5 px simplification changed topology: "
            f"reference={reference_topology}, reconstructed={reconstructed_topology}"
        )
    reconstruction_iou = _mask_iou(reference_mask, reconstructed)
    if reconstruction_iou < MINIMUM_RECONSTRUCTION_IOU:
        raise ExtractionError(
            f"reconstructed mask IoU {reconstruction_iou:.6f} is below "
            f"{MINIMUM_RECONSTRUCTION_IOU:.2f}"
        )
    actual_counts = {
        "outer_outlines": 1,
        "void_holes": len(holes),
        "cover_groups": len(covers),
        "portals": len(portals),
        "shockwave_nodes": len(shockwave_nodes),
        "spawns": len(spawns),
    }
    for count_name, actual in actual_counts.items():
        _assert_count(count_name, actual)
    layout["validation"] = {
        "counts": actual_counts,
        "reference_topology": reference_topology,
        "reconstructed_topology": reconstructed_topology,
        "reference_mask_pixels": int(np.count_nonzero(reference_mask)),
        "reconstructed_mask_pixels": int(np.count_nonzero(reconstructed)),
        "reconstruction_iou": _clean_float(reconstruction_iou, 9),
        "minimum_required_iou": MINIMUM_RECONSTRUCTION_IOU,
        "visual_projection_depth_pixels": VISUAL_DEPTH_PROJECTION_PX,
        "visual_projection_iou": _clean_float(visual_projection_iou, 9),
        "visual_projection_minimum_required_iou": MINIMUM_VISUAL_PROJECTION_IOU,
        "passed": True,
        "reconstruction_basis": (
            "platform outer outline minus all stored void, cover, portal, and "
            "shockwave-node footprint contours"
        ),
    }
    return layout


def _serialise(layout: dict[str, Any]) -> str:
    return json.dumps(layout, ensure_ascii=False, indent=2) + "\n"


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract the frozen Momentum Circuit whitebox layout."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"frozen 1536x1024 source image (default: {DEFAULT_SOURCE})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"layout JSON destination (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the existing output equals a fresh extraction; do not rewrite",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="also print the generated layout JSON to stdout",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        layout = extract_layout(args.source)
        payload = _serialise(layout)
        output = args.output.resolve()
        if args.check:
            if not output.is_file():
                raise ExtractionError(f"layout JSON not found for --check: {output}")
            existing = output.read_text(encoding="utf-8")
            if existing != payload:
                raise ExtractionError(
                    f"layout JSON is stale; regenerate with {Path(__file__).name}"
                )
            action = "validated"
        else:
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(payload, encoding="utf-8", newline="\n")
            action = "wrote"
    except (ExtractionError, OSError, cv2.error, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    validation = layout["validation"]
    counts = validation["counts"]
    print(
        f"{action} {output}: "
        f"outer={counts['outer_outlines']} holes={counts['void_holes']} "
        f"covers={counts['cover_groups']} portals={counts['portals']} "
        f"nodes={counts['shockwave_nodes']} spawns={counts['spawns']} "
        f"IoU={validation['reconstruction_iou']:.6f}"
    )
    if args.json:
        print(payload, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
