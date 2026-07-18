extends RefCounted
class_name TwinBaysLayout

const DEFAULT_PATH := "res://resources/maps/twin_bays_layout_v1.json"
const SCHEMA_NAME := "chaos_gun.twin_bays_layout"
const SCHEMA_VERSION := 1

static func load_default() -> Dictionary:
	return load_file(DEFAULT_PATH)

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Twin Bays layout file does not exist: %s" % path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		push_error("Twin Bays layout JSON parse error at line %d: %s" % [
			parser.get_error_line(),
			parser.get_error_message(),
		])
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		push_error("Twin Bays layout root must be a Dictionary: %s" % path)
		return {}
	var layout := parsed as Dictionary
	var errors := validate(layout)
	if not errors.is_empty():
		push_error("Twin Bays layout validation failed:\n- %s" % "\n- ".join(errors))
		return {}
	return layout

static func validate(layout: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	_require_keys(layout, ["schema", "version", "units", "platform", "walls", "portal_pipes", "covers", "spawns", "pickup_markers", "special_pickup_marker", "portals", "runtime"], "root", errors)
	if layout.get("schema") != SCHEMA_NAME:
		errors.append("root.schema must equal %s" % SCHEMA_NAME)
	if int(layout.get("version", -1)) != SCHEMA_VERSION:
		errors.append("root.version must equal %d" % SCHEMA_VERSION)

	_validate_units(layout.get("units"), errors)
	_validate_platform(layout.get("platform"), errors)
	_validate_walls(layout.get("walls"), errors)
	_validate_portal_pipes(layout.get("portal_pipes"), layout.get("portals"), errors)
	_validate_blocks(layout.get("covers"), "covers", 10, true, errors)
	_validate_spawns(layout.get("spawns"), errors)
	_validate_pickups(layout.get("pickup_markers"), errors)
	_validate_special_pickup(layout.get("special_pickup_marker"), errors)
	_validate_portals(layout.get("portals"), layout.get("portal_pipes"), errors)
	_validate_runtime(layout.get("runtime"), errors)
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

static func packed_vector2_array(value: Variant, field_name: String = "PackedVector2Array") -> PackedVector2Array:
	var result := PackedVector2Array()
	if not value is Array:
		push_error("%s must be an array" % field_name)
		return result
	var values := value as Array
	for index in range(values.size()):
		result.append(vector2(values[index], "%s[%d]" % [field_name, index]))
	return result

static func float_array(value: Variant, field_name: String = "float array") -> Array[float]:
	var result: Array[float] = []
	if not value is Array:
		push_error("%s must be an array" % field_name)
		return result
	var values := value as Array
	for index in range(values.size()):
		if not _is_number(values[index]):
			push_error("%s[%d] must be numeric" % [field_name, index])
			return []
		result.append(float(values[index]))
	return result

static func find_by_id(items: Variant, item_id: String) -> Dictionary:
	if not items is Array:
		return {}
	for value: Variant in items as Array:
		if value is Dictionary and String((value as Dictionary).get("id", "")) == item_id:
			return value as Dictionary
	return {}

static func _validate_units(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.units must be a Dictionary")
		return
	var units := value as Dictionary
	_require_keys(units, ["distance", "plane", "rotation"], "units", errors)
	if units.get("distance") != "godot_world_units":
		errors.append("units.distance must equal godot_world_units")
	if units.get("plane") != "xz":
		errors.append("units.plane must equal xz")
	if units.get("rotation") != "yaw_degrees":
		errors.append("units.rotation must equal yaw_degrees")

static func _validate_platform(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.platform must be a Dictionary")
		return
	var platform := value as Dictionary
	_require_keys(platform, ["floor_top_y", "depth", "outline", "bevel_cap", "top_cap", "causeway"], "platform", errors)
	_require_number(platform, "floor_top_y", "platform", errors)
	_require_number(platform, "depth", "platform", errors)
	var outline: Variant = platform.get("outline")
	if not outline is Array:
		errors.append("platform.outline must be an Array")
	else:
		var points := outline as Array
		if points.size() != 116:
			errors.append("platform.outline must contain exactly 116 points, got %d" % points.size())
		_validate_vector_array(points, 2, "platform.outline", errors)
	for cap_key in ["bevel_cap", "top_cap"]:
		var cap: Variant = platform.get(cap_key)
		if not cap is Dictionary:
			errors.append("platform.%s must be a Dictionary" % cap_key)
			continue
		var cap_data := cap as Dictionary
		_require_keys(cap_data, ["inset", "depth", "base_y"], "platform.%s" % cap_key, errors)
		for key in ["inset", "depth", "base_y"]:
			_require_number(cap_data, key, "platform.%s" % cap_key, errors)
	var causeway: Variant = platform.get("causeway")
	if not causeway is Dictionary:
		errors.append("platform.causeway must be a Dictionary")
		return
	var causeway_data := causeway as Dictionary
	_require_keys(causeway_data, ["id", "visible_width", "safe_width", "collision_position", "collision_size"], "platform.causeway", errors)
	_require_number(causeway_data, "visible_width", "platform.causeway", errors)
	_require_number(causeway_data, "safe_width", "platform.causeway", errors)
	_require_vector(causeway_data, "collision_position", 3, "platform.causeway", errors)
	_require_vector(causeway_data, "collision_size", 3, "platform.causeway", errors)

static func _validate_walls(value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.walls must be an Array")
		return
	var walls := value as Array
	if walls.size() != 4:
		errors.append("walls must contain exactly 4 entries, got %d" % walls.size())
	_validate_unique_strings(walls, "id", "walls", errors)
	_validate_unique_strings(walls, "node_prefix", "walls", errors)
	var section_count := 0
	for index in range(walls.size()):
		if not walls[index] is Dictionary:
			errors.append("walls[%d] must be a Dictionary" % index)
			continue
		var wall := walls[index] as Dictionary
		var path := "walls[%d]" % index
		_require_keys(wall, ["id", "node_prefix", "material_role", "points", "sections", "cap_inset", "cap_depth"], path, errors)
		if String(wall.get("material_role", "")) not in ["north", "south"]:
			errors.append("%s.material_role must be north or south" % path)
		var points: Variant = wall.get("points")
		if not points is Array or (points as Array).size() < 2:
			errors.append("%s.points must contain at least 2 points" % path)
		else:
			_validate_vector_array(points as Array, 2, "%s.points" % path, errors)
		var sections: Variant = wall.get("sections")
		if not sections is Array or (sections as Array).is_empty():
			errors.append("%s.sections must contain at least 1 entry" % path)
		else:
			section_count += (sections as Array).size()
			for section_index in range((sections as Array).size()):
				_validate_wall_section((sections as Array)[section_index], "%s.sections[%d]" % [path, section_index], (points as Array).size() if points is Array else 0, errors)
		_require_number(wall, "cap_inset", path, errors)
		_require_number(wall, "cap_depth", path, errors)
	if section_count != 6:
		errors.append("walls must contain exactly 6 authored sections, got %d" % section_count)

static func _validate_wall_section(value: Variant, path: String, point_count: int, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("%s must be a Dictionary" % path)
		return
	var section := value as Dictionary
	_require_keys(section, ["start", "end_exclusive", "label", "offsets", "thicknesses", "height"], path, errors)
	for key in ["start", "end_exclusive", "label"]:
		if typeof(section.get(key)) != TYPE_INT and typeof(section.get(key)) != TYPE_FLOAT:
			errors.append("%s.%s must be numeric" % [path, key])
	var start := int(section.get("start", -1))
	var end_exclusive := int(section.get("end_exclusive", -1))
	if start < 0 or end_exclusive <= start or end_exclusive > point_count:
		errors.append("%s range [%d, %d) is invalid for %d points" % [path, start, end_exclusive, point_count])
	var expected_size := maxi(end_exclusive - start, 0)
	for key in ["offsets", "thicknesses"]:
		var values: Variant = section.get(key)
		if not values is Array or (values as Array).size() != expected_size:
			errors.append("%s.%s must contain %d numbers" % [path, key, expected_size])
		elif not _all_numbers(values as Array):
			errors.append("%s.%s must contain only numbers" % [path, key])
	_require_number(section, "height", path, errors)

static func _validate_portal_pipes(value: Variant, portal_value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.portal_pipes must be an Array")
		return
	var pipes := value as Array
	if pipes.size() != 2:
		errors.append("portal_pipes must contain exactly 2 entries, got %d" % pipes.size())
	_validate_unique_strings(pipes, "id", "portal_pipes", errors)
	_validate_unique_strings(pipes, "node_name", "portal_pipes", errors)
	_validate_unique_strings(pipes, "portal_id", "portal_pipes", errors)
	for index in range(pipes.size()):
		if not pipes[index] is Dictionary:
			errors.append("portal_pipes[%d] must be a Dictionary" % index)
			continue
		var pipe := pipes[index] as Dictionary
		var path := "portal_pipes[%d]" % index
		_require_keys(pipe, ["id", "node_name", "portal_id", "outer_radius", "inner_radius", "collar_outer_radius", "collar_depth", "radial_segments", "path", "water_entry_position", "water_entry_foam_radius"], path, errors)
		if find_by_id(portal_value, String(pipe.get("portal_id", ""))).is_empty():
			errors.append("%s.portal_id does not reference a portal" % path)
		for radius_key in ["outer_radius", "inner_radius", "collar_outer_radius"]:
			_require_vector(pipe, radius_key, 2, path, errors)
		_require_number(pipe, "collar_depth", path, errors)
		_require_number(pipe, "radial_segments", path, errors)
		_require_number(pipe, "water_entry_foam_radius", path, errors)
		_require_vector(pipe, "water_entry_position", 3, path, errors)
		var points: Variant = pipe.get("path")
		if not points is Array or (points as Array).size() < 4:
			errors.append("%s.path must contain at least 4 points" % path)
		else:
			_validate_vector_array(points as Array, 3, "%s.path" % path, errors)
		var outer := vector2(pipe.get("outer_radius"), "%s.outer_radius" % path)
		var inner := vector2(pipe.get("inner_radius"), "%s.inner_radius" % path)
		if inner.x <= 0.0 or inner.y <= 0.0 or outer.x <= inner.x or outer.y <= inner.y:
			errors.append("%s outer radius must be larger than its positive inner radius" % path)

static func _validate_blocks(value: Variant, path: String, expected_count: int, require_lightness: bool, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.%s must be an Array" % path)
		return
	var items := value as Array
	if items.size() != expected_count:
		errors.append("%s must contain exactly %d entries, got %d" % [path, expected_count, items.size()])
	_validate_unique_strings(items, "id", path, errors)
	_validate_unique_strings(items, "node_name", path, errors)
	for index in range(items.size()):
		if not items[index] is Dictionary:
			errors.append("%s[%d] must be a Dictionary" % [path, index])
			continue
		var item := items[index] as Dictionary
		var item_path := "%s[%d]" % [path, index]
		_require_keys(item, ["id", "node_name", "position", "size", "yaw_degrees", "bevel"], item_path, errors)
		_require_vector(item, "position", 3, item_path, errors)
		_require_vector(item, "size", 3, item_path, errors)
		_require_number(item, "yaw_degrees", item_path, errors)
		_require_number(item, "bevel", item_path, errors)
		if require_lightness:
			_require_number(item, "side_lightness", item_path, errors)

static func _validate_spawns(value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.spawns must be an Array")
		return
	var spawns := value as Array
	if spawns.size() != 4:
		errors.append("spawns must contain exactly 4 entries, got %d" % spawns.size())
	_validate_unique_strings(spawns, "id", "spawns", errors)
	for index in range(spawns.size()):
		if not spawns[index] is Dictionary:
			errors.append("spawns[%d] must be a Dictionary" % index)
			continue
		var spawn := spawns[index] as Dictionary
		_require_keys(spawn, ["id", "position"], "spawns[%d]" % index, errors)
		_require_vector(spawn, "position", 3, "spawns[%d]" % index, errors)

static func _validate_pickups(value: Variant, errors: Array[String]) -> void:
	_validate_blocks(value, "pickup_markers", 4, false, errors)
	if not value is Array:
		return
	var pickups := value as Array
	for index in range(pickups.size()):
		if pickups[index] is Dictionary:
			_require_vector(pickups[index] as Dictionary, "spawn_position", 3, "pickup_markers[%d]" % index, errors)

static func _validate_special_pickup(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.special_pickup_marker must be a Dictionary")
		return
	var entries: Array = [value]
	_validate_blocks(entries, "special_pickup_marker", 1, false, errors)
	_require_vector(value as Dictionary, "spawn_position", 3, "special_pickup_marker", errors)

static func _validate_portals(value: Variant, pipe_value: Variant, errors: Array[String]) -> void:
	if not value is Array:
		errors.append("root.portals must be an Array")
		return
	var portals := value as Array
	if portals.size() != 2:
		errors.append("portals must contain exactly 2 entries, got %d" % portals.size())
	_validate_unique_strings(portals, "id", "portals", errors)
	_validate_unique_strings(portals, "node_name", "portals", errors)
	for index in range(portals.size()):
		if not portals[index] is Dictionary:
			errors.append("portals[%d] must be a Dictionary" % index)
			continue
		var portal := portals[index] as Dictionary
		var path := "portals[%d]" % index
		_require_keys(portal, ["id", "node_name", "paired_portal_id", "pipe_id", "position", "cooldown_seconds", "trigger", "exit", "normal", "ring", "core", "light"], path, errors)
		_require_vector(portal, "position", 3, path, errors)
		_require_vector(portal, "normal", 3, path, errors)
		_require_number(portal, "cooldown_seconds", path, errors)
		if find_by_id(portals, String(portal.get("paired_portal_id", ""))).is_empty():
			errors.append("%s.paired_portal_id does not reference another portal" % path)
		if find_by_id(pipe_value, String(portal.get("pipe_id", ""))).is_empty():
			errors.append("%s.pipe_id does not reference a portal pipe" % path)
		_validate_portal_part(portal.get("trigger"), ["local_position", "size"], ["local_position", "size"], path + ".trigger", errors)
		_validate_portal_part(portal.get("exit"), ["node_name", "local_position"], ["local_position"], path + ".exit", errors)
		_validate_portal_part(portal.get("ring"), ["local_position", "inner_radius", "outer_radius", "segments", "scale"], ["local_position", "scale"], path + ".ring", errors)
		_validate_portal_part(portal.get("core"), ["local_position", "radius", "segments", "scale"], ["local_position", "scale"], path + ".core", errors)
		_validate_portal_part(portal.get("light"), ["local_position", "range", "energy"], ["local_position"], path + ".light", errors)

static func _validate_portal_part(value: Variant, keys: Array, vector_keys: Array, path: String, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("%s must be a Dictionary" % path)
		return
	var part := value as Dictionary
	_require_keys(part, keys, path, errors)
	for key: Variant in vector_keys:
		_require_vector(part, String(key), 3, path, errors)
	for key: Variant in keys:
		var key_string := String(key)
		if key_string not in vector_keys and key_string != "node_name":
			_require_number(part, key_string, path, errors)

static func _validate_runtime(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.runtime must be a Dictionary")
		return
	var runtime := value as Dictionary
	var keys := [
		"default_lives",
		"respawn_delay",
		"invincible_duration",
		"fall_threshold",
		"pickup_initial_delay",
		"pickup_stay_duration",
		"pickup_respawn_cooldown",
		"pickup_max_active",
		"special_pickup_initial_delay",
		"special_pickup_stay_duration",
		"special_pickup_interval",
		"special_pickup_max_active",
	]
	_require_keys(runtime, keys, "runtime", errors)
	for key: Variant in keys:
		_require_number(runtime, String(key), "runtime", errors)

static func _require_keys(value: Dictionary, keys: Array, path: String, errors: Array[String]) -> void:
	for key: Variant in keys:
		if not value.has(key):
			errors.append("%s.%s is required" % [path, String(key)])

static func _require_number(value: Dictionary, key: String, path: String, errors: Array[String]) -> void:
	if not _is_number(value.get(key)):
		errors.append("%s.%s must be numeric" % [path, key])

static func _require_vector(value: Dictionary, key: String, dimensions: int, path: String, errors: Array[String]) -> void:
	if not _is_vector(value.get(key), dimensions):
		errors.append("%s.%s must be a %d-number array" % [path, key, dimensions])

static func _validate_vector_array(values: Array, dimensions: int, path: String, errors: Array[String]) -> void:
	for index in range(values.size()):
		if not _is_vector(values[index], dimensions):
			errors.append("%s[%d] must be a %d-number array" % [path, index, dimensions])

static func _validate_unique_strings(items: Array, key: String, path: String, errors: Array[String]) -> void:
	var seen := {}
	for index in range(items.size()):
		if not items[index] is Dictionary:
			continue
		var text := String((items[index] as Dictionary).get(key, ""))
		if text.is_empty():
			errors.append("%s[%d].%s must be a non-empty String" % [path, index, key])
		elif seen.has(text):
			errors.append("%s.%s values must be unique: %s" % [path, key, text])
		seen[text] = true

static func _is_vector(value: Variant, dimensions: int) -> bool:
	return value is Array and (value as Array).size() == dimensions and _all_numbers(value as Array)

static func _all_numbers(values: Array) -> bool:
	for value: Variant in values:
		if not _is_number(value):
			return false
	return true

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
