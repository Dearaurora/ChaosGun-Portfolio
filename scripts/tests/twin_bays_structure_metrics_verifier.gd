extends SceneTree

## Measures the production GLB directly against the authoritative layout JSON.
## This deliberately avoids concept-image pixel matching: the release geometry
## gate is about the shipped platform mesh, including the JSON-derived 16-unit
## safe causeway shoulder.

const LAYOUT_PATH := "res://resources/maps/twin_bays_layout_v1.json"
const FOREGROUND_GLB_PATH := (
	"res://assets/models/generated/twin_bays_splash_arena_v4/"
	+ "twin_bays_splash_arena_v4_foreground.glb"
)
const REPORT_PATH := "res://reports/twin_bays_splash_arena_structure_metrics.json"
# The deterministic builder batches static meshes by material before GLB export.
# Both dry top prisms therefore ship in this one production MeshInstance3D.
const PLATFORM_MESH_NAMES := [&"Foreground_TBSA_DryCream"]
const MASK_WIDTH := 512
const MASK_HEIGHT := 320
const MIN_MASK_IOU := 0.95
const MIN_BBOX_CENTROID_SCORE := 0.98
const MIN_NORMALIZED_CHAMFER := 0.99
const TOP_EPSILON := 0.02
const POINT_KEY_SCALE := 100000.0

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Production Structure Metrics]")
	print("==================================================")

	var layout := _load_json_dictionary(LAYOUT_PATH)
	if layout.is_empty():
		_fail("Layout JSON is missing or invalid: %s" % LAYOUT_PATH)
		await _finish({})
		return
	if not ResourceLoader.exists(FOREGROUND_GLB_PATH):
		_fail("Production foreground GLB is missing: %s" % FOREGROUND_GLB_PATH)
		await _finish({})
		return

	var packed := load(FOREGROUND_GLB_PATH) as PackedScene
	if packed == null:
		_fail("Could not load production foreground GLB")
		await _finish({})
		return
	var foreground := packed.instantiate() as Node3D
	if foreground == null:
		_fail("Production foreground GLB root must be Node3D")
		await _finish({})
		return
	root.add_child(foreground)
	await process_frame

	var expected := _build_expected_geometry(layout)
	var actual := _extract_actual_geometry(foreground)
	var report := _measure(expected, actual)

	foreground.queue_free()
	await process_frame
	await _finish(report)


func _build_expected_geometry(layout: Dictionary) -> Dictionary:
	var platform: Dictionary = layout.get("platform", {})
	var outline: Array[Vector2] = []
	for raw_point in platform.get("outline", []):
		var point := raw_point as Array
		if point.size() >= 2:
			outline.append(Vector2(float(point[0]), float(point[1])))
	if outline.size() != 116:
		_fail("Expected 116 authoritative platform points, got %d" % outline.size())

	var causeway: Dictionary = platform.get("causeway", {})
	var collision_position: Array = causeway.get("collision_position", [])
	var collision_size: Array = causeway.get("collision_size", [])
	var safe_rect: Array[Vector2] = []
	if collision_position.size() >= 3 and collision_size.size() >= 3:
		var center := Vector2(float(collision_position[0]), float(collision_position[2]))
		var half_size := Vector2(float(collision_size[0]), float(collision_size[2])) * 0.5
		safe_rect = [
			center + Vector2(-half_size.x, -half_size.y),
			center + Vector2(half_size.x, -half_size.y),
			center + Vector2(half_size.x, half_size.y),
			center + Vector2(-half_size.x, half_size.y),
		]
	else:
		_fail("Causeway collision rectangle is incomplete in layout JSON")

	var triangles: Array = []
	_append_polygon_triangles(outline, triangles, "authoritative outline")
	_append_polygon_triangles(safe_rect, triangles, "safe causeway rectangle")
	var boundary_points: Array[Vector2] = []
	boundary_points.append_array(outline)
	boundary_points.append_array(safe_rect)
	return {
		"triangles": triangles,
		"boundary_points": boundary_points,
		"outline_points": outline.size(),
		"safe_causeway_width": float(collision_size[2]) if collision_size.size() >= 3 else 0.0,
	}


func _append_polygon_triangles(points: Array[Vector2], target: Array, label: String) -> void:
	if points.size() < 3:
		_fail("%s has fewer than three points" % label)
		return
	var packed_points := PackedVector2Array(points)
	var indices := Geometry2D.triangulate_polygon(packed_points)
	if indices.is_empty():
		_fail("Could not triangulate %s" % label)
		return
	for index in range(0, indices.size(), 3):
		target.append([
			packed_points[indices[index]],
			packed_points[indices[index + 1]],
			packed_points[indices[index + 2]],
		])


