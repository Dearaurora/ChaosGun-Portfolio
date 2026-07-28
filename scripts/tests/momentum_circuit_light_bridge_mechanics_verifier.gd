extends SceneTree

const CONFIG_PATH := "res://resources/maps/momentum_circuit_production_v9.json"
const LAYOUT_PATH := "res://resources/maps/momentum_circuit_layout_v2.json"
const ControllerScript = preload("res://scripts/maps/momentum_circuit_light_bridge_controller.gd")

var _failures: Array[String] = []
var _state_signal_count := 0
var _switch_signal_count := 0


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit Light Bridge Mechanics Verifier]")
	print("==================================================")
	var config := _load_json(CONFIG_PATH)
	var layout := _load_json(LAYOUT_PATH)
	if config.is_empty() or layout.is_empty():
		_fail("v7 config or layout v2 is missing")
		_finish()
		return
	var bridge_config := config.get("light_bridges", {}) as Dictionary
	_verify_geometry(bridge_config, layout)

	var controller := ControllerScript.new() as Node3D
	controller.name = "LightBridgeControllerUnderTest"
	root.add_child(controller)
	controller.set_physics_process(false)
	controller.bridge_state_changed.connect(_on_state_changed)
	controller.bridge_switched.connect(_on_bridge_switched)
	controller.configure(bridge_config)
	await process_frame
	controller.set_physics_process(false)

	_expect_state(controller, "ACTIVE", "bridge_hole_02", ["bridge_hole_02"])
	await _verify_forced_safe_traversal(controller, bridge_config)
	await _verify_two_character_bounce(controller, bridge_config)
	controller.test_step(8.0)
	_expect_state(controller, "WARNING", "bridge_hole_02", ["bridge_hole_02"])
	_verify_ai_warning_bias(controller, bridge_config)
	await _verify_warning_safely_returns_new_entrant(controller, bridge_config)
	controller.test_step(2.0)
	_expect_state(controller, "SWITCHING", "bridge_hole_02", [])
	controller.test_step(0.45)
	_expect_state(controller, "ACTIVE", "bridge_hole_01", ["bridge_hole_01"])
	controller.test_step(10.45)
	_expect_state(controller, "ACTIVE", "bridge_hole_03", ["bridge_hole_03"])
	controller.test_step(10.45)
	_expect_state(controller, "ACTIVE", "bridge_hole_02", ["bridge_hole_02"])
	var debug := controller.get_debug_state() as Dictionary
	if int(debug.get("switch_serial", -1)) != 3:
		_fail("Three complete cycles must report switch_serial=3")
	if _switch_signal_count != 3:
		_fail("bridge_switched must emit once per completed expansion")
	if _state_signal_count < 10:
		_fail("bridge_state_changed did not expose every state transition")
	await _verify_unassisted_drop(controller, bridge_config)

	var collision_bodies := get_nodes_in_group(&"momentum_circuit_light_bridge_collision")
	if collision_bodies.size() != 3:
		_fail("Controller must create exactly three Gameplay collision bodies")
	for body: Node in collision_bodies:
		if body.get_child_count() != 1 or not body.get_child(0) is CollisionShape3D:
			_fail("Every light bridge body must own one CollisionShape3D")

	await _verify_detached_character_teardown(bridge_config)
	controller.queue_free()
	await process_frame
	_finish()


