extends RefCounted
class_name TwinBaysResidueShapes

## Deterministic concept-aligned residual-water silhouettes shared by rendering
## and interaction queries. These are area-shaped puddles, never path ribbons.

const MAJOR_VERTICES := 24
const SECONDARY_VERTICES := 20
const DROPLET_VERTICES := 16


static func build_puddle_polygons(
	networks: Array,
	drain_progress: float,
	platform: PackedVector2Array,
	exclusions: Array,
	art: Dictionary
) -> Array[PackedVector2Array]:
	var progress := clampf(drain_progress, 0.0, 1.0)
	if progress >= 0.999 or platform.size() < 3:
		return []
	var topology := art.get("residue_topology", {}) as Dictionary
	if String(topology.get("style", "")) == "source_connected_clear_water":
		return _build_source_connected_runoff(
			networks, progress, platform, exclusions, topology
		)
	var polygons: Array[PackedVector2Array] = []
	var major_scale := lerpf(1.0, 0.50, progress)
	var secondary_scale := maxf(0.0, 1.0 - smoothstep(0.18, 0.72, progress))
	var droplet_scale := maxf(0.0, 1.0 - smoothstep(0.06, 0.48, progress))
	var max_aspect := float(topology.get("max_aspect_ratio", 2.2))
	for network_value: Variant in networks:
		var network := network_value as Dictionary
		var points := network.get("points", []) as Array
		if points.size() < 4:
			continue
		var seed_value: int = absi(String(network.get("id", "puddle")).hash())
		var p1 := _v2(points[1] as Array)
		var p2 := _v2(points[2] as Array)
		var p3 := _v2(points[3] as Array)
		var direction := (p2 - p1).normalized()
		if direction.length_squared() < 0.001:
			direction = Vector2.RIGHT
		var normal := Vector2(-direction.y, direction.x)
		var width := float(network.get("width_start", 5.0))
		var major_center := p1.lerp(p2, 0.30) + normal * _signed_noise(seed_value, 3) * 0.55
		var major_radii := Vector2(width * 0.72, width * 0.54) * major_scale
		major_radii.x = minf(major_radii.x, major_radii.y * max_aspect)
		_try_add_polygon(polygons, major_center, major_radii, direction.angle(), seed_value, MAJOR_VERTICES, platform, exclusions)

		if secondary_scale > 0.04:
			var second_direction := (p3 - p2).normalized()
			if second_direction.length_squared() < 0.001:
				second_direction = direction
			var second_normal := Vector2(-second_direction.y, second_direction.x)
			var second_center := p3.lerp(p2, 0.28) + second_normal * _signed_noise(seed_value, 7) * 0.42
			var second_radii := Vector2(width * 0.43, width * 0.35) * secondary_scale
			_try_add_polygon(polygons, second_center, second_radii, second_direction.angle(), seed_value + 97, SECONDARY_VERTICES, platform, exclusions)

		if droplet_scale > 0.04:
			for droplet_index in range(2):
				var droplet_center := p2.lerp(p3, 0.55 + float(droplet_index) * 0.20)
				droplet_center += normal * (_signed_noise(seed_value, 11 + droplet_index) * (1.9 + float(droplet_index) * 0.35))
				var radius := width * (0.12 + 0.025 * float((seed_value + droplet_index) % 3)) * droplet_scale
				_try_add_polygon(polygons, droplet_center, Vector2(radius, radius * 0.86), 0.0, seed_value + 173 + droplet_index, DROPLET_VERTICES, platform, exclusions)

	polygons = _merge_overlapping(polygons)
	var target_coverage := _target_coverage(progress, topology)
	return _merge_overlapping(_normalize_coverage(polygons, platform, exclusions, target_coverage))


