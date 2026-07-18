extends SceneTree

const SCENE_PATH := "res://scenes/maps/momentum_circuit_whitebox.tscn"
const LAYOUT_PATH := "res://resources/maps/momentum_circuit_layout_v2.json"
const BATTLE_ARENA_SCRIPT_PATH := "res://scripts/maps/battle_arena.gd"
const LAYOUT_SCRIPT := preload("res://scripts/maps/momentum_circuit_layout.gd")
const VIEWPORT_SIZE := Vector2i(1536, 1024)
const POSITION_EPSILON := 0.03
const ANGLE_EPSILON_DEGREES := 0.08
const POLYGON_EPSILON := 0.03

var _failures: Array[String] = []
var _host: Node = null
var _arena: Node3D = null
var _layout: Dictionary = {}


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit Whitebox Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	root.size = VIEWPORT_SIZE

	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		await _finish()
		return
	match_config.slots = [
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]

	_layout = _load_layout()
	if _layout.is_empty():
		await _finish()
		return

	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	_host = Node.new()
	_host.name = "MomentumCircuitVerifierHost"
	root.add_child(_host)
	_arena = packed_scene.instantiate() as Node3D
	if _arena == null:
		_fail("Momentum Circuit scene root is not a Node3D")
		await _finish()
		return
	_host.add_child(_arena)
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame

	_verify_layout_contract()
	_verify_required_nodes_and_groups()
	_verify_platform_geometry()
	_verify_platform_collision()
	_verify_coverless_contract()
	_verify_spawns()
	_verify_camera()
	_verify_portals()
	_verify_shockwave()
	_verify_activators()
	_verify_development_scene_isolated(match_config)

	await _finish()