func _extract_actual_geometry(foreground: Node3D) -> Dictionary:
	var triangles: Array = []
	var boundary_points: Array[Vector2] = []
	var mesh_reports: Array = []
	for mesh_name in PLATFORM_MESH_NAMES:
		var mesh_node := foreground.find_child(String(mesh_name), true, false) as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			_fail("Production GLB is missing mesh: %s" % mesh_name)
			continue
		var extracted := _extract_mesh_top(mesh_node)
		triangles.append_array(extracted.get("triangles", []))
		boundary_points.append_array(extracted.get("boundary_points", []))
		mesh_reports.append({
			"name": String(mesh_name),
			"top_triangles": (extracted.get("triangles", []) as Array).size(),
			"boundary_vertices": (extracted.get("boundary_points", []) as Array).size(),
			"top_y": float(extracted.get("top_y", 0.0)),
		})
	return {
		"triangles": triangles,
		"boundary_points": _unique_points(boundary_points),
		"meshes": mesh_reports,
	}


func _extract_mesh_top(mesh_node: MeshInstance3D) -> Dictionary:
	var mesh := mesh_node.mesh
	var top_y := -INF
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var world_vertex := mesh_node.global_transform * vertex
			top_y = maxf(top_y, world_vertex.y)

	var top_triangles: Array = []
	var edge_counts: Dictionary = {}
	var point_lookup: Dictionary = {}
	for surface_index in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var triangle_count := indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		for triangle_index in range(triangle_count):
			var vertex_indices := [
				indices[triangle_index * 3] if not indices.is_empty() else triangle_index * 3,
				indices[triangle_index * 3 + 1] if not indices.is_empty() else triangle_index * 3 + 1,
				indices[triangle_index * 3 + 2] if not indices.is_empty() else triangle_index * 3 + 2,
			]
			var world_vertices: Array[Vector3] = []
			for vertex_index in vertex_indices:
				world_vertices.append(mesh_node.global_transform * vertices[int(vertex_index)])
			if (
				absf(world_vertices[0].y - top_y) > TOP_EPSILON
				or absf(world_vertices[1].y - top_y) > TOP_EPSILON
				or absf(world_vertices[2].y - top_y) > TOP_EPSILON
			):
				continue
			var triangle := [
				Vector2(world_vertices[0].x, world_vertices[0].z),
				Vector2(world_vertices[1].x, world_vertices[1].z),
				Vector2(world_vertices[2].x, world_vertices[2].z),
			]
			top_triangles.append(triangle)
			_count_triangle_edges(triangle, edge_counts, point_lookup)

	var boundary_points: Array[Vector2] = []
	for edge_key in edge_counts:
		if int(edge_counts[edge_key]) != 1:
			continue
		for point_key in String(edge_key).split("|"):
			boundary_points.append(point_lookup[point_key] as Vector2)
	return {
		"triangles": top_triangles,
		"boundary_points": _unique_points(boundary_points),
		"top_y": top_y,
	}


func _count_triangle_edges(triangle: Array, edge_counts: Dictionary, point_lookup: Dictionary) -> void:
	for edge_index in range(3):
		var point_a := triangle[edge_index] as Vector2
		var point_b := triangle[(edge_index + 1) % 3] as Vector2
		var key_a := _point_key(point_a)
		var key_b := _point_key(point_b)
		point_lookup[key_a] = point_a
		point_lookup[key_b] = point_b
		var edge_key := "%s|%s" % [key_a, key_b] if key_a < key_b else "%s|%s" % [key_b, key_a]
		edge_counts[edge_key] = int(edge_counts.get(edge_key, 0)) + 1