func _verify_geometry(config: Dictionary, layout: Dictionary) -> void:
	var platform := layout.get("platform", {}) as Dictionary
	var outer := _polygon(platform.get("visual_top_outline_world_xz", platform.get("outline_world_xz", [])))
	var holes := {}
	for value: Variant in layout.get("holes", []):
		var hole := value as Dictionary
		holes[String(hole.get("id", ""))] = _polygon(hole.get("visual_top_outline_world_xz", hole.get("outline_world_xz", [])))
	var expected_order := ["bridge_hole_02", "bridge_hole_01", "bridge_hole_03"]
	if config.get("order", []) != expected_order:
		_fail("Bridge order must be hole 2 -> hole 1 -> hole 3")
	if absf(float(config.get("width", 0.0)) - 4.0) > 0.001:
		_fail("Bridge width must be 4.0u")
	for value: Variant in config.get("bridges", []):
		var spec := value as Dictionary
		var start := _vector2(spec.get("start_xz", []))
		var finish := _vector2(spec.get("end_xz", []))
		var hole_id := String(spec.get("hole_id", ""))
		if not _walkable(start, outer, holes.values()) or not _walkable(finish, outer, holes.values()):
			_fail("%s endpoints must both land on valid platform" % spec.get("id", "?"))
		var target_hole: PackedVector2Array = holes.get(hole_id, PackedVector2Array())
		if target_hole.size() < 3 or not Geometry2D.is_point_in_polygon(start.lerp(finish, 0.5), target_hole):
			_fail("%s midpoint must cross its assigned hole" % spec.get("id", "?"))
		for collection_name in ["spawns", "portals", "weapon_spawns"]:
			for point_value: Variant in layout.get(collection_name, []):
				var point_data := point_value as Dictionary
				var world := point_data.get("position_world", []) as Array
				if world.size() >= 3 and Geometry2D.get_closest_point_to_segment(Vector2(float(world[0]), float(world[2])), start, finish).distance_to(Vector2(float(world[0]), float(world[2]))) < 3.0:
					_fail("%s overlaps %s/%s" % [spec.get("id", "?"), collection_name, point_data.get("id", "?")])


func _verify_ai_warning_bias(controller: Node3D, config: Dictionary) -> void:
	var spec := _find_spec(config, "bridge_hole_02")
	var start2 := _vector2(spec.get("start_xz", []))
	var finish2 := _vector2(spec.get("end_xz", []))
	var sample2 := start2.lerp(finish2, 0.25)
	var ai := Node3D.new()
	ai.position = Vector3(sample2.x, float(config.get("top_y", 1.06)) + 0.8, sample2.y)
	root.add_child(ai)
	var bias := controller.get_ai_movement_bias(ai) as Dictionary
	if absf(float(bias.get("weight", 0.0)) - 0.85) > 0.001:
		_fail("AI on warning bridge must receive 0.85 escape bias")
	if String(bias.get("reason", "")) != "warning_bridge_nearest_bank":
		_fail("AI warning bridge bias must expose its reason")
	ai.position += Vector3(12.0, 0.0, 0.0)
	var outside := controller.get_ai_movement_bias(ai) as Dictionary
	if float(outside.get("weight", 1.0)) != 0.0:
		_fail("AI outside warning bridge must receive no light-bridge bias")
	ai.queue_free()


func _verify_forced_safe_traversal(controller: Node3D, config: Dictionary) -> void:
	var spec := _find_spec(config, "bridge_hole_02")
	var start := _world_point(spec.get("start_xz", []), config)
	var finish := _world_point(spec.get("end_xz", []), config)
	var direction := (finish - start).normalized()
	var character := _make_character("SoloBridgeTraveler", start.lerp(finish, 0.25))
	var expected_destination := finish + direction * float(config.get("bank_clearance", 1.6))
	controller.test_scan_for_traversals()
	var debug := controller.get_debug_state() as Dictionary
	if int(debug.get("active_traversal_count", 0)) != 1:
		_fail("A character stepping onto the active bridge must enter forced traversal")
	if not character.is_scripted_traversal_active() or not character.is_invincible:
		_fail("Forced bridge traversal must suppress normal physics, damage, and falling")
	var minimum_y := character.global_position.y
	for _step in range(40):
		controller.test_traversal_step(0.1)
		minimum_y = minf(minimum_y, character.global_position.y)
		if not character.is_scripted_traversal_active():
			break
	if character.is_scripted_traversal_active():
		_fail("A solo bridge traveler did not reach the opposite bank")
	if minimum_y < float(config.get("top_y", 1.06)) + 0.60:
		_fail("A forced bridge traveler moved below the safe bridge plane")
	if Vector2(character.global_position.x, character.global_position.z).distance_to(Vector2(expected_destination.x, expected_destination.z)) > 0.15:
		_fail("A solo bridge traveler must be deposited beyond the opposite endpoint")
	if character.is_invincible:
		_fail("Bridge traversal must restore the character's prior invincibility state")
	debug = controller.get_debug_state() as Dictionary
	if int(debug.get("traversal_completed_count", 0)) < 1:
		_fail("Safe bridge completion was not reported")
	character.queue_free()
	await process_frame