func _load_layout() -> Dictionary:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		_fail("Could not open authoritative layout: %s" % LAYOUT_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Authoritative layout is not valid JSON object data")
		return {}
	return parsed as Dictionary


func _verify_layout_contract() -> void:
	print("\n--- Authoritative Layout ---")
	var validation_errors: Array[String] = LAYOUT_SCRIPT.validate(_layout)
	if not validation_errors.is_empty():
		_fail("Layout helper rejected authoritative data: %s" % "; ".join(validation_errors))
	if String(_layout.get("schema", "")) != "chaos_gun.momentum_circuit_layout":
		_fail("Unexpected layout schema: %s" % String(_layout.get("schema", "<missing>")))
	if int(_layout.get("version", -1)) != 2:
		_fail("Unexpected layout version: %s" % str(_layout.get("version", "<missing>")))

	_verify_layout_collection("holes", 3)
	_verify_layout_collection("covers", 0)
	_verify_layout_collection("portals", 4)
	_verify_layout_collection("shockwave_nodes", 3)
	_verify_layout_collection("spawns", 4)

	var platform := _layout.get("platform", {}) as Dictionary
	_compare_float(float(platform.get("top_y", NAN)), 1.0, 0.001, "platform top Y")
	_compare_float(float(platform.get("depth", NAN)), 4.0, 0.001, "platform depth")
	var outline := _packed_vector2_array(platform.get("outline_world_xz", []))
	if outline.size() < 24 or Geometry2D.triangulate_polygon(outline).is_empty():
		_fail("Platform source-projection outline must be detailed and triangulatable")
	var visual_outline := _packed_vector2_array(
		platform.get("visual_top_outline_world_xz", [])
	)
	if visual_outline.size() < 24 or Geometry2D.triangulate_polygon(visual_outline).is_empty():
		_fail("Platform visual-top outline must be detailed and triangulatable")

	for hole_value: Variant in _layout.get("holes", []) as Array:
		var hole := hole_value as Dictionary
		var hole_outline := _packed_vector2_array(hole.get("outline_world_xz", []))
		if hole_outline.size() < 3 or Geometry2D.triangulate_polygon(hole_outline).is_empty():
			_fail("Layout source-projection hole is invalid: %s" % String(hole.get("id", "<missing>")))
		var visual_hole_outline := _packed_vector2_array(
			hole.get("visual_top_outline_world_xz", [])
		)
		if visual_hole_outline.size() < 3 or Geometry2D.triangulate_polygon(visual_hole_outline).is_empty():
			_fail("Layout visual-top hole is invalid: %s" % String(hole.get("id", "<missing>")))

	var validation := _layout.get("validation", {}) as Dictionary
	var reconstruction_iou := float(validation.get("reconstruction_iou", 0.0))
	if not bool(validation.get("passed", false)) or reconstruction_iou < 0.95:
		_fail("Authoritative extraction validation is below 95%%: %.6f" % reconstruction_iou)
	else:
		print("OK  source reconstruction IoU: %.6f" % reconstruction_iou)
	var visual_projection_iou := float(validation.get("visual_projection_iou", 0.0))
	if visual_projection_iou < 0.95:
		_fail("Visual slab projection validation is below 95%%: %.6f" % visual_projection_iou)
	else:
		print("OK  visual slab projection IoU: %.6f" % visual_projection_iou)

	var expected_pairs := {
		"portal_01": "portal_04",
		"portal_02": "portal_03",
		"portal_03": "portal_02",
		"portal_04": "portal_01",
	}
	for portal_value: Variant in _layout.get("portals", []) as Array:
		var portal := portal_value as Dictionary
		var portal_id := String(portal.get("id", ""))
		if not expected_pairs.has(portal_id):
			_fail("Unexpected portal id in layout: %s" % portal_id)
		elif String(portal.get("paired_portal_id", "")) != String(expected_pairs[portal_id]):
			_fail("Incorrect authoritative pairing for %s" % portal_id)
	print("OK  layout schema, topology, counts, and portal pairing")


func _verify_layout_collection(key: String, expected_count: int) -> void:
	var collection: Variant = _layout.get(key, null)
	if not collection is Array:
		_fail("Layout collection missing: %s" % key)
		return
	var values := collection as Array
	if values.size() != expected_count:
		_fail("Layout %s count differs: %d != %d" % [key, values.size(), expected_count])
	var ids: Dictionary = {}
	for value: Variant in values:
		if not value is Dictionary:
			_fail("Layout %s contains a non-object entry" % key)
			continue
		var identifier := String((value as Dictionary).get("id", ""))
		if identifier.is_empty() or ids.has(identifier):
			_fail("Layout %s contains missing or duplicate id: %s" % [key, identifier])
		ids[identifier] = true


func _verify_required_nodes_and_groups() -> void:
	print("\n--- Required Nodes And Groups ---")
	if not _script_inherits_path(_arena.get_script() as Script, BATTLE_ARENA_SCRIPT_PATH):
		_fail("Momentum Circuit scene root must inherit battle_arena.gd")
	var required_paths := [
		"MomentumCircuitWhitebox",
		"MomentumCircuitWhitebox/ArenaSurface",
		"MomentumCircuitWhitebox/ArenaSurface/PlatformBody",
		"MomentumCircuitWhitebox/ArenaSurface/VoidHole01",
		"MomentumCircuitWhitebox/ArenaSurface/VoidHole02",
		"MomentumCircuitWhitebox/ArenaSurface/VoidHole03",
		"MomentumCircuitMechanisms",
		"MomentumCircuitMechanisms/Portals",
		"MomentumCircuitMechanisms/Shockwave/CircuitShockwave",
		"MomentumCircuitMechanisms/Shockwave/Activators",
		"MomentumCircuitSpawns",
		"GlobalCamera",
		"WeaponSpawner",
		"PauseMenu",
	]
	for index in range(1, 5):
		var portal_path := "MomentumCircuitMechanisms/Portals/Portal%02d" % index
		required_paths.append(portal_path)
		for child_name in ["TriggerShape", "ExitMarker", "PortalRing", "PortalCore"]:
			required_paths.append("%s/%s" % [portal_path, child_name])
		required_paths.append("MomentumCircuitSpawns/Spawn%02d" % index)
	for index in range(1, 4):
		required_paths.append(
			"MomentumCircuitMechanisms/Shockwave/Activators/ShockwaveNode%02d" % index
		)

	for path in required_paths:
		if _arena.get_node_or_null(path) == null:
			_fail("Missing required node: %s" % path)

	_verify_group("momentum_circuit_geometry", 1, [
		"MomentumCircuitWhitebox/ArenaSurface",
	])
	_verify_group("momentum_circuit_cover", 0, [])
	var portal_paths: Array[String] = []
	var spawn_paths: Array[String] = []
	for index in range(1, 5):
		portal_paths.append("MomentumCircuitMechanisms/Portals/Portal%02d" % index)
		spawn_paths.append("MomentumCircuitSpawns/Spawn%02d" % index)
	_verify_group("momentum_circuit_portal", 4, portal_paths)
	_verify_group("momentum_circuit_spawn", 4, spawn_paths)
	var activator_paths: Array[String] = []
	for index in range(1, 4):
		activator_paths.append(
			"MomentumCircuitMechanisms/Shockwave/Activators/ShockwaveNode%02d" % index
		)
	_verify_group("momentum_circuit_shockwave_activator", 3, activator_paths)
	if _failures.is_empty():
		print("OK  complete node contract and exact group counts")


func _script_inherits_path(script: Script, expected_path: String) -> bool:
	var current := script
	while current != null:
		if current.resource_path == expected_path:
			return true
		current = current.get_base_script()
	return false


func _verify_group(group_name: String, expected_count: int, required_paths: Array[String]) -> void:
	var nodes := get_nodes_in_group(StringName(group_name))
	if nodes.size() != expected_count:
		_fail("Group %s count differs: %d != %d" % [group_name, nodes.size(), expected_count])
	for path in required_paths:
		var node := _arena.get_node_or_null(path)
		if node != null and not node.is_in_group(StringName(group_name)):
			_fail("Node is missing group %s: %s" % [group_name, path])


func _verify_platform_geometry() -> void:
	print("\n--- Platform CSG Geometry ---")
	var arena_surface := _arena.get_node_or_null("MomentumCircuitWhitebox/ArenaSurface")
	var subtraction_count := 0
	if arena_surface != null:
		for child: Node in arena_surface.get_children():
			if child is CSGShape3D and int(child.get("operation")) == 2:
				subtraction_count += 1
	if subtraction_count != 3:
		_fail("ArenaSurface must contain exactly three CSG subtraction holes, got %d" % subtraction_count)
	var platform := _arena.get_node_or_null(
		"MomentumCircuitWhitebox/ArenaSurface/PlatformBody"
	) as CSGPolygon3D
	if platform == null:
		_fail("PlatformBody must expose its authoritative polygon as CSGPolygon3D")
		return
	if int(platform.get("operation")) != 0:
		_fail("PlatformBody CSG operation must be union")

	var platform_data := _layout.get("platform", {}) as Dictionary
	var source_platform_outline := _packed_vector2_array(
		platform_data.get("outline_world_xz", [])
	)
	var visual_platform_outline := _packed_vector2_array(
		platform_data.get("visual_top_outline_world_xz", [])
	)
	_compare_polygon_any_start(
		platform.polygon,
		visual_platform_outline,
		"PlatformBody visual-top outline"
	)
	_compare_polygon_metadata(
		platform,
		&"source_projection_outline_world_xz",
		source_platform_outline,
		"PlatformBody source-projection metadata"
	)
	if arena_surface != null:
		_compare_polygon_metadata(
			arena_surface,
			&"source_projection_outline_world_xz",
			source_platform_outline,
			"ArenaSurface source-projection metadata"
		)
	_compare_float(platform.depth, float(platform_data.get("depth", 0.0)), 0.01, "PlatformBody depth")

	var holes := _layout.get("holes", []) as Array
	for index in range(3):
		var path := "MomentumCircuitWhitebox/ArenaSurface/VoidHole%02d" % (index + 1)
		var hole := _arena.get_node_or_null(path) as CSGPolygon3D
		if hole == null:
			_fail("%s must expose its subtraction polygon as CSGPolygon3D" % path)
			continue
		if int(hole.get("operation")) != 2:
			_fail("%s CSG operation must be subtraction" % path)
		var hole_data := holes[index] as Dictionary
		var source_hole_outline := _packed_vector2_array(
			hole_data.get("outline_world_xz", [])
		)
		_compare_polygon_any_start(
			hole.polygon,
			_packed_vector2_array(hole_data.get("visual_top_outline_world_xz", [])),
			"%s visual-top outline" % path
		)
		_compare_polygon_metadata(
			hole,
			&"source_projection_outline_world_xz",
			source_hole_outline,
			"%s source-projection metadata" % path
		)
	print("OK  one outer platform and three authoritative subtraction holes")


func _verify_platform_collision() -> void:
	print("\n--- Walkable Collision ---")
	if _arena.get_world_3d() == null:
		_fail("Momentum Circuit has no World3D for collision verification")
		return
	var space := _arena.get_world_3d().direct_space_state
	for spawn_value: Variant in _layout.get("spawns", []) as Array:
		var spawn := spawn_value as Dictionary
		var position := _vector3(spawn.get("position_world", []))
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(position.x, 8.0, position.z),
			Vector3(position.x, -6.0, position.z)
		)
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			_fail("Spawn has no platform collision below it: %s" % String(spawn.get("id", "<missing>")))
	for hole_value: Variant in _layout.get("holes", []) as Array:
		var hole := hole_value as Dictionary
		var center := _vector2(hole.get("center_world_xz", []))
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(center.x, 8.0, center.y),
			Vector3(center.x, -6.0, center.y)
		)
		query.collision_mask = 1
		if not space.intersect_ray(query).is_empty():
			_fail("Void center unexpectedly has platform collision: %s" % String(hole.get("id", "<missing>")))
	print("OK  four spawn floors collide and three void centers remain open")


