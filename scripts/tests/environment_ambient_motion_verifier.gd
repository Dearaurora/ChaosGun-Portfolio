extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"

var _failures: Array[String] = []
var _arena: Node = null


func _initialize() -> void:
	print("==================================================")
	print("[Environment Ambient Motion Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	_configure_empty_roster()

	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return
	_arena = packed.instantiate()
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame

	if not _arena.has_method("get_environment_motion_debug"):
		_fail("Open Ring-Out does not expose the P25 environment motion contract")
		await _finish()
		return

	var before := _arena.call("get_environment_motion_debug") as Dictionary
	_verify_registration(before)
	_arena.call("_update_p25_environment_motion", 1.0)
	var after := _arena.call("get_environment_motion_debug") as Dictionary
	_verify_motion(before, after)
	_verify_visual_only_layers()

	await _finish()


func _verify_registration(debug: Dictionary) -> void:
	if not bool(debug.get("ready", false)):
		_fail("P25 environment motion controller did not become ready")
	if int(debug.get("rotor_count", 0)) != 2:
		_fail("Expected hero and distant windmill rotors, got %d" % int(debug.get("rotor_count", 0)))
	if int(debug.get("cloud_count", 0)) != 10:
		_fail("Expected ten drifting authored cloud banks, got %d" % int(debug.get("cloud_count", 0)))
	if int(debug.get("edge_gem_count", 0)) < 18:
		_fail("Expected the arena edge-light set to pulse, got %d gems" % int(debug.get("edge_gem_count", 0)))


func _verify_motion(before: Dictionary, after: Dictionary) -> void:
	var rotor_delta := absf(
		float(after.get("hero_rotor_rotation", 0.0))
		- float(before.get("hero_rotor_rotation", 0.0))
	)
	if rotor_delta < 0.40:
		_fail("Hero windmill rotor did not advance by the authored P25 rate")

	var balloon_offset := after.get("balloon_offset", Vector3.ZERO) as Vector3
	if balloon_offset.length() < 0.08:
		_fail("Hot-air balloon assembly did not produce a readable whole-object drift")

	var cloud_offset := after.get("cloud_offset", Vector3.ZERO) as Vector3
	if cloud_offset.length() < 0.08:
		_fail("Cloud bank drift did not produce a readable offset")

	var edge_scale_ratio := float(after.get("edge_scale_ratio", 1.0))
	if absf(edge_scale_ratio - 1.0) < 0.01:
		_fail("Arena edge lights did not pulse after advancing P25 motion")

	print(
		"OK  rotor_delta=%.3f balloon_offset=%s cloud_offset=%s edge_scale=%.3f"
		% [rotor_delta, balloon_offset, cloud_offset, edge_scale_ratio]
	)


func _verify_visual_only_layers() -> void:
	for path in [
		"OpenRingoutBlenderVisuals/SunsetV2GameplayVisuals",
		"OpenRingoutBlenderVisuals/P14SunsetEnvironment",
	]:
		var visual_root := _arena.get_node_or_null(path)
		if visual_root == null:
			_fail("Missing visual layer while checking P25 motion: %s" % path)
		elif _contains_collision(visual_root):
			_fail("P25 animated visual layer must remain collision-free: %s" % path)


func _contains_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _contains_collision(child):
			return true
	return false


func _configure_empty_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[Environment Ambient Motion Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Environment Ambient Motion Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
