extends RefCounted
class_name MomentumCircuitLayout

const DEFAULT_PATH := "res://resources/maps/momentum_circuit_layout_v2.json"
const SCHEMA_NAME := "chaos_gun.momentum_circuit_layout"
const SCHEMA_VERSION := 2


static func load_default() -> Dictionary:
	return load_file(DEFAULT_PATH)


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Momentum Circuit layout file does not exist: %s" % path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		push_error("Momentum Circuit layout JSON parse error at line %d: %s" % [
			parser.get_error_line(),
			parser.get_error_message(),
		])
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		push_error("Momentum Circuit layout root must be a Dictionary: %s" % path)
		return {}
	var layout := parsed as Dictionary
	var errors := validate(layout)
	if not errors.is_empty():
		push_error("Momentum Circuit layout validation failed:\n- %s" % "\n- ".join(errors))
		return {}
	return layout


static func validate(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	_require_keys(
		layout,
		[
			"schema", "version", "source_image", "source_size_px", "units",
			"projection", "camera", "platform", "holes", "covers", "portals",
			"shockwave_nodes", "spawns", "validation",
		],
		"root",
		errors
	)
	if String(layout.get("schema", "")) != SCHEMA_NAME:
		errors.append("root.schema must equal %s" % SCHEMA_NAME)
	if int(layout.get("version", -1)) != SCHEMA_VERSION:
		errors.append("root.version must equal %d" % SCHEMA_VERSION)
	_require_vector(layout, "source_size_px", 2, "root", errors)
	_validate_units(layout.get("units"), errors)
	_validate_projection(layout.get("projection"), errors)
	_validate_camera(layout.get("camera"), errors)
	_validate_platform(layout.get("platform"), errors)
	_validate_holes(layout.get("holes"), errors)
	_validate_covers(layout.get("covers"), errors)
	_validate_portals(layout.get("portals"), errors)
	_validate_mechanism_nodes(layout.get("shockwave_nodes"), errors)
	_validate_spawns(layout.get("spawns"), layout.get("portals"), errors)
	_validate_reconstruction(layout.get("validation"), errors)
	return errors


static func vector2(value: Variant, field_name: String = "Vector2") -> Vector2:
	if not _is_vector(value, 2):
		push_error("%s must be a two-number array" % field_name)
		return Vector2.ZERO
	var values := value as Array
	return Vector2(float(values[0]), float(values[1]))


static func vector3(value: Variant, field_name: String = "Vector3") -> Vector3:
	if not _is_vector(value, 3):
		push_error("%s must be a three-number array" % field_name)
		return Vector3.ZERO
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func xz_vector3(value: Variant, y: float, field_name: String = "XZ point") -> Vector3:
	var point := vector2(value, field_name)
	return Vector3(point.x, y, point.y)


static func packed_vector2_array(
	value: Variant,
	field_name: String = "PackedVector2Array"
) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not value is Array:
		push_error("%s must be an array" % field_name)
		return result
	var values := value as Array
	for index in range(values.size()):
		result.append(vector2(values[index], "%s[%d]" % [field_name, index]))
	return result


static func find_by_id(items: Variant, item_id: String) -> Dictionary:
	if not items is Array:
		return {}
	for item_value: Variant in items as Array:
		if item_value is Dictionary:
			var item := item_value as Dictionary
			if String(item.get("id", "")) == item_id:
				return item
	return {}


static func _validate_units(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.units must be a Dictionary")
		return
	var units := value as Dictionary
	_require_keys(units, ["distance", "plane", "rotation"], "units", errors)
	if String(units.get("distance", "")) != "godot_world_units":
		errors.append("units.distance must equal godot_world_units")
	if String(units.get("plane", "")) != "xz":
		errors.append("units.plane must equal xz")
	if String(units.get("rotation", "")) != "yaw_degrees":
		errors.append("units.rotation must equal yaw_degrees")


static func _validate_projection(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.projection must be a Dictionary")
		return
	var projection := value as Dictionary
	_require_keys(
		projection,
		[
			"type", "screen_center_px", "world_units_per_pixel_x",
			"world_units_per_pixel_z", "world_y_for_layout",
		],
		"projection",
		errors
	)
	if String(projection.get("type", "")) != "orthographic_ground_plane":
		errors.append("projection.type must equal orthographic_ground_plane")
	_require_vector(projection, "screen_center_px", 2, "projection", errors)
	for key in ["world_units_per_pixel_x", "world_units_per_pixel_z", "world_y_for_layout"]:
		_require_number(projection, key, "projection", errors)


static func _validate_camera(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.camera must be a Dictionary")
		return
	var camera := value as Dictionary
	_require_keys(
		camera,
		[
			"projection", "yaw_degrees", "elevation_degrees",
			"orthographic_size_world", "viewport_size_px", "framing_origin_world_xz",
		],
		"camera",
		errors
	)
	if String(camera.get("projection", "")) != "orthographic":
		errors.append("camera.projection must equal orthographic")
	for key in ["yaw_degrees", "elevation_degrees", "orthographic_size_world"]:
		_require_number(camera, key, "camera", errors)
	_require_vector(camera, "viewport_size_px", 2, "camera", errors)
	_require_vector(camera, "framing_origin_world_xz", 2, "camera", errors)


static func _validate_platform(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.platform must be a Dictionary")
		return
	var platform := value as Dictionary
	_require_keys(
		platform,
		[
			"top_y", "depth", "bottom_y", "bounds_world_xz", "dimensions_world",
			"outline_world_xz", "visual_top_outline_world_xz",
		],
		"platform",
		errors
	)
	for key in ["top_y", "depth", "bottom_y"]:
		_require_number(platform, key, "platform", errors)
	_validate_outline(platform.get("outline_world_xz"), "platform.outline_world_xz", errors)
	_validate_outline(
		platform.get("visual_top_outline_world_xz"),
		"platform.visual_top_outline_world_xz",
		errors
	)
	if _is_number(platform.get("top_y")) and _is_number(platform.get("bottom_y")) and _is_number(platform.get("depth")):
		var reconstructed_top := float(platform.get("bottom_y")) + float(platform.get("depth"))
		if not is_equal_approx(reconstructed_top, float(platform.get("top_y"))):
			errors.append("platform.bottom_y + platform.depth must equal platform.top_y")


static func _validate_holes(value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.holes must be an Array")
		return
	var holes := value as Array
	if holes.size() != 3:
		errors.append("holes must contain exactly 3 entries, got %d" % holes.size())
	_validate_unique_ids(holes, "holes", errors)
	for index in range(holes.size()):
		if not holes[index] is Dictionary:
			errors.append("holes[%d] must be a Dictionary" % index)
			continue
		var hole := holes[index] as Dictionary
		var path := "holes[%d]" % index
		_require_keys(
			hole,
			["id", "center_world_xz", "outline_world_xz", "visual_top_outline_world_xz"],
			path,
			errors
		)
		_require_vector(hole, "center_world_xz", 2, path, errors)
		_validate_outline(hole.get("outline_world_xz"), path + ".outline_world_xz", errors)
		_validate_outline(
			hole.get("visual_top_outline_world_xz"),
			path + ".visual_top_outline_world_xz",
			errors
		)


static func _validate_covers(value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.covers must be an Array")
		return
	var covers := value as Array
	if not covers.is_empty():
		errors.append("covers must be empty in the coverless v2 layout, got %d entries" % covers.size())


static func _validate_portals(value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.portals must be an Array")
		return
	var portals := value as Array
	if portals.size() != 4:
		errors.append("portals must contain exactly 4 entries, got %d" % portals.size())
	_validate_unique_ids(portals, "portals", errors)
	for index in range(portals.size()):
		if not portals[index] is Dictionary:
			errors.append("portals[%d] must be a Dictionary" % index)
			continue
		var portal := portals[index] as Dictionary
		var path := "portals[%d]" % index
		_require_keys(
			portal,
			["id", "paired_portal_id", "position_world", "component_bounds_xywh_px"],
			path,
			errors
		)
		_require_vector(portal, "position_world", 3, path, errors)
		_require_vector(portal, "component_bounds_xywh_px", 4, path, errors)
		var pair_id := String(portal.get("paired_portal_id", ""))
		var pair := find_by_id(portals, pair_id)
		if pair.is_empty():
			errors.append("%s.paired_portal_id does not reference another portal" % path)
		elif String(pair.get("paired_portal_id", "")) != String(portal.get("id", "")):
			errors.append("%s portal pairing must be reciprocal" % path)


static func _validate_mechanism_nodes(value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.shockwave_nodes must be an Array")
		return
	var nodes := value as Array
	if nodes.size() != 3:
		errors.append("shockwave_nodes must contain exactly 3 entries, got %d" % nodes.size())
	_validate_unique_ids(nodes, "shockwave_nodes", errors)
	for index in range(nodes.size()):
		if not nodes[index] is Dictionary:
			errors.append("shockwave_nodes[%d] must be a Dictionary" % index)
			continue
		var node := nodes[index] as Dictionary
		var path := "shockwave_nodes[%d]" % index
		_require_keys(node, ["id", "position_world", "component_bounds_xywh_px"], path, errors)
		_require_vector(node, "position_world", 3, path, errors)
		_require_vector(node, "component_bounds_xywh_px", 4, path, errors)


static func _validate_spawns(
	value: Variant,
	portal_value: Variant,
	errors: Array[String]
) -> void:
	if not value is Array:
		errors.append("root.spawns must be an Array")
		return
	var spawns := value as Array
	if spawns.size() != 4:
		errors.append("spawns must contain exactly 4 entries, got %d" % spawns.size())
	_validate_unique_ids(spawns, "spawns", errors)
	for index in range(spawns.size()):
		if not spawns[index] is Dictionary:
			errors.append("spawns[%d] must be a Dictionary" % index)
			continue
		var spawn := spawns[index] as Dictionary
		var path := "spawns[%d]" % index
		_require_keys(
			spawn,
			["id", "source_portal_id", "position_world", "inward_direction_world_xz"],
			path,
			errors
		)
		_require_vector(spawn, "position_world", 3, path, errors)
		_require_vector(spawn, "inward_direction_world_xz", 2, path, errors)
		if find_by_id(portal_value, String(spawn.get("source_portal_id", ""))).is_empty():
			errors.append("%s.source_portal_id does not reference a portal" % path)


static func _validate_reconstruction(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.validation must be a Dictionary")
		return
	var validation := value as Dictionary
	_require_keys(
		validation,
		[
			"reconstruction_iou", "minimum_required_iou", "visual_projection_depth_pixels",
			"visual_projection_iou", "visual_projection_minimum_required_iou", "passed", "counts",
		],
		"validation",
		errors
	)
	_require_number(validation, "reconstruction_iou", "validation", errors)
	_require_number(validation, "minimum_required_iou", "validation", errors)
	_require_number(validation, "visual_projection_depth_pixels", "validation", errors)
	_require_number(validation, "visual_projection_iou", "validation", errors)
	_require_number(validation, "visual_projection_minimum_required_iou", "validation", errors)
	if (
		_is_number(validation.get("visual_projection_iou"))
		and _is_number(validation.get("visual_projection_minimum_required_iou"))
	):
		var required_iou := maxf(
			0.95,
			float(validation.get("visual_projection_minimum_required_iou"))
		)
		if float(validation.get("visual_projection_iou")) < required_iou:
			errors.append(
				"validation.visual_projection_iou must be at least %.6f" % required_iou
			)
	if validation.get("passed") != true:
		errors.append("validation.passed must be true")


static func _validate_outline(value: Variant, path: String, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("%s must be an Array" % path)
		return
	var points := value as Array
	if points.size() < 3:
		errors.append("%s must contain at least 3 points" % path)
	for index in range(points.size()):
		if not _is_vector(points[index], 2):
			errors.append("%s[%d] must be a two-number array" % [path, index])


static func _validate_unique_ids(items: Array, path: String, errors: Array[String]) -> void:
	var seen: Dictionary = {}
	for index in range(items.size()):
		if not items[index] is Dictionary:
			continue
		var item := items[index] as Dictionary
		var item_id := String(item.get("id", ""))
		if item_id.is_empty():
			errors.append("%s[%d].id must be a non-empty String" % [path, index])
		elif seen.has(item_id):
			errors.append("%s.id values must be unique: %s" % [path, item_id])
		seen[item_id] = true


static func _require_keys(
	value: Dictionary,
	keys: Array,
	path: String,
	errors: Array[String]
) -> void:
	for key_value: Variant in keys:
		var key := String(key_value)
		if not value.has(key):
			errors.append("%s.%s is required" % [path, key])


static func _require_number(
	value: Dictionary,
	key: String,
	path: String,
	errors: Array[String]
) -> void:
	if not _is_number(value.get(key)):
		errors.append("%s.%s must be numeric" % [path, key])


static func _require_vector(
	value: Dictionary,
	key: String,
	dimensions: int,
	path: String,
	errors: Array[String]
) -> void:
	if not _is_vector(value.get(key), dimensions):
		errors.append("%s.%s must be a %d-number array" % [path, key, dimensions])


static func _is_vector(value: Variant, dimensions: int) -> bool:
	return value is Array and (value as Array).size() == dimensions and _all_numbers(value as Array)


static func _all_numbers(values: Array) -> bool:
	for value: Variant in values:
		if not _is_number(value):
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