func _verify_coverless_contract() -> void:
	print("\n--- Coverless Layout ---")
	if not (_layout.get("covers", []) as Array).is_empty():
		_fail("v2 layout covers array must be empty")
	if _arena.get_node_or_null("MomentumCircuitWhitebox/Covers") != null:
		_fail("Whitebox must not create a Covers node")
	if not get_nodes_in_group(&"momentum_circuit_cover").is_empty():
		_fail("Whitebox must not expose momentum_circuit_cover group members")
	print("OK  no cover nodes, collisions, or groups")


func _verify_spawns() -> void:
	print("\n--- Spawn Anchors ---")
	var spawns := _layout.get("spawns", []) as Array
	var expected_positions: Array[Vector3] = []
	for index in range(spawns.size()):
		var data := spawns[index] as Dictionary
		var expected := _vector3(data.get("position_world", []))
		expected_positions.append(expected)
		var marker := _arena.get_node_or_null(
			"MomentumCircuitSpawns/Spawn%02d" % (index + 1)
		) as Marker3D
		if marker == null:
			_fail("Spawn%02d must be a Marker3D" % (index + 1))
		else:
			_compare_vector3(marker.global_position, expected, POSITION_EPSILON, "Spawn%02d position" % (index + 1))

	if not _arena.has_method("_get_spawn_points"):
		_fail("Arena does not expose BattleArena spawn points")
		return
	var runtime_value: Variant = _arena.call("_get_spawn_points")
	if not runtime_value is Array:
		_fail("_get_spawn_points() did not return an Array")
		return
	var runtime_spawns := runtime_value as Array
	if runtime_spawns.size() != expected_positions.size():
		_fail("Runtime spawn count differs: %d != %d" % [runtime_spawns.size(), expected_positions.size()])
		return
	for index in range(expected_positions.size()):
		if not runtime_spawns[index] is Vector3:
			_fail("Runtime spawn %d is not a Vector3" % (index + 1))
			continue
		_compare_vector3(runtime_spawns[index] as Vector3, expected_positions[index], POSITION_EPSILON, "Runtime spawn %02d" % (index + 1))
	print("OK  four marker and runtime spawn positions match")


