extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_whitebox.tscn"
const TwinBaysLayoutScript = preload("res://scripts/maps/twin_bays_layout.gd")
const LAYOUT_EPSILON := 0.01

var _failures: Array[String] = []
var _host: Node = null
var _arena: Node3D = null
var _layout: Dictionary = {}

func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Whitebox Verifier]")
	print("==================================================")

	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	var match_config = root.get_node_or_null("MatchConfig")
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

	_host = Node.new()
	_host.name = "TwinBaysVerifierHost"
	root.add_child(_host)
	_arena = packed_scene.instantiate() as Node3D
	_host.add_child(_arena)

	await process_frame
	await process_frame
	await physics_frame

	_layout = TwinBaysLayoutScript.load_default()
	_verify_required_nodes()
	_verify_authoritative_layout()
	_verify_curved_outline()
	_verify_causeway()
	_verify_spawn_and_void_samples()
	_verify_open_pickup_markers()
	_verify_portal_pair()
	_verify_development_scene_isolated(match_config)
	await _verify_runtime_teleport()

	await _finish()

func _verify_authoritative_layout() -> void:
	print("\n--- Authoritative Layout Data ---")
	if _layout.is_empty():
		_fail("Authoritative Twin Bays layout failed to load")
		return
	var errors: Array[String] = TwinBaysLayoutScript.validate(_layout)
	if not errors.is_empty():
		_fail("Authoritative layout schema validation failed: %s" % "; ".join(errors))
		return

	_verify_layout_platform()
	_verify_layout_walls()
	_verify_retired_portal_towers_absent()
	_verify_layout_blocks()
	_verify_removed_geometry_absent()
	_verify_layout_spawns()
	_verify_layout_portals()
	print("OK  layout schema/version and all runtime anchors match within %.2f" % LAYOUT_EPSILON)

func _verify_layout_platform() -> void:
	var platform := _layout["platform"] as Dictionary
	var surface := _arena.get_node_or_null("TwinBaysWhitebox/ArenaSurface") as CSGPolygon3D
	if surface == null:
		return
	var expected_outline := TwinBaysLayoutScript.packed_vector2_array(platform["outline"], "platform.outline")
	_compare_polygon(surface.polygon, expected_outline, "ArenaSurface outline")
	_compare_float(surface.depth, float(platform["depth"]), "ArenaSurface depth")
	_compare_float(surface.position.y, float(platform["floor_top_y"]) - float(platform["depth"]), "ArenaSurface base Y")

	var causeway := platform["causeway"] as Dictionary
	var body := _arena.get_node_or_null("TwinBaysWhitebox/CausewaySafetyCollision") as StaticBody3D
	if body == null:
		return
	_compare_vector3(body.position, TwinBaysLayoutScript.vector3(causeway["collision_position"]), "Causeway collision position")
	var collision := body.get_child(0) as CollisionShape3D
	var box := collision.shape as BoxShape3D if collision else null
	if box == null:
		_fail("Causeway safety collision must remain a BoxShape3D")
	else:
		_compare_vector3(box.size, TwinBaysLayoutScript.vector3(causeway["collision_size"]), "Causeway collision size")

func _verify_layout_walls() -> void:
	var map_root := _arena.get_node_or_null("TwinBaysWhitebox")
	if map_root == null:
		return
	var floor_top_y := float((_layout["platform"] as Dictionary)["floor_top_y"])
	for wall_value: Variant in _layout["walls"] as Array:
		var wall := wall_value as Dictionary
		var points := TwinBaysLayoutScript.packed_vector2_array(wall["points"])
		for section_value: Variant in wall["sections"] as Array:
			var section := section_value as Dictionary
			var shifted := PackedVector2Array()
			for point_index in range(int(section["start"]), int(section["end_exclusive"])):
				shifted.append(points[point_index])
			var offsets := TwinBaysLayoutScript.float_array(section["offsets"])
			for point_index in range(shifted.size()):
				shifted[point_index].y += offsets[point_index]
			var expected: PackedVector2Array = _arena.call(
				"_build_variable_width_polyline_footprint",
				shifted,
				TwinBaysLayoutScript.float_array(section["thicknesses"])
			)
			var node_name := "%s_%02d" % [wall["node_prefix"], int(section["label"])]
			var wall_node := map_root.get_node_or_null(node_name) as CSGPolygon3D
			if wall_node == null:
				_fail("Layout wall node missing: %s" % node_name)
				continue
			_compare_polygon(wall_node.polygon, expected, "%s footprint" % node_name)
			_compare_float(wall_node.depth, float(section["height"]), "%s height" % node_name)
			_compare_float(wall_node.position.y, floor_top_y, "%s base Y" % node_name)

