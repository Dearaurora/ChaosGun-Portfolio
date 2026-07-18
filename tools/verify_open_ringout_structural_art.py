import json

import bpy


CLIFF_LIMITS = {
    "V2CentralCliff": 0.62,
    "V3NorthIslandCliff": 0.46,
    "V3EastIslandCliff": 0.50,
    "V3SouthIslandCliff": 0.44,
    "V3WestIslandCliff": 0.48,
}


def projected_area(points):
    width = max(point.x for point in points) - min(point.x for point in points)
    depth = max(point.y for point in points) - min(point.y for point in points)
    return width * depth


def cliff_taper_ratio(name):
    obj = bpy.data.objects.get(name)
    if obj is None or obj.type != "MESH":
        raise RuntimeError(f"Missing structural cliff mesh: {name}")
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    top_z = max(point.z for point in points)
    bottom_z = min(point.z for point in points)
    height = top_z - bottom_z
    if height < 9.0:
        raise RuntimeError(f"{name} is too shallow to read as a floating island: {height:.3f}")
    top_points = [point for point in points if point.z >= top_z - height * 0.16]
    lower_points = [point for point in points if point.z <= top_z - height * 0.58]
    if not top_points or not lower_points:
        raise RuntimeError(f"Could not sample taper rings for {name}")
    return projected_area(lower_points) / projected_area(top_points), height


def require_supports(fragment, expected_count, minimum_height):
    names = [name for name in bpy.data.objects.keys() if fragment in name]
    if len(names) != expected_count:
        raise RuntimeError(f"Expected {expected_count} {fragment} supports, found {len(names)}")
    short = [name for name in names if bpy.data.objects[name].dimensions.z < minimum_height]
    if short:
        raise RuntimeError(f"Undersized {fragment} supports: {short}")
    return names


def main():
    cliff_report = {}
    for name, maximum_ratio in CLIFF_LIMITS.items():
        ratio, height = cliff_taper_ratio(name)
        if ratio > maximum_ratio:
            raise RuntimeError(
                f"{name} regressed toward a slab profile: {ratio:.3f} > {maximum_ratio:.3f}"
            )
        cliff_report[name] = {
            "lower_to_top_area_ratio": round(ratio, 4),
            "height": round(height, 4),
        }
    mouth_beams = require_supports("BridgeMouthBeam_", 8, 1.10)
    socket_side_beams = require_supports("SocketSideBeam_", 16, 0.72)
    print("OPEN_RINGOUT_STRUCTURAL_ART=" + json.dumps({
        "cliffs": cliff_report,
        "bridge_mouth_supports": len(mouth_beams),
        "socket_side_supports": len(socket_side_beams),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