func _verify_camera() -> void:
	print("\n--- Fixed Reference Camera ---")
	var camera := _arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		return
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_fail("GlobalCamera must use orthographic projection")
	_compare_float(camera.size, 81.92, 0.001, "GlobalCamera orthographic size")
	var forward := -camera.global_basis.z.normalized()
	var elevation_radians := deg_to_rad(55.0)
	var expected_forward := Vector3(0.0, -sin(elevation_radians), -cos(elevation_radians))
	if forward.dot(expected_forward) < 0.9995:
		_fail("GlobalCamera orientation differs from yaw 0 / elevation 55: %s" % str(forward))
	if not camera.current:
		_fail("GlobalCamera must be current")
	if not _arena.has_method("_uses_fixed_runtime_camera") or not bool(_arena.call("_uses_fixed_runtime_camera")):
		_fail("Momentum Circuit must opt into its fixed runtime camera")
	var camera_data := _layout.get("camera", {}) as Dictionary
	var viewport_values := camera_data.get("viewport_size_px", []) as Array
	if viewport_values.size() != 2 or Vector2i(int(viewport_values[0]), int(viewport_values[1])) != VIEWPORT_SIZE:
		_fail("Authoritative camera viewport is not 1536x1024")
	print("OK  orthographic 1536x1024 reference camera")


