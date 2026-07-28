extends RefCounted
class_name MomentumCircuitProductionConfig

const DEFAULT_PATH := "res://resources/maps/momentum_circuit_production_v9.json"
const SCHEMA_NAME := "chaos_gun.momentum_circuit_production"
const SCHEMA_VERSION := 9

static func load_default() -> Dictionary:
	return load_file(DEFAULT_PATH)

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Momentum Circuit production config does not exist: %s" % path)
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		push_error("Momentum Circuit production config is invalid: %s" % path)
		return {}
	var config := parser.data as Dictionary
	var errors := validate(config)
	if not errors.is_empty():
		push_error("Momentum Circuit production config validation failed:\n- %s" % "\n- ".join(errors))
		return {}
	return config

static func validate(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key in ["schema", "version", "layout_path", "foreground_path", "visual_reference", "teleporters", "light_bridges", "foreground_art", "hole_depth", "map_audio", "surface_style", "camera", "weapons", "cloud_vortex", "environment_dressing"]:
		if not config.has(key): errors.append("root.%s is required" % key)
	if String(config.get("schema", "")) != SCHEMA_NAME: errors.append("root.schema mismatch")
	if int(config.get("version", -1)) != SCHEMA_VERSION: errors.append("root.version must equal %d" % SCHEMA_VERSION)
	if String(config.get("layout_path", "")) != MomentumCircuitLayout.DEFAULT_PATH: errors.append("root.layout_path must reference layout v2")
	_validate_teleporters(config.get("teleporters"), errors)
	_validate_light_bridges(config.get("light_bridges"), errors)
	_validate_foreground_art(config.get("foreground_art"), errors)
	_validate_hole_depth(config.get("hole_depth"), errors)
	_validate_map_audio(config.get("map_audio"), errors)
	_validate_surface(config.get("surface_style"), errors)
	_validate_camera(config.get("camera"), errors)
	_validate_weapons(config.get("weapons"), errors)
	_validate_cloud(config.get("cloud_vortex"), errors)
	_validate_environment_dressing(config.get("environment_dressing"), errors)
	return errors

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

static func _validate_teleporters(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.teleporters must be a Dictionary"); return
	var tele := value as Dictionary
	for key in ["trigger_radius", "trigger_height", "cooldown_seconds", "landing_cooldown_seconds", "arrival_height", "occupied_radius", "occupied_retry_seconds", "trail_duration", "cooldown_ring_segments", "seed"]:
		_require_number(tele, key, "teleporters", errors)
	if float(tele.get("trigger_radius", 0.0)) <= 0.0: errors.append("teleporters.trigger_radius must be positive")
	if absf(float(tele.get("landing_cooldown_seconds", 0.0)) - 3.0) > 0.001: errors.append("teleporters.landing_cooldown_seconds must equal 3.0")
	if absf(float(tele.get("occupied_radius", 0.0)) - 2.6) > 0.001: errors.append("teleporters.occupied_radius must equal 2.6")
	if absf(float(tele.get("occupied_retry_seconds", 0.0)) - 0.25) > 0.001: errors.append("teleporters.occupied_retry_seconds must equal 0.25")
	if absf(float(tele.get("trail_duration", 0.0)) - 0.28) > 0.001: errors.append("teleporters.trail_duration must equal 0.28")
	if int(tele.get("cooldown_ring_segments", 0)) != 8: errors.append("teleporters.cooldown_ring_segments must equal 8")

static func _validate_light_bridges(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.light_bridges must be a Dictionary"); return
	var bridges := value as Dictionary
	for key in ["width", "top_y", "thickness", "active_seconds", "warning_seconds", "switching_seconds", "ai_warning_bias_weight", "traversal_speed", "bounce_speed", "bank_clearance", "capture_inset", "capture_lateral_margin", "capture_vertical_range", "arc_height", "arrival_lockout"]:
		_require_number(bridges, key, "light_bridges", errors)
	if not bool(bridges.get("enabled", false)): errors.append("light_bridges.enabled must be true")
	if not bool(bridges.get("forced_traversal_enabled", false)): errors.append("light_bridges.forced_traversal_enabled must be true")
	if absf(float(bridges.get("width", 0.0)) - 4.0) > 0.001: errors.append("light_bridges.width must equal 4.0")
	for key in ["thickness", "active_seconds", "warning_seconds", "switching_seconds", "traversal_speed", "bounce_speed", "bank_clearance", "capture_inset", "capture_vertical_range", "arrival_lockout"]:
		if float(bridges.get(key, 0.0)) <= 0.0: errors.append("light_bridges.%s must be positive" % key)
	if float(bridges.get("capture_lateral_margin", -1.0)) < 0.0: errors.append("light_bridges.capture_lateral_margin must not be negative")
	if float(bridges.get("arc_height", -1.0)) < 0.0: errors.append("light_bridges.arc_height must not be negative")
	var bias_weight := float(bridges.get("ai_warning_bias_weight", -1.0))
	if bias_weight < 0.0 or bias_weight > 1.0: errors.append("light_bridges.ai_warning_bias_weight must be within 0..1")
	if int(bridges.get("visual_layers", 0)) != 3: errors.append("light_bridges.visual_layers must equal 3")
	for key in ["active_color", "warning_color", "dormant_color"]:
		if not String(bridges.get(key, "")).is_valid_html_color(): errors.append("light_bridges.%s must be a color" % key)
	var order_value: Variant = bridges.get("order", [])
	var specs_value: Variant = bridges.get("bridges", [])
	if not order_value is Array or (order_value as Array).size() != 3:
		errors.append("light_bridges.order must contain three bridge ids")
		return
	if not specs_value is Array or (specs_value as Array).size() != 3:
		errors.append("light_bridges.bridges must contain three bridge specs")
		return
	var ids := {}
	var hole_ids := {}
	for index in range((specs_value as Array).size()):
		var spec_value: Variant = (specs_value as Array)[index]
		if not spec_value is Dictionary:
			errors.append("light_bridges.bridges[%d] must be a Dictionary" % index)
			continue
		var spec := spec_value as Dictionary
		var bridge_id := String(spec.get("id", ""))
		var hole_id := String(spec.get("hole_id", ""))
		if bridge_id.is_empty() or ids.has(bridge_id): errors.append("light_bridges bridge ids must be unique and non-empty")
		if hole_id.is_empty() or hole_ids.has(hole_id): errors.append("light_bridges hole ids must be unique and non-empty")
		ids[bridge_id] = true
		hole_ids[hole_id] = true
		if not _is_vector(spec.get("start_xz"), 2): errors.append("light_bridges.bridges[%d].start_xz must be a two-number array" % index)
		if not _is_vector(spec.get("end_xz"), 2): errors.append("light_bridges.bridges[%d].end_xz must be a two-number array" % index)
	var order_seen := {}
	for raw_id: Variant in order_value as Array:
		var bridge_id := String(raw_id)
		if not ids.has(bridge_id) or order_seen.has(bridge_id): errors.append("light_bridges.order must reference each bridge exactly once")
		order_seen[bridge_id] = true

static func _validate_foreground_art(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.foreground_art must be a Dictionary"); return
	var art := value as Dictionary
	if int(art.get("asset_version", 0)) != 9: errors.append("foreground_art.asset_version must equal 9")
	if int(art.get("panel_units", 0)) != 14: errors.append("foreground_art.panel_units must equal 14")
	if int(art.get("hole_inner_wall_layers", 0)) != 3: errors.append("foreground_art.hole_inner_wall_layers must equal 3")
	if int(art.get("endpoint_slot_count", 0)) != 6: errors.append("foreground_art.endpoint_slot_count must equal 6")
	if int(art.get("teleporter_device_layers", 0)) != 3: errors.append("foreground_art.teleporter_device_layers must equal 3")
	if float(art.get("max_device_height", 1.0)) > 0.3: errors.append("foreground_art.max_device_height must not exceed 0.3")
	if not bool(art.get("visual_only", false)): errors.append("foreground_art.visual_only must be true")

static func _validate_hole_depth(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.hole_depth must be a Dictionary"); return
	var depth := value as Dictionary
	if not bool(depth.get("enabled", false)): errors.append("hole_depth.enabled must be true")
	for key in ["occlusion_depth", "cloud_parallax_speed", "cloud_alpha"]:
		_require_number(depth, key, "hole_depth", errors)
	if int(depth.get("inner_wall_layers", 0)) != 3: errors.append("hole_depth.inner_wall_layers must equal 3")

static func _validate_map_audio(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.map_audio must be a Dictionary"); return
	var audio := value as Dictionary
	if not bool(audio.get("enabled", false)): errors.append("map_audio.enabled must be true")
	if int(audio.get("warning_pulse_count", 0)) != 4: errors.append("map_audio.warning_pulse_count must equal 4")
	for key in ["active_hum_db", "warning_db", "switch_db", "teleport_db", "ready_db", "max_distance"]:
		_require_number(audio, key, "map_audio", errors)

static func _validate_surface(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.surface_style must be a Dictionary"); return
	var style := value as Dictionary
	for key in ["base_color", "inset_color", "seam_color", "static_rim_color", "side_color"]:
		if not String(style.get(key, "")).is_valid_html_color(): errors.append("surface_style.%s must be a color" % key)
	if int(style.get("panel_count", 0)) != 14: errors.append("surface_style.panel_count must equal 14")
	if float(style.get("metallic_max", 1.0)) > 0.03: errors.append("surface_style.metallic_max too high")

static func _validate_camera(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.camera must be a Dictionary"); return
	var camera := value as Dictionary
	for key in ["profile_id", "map_focus", "view_offset", "initial_size", "idle_overview_size", "min_size", "max_size", "playable_min", "playable_max", "focus_min", "focus_max", "track_min_y", "world_frame_padding", "character_screen_radius", "screen_edge_gutter", "fallback_viewport"]:
		if not camera.has(key): errors.append("camera.%s is required" % key)

static func _validate_weapons(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.weapons must be a Dictionary"); return
	var weapons := value as Dictionary
	for key in ["initial_delay", "stay_duration", "respawn_cooldown", "max_active_pickups", "spawn_pool"]:
		if not weapons.has(key): errors.append("weapons.%s is required" % key)

static func _validate_cloud(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.cloud_vortex must be a Dictionary"); return
	var cloud := value as Dictionary
	for key in ["upper_angular_speed", "lower_angular_speed", "ev_reduction", "background_exposure"]:
		_require_number(cloud, key, "cloud_vortex", errors)
	if String(cloud.get("base_texture_path", "")).is_empty():
		errors.append("cloud_vortex.base_texture_path is required")
	if not _is_vector(cloud.get("background_plane_size"), 2):
		errors.append("cloud_vortex.background_plane_size must be a two-number array")


static func _validate_environment_dressing(value: Variant, errors: Array[String]) -> void:
	if not value is Dictionary:
		errors.append("root.environment_dressing must be a Dictionary"); return
	var dressing := value as Dictionary
	if not bool(dressing.get("enabled", false)):
		errors.append("environment_dressing.enabled must be true")
	if int(dressing.get("version", 0)) != 9:
		errors.append("environment_dressing.version must equal 9")
	if int(dressing.get("model_family_count", 0)) != 10:
		errors.append("environment_dressing.model_family_count must equal 10")
	if int(dressing.get("max_unique_triangles", 0)) > 35000:
		errors.append("environment_dressing.max_unique_triangles must not exceed 35000")
	if int(dressing.get("max_materials", 0)) > 5:
		errors.append("environment_dressing.max_materials must not exceed 5")
	if int(dressing.get("max_added_draw_calls", 0)) > 55:
		errors.append("environment_dressing.max_added_draw_calls must not exceed 55")
	if not bool(dressing.get("collision_free", false)):
		errors.append("environment_dressing.collision_free must be true")
	if not bool(dressing.get("shadow_free", false)):
		errors.append("environment_dressing.shadow_free must be true")
	if String(dressing.get("model_scene_path", "")).is_empty():
		errors.append("environment_dressing.model_scene_path is required")
	var layers := dressing.get("layers", []) as Array
	if layers.size() != 3:
		errors.append("environment_dressing.layers must contain exactly three layers")
	else:
		var layer_ids := {}
		for layer_value: Variant in layers:
			if not layer_value is Dictionary:
				errors.append("environment_dressing.layers entries must be Dictionaries")
				continue
			var layer := layer_value as Dictionary
			var layer_id := String(layer.get("id", ""))
			if layer_id.is_empty() or layer_ids.has(layer_id):
				errors.append("environment_dressing layer ids must be unique and non-empty")
			layer_ids[layer_id] = true
			_require_number(layer, "parallax", "environment_dressing.layers", errors)
	var ring_speeds := dressing.get("ring_angular_speeds", []) as Array
	if ring_speeds.size() != 2:
		errors.append("environment_dressing.ring_angular_speeds must contain two values")
	var routes := dressing.get("traffic_routes", []) as Array
	if routes.size() != 3:
		errors.append("environment_dressing.traffic_routes must contain exactly three routes")
	for route_value: Variant in routes:
		if not route_value is Dictionary:
			errors.append("environment_dressing traffic routes must be Dictionaries")
			continue
		var route := route_value as Dictionary
		var period := float(route.get("period", 0.0))
		if period < 18.0 or period > 32.0:
			errors.append("environment_dressing traffic periods must stay within 18..32 seconds")
		if not (route.get("points", []) is Array) or (route.get("points", []) as Array).size() < 4:
			errors.append("environment_dressing traffic routes need at least four points")
	var scan := dressing.get("sensor_scan", {}) as Dictionary
	if absf(float(scan.get("period", 0.0)) - 7.0) > 0.001:
		errors.append("environment_dressing.sensor_scan.period must equal 7.0")
	var scan_alpha := float(scan.get("max_alpha", -1.0))
	if scan_alpha < 0.0 or scan_alpha > 0.18:
		errors.append("environment_dressing.sensor_scan.max_alpha must stay within 0..0.18")

static func _require_number(value: Dictionary, key: String, prefix: String, errors: Array[String]) -> void:
	if not value.has(key) or not (value[key] is float or value[key] is int): errors.append("%s.%s must be numeric" % [prefix, key])

static func _is_vector(value: Variant, size: int) -> bool:
	if not value is Array or (value as Array).size() != size: return false
	for item in value as Array:
		if not (item is float or item is int): return false
	return true