func _verify_retired_portal_towers_absent() -> void:
	var map_root := _arena.get_node_or_null("TwinBaysWhitebox")
	if map_root == null:
		return
	for retired_name in ["LeftPortalTower", "RightPortalTower"]:
		if map_root.find_child(retired_name, true, false) != null:
			_fail("Retired portal wall remains in whitebox gameplay: %s" % retired_name)
	print("OK  retired portal wall bodies are absent from whitebox gameplay")

func _verify_layout_blocks() -> void:
	var map_root := _arena.get_node_or_null("TwinBaysWhitebox")
	if map_root == null:
		return
	for collection_name in ["covers", "pickup_markers"]:
		for item_value: Variant in _layout[collection_name] as Array:
			var item := item_value as Dictionary
			var node_name := String(item["node_name"])
			var root_node := map_root.get_node_or_null(node_name) as Node3D
			if root_node == null:
				_fail("Layout block node missing: %s" % node_name)
				continue
			_compare_vector3(root_node.position, TwinBaysLayoutScript.vector3(item["position"]), "%s position" % node_name)
			_compare_float(root_node.rotation_degrees.y, float(item["yaw_degrees"]), "%s yaw" % node_name)
			var mesh_instance := root_node.get_node_or_null("BeveledMesh") as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				_fail("Layout block mesh missing: %s" % node_name)
			else:
				_compare_vector3(mesh_instance.mesh.get_aabb().size, TwinBaysLayoutScript.vector3(item["size"]), "%s size" % node_name)
	var special_marker := _layout.get("special_pickup_marker", {}) as Dictionary
	if not special_marker.is_empty():
		_verify_layout_block(special_marker, map_root)

func _verify_layout_block(item: Dictionary, map_root: Node) -> void:
	var node_name := String(item["node_name"])
	var root_node := map_root.get_node_or_null(node_name) as Node3D
	if root_node == null:
		_fail("Layout block node missing: %s" % node_name)
		return
	_compare_vector3(root_node.position, TwinBaysLayoutScript.vector3(item["position"]), "%s position" % node_name)
	_compare_float(root_node.rotation_degrees.y, float(item["yaw_degrees"]), "%s yaw" % node_name)
	var mesh_instance := root_node.get_node_or_null("BeveledMesh") as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		_fail("Layout block mesh missing: %s" % node_name)
	else:
		_compare_vector3(mesh_instance.mesh.get_aabb().size, TwinBaysLayoutScript.vector3(item["size"]), "%s size" % node_name)

func _verify_removed_geometry_absent() -> void:
	for removed_name in [
		"WestNorthCoverInner",
		"EastNorthCoverInner",
		"WestSouthCoverInner",
		"EastSouthCoverInner",
		"WestSouthOuterWall_00",
		"EastSouthOuterWall_00",
	]:
		if _arena.find_child(removed_name, true, false) != null:
			_fail("Removed visual/collision node remains in whitebox: %s" % removed_name)
	print("OK  removed inner covers and south wall sections are absent")

func _verify_layout_spawns() -> void:
	var runtime_spawns := _arena.call("_get_spawn_points") as Array
	var layout_spawns := _layout["spawns"] as Array
	if runtime_spawns.size() != layout_spawns.size():
		_fail("Runtime spawn count differs from layout")
		return
	for index in range(layout_spawns.size()):
		var spawn := layout_spawns[index] as Dictionary
		_compare_vector3(runtime_spawns[index] as Vector3, TwinBaysLayoutScript.vector3(spawn["position"]), "Spawn %s" % spawn["id"])