static func _build_source_connected_runoff(
	networks: Array,
	progress: float,
	platform: PackedVector2Array,
	exclusions: Array,
	topology: Dictionary
) -> Array[PackedVector2Array]:
	# V5 runoff is made from overlapping rounded aprons. It retains a readable
	# connection to the wall/pipe source without producing long tapered ribbons
	# or sharp leaf tips across the combat floor.
	var polygons: Array[PackedVector2Array] = []
	var reach := lerpf(0.34, 0.16, smoothstep(0.0, 0.92, progress))
	var radius_scale := lerpf(1.28, 0.66, progress)
	for network_value: Variant in networks:
		var network := network_value as Dictionary
		var values := network.get("points", []) as Array
		if values.size() < 2:
			continue
		var controls := PackedVector2Array()
		for value: Variant in values:
			controls.append(_v2(value as Array))
		var samples := _sample_polyline_prefix(controls, reach, 0.72)
		if samples.size() < 2:
			continue
		var seed_value: int = absi(String(network.get("id", "runoff")).hash())
		var width_start := float(network.get("width_start", 5.0))
		var width_end := maxf(float(network.get("width_end", 1.2)), width_start * 0.42)
		var network_lobes: Array[PackedVector2Array] = []
		for sample_index in range(samples.size()):
			var t := float(sample_index) / maxf(float(samples.size() - 1), 1.0)
			# The end remains round and substantial instead of collapsing to a
			# point. Small low-frequency variation prevents a stamped capsule.
			var width := lerpf(width_start, width_end, smoothstep(0.0, 1.0, t))
			var modulation := 1.0 + sin(t * TAU * 1.35 + float(seed_value % 29)) * 0.07
			var radius := width * 0.48 * radius_scale * modulation
			var before := samples[maxi(0, sample_index - 1)]
			var after := samples[mini(samples.size() - 1, sample_index + 1)]
			var direction := (after - before).normalized()
			if direction.length_squared() < 0.001:
				direction = Vector2.RIGHT
			var center := samples[sample_index]
			var lobe_radii := Vector2(radius * 1.02, radius * 0.94)
			_try_add_polygon(
				network_lobes, center, lobe_radii, direction.angle(),
				seed_value + sample_index * 17, 18, platform, exclusions
			)
		polygons.append_array(_merge_overlapping(network_lobes))
	polygons = _merge_overlapping(polygons)
	var target_coverage := _target_coverage(progress, topology)
	return _merge_overlapping(
		_normalize_coverage(polygons, platform, exclusions, target_coverage)
	)