func _verify_portals() -> void:
	print("\n--- Momentum Portal Pairs ---")
	var portals := _layout.get("portals", []) as Array
	var by_id: Dictionary = {}
	for index in range(portals.size()):
		var data := portals[index] as Dictionary
		var portal := _arena.get_node_or_null(
			"MomentumCircuitMechanisms/Portals/Portal%02d" % (index + 1)
		) as Node3D
		if portal == null:
			continue
		by_id[String(data.get("id", ""))] = portal
		_compare_vector3(portal.global_position, _vector3(data.get("position_world", [])), POSITION_EPSILON, "%s position" % portal.name)
		if not portal.has_method("get_debug_state"):
			_fail("%s does not expose portal debug configuration" % portal.name)
			continue
		var debug_value: Variant = portal.call("get_debug_state")
		if not debug_value is Dictionary or not bool((debug_value as Dictionary).get("configured", false)):
			_fail("%s is not configured" % portal.name)

	for data_value: Variant in portals:
		var data := data_value as Dictionary
		var source_id := String(data.get("id", ""))
		var destination_id := String(data.get("paired_portal_id", ""))
		var source := by_id.get(source_id) as Node3D
		var destination := by_id.get(destination_id) as Node3D
		if source == null or destination == null:
			_fail("Runtime portal pair is incomplete: %s -> %s" % [source_id, destination_id])
			continue
		var expected_marker := destination.get_node_or_null("ExitMarker") as Marker3D
		var actual_marker: Variant = source.get("destination_marker")
		if actual_marker != expected_marker:
			_fail("Runtime portal destination differs: %s -> %s" % [source_id, destination_id])
		var source_tangent: Variant = source.get("source_tangent")
		var destination_tangent: Variant = source.get("destination_tangent")
		if not source_tangent is Vector3 or (source_tangent as Vector3).length() < 0.99:
			_fail("%s source tangent is not normalized/configured" % source.name)
		if not destination_tangent is Vector3 or (destination_tangent as Vector3).length() < 0.99:
			_fail("%s destination tangent is not normalized/configured" % source.name)
	print("OK  Portal01 <-> Portal04 and Portal02 <-> Portal03")


func _verify_shockwave() -> void:
	print("\n--- Closed-Circuit Shockwave ---")
	var shockwave := _arena.get_node_or_null(
		"MomentumCircuitMechanisms/Shockwave/CircuitShockwave"
	) as Node3D
	if shockwave == null:
		return
	if not shockwave.has_method("get_debug_state"):
		_fail("CircuitShockwave does not expose configuration debug state")
		return
	var debug_value: Variant = shockwave.call("get_debug_state")
	if not debug_value is Dictionary:
		_fail("CircuitShockwave debug state is invalid")
		return
	var debug := debug_value as Dictionary
	if not bool(debug.get("curve_is_closed", false)):
		_fail("CircuitShockwave path is not closed")
	if float(debug.get("curve_length", 0.0)) <= 1.0:
		_fail("CircuitShockwave path has no useful length")
	if String(debug.get("state", "")) != "idle":
		_fail("CircuitShockwave should start idle")
	if not bool(shockwave.get_meta("path_validated_against_walkable_mask", false)):
		_fail("CircuitShockwave path was not validated against the visual walkable surface")
	var curve_value: Variant = shockwave.get("path_curve")
	if not curve_value is Curve3D:
		_fail("CircuitShockwave path_curve is missing")
	else:
		var curve := curve_value as Curve3D
		if curve.get_point_count() < 4:
			_fail("CircuitShockwave closed curve has too few points")
		elif curve.get_point_position(0).distance_to(curve.get_point_position(curve.get_point_count() - 1)) > 0.05:
			_fail("CircuitShockwave curve does not repeat its first point")
		_verify_curve_stays_walkable(curve)
	print("OK  configured closed path and idle shockwave controller")