func _verify_layout_portals() -> void:
	var portal_root := _arena.get_node_or_null("TwinBaysPortals")
	if portal_root == null:
		return
	for portal_value: Variant in _layout["portals"] as Array:
		var portal_data := portal_value as Dictionary
		var node_name := String(portal_data["node_name"])
		var portal := portal_root.get_node_or_null(node_name) as TwinBaysPortal
		if portal == null:
			_fail("Layout portal node missing: %s" % node_name)
			continue
		_compare_vector3(portal.position, TwinBaysLayoutScript.vector3(portal_data["position"]), "%s position" % node_name)
		_compare_float(portal.cooldown_seconds, float(portal_data["cooldown_seconds"]), "%s cooldown" % node_name)

		var trigger_data := portal_data["trigger"] as Dictionary
		var trigger := portal.get_node_or_null("TriggerShape") as CollisionShape3D
		if trigger == null or not trigger.shape is BoxShape3D:
			_fail("Layout portal trigger missing: %s" % node_name)
		else:
			_compare_vector3(trigger.position, TwinBaysLayoutScript.vector3(trigger_data["local_position"]), "%s trigger position" % node_name)
			_compare_vector3((trigger.shape as BoxShape3D).size, TwinBaysLayoutScript.vector3(trigger_data["size"]), "%s trigger size" % node_name)

		var exit_data := portal_data["exit"] as Dictionary
		if portal.exit_marker == null:
			_fail("Layout portal exit missing: %s" % node_name)
		else:
			_compare_vector3(portal.exit_marker.position, TwinBaysLayoutScript.vector3(exit_data["local_position"]), "%s exit position" % node_name)

		var ring_data := portal_data["ring"] as Dictionary
		var ring := portal.get_node_or_null("PortalGlow") as MeshInstance3D
		if ring == null:
			_fail("Layout portal ring missing: %s" % node_name)
		else:
			_compare_vector3(ring.position, TwinBaysLayoutScript.vector3(ring_data["local_position"]), "%s ring position" % node_name)
			_compare_vector3(ring.scale, TwinBaysLayoutScript.vector3(ring_data["scale"]), "%s ring scale" % node_name)
			var expected_normal := TwinBaysLayoutScript.vector3(portal_data["normal"]).normalized()
			_compare_vector3(ring.basis.y.normalized(), expected_normal, "%s ring normal" % node_name)

func _compare_polygon(actual: PackedVector2Array, expected: PackedVector2Array, label: String) -> void:
	if actual.size() != expected.size():
		_fail("%s count differs: %d != %d" % [label, actual.size(), expected.size()])
		return
	for index in range(expected.size()):
		if actual[index].distance_to(expected[index]) > LAYOUT_EPSILON:
			_fail("%s point %d differs: %s != %s" % [label, index, actual[index], expected[index]])
			return

func _compare_vector3(actual: Vector3, expected: Vector3, label: String) -> void:
	if actual.distance_to(expected) > LAYOUT_EPSILON:
		_fail("%s differs: %s != %s" % [label, actual, expected])