static func _sample_polyline_prefix(
	controls: PackedVector2Array,
	reach: float,
	spacing: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if controls.size() < 2:
		return result
	var total_length := 0.0
	for index in range(controls.size() - 1):
		total_length += controls[index].distance_to(controls[index + 1])
	var target_length := total_length * clampf(reach, 0.08, 1.0)
	var travelled := 0.0
	result.append(controls[0])
	for index in range(controls.size() - 1):
		var start := controls[index]
		var finish := controls[index + 1]
		var segment_length := start.distance_to(finish)
		if segment_length <= 0.001:
			continue
		var remaining := target_length - travelled
		if remaining <= 0.001:
			break
		var used_length := minf(segment_length, remaining)
		var step_count := maxi(1, ceili(used_length / maxf(spacing, 0.25)))
		for step in range(1, step_count + 1):
			var distance_on_segment := minf(
				used_length, float(step) * used_length / float(step_count)
			)
			result.append(start.lerp(finish, distance_on_segment / segment_length))
		travelled += used_length
	return result


static func scaled_polygons(polygons: Array[PackedVector2Array], scale_value: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon in polygons:
		var center := centroid(polygon)
		var scaled := PackedVector2Array()
		for point in polygon:
			scaled.append(center + (point - center) * scale_value)
		result.append(scaled)
	return result


static func point_in_any(point: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


static func build_exclusions(layout: Dictionary, clean: Dictionary) -> Array:
	var result: Array = []
	for marker_value: Variant in layout.get("pickup_markers", []):
		result.append({"center": _xz((marker_value as Dictionary).get("position", []) as Array), "radius": float(clean.get("ordinary_pickup_radius", 2.5))})
	var special := layout.get("special_pickup_marker", {}) as Dictionary
	result.append({"center": _xz(special.get("position", []) as Array), "radius": float(clean.get("special_pickup_radius", 3.5))})
	for spawn_value: Variant in layout.get("spawns", []):
		result.append({"center": _xz((spawn_value as Dictionary).get("position", []) as Array), "radius": float(clean.get("spawn_radius", 2.5))})
	for cover_value: Variant in layout.get("covers", []):
		var cover := cover_value as Dictionary
		var size := cover.get("size", []) as Array
		var radius := maxf(float(size[0]), float(size[2])) * 0.5 + float(clean.get("cover_margin", 0.5))
		result.append({"center": _xz(cover.get("position", []) as Array), "radius": radius})
	for portal_value: Variant in layout.get("portals", []):
		result.append({"center": _xz((portal_value as Dictionary).get("position", []) as Array), "radius": float(clean.get("portal_exit_radius", 2.5))})
	return result


static func coverage(polygons: Array[PackedVector2Array], platform: PackedVector2Array) -> float:
	var platform_area := absf(polygon_area(platform))
	if platform_area <= 0.001:
		return 0.0
	var puddle_area := 0.0
	for polygon in polygons:
		puddle_area += absf(polygon_area(polygon))
	return puddle_area / platform_area


static func centroid(polygon: PackedVector2Array) -> Vector2:
	var result := Vector2.ZERO
	if polygon.is_empty():
		return result
	for point in polygon:
		result += point
	return result / float(polygon.size())


static func polygon_area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for index in range(polygon.size()):
		var current := polygon[index]
		var following := polygon[(index + 1) % polygon.size()]
		result += current.x * following.y - following.x * current.y
	return result * 0.5


static func _try_add_polygon(
	result: Array[PackedVector2Array],
	center: Vector2,
	radii: Vector2,
	rotation: float,
	seed_value: int,
	vertex_count: int,
	platform: PackedVector2Array,
	exclusions: Array
) -> void:
	if radii.x < 0.18 or radii.y < 0.18 or not _point_allowed(center, platform, exclusions):
		return
	var fitted_radii := radii
	for _attempt in range(8):
		var polygon := _organic_polygon(center, fitted_radii, rotation, seed_value, vertex_count)
		if _polygon_allowed(polygon, platform, exclusions):
			result.append(polygon)
			return
		fitted_radii *= 0.84


static func _organic_polygon(center: Vector2, radii: Vector2, rotation: float, seed_value: int, vertex_count: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var phase := float(seed_value % 997) * 0.037
	for index in range(vertex_count):
		var angle := TAU * float(index) / float(vertex_count)
		var modulation := 1.0
		modulation += sin(angle * 3.0 + phase) * 0.115
		modulation += sin(angle * 5.0 - phase * 0.71) * 0.058
		modulation += sin(angle * 7.0 + phase * 1.31) * 0.026
		var local := Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * modulation
		polygon.append(center + local.rotated(rotation))
	return polygon


static func _normalize_coverage(
	polygons: Array[PackedVector2Array],
	platform: PackedVector2Array,
	exclusions: Array,
	target: float
) -> Array[PackedVector2Array]:
	var current := coverage(polygons, platform)
	if current <= 0.001 or target <= 0.001:
		return polygons
	var desired_scale := clampf(sqrt(target / current), 0.72, 1.42)
	var result: Array[PackedVector2Array] = []
	for polygon in polygons:
		var center := centroid(polygon)
		var factor := desired_scale
		for _attempt in range(8):
			var candidate := PackedVector2Array()
			for point in polygon:
				candidate.append(center + (point - center) * factor)
			if _polygon_allowed(candidate, platform, exclusions):
				result.append(candidate)
				break
			factor *= 0.90
	return result


static func _merge_overlapping(source: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for source_polygon in source:
		var candidate := source_polygon
		var did_merge := true
		while did_merge:
			did_merge = false
			for index in range(result.size() - 1, -1, -1):
				if Geometry2D.intersect_polygons(candidate, result[index]).is_empty():
					continue
				var merged := Geometry2D.merge_polygons(candidate, result[index])
				if merged.size() != 1:
					continue
				candidate = merged[0]
				result.remove_at(index)
				did_merge = true
		result.append(candidate)
	return result


static func _target_coverage(progress: float, topology: Dictionary) -> float:
	var start_target := float(topology.get("drain_start_coverage", 0.15))
	var midpoint_target := float(topology.get("drain_mid_coverage", 0.08))
	if progress <= 0.5:
		return lerpf(start_target, midpoint_target, progress / 0.5)
	return lerpf(midpoint_target, 0.0, (progress - 0.5) / 0.5)


static func _polygon_allowed(polygon: PackedVector2Array, platform: PackedVector2Array, exclusions: Array) -> bool:
	for point in polygon:
		if not _point_allowed(point, platform, exclusions):
			return false
	return true


static func _point_allowed(point: Vector2, platform: PackedVector2Array, exclusions: Array) -> bool:
	if not Geometry2D.is_point_in_polygon(point, platform):
		return false
	for exclusion_value: Variant in exclusions:
		var exclusion := exclusion_value as Dictionary
		if point.distance_to(exclusion.get("center", Vector2.INF) as Vector2) < float(exclusion.get("radius", 0.0)):
			return false
	return true


static func _signed_noise(seed_value: int, salt: int) -> float:
	var value := sin(float(seed_value % 10007) * 0.0137 + float(salt) * 2.173)
	return clampf(value, -1.0, 1.0)


static func _v2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1]))


static func _xz(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[2])) if values.size() >= 3 else Vector2.INF