func _verify_curve_stays_walkable(curve: Curve3D) -> void:
	var platform := _layout.get("platform", {}) as Dictionary
	var outer := _packed_vector2_array(platform.get("visual_top_outline_world_xz", []))
	var holes: Array[PackedVector2Array] = []
	for hole_value: Variant in _layout.get("holes", []) as Array:
		var hole := hole_value as Dictionary
		holes.append(_packed_vector2_array(hole.get("visual_top_outline_world_xz", [])))
	var length := curve.get_baked_length()
	var sample_count := maxi(1, int(ceil(length / 0.25)))
	for index in range(sample_count + 1):
		var point := curve.sample_baked(length * float(index) / float(sample_count), true)
		var point_xz := Vector2(point.x, point.z)
		if not Geometry2D.is_point_in_polygon(point_xz, outer):
			_fail("CircuitShockwave curve leaves outer walkable surface at %s" % str(point_xz))
			return
		for hole: PackedVector2Array in holes:
			if Geometry2D.is_point_in_polygon(point_xz, hole):
				_fail("CircuitShockwave curve enters a void at %s" % str(point_xz))
				return


func _verify_activators() -> void:
	print("\n--- Shockwave Activators ---")
	var shockwave := _arena.get_node_or_null(
		"MomentumCircuitMechanisms/Shockwave/CircuitShockwave"
	)
	var nodes := _layout.get("shockwave_nodes", []) as Array
	for index in range(nodes.size()):
		var data := nodes[index] as Dictionary
		var path := "MomentumCircuitMechanisms/Shockwave/Activators/ShockwaveNode%02d" % (index + 1)
		var activator := _arena.get_node_or_null(path) as Node3D
		if activator == null:
			continue
		_compare_vector3(activator.global_position, _vector3(data.get("position_world", [])), POSITION_EPSILON, "%s position" % path)
		if not activator.has_method("get_debug_state"):
			_fail("%s does not expose activator debug configuration" % path)
			continue
		var debug_value: Variant = activator.call("get_debug_state")
		if not debug_value is Dictionary:
			_fail("%s activator debug state is invalid" % path)
			continue
		var debug := debug_value as Dictionary
		if not bool(debug.get("controller_valid", false)) or activator.get("controller") != shockwave:
			_fail("%s is not configured to the circuit shockwave" % path)
		if not bool(debug.get("ready", false)):
			_fail("%s should start ready" % path)
		for direction_key in ["tangent", "side_axis"]:
			var direction_value: Variant = debug.get(direction_key, Vector3.ZERO)
			if not direction_value is Vector3 or (direction_value as Vector3).length() < 0.99:
				_fail("%s %s is not configured" % [path, direction_key])
			elif absf((direction_value as Vector3).y) > 0.001:
				_fail("%s %s must be horizontal" % [path, direction_key])
	_verify_activator_origin_and_warning_visual(shockwave as Node3D)
	print("OK  three positioned, ready, direction-selecting activators")


func _verify_activator_origin_and_warning_visual(shockwave: Node3D) -> void:
	if shockwave == null:
		return
	var activator := _arena.get_node_or_null(
		"MomentumCircuitMechanisms/Shockwave/Activators/ShockwaveNode01"
	) as Node3D
	if activator == null or not activator.has_method("apply_hit"):
		_fail("ShockwaveNode01 cannot receive a verifier hit")
		return
	var visual := shockwave.get_node_or_null("TravellingWaveVisual") as MeshInstance3D
	if visual == null:
		_fail("CircuitShockwave has no travelling warning/wave visual")
		return
	activator.call("apply_hit", Vector3.ZERO, 0.0, null, &"whitebox_verifier")
	var debug := shockwave.call("get_debug_state") as Dictionary
	if String(debug.get("state", "")) != "warning":
		_fail("Activator hit did not start the 1.5-second warning state")
	if int(debug.get("last_activator_instance_id", 0)) != activator.get_instance_id():
		_fail("Shockwave did not retain the struck map node as its origin")
	var curve := shockwave.get("path_curve") as Curve3D
	if curve != null:
		var expected_offset := curve.get_closest_offset(shockwave.to_local(activator.global_position))
		_compare_float(
			float(debug.get("start_curve_offset", -1.0)),
			expected_offset,
			0.01,
			"Shockwave activator-relative start offset"
		)
	shockwave.call("_physics_process", 0.0)
	if not visual.visible:
		_fail("Shockwave warning visual did not become visible")