func _verify_two_character_bounce(controller: Node3D, config: Dictionary) -> void:
	var spec := _find_spec(config, "bridge_hole_02")
	var start := _world_point(spec.get("start_xz", []), config)
	var finish := _world_point(spec.get("end_xz", []), config)
	var direction := (finish - start).normalized()
	var clearance := float(config.get("bank_clearance", 1.6))
	var expected_a := start - direction * clearance
	var expected_b := finish + direction * clearance
	var character_a := _make_character("BridgeTravelerA", start.lerp(finish, 0.28))
	var character_b := _make_character("BridgeTravelerB", start.lerp(finish, 0.72))
	controller.test_scan_for_traversals()
	var debug := controller.get_debug_state() as Dictionary
	if int(debug.get("active_traversal_count", 0)) != 2:
		_fail("Two simultaneous bridge entrants must both be captured safely")
	if int(debug.get("returning_traversal_count", 0)) != 2:
		_fail("Two characters on one bridge must both reverse toward their own bank")
	if int(debug.get("collision_bounce_count", 0)) < 1:
		_fail("Two-character bridge conflict must be reported as a bounce")
	for _step in range(40):
		controller.test_traversal_step(0.1)
		if not character_a.is_scripted_traversal_active() and not character_b.is_scripted_traversal_active():
			break
	if character_a.is_scripted_traversal_active() or character_b.is_scripted_traversal_active():
		_fail("Bounced characters did not return to their banks")
	if Vector2(character_a.global_position.x, character_a.global_position.z).distance_to(Vector2(expected_a.x, expected_a.z)) > 0.15:
		_fail("First conflicted character did not return to its entry bank")
	if Vector2(character_b.global_position.x, character_b.global_position.z).distance_to(Vector2(expected_b.x, expected_b.z)) > 0.15:
		_fail("Second conflicted character did not return to its entry bank")
	if character_a.is_dead or character_b.is_dead:
		_fail("Bridge conflict bounce must never eliminate either character")
	character_a.queue_free()
	character_b.queue_free()
	await process_frame


func _verify_warning_safely_returns_new_entrant(controller: Node3D, config: Dictionary) -> void:
	var spec := _find_spec(config, "bridge_hole_02")
	var start := _world_point(spec.get("start_xz", []), config)
	var finish := _world_point(spec.get("end_xz", []), config)
	var direction := (finish - start).normalized()
	var expected_origin := start - direction * float(config.get("bank_clearance", 1.6))
	var character := _make_character("WarningBridgeEntrant", start.lerp(finish, 0.35))
	controller.test_scan_for_traversals()
	var debug := controller.get_debug_state() as Dictionary
	if not character.is_scripted_traversal_active() or int(debug.get("returning_traversal_count", 0)) != 1:
		_fail("A warning bridge entrant must be captured and safely returned, not accepted for crossing")
	for _step in range(40):
		controller.test_traversal_step(0.1)
		if not character.is_scripted_traversal_active():
			break
	if character.is_scripted_traversal_active():
		_fail("A warning bridge entrant did not reach the safe entry bank")
	if Vector2(character.global_position.x, character.global_position.z).distance_to(Vector2(expected_origin.x, expected_origin.z)) > 0.15:
		_fail("A warning bridge entrant must return beyond the entry endpoint")
	if character.is_dead:
		_fail("A warning bridge entrant must not be eliminated by bridge withdrawal")
	debug = controller.get_debug_state() as Dictionary
	if int(debug.get("warning_return_count", 0)) < 1:
		_fail("Warning-period safety return was not reported")
	character.queue_free()
	await process_frame


func _verify_unassisted_drop(controller: Node3D, config: Dictionary) -> void:
	controller.set_physics_process(false)
	var spec := _find_spec(config, "bridge_hole_02")
	var start2 := _vector2(spec.get("start_xz", []))
	var finish2 := _vector2(spec.get("end_xz", []))
	var center2 := start2.lerp(finish2, 0.5)
	var body := RigidBody3D.new()
	body.name = "BridgeDropProbe"
	body.position = Vector3(center2.x, float(config.get("top_y", 1.06)) + 1.5, center2.y)
	body.mass = 1.0
	body.gravity_scale = 1.0
	body.lock_rotation = true
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	collision.shape = sphere
	body.add_child(collision)
	root.add_child(body)
	for _frame in range(45):
		await physics_frame
	var supported_y := body.global_position.y
	if supported_y < float(config.get("top_y", 1.06)) + 0.35:
		_fail("Active bridge did not support the physics drop probe")
	var debug := controller.get_debug_state() as Dictionary
	controller.test_step(maxf(0.0, float(debug.get("state_duration", 8.0)) - float(debug.get("state_elapsed", 0.0))))
	debug = controller.get_debug_state() as Dictionary
	controller.test_step(maxf(0.0, float(debug.get("state_duration", 2.0)) - float(debug.get("state_elapsed", 0.0))))
	_expect_state(controller, "SWITCHING", "bridge_hole_02", [])
	for _frame in range(30):
		await physics_frame
	if body.global_position.y > supported_y - 0.8:
		_fail("Probe did not fall normally after warning bridge collision was removed")
	if body.linear_velocity.y >= -0.1:
		_fail("Bridge withdrawal must not hover, push, or rescue the falling probe")
	body.queue_free()