func _measure(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var expected_points: Array[Vector2] = expected.get("boundary_points", [])
	var actual_points: Array[Vector2] = actual.get("boundary_points", [])
	if expected_points.is_empty() or actual_points.is_empty():
		_fail("Expected or actual platform boundary is empty")
		return {}

	var expected_bbox := _bounds(expected_points)
	var actual_bbox := _bounds(actual_points)
	# Include both candidates in the raster domain so unexpected production
	# geometry cannot be clipped out and accidentally improve the score.
	var mask_bounds := expected_bbox.merge(actual_bbox).grow(1.0)
	var expected_mask := _rasterize(expected.get("triangles", []), mask_bounds)
	var actual_mask := _rasterize(actual.get("triangles", []), mask_bounds)
	var overlap := _mask_overlap(expected_mask, actual_mask)
	var bbox_iou := _rect_iou(expected_bbox, actual_bbox)
	var expected_centroid := _mask_centroid(expected_mask, mask_bounds)
	var actual_centroid := _mask_centroid(actual_mask, mask_bounds)
	var diagonal := maxf(expected_bbox.size.length(), 0.001)
	var centroid_distance := expected_centroid.distance_to(actual_centroid)
	var centroid_similarity := clampf(1.0 - centroid_distance / diagonal, 0.0, 1.0)
	var bbox_centroid_score := minf(bbox_iou, centroid_similarity)
	var expected_contour := _mask_contour_points(expected_mask, mask_bounds)
	var actual_contour := _mask_contour_points(actual_mask, mask_bounds)
	var chamfer_distance := _symmetric_chamfer(expected_contour, actual_contour)
	var chamfer_similarity := clampf(1.0 - chamfer_distance / diagonal, 0.0, 1.0)

	if float(overlap["iou"]) < MIN_MASK_IOU:
		_fail("Platform mask IoU %.5f is below %.2f" % [overlap["iou"], MIN_MASK_IOU])
	if bbox_centroid_score < MIN_BBOX_CENTROID_SCORE:
		_fail("Platform bbox/centroid score %.5f is below %.2f" % [bbox_centroid_score, MIN_BBOX_CENTROID_SCORE])
	if chamfer_similarity < MIN_NORMALIZED_CHAMFER:
		_fail("Normalized chamfer similarity %.5f is below %.2f" % [chamfer_similarity, MIN_NORMALIZED_CHAMFER])

	print("MASK       IoU=%.5f (%d expected / %d actual cells)" % [
		overlap["iou"], overlap["expected_cells"], overlap["actual_cells"],
	])
	print("BBOX       IoU=%.5f" % bbox_iou)
	print("CENTROID   similarity=%.5f distance=%.6f" % [centroid_similarity, centroid_distance])
	print("CHAMFER    similarity=%.5f distance=%.6f" % [chamfer_similarity, chamfer_distance])

	return {
		"schema_version": 1,
		"authoritative_layout": LAYOUT_PATH,
		"authoritative_layout_sha256": FileAccess.get_sha256(LAYOUT_PATH),
		"production_foreground": FOREGROUND_GLB_PATH,
		"production_foreground_sha256": FileAccess.get_sha256(FOREGROUND_GLB_PATH),
		"comparison_scope": "JSON platform + 16-unit causeway versus production GLB top triangles",
		"raster_resolution": [MASK_WIDTH, MASK_HEIGHT],
		"expected": {
			"outline_points": int(expected.get("outline_points", 0)),
			"safe_causeway_width": float(expected.get("safe_causeway_width", 0.0)),
			"boundary_vertices": expected_points.size(),
			"mask_cells": int(overlap["expected_cells"]),
			"contour_samples": expected_contour.size(),
			"bbox": _rect_to_array(expected_bbox),
			"centroid": [expected_centroid.x, expected_centroid.y],
		},
		"actual": {
			"boundary_vertices": actual_points.size(),
			"mask_cells": int(overlap["actual_cells"]),
			"contour_samples": actual_contour.size(),
			"bbox": _rect_to_array(actual_bbox),
			"centroid": [actual_centroid.x, actual_centroid.y],
			"meshes": actual.get("meshes", []),
		},
		"metrics": {
			"platform_mask_iou": float(overlap["iou"]),
			"bbox_iou": bbox_iou,
			"centroid_distance_world_units": centroid_distance,
			"centroid_similarity": centroid_similarity,
			"bbox_centroid_score": bbox_centroid_score,
			"symmetric_chamfer_world_units": chamfer_distance,
			"normalized_chamfer_similarity": chamfer_similarity,
		},
		"thresholds": {
			"minimum_platform_mask_iou": MIN_MASK_IOU,
			"minimum_bbox_centroid_score": MIN_BBOX_CENTROID_SCORE,
			"minimum_normalized_chamfer_similarity": MIN_NORMALIZED_CHAMFER,
		},
	}


func _rasterize(triangles: Array, bounds: Rect2) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(MASK_WIDTH * MASK_HEIGHT)
	mask.fill(0)
	for raw_triangle in triangles:
		var triangle := raw_triangle as Array
		if triangle.size() != 3:
			continue
		var a := triangle[0] as Vector2
		var b := triangle[1] as Vector2
		var c := triangle[2] as Vector2
		var triangle_min := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
		var triangle_max := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
		var min_column := clampi(int(floor((triangle_min.x - bounds.position.x) / bounds.size.x * MASK_WIDTH)), 0, MASK_WIDTH - 1)
		var max_column := clampi(int(floor((triangle_max.x - bounds.position.x) / bounds.size.x * MASK_WIDTH)), 0, MASK_WIDTH - 1)
		var min_row := clampi(int(floor((triangle_min.y - bounds.position.y) / bounds.size.y * MASK_HEIGHT)), 0, MASK_HEIGHT - 1)
		var max_row := clampi(int(floor((triangle_max.y - bounds.position.y) / bounds.size.y * MASK_HEIGHT)), 0, MASK_HEIGHT - 1)
		for row in range(min_row, max_row + 1):
			var world_y := bounds.position.y + (float(row) + 0.5) / MASK_HEIGHT * bounds.size.y
			for column in range(min_column, max_column + 1):
				var world_x := bounds.position.x + (float(column) + 0.5) / MASK_WIDTH * bounds.size.x
				if _point_in_triangle(Vector2(world_x, world_y), a, b, c):
					mask[row * MASK_WIDTH + column] = 1
	return mask


func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _cross(point - b, a - b)
	var d2 := _cross(point - c, b - c)
	var d3 := _cross(point - a, c - a)
	var has_negative := d1 < -0.000001 or d2 < -0.000001 or d3 < -0.000001
	var has_positive := d1 > 0.000001 or d2 > 0.000001 or d3 > 0.000001
	return not (has_negative and has_positive)


func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


func _mask_overlap(expected: PackedByteArray, actual: PackedByteArray) -> Dictionary:
	var intersection := 0
	var union := 0
	var expected_cells := 0
	var actual_cells := 0
	for index in range(mini(expected.size(), actual.size())):
		var expected_on := expected[index] != 0
		var actual_on := actual[index] != 0
		if expected_on:
			expected_cells += 1
		if actual_on:
			actual_cells += 1
		if expected_on and actual_on:
			intersection += 1
		if expected_on or actual_on:
			union += 1
	return {
		"iou": float(intersection) / float(union) if union > 0 else 0.0,
		"intersection_cells": intersection,
		"union_cells": union,
		"expected_cells": expected_cells,
		"actual_cells": actual_cells,
	}


func _mask_centroid(mask: PackedByteArray, bounds: Rect2) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for row in range(MASK_HEIGHT):
		for column in range(MASK_WIDTH):
			if mask[row * MASK_WIDTH + column] == 0:
				continue
			sum += Vector2(
				bounds.position.x + (float(column) + 0.5) / MASK_WIDTH * bounds.size.x,
				bounds.position.y + (float(row) + 0.5) / MASK_HEIGHT * bounds.size.y
			)
			count += 1
	return sum / float(count) if count > 0 else Vector2.ZERO


func _mask_contour_points(mask: PackedByteArray, bounds: Rect2) -> Array[Vector2]:
	var contour: Array[Vector2] = []
	for row in range(MASK_HEIGHT):
		for column in range(MASK_WIDTH):
			if mask[row * MASK_WIDTH + column] == 0:
				continue
			var is_boundary := false
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var neighbor_column: int = column + int(offset.x)
				var neighbor_row: int = row + int(offset.y)
				if (
					neighbor_column < 0
					or neighbor_column >= MASK_WIDTH
					or neighbor_row < 0
					or neighbor_row >= MASK_HEIGHT
					or mask[neighbor_row * MASK_WIDTH + neighbor_column] == 0
				):
					is_boundary = true
					break
			if not is_boundary:
				continue
			contour.append(Vector2(
				bounds.position.x + (float(column) + 0.5) / MASK_WIDTH * bounds.size.x,
				bounds.position.y + (float(row) + 0.5) / MASK_HEIGHT * bounds.size.y
			))
	return contour


func _bounds(points: Array[Vector2]) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _rect_iou(a: Rect2, b: Rect2) -> float:
	var intersection := a.intersection(b).get_area()
	var union := a.get_area() + b.get_area() - intersection
	return intersection / union if union > 0.0 else 0.0


func _symmetric_chamfer(expected: Array[Vector2], actual: Array[Vector2]) -> float:
	return (_mean_nearest_distance(expected, actual) + _mean_nearest_distance(actual, expected)) * 0.5


func _mean_nearest_distance(source: Array[Vector2], target: Array[Vector2]) -> float:
	if source.is_empty() or target.is_empty():
		return INF
	var total := 0.0
	for source_point in source:
		var nearest := INF
		for target_point in target:
			nearest = minf(nearest, source_point.distance_to(target_point))
		total += nearest
	return total / float(source.size())


func _unique_points(points: Array[Vector2]) -> Array[Vector2]:
	var unique: Array[Vector2] = []
	var seen: Dictionary = {}
	for point in points:
		var key := _point_key(point)
		if seen.has(key):
			continue
		seen[key] = true
		unique.append(point)
	return unique


func _point_key(point: Vector2) -> String:
	return "%d,%d" % [roundi(point.x * POINT_KEY_SCALE), roundi(point.y * POINT_KEY_SCALE)]


func _rect_to_array(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.end.x, rect.end.y]


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _write_report(report: Dictionary) -> void:
	report["passed"] = _failures.is_empty()
	report["failures"] = _failures
	report["generated_at_unix"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Could not write structure metrics report: %s" % REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(report: Dictionary) -> void:
	_write_report(report)
	print("==================================================")
	if _failures.is_empty():
		print("[Twin Bays Production Structure Metrics] PASS")
		quit(0)
		return
	print("[Twin Bays Production Structure Metrics] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