func _verify_development_scene_isolated(match_config: Node) -> void:
	print("\n--- Development Scene Isolation ---")
	var maps: Variant = match_config.MAPS
	if maps is Array:
		for entry: Variant in maps as Array:
			if entry is Array and (entry as Array).size() > 1 and String((entry as Array)[1]) == SCENE_PATH:
				_fail("Standalone Momentum Circuit whitebox must not be in MatchConfig.MAPS")
				return
	print("OK  standalone whitebox is not exposed in the formal map pool")


func _packed_vector2_array(value: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not value is Array:
		return result
	for item: Variant in value as Array:
		if item is Array and (item as Array).size() >= 2:
			result.append(Vector2(float((item as Array)[0]), float((item as Array)[1])))
	return result


func _vector2(value: Variant) -> Vector2:
	if not value is Array or (value as Array).size() < 2:
		return Vector2(INF, INF)
	var values := value as Array
	return Vector2(float(values[0]), float(values[1]))


func _vector3(value: Variant) -> Vector3:
	if not value is Array or (value as Array).size() < 3:
		return Vector3(INF, INF, INF)
	var values := value as Array
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _compare_polygon_any_start(
	actual: PackedVector2Array,
	expected: PackedVector2Array,
	label: String
) -> void:
	if actual.size() != expected.size():
		_fail("%s point count differs: %d != %d" % [label, actual.size(), expected.size()])
		return
	if actual.is_empty():
		_fail("%s is empty" % label)
		return
	for reversed in [false, true]:
		for start in range(actual.size()):
			var matches := true
			for offset in range(actual.size()):
				var actual_index := posmod(start - offset if reversed else start + offset, actual.size())
				if actual[actual_index].distance_to(expected[offset]) > POLYGON_EPSILON:
					matches = false
					break
			if matches:
				return
	_fail("%s points differ from authoritative layout" % label)


func _compare_polygon_metadata(
	node: Node,
	key: StringName,
	expected: PackedVector2Array,
	label: String
) -> void:
	if not node.has_meta(key):
		_fail("%s is missing" % label)
		return
	var value: Variant = node.get_meta(key)
	if typeof(value) != TYPE_PACKED_VECTOR2_ARRAY:
		_fail("%s must be a PackedVector2Array" % label)
		return
	_compare_polygon_any_start(value as PackedVector2Array, expected, label)


func _compare_vector3(actual: Vector3, expected: Vector3, epsilon: float, label: String) -> void:
	if actual.distance_to(expected) > epsilon:
		_fail("%s differs: %s != %s" % [label, str(actual), str(expected)])


func _compare_float(actual: float, expected: float, epsilon: float, label: String) -> void:
	if is_nan(actual) or absf(actual - expected) > epsilon:
		_fail("%s differs: %.6f != %.6f" % [label, actual, expected])


func _compare_angle_degrees(actual: float, expected: float, label: String) -> void:
	if absf(wrapf(actual - expected, -180.0, 180.0)) > ANGLE_EPSILON_DEGREES:
		_fail("%s differs: %.6f != %.6f" % [label, actual, expected])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
	print("FAIL ", message)


func _finish() -> void:
	if _host != null and is_instance_valid(_host):
		_host.queue_free()
	await process_frame
	await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Momentum Circuit Whitebox Verifier] PASS")
		print("MOMENTUM_CIRCUIT_VERIFY_OK|failures=0")
		print("==================================================")
		quit(0)
		return

	print("[Momentum Circuit Whitebox Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("MOMENTUM_CIRCUIT_VERIFY_ERROR|failures=%d" % _failures.size())
	print("==================================================")
	quit(1)