func _verify_detached_character_teardown(config: Dictionary) -> void:
	var controller := ControllerScript.new() as Node3D
	controller.name = "LightBridgeTeardownControllerUnderTest"
	root.add_child(controller)
	controller.set_physics_process(false)
	controller.configure(config)
	await process_frame
	controller.set_physics_process(false)

	var spec := _find_spec(config, "bridge_hole_02")
	var start := _world_point(spec.get("start_xz", []), config)
	var finish := _world_point(spec.get("end_xz", []), config)
	var character := _make_character("DetachedBridgeTraveler", start.lerp(finish, 0.35))
	controller.test_scan_for_traversals()
	if not character.is_scripted_traversal_active():
		_fail("Teardown probe did not begin scripted traversal")
		character.queue_free()
		controller.queue_free()
		await process_frame
		return

	root.remove_child(character)
	controller.queue_free()
	await process_frame
	if character.is_scripted_traversal_active():
		_fail("Controller teardown must release a traveler that already left the SceneTree")
	character.free()


func _make_character(character_name: String, position: Vector3) -> BaseCharacter:
	var character := BaseCharacter.new()
	character.name = character_name
	character.freeze = true
	character.position = position + Vector3.UP * 1.0
	character.add_to_group(&"player")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.6
	collision.shape = capsule
	character.add_child(collision)
	root.add_child(character)
	return character


func _expect_state(controller: Node, state: String, active_id: String, enabled_ids: Array) -> void:
	var debug := controller.get_debug_state() as Dictionary
	if String(debug.get("state", "")) != state:
		_fail("Expected state %s, got %s" % [state, debug.get("state", "")])
	if String(debug.get("active_bridge_id", "")) != active_id:
		_fail("Expected active bridge %s, got %s" % [active_id, debug.get("active_bridge_id", "")])
	var actual := debug.get("collision_enabled_ids", []) as Array
	actual.sort()
	var expected := enabled_ids.duplicate()
	expected.sort()
	if actual != expected:
		_fail("State %s collision ids differ: expected %s got %s" % [state, expected, actual])


func _on_state_changed(_state: StringName, _active: String, _next: String) -> void:
	_state_signal_count += 1


func _on_bridge_switched(_previous: String, _active: String, _serial: int) -> void:
	_switch_signal_count += 1


func _find_spec(config: Dictionary, bridge_id: String) -> Dictionary:
	for value: Variant in config.get("bridges", []):
		var spec := value as Dictionary
		if String(spec.get("id", "")) == bridge_id:
			return spec
	return {}


func _walkable(point: Vector2, outer: PackedVector2Array, holes: Array) -> bool:
	if not Geometry2D.is_point_in_polygon(point, outer):
		return false
	for value: Variant in holes:
		if Geometry2D.is_point_in_polygon(point, value as PackedVector2Array):
			return false
	return true


func _polygon(value: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Variant in value as Array:
		var values := point as Array
		result.append(Vector2(float(values[0]), float(values[1])))
	return result


func _vector2(value: Variant) -> Vector2:
	var values := value as Array
	return Vector2(float(values[0]), float(values[1]))


func _world_point(value: Variant, config: Dictionary) -> Vector3:
	var point := _vector2(value)
	return Vector3(point.x, float(config.get("top_y", 1.06)), point.y)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT momentum_circuit_light_bridge_mechanics passed=true order=2-1-3 cadence=8/2/0.45 forced_safe_traversal=true two_character_bounce=true")
		print("[Momentum Circuit Light Bridge Mechanics Verifier] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_light_bridge_mechanics passed=false failures=%d" % _failures.size())
	print("[Momentum Circuit Light Bridge Mechanics Verifier] FAIL")
	quit(1)