func _compare_float(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > LAYOUT_EPSILON:
		_fail("%s differs: %.4f != %.4f" % [label, actual, expected])

func _verify_required_nodes() -> void:
	print("\n--- Required Nodes ---")
	for path in [
		"TwinBaysWhitebox",
		"TwinBaysWhitebox/ArenaSurface",
		"TwinBaysWhitebox/ArenaBevelCap",
		"TwinBaysWhitebox/ArenaTopCap",
		"TwinBaysWhitebox/CausewaySafetyCollision",
		"TwinBaysPortals/LeftPortal",
		"TwinBaysPortals/RightPortal",
	]:
		if _arena.get_node_or_null(path) == null:
			_fail("Missing node: %s" % path)
		else:
			print("OK  ", path)

func _verify_causeway() -> void:
	print("\n--- Central Causeway ---")
	var surface := _arena.get_node_or_null("TwinBaysWhitebox/ArenaSurface")
	var visual_width := float(surface.get_meta("central_causeway_width", 0.0)) if surface else 0.0
	var safe_width := float(surface.get_meta("safe_causeway_width", 0.0)) if surface else 0.0
	if visual_width < 12.0:
		_fail("Visible central causeway is not wide enough: %.2f" % visual_width)
	else:
		print("OK  visible causeway width: ", visual_width)
	if safe_width < 16.0:
		_fail("Invisible safety shoulder is not wide enough: %.2f" % safe_width)
	else:
		print("OK  safe causeway width: ", safe_width)

	for point in [
		Vector3(-22, 5, -4), Vector3(0, 5, -4), Vector3(22, 5, -4),
		Vector3(0, 5, -11.5), Vector3(0, 5, 3.5),
	]:
		if not _has_ground_at(point):
			_fail("Central causeway sample has no ground: %s" % str(point))
		else:
			print("OK  causeway grounded: ", point)
	for point in [Vector3(0, 5, -13.5), Vector3(0, 5, 5.5)]:
		if _has_ground_at(point):
			_fail("Causeway exceeds the intended curved bay edge: %s" % str(point))
		else:
			print("OK  causeway edge opens to void: ", point)

func _verify_curved_outline() -> void:
	print("\n--- Curved Arena Outline ---")
	var surface := _arena.get_node_or_null("TwinBaysWhitebox/ArenaSurface") as CSGPolygon3D
	if surface == null:
		_fail("ArenaSurface must be an extruded CSGPolygon3D, not box-built terrain")
		return
	if surface.polygon.size() < 60:
		_fail("Arena outline needs enough control points for both curved bays, got %d" % surface.polygon.size())
	else:
		print("OK  curved outline control points: ", surface.polygon.size())
	var triangles := Geometry2D.triangulate_polygon(surface.polygon)
	if triangles.is_empty():
		_fail("Arena outline is not a valid simple concave polygon")
	else:
		print("OK  outline triangulates: ", triangles.size() / 3, " triangles")

	var map_root := _arena.get_node_or_null("TwinBaysWhitebox")
	if map_root == null:
		return
	var expected_wall_sections := {
		"WestNorthOuterWall_": 2,
		"EastNorthOuterWall_": 2,
		"WestSouthOuterWall_": 1,
		"EastSouthOuterWall_": 1,
	}
	for prefix in expected_wall_sections:
		var segment_count := 0
		for child in map_root.get_children():
			if String(child.name).begins_with(prefix) and not String(child.name).ends_with("Cap"):
				segment_count += 1
		var expected_count := int(expected_wall_sections[prefix])
		if segment_count != expected_count:
			_fail("Curved wall strip count drifted for %s: %d != %d" % [prefix, segment_count, expected_count])
		else:
			print("OK  ", prefix, segment_count, " continuous pieces")

func _verify_spawn_and_void_samples() -> void:
	print("\n--- Spawn And Void Samples ---")
	var spawn_points := _arena.call("_get_spawn_points") as Array
	if spawn_points.size() != 4:
		_fail("Expected 4 spawn points, got %d" % spawn_points.size())
	for point in spawn_points:
		if not _has_ground_at(point as Vector3):
			_fail("Spawn point has no ground: %s" % str(point))
		else:
			print("OK  spawn grounded: ", point)

	for point in [Vector3(0, 5, -21), Vector3(0, 5, 21)]:
		if _has_ground_at(point):
			_fail("Lethal bay void was filled at: %s" % str(point))
		else:
			print("OK  void clear: ", point)

func _verify_open_pickup_markers() -> void:
	print("\n--- Open Yellow Pickup Markers ---")
	var marker_names := [
		"YellowPickupNorthWest",
		"YellowPickupSouthWest",
		"YellowPickupNorthEast",
		"YellowPickupSouthEast",
		"SpecialPickupCenter",
	]
	for marker_name in marker_names:
		var marker := _arena.get_node_or_null("TwinBaysWhitebox/%s" % marker_name)
		if marker == null:
			_fail("Missing yellow pickup marker: %s" % marker_name)
			continue
		if marker.find_child("StaticBody3D", true, false) != null:
			_fail("Yellow pickup marker must remain collision-free: %s" % marker_name)
		else:
			print("OK  open marker: ", marker_name)
	var special_marker := _layout.get("special_pickup_marker", {}) as Dictionary
	if not special_marker.is_empty():
		var special_position := TwinBaysLayoutScript.vector3(special_marker["spawn_position"])
		if not _has_ground_at(special_position):
			_fail("Center special pickup marker is not safely grounded")

	for child in _arena.get_node("TwinBaysWhitebox").get_children():
		var child_name := String(child.name).to_lower()
		if child_name.contains("yellow") and child_name.contains("wall"):
			_fail("Yellow pickup marker still has a surrounding wall: %s" % child.name)

func _verify_portal_pair() -> void:
	print("\n--- Portal Pair ---")
	var left := _arena.get_node_or_null("TwinBaysPortals/LeftPortal") as TwinBaysPortal
	var right := _arena.get_node_or_null("TwinBaysPortals/RightPortal") as TwinBaysPortal
	if left == null or right == null:
		_fail("Portal pair is incomplete")
		return

	if left.paired_portal != right or right.paired_portal != left:
		_fail("Portals are not paired bidirectionally")
	else:
		print("OK  bidirectional pairing")
	if left.exit_marker == null or right.exit_marker == null:
		_fail("Portal exit marker missing")
		return
	for portal in [left, right]:
		if portal.collision_layer != 0 or portal.collision_mask != 1:
			_fail("Portal collision filtering must be layer 0 / mask 1: %s" % portal.name)
		if not _has_ground_at(portal.exit_marker.global_position):
			_fail("Portal exit is not safely inset on playable ground: %s" % portal.name)
		else:
			print("OK  safe exit: ", portal.exit_marker.global_position)

	for side_name in ["Left", "Right"]:
		var tower_path := "TwinBaysWhitebox/%sPortalTower" % side_name
		if _arena.get_node_or_null(tower_path) != null:
			_fail("Retired portal wall must stay removed: %s" % tower_path)
		var portal := _arena.get_node_or_null("TwinBaysPortals/%sPortal" % side_name)
		var ring: MeshInstance3D = portal.get_node_or_null("PortalGlow") as MeshInstance3D if portal else null
		if ring == null or ring.mesh == null or not (ring.mesh is TorusMesh or ring.mesh is ArrayMesh):
			_fail("Portal must use a renderable ring mesh: %s" % side_name)
		elif absf(ring.global_basis.y.normalized().dot(Vector3.UP)) > 0.15:
			_fail("Portal ring must remain vertical: %s" % side_name)
		else:
			print("OK  vertical portal ring: ", side_name)

	for forbidden_name in ["LeftPortalPad", "RightPortalPad", "BluePortalFloor"]:
		if _arena.find_child(forbidden_name, true, false) != null:
			_fail("Forbidden blue floor pad remains: %s" % forbidden_name)

func _verify_development_scene_isolated(match_config: Node) -> void:
	print("\n--- Development Scene Isolation ---")
	for entry in match_config.MAPS:
		if entry[1] == SCENE_PATH:
			_fail("Unapproved whitebox must not be exposed in the player-facing map list")
			return
	if (
		match_config.MAPS.size() != 3
		or match_config.MAPS[0][1] != "res://scenes/maps/open_ringout_slice.tscn"
		or match_config.MAPS[1][1] != "res://scenes/maps/twin_bays_splash_arena.tscn"
		or match_config.MAPS[2][1] != "res://scenes/maps/momentum_circuit_arena.tscn"
	):
		_fail("Player-facing map policy must keep Open Ring-Out, Twin Bays, and Momentum Circuit at release indices 0, 1, and 2")
	else:
		print("OK  whitebox stays isolated while all three production maps retain their release indices")

func _verify_runtime_teleport() -> void:
	print("\n--- Runtime Teleport ---")
	var left := _arena.get_node_or_null("TwinBaysPortals/LeftPortal") as TwinBaysPortal
	var right := _arena.get_node_or_null("TwinBaysPortals/RightPortal") as TwinBaysPortal
	if left == null or right == null or left.exit_marker == null or right.exit_marker == null:
		return

	var character := BaseCharacter.new()
	character.name = "PortalVerifierCharacter"
	character.can_sleep = false
	var body_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	body_shape.shape = sphere
	body_shape.position = Vector3(0, 1.5, 0)
	character.add_child(body_shape)
	_arena.add_child(character)
	# BaseCharacter._ready() reapplies the project gravity profile, so disable gravity only
	# after the node enters the tree. This probe has no collision shape by design.
	character.gravity_scale = 0.0
	character.global_position = left.global_position + Vector3(5.5, 0.15, 0)
	character.linear_velocity = Vector3(-18, 3, 4)
	character.angular_velocity = Vector3(0, 5, 0)

	await physics_frame
	await process_frame
	await physics_frame
	if character.global_position.distance_to(right.exit_marker.global_position) > 0.08:
		_fail("Left-to-right teleport landed at %s instead of %s" % [
			str(character.global_position),
			str(right.exit_marker.global_position),
		])
	elif character.linear_velocity.length() > 0.25 or character.angular_velocity.length() > 0.05:
		_fail("Portal did not clear unsafe rigid-body momentum: linear=%s angular=%s" % [
			str(character.linear_velocity),
			str(character.angular_velocity),
		])
	else:
		print("OK  left-to-right teleport")

	var right_exit_position := character.global_position
	right.call("_on_body_entered", character)
	await process_frame
	if character.global_position.distance_to(right_exit_position) > 0.08:
		_fail("Portal cooldown failed to prevent immediate rebound: before=%s after=%s" % [
			str(right_exit_position),
			str(character.global_position),
		])
	else:
		print("OK  cooldown prevents rebound")

	character.set_meta(&"twin_bays_portal_unlock_ms", 0)
	right.call("_on_body_entered", character)
	await process_frame
	await physics_frame
	if character.global_position.distance_to(left.exit_marker.global_position) > 0.08:
		_fail("Right-to-left teleport landed at %s instead of %s" % [
			str(character.global_position),
			str(left.exit_marker.global_position),
		])
	else:
		print("OK  right-to-left teleport")

	character.queue_free()
	await process_frame

func _has_ground_at(pos: Vector3) -> bool:
	var world := root.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, 8, pos.z), Vector3(pos.x, -6, pos.z))
	var result := world.direct_space_state.intersect_ray(query)
	return not result.is_empty()

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
	print("FAIL ", message)

func _finish() -> void:
	if _host and is_instance_valid(_host):
		_host.queue_free()
	await process_frame
	await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Twin Bays Whitebox Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Twin Bays Whitebox Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
