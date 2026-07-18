extends RefCounted
class_name MomentumCircuitProductionConfig

const DEFAULT_PATH := "res://resources/maps/momentum_circuit_production_v2.json"
const SCHEMA_NAME := "chaos_gun.momentum_circuit_production"
const SCHEMA_VERSION := 2


static func load_default() -> Dictionary:
	return load_file(DEFAULT_PATH)


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Momentum Circuit production config does not exist: %s" % path)
		return {}
	var parser := JSON.new()
	var parse_error := parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		push_error("Momentum Circuit production config JSON parse error at line %d: %s" % [
			parser.get_error_line(),
			parser.get_error_message(),
		])
		return {}
	if not parser.data is Dictionary:
		push_error("Momentum Circuit production config root must be a Dictionary")
		return {}
	var config := parser.data as Dictionary
	var errors := validate(config)
	if not errors.is_empty():
		push_error("Momentum Circuit production config validation failed:\n- %s" % "\n- ".join(errors))
		return {}
	return config


static func validate(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["schema", "version", "layout_path", "visual_reference", "gravity", "anchors", "surface_style", "camera", "weapons", "cloud_vortex"]:
		if not config.has(key):
			errors.append("root.%s is required" % key)
	if String(config.get("schema", "")) != SCHEMA_NAME:
		errors.append("root.schema must equal %s" % SCHEMA_NAME)
	if int(config.get("version", -1)) != SCHEMA_VERSION:
		errors.append("root.version must equal %d" % SCHEMA_VERSION)
	if String(config.get("layout_path", "")) != MomentumCircuitLayout.DEFAULT_PATH:
		errors.append("root.layout_path must reference the authoritative v2 layout")

	_validate_gravity(config.get("gravity"), errors)
	_validate_anchors(config.get("anchors"), errors)
	_validate_surface_style(config.get("surface_style"), errors)
	_validate_camera(config.get("camera"), errors)
	_validate_weapons(config.get("weapons"), errors)
	_validate_cloud(config.get("cloud_vortex"), errors)
	return errors


static func _validate_surface_style(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.surface_style must be a Dictionary")
		return
	var style := value as Dictionary
	for key in ["base_color", "inset_color", "seam_color", "static_rim_color", "side_color"]:
		var token := String(style.get(key, ""))
		if not token.is_valid_html_color() or token.length() != 7:
			errors.append("surface_style.%s must be a #RRGGBB color" % key)
	for key in ["panel_count", "seam_width", "static_rim_width", "static_rim_emission", "roughness_min", "roughness_max", "metallic_max"]:
		_require_number(style, key, "surface_style", errors)
	if int(style.get("panel_count", 0)) != 14:
		errors.append("surface_style.panel_count must equal 14")
	if float(style.get("roughness_min", 0.0)) < 0.78 or float(style.get("roughness_max", 1.0)) > 0.84:
		errors.append("surface_style roughness must remain within 0.78-0.84")
	if float(style.get("metallic_max", 1.0)) > 0.03:
		errors.append("surface_style.metallic_max must not exceed 0.03")
	if float(style.get("static_rim_emission", 1.0)) > 0.35:
		errors.append("surface_style.static_rim_emission must not exceed 0.35")


static func vector2(value: Variant, field_name: String) -> Vector2:
	if not _is_vector(value, 2):
		push_error("%s must be a two-number array" % field_name)
		return Vector2.ZERO
	var values := value as Array
	return Vector2(float(values[0]), float(values[1]))


static func vector3(value: Variant, field_name: String) -> Vector3:
	if not _is_vector(value, 3):
		push_error("%s must be a three-number array" % field_name)
		return Vector3.ZERO
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func _validate_gravity(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.gravity must be a Dictionary")
		return
	var gravity := value as Dictionary
	for key in ["corridor_x_min", "corridor_y_min", "corridor_y_max", "warning_seconds", "active_seconds", "reversing_seconds", "recovery_seconds", "global_guard_seconds", "node_cooldown_seconds", "acceleration", "max_field_axis_speed", "initial_direction"]:
		_require_number(gravity, key, "gravity", errors)
	if not _is_vector(gravity.get("axis_world"), 3):
		errors.append("gravity.axis_world must be a three-number array")
	if int(gravity.get("initial_direction", 0)) not in [-1, 1]:
		errors.append("gravity.initial_direction must be -1 or 1")


static func _validate_anchors(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.anchors must be a Dictionary")
		return
	var anchors := value as Dictionary
	for key in ["outer_radius", "core_radius", "brake_seconds"]:
		_require_number(anchors, key, "anchors", errors)
	if float(anchors.get("outer_radius", 0.0)) <= float(anchors.get("core_radius", 0.0)):
		errors.append("anchors.outer_radius must be larger than anchors.core_radius")


static func _validate_camera(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.camera must be a Dictionary")
		return
	var camera := value as Dictionary
	for key in ["initial_size", "idle_overview_size", "min_size", "max_size", "track_min_y", "world_frame_padding", "character_screen_radius", "screen_edge_gutter"]:
		_require_number(camera, key, "camera", errors)
	for entry in [["map_focus", 3], ["view_offset", 3], ["playable_min", 2], ["playable_max", 2], ["focus_min", 2], ["focus_max", 2], ["fallback_viewport", 2]]:
		if not _is_vector(camera.get(entry[0]), int(entry[1])):
			errors.append("camera.%s must be a %d-number array" % [entry[0], entry[1]])
	if float(camera.get("min_size", 0.0)) >= float(camera.get("max_size", 0.0)):
		errors.append("camera.min_size must be smaller than camera.max_size")


static func _validate_weapons(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.weapons must be a Dictionary")
		return
	var weapons := value as Dictionary
	for key in ["initial_delay", "stay_duration", "respawn_cooldown", "max_active_pickups"]:
		_require_number(weapons, key, "weapons", errors)
	var expected := ["smg", "ak_rifle", "shotgun", "gatling", "sniper"]
	if weapons.get("spawn_pool", []) != expected:
		errors.append("weapons.spawn_pool must preserve the five-weapon default pool")


static func _validate_cloud(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.cloud_vortex must be a Dictionary")
		return
	var cloud := value as Dictionary
	for key in ["upper_angular_speed", "lower_angular_speed"]:
		_require_number(cloud, key, "cloud_vortex", errors)
	if float(cloud.get("upper_angular_speed", 0.0)) * float(cloud.get("lower_angular_speed", 0.0)) >= 0.0:
		errors.append("cloud vortex layers must counter-rotate")


static func _require_number(value: Dictionary, key: String, path: String, errors: Array[String]) -> void:
	if not _is_number(value.get(key)):
		errors.append("%s.%s must be numeric" % [path, key])


static func _is_vector(value: Variant, dimensions: int) -> bool:
	if not value is Array or (value as Array).size() != dimensions:
		return false
	for entry in value as Array:
		if not _is_number(entry):
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]
