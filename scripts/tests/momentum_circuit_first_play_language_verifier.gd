extends SceneTree

## Runtime proof for Momentum Circuit's current no-text language:
## one complete lavender bridge is usable, orange warning precedes removal,
## and cyan segmented pads remain visually separate from the bridge system.

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"

var _failures: Array[String] = []
var _arena: Node3D = null


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit First-Play Language Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config != null:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]
	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed != null else null
	if _arena == null:
		_fail("Could not instantiate Momentum Circuit")
		await _finish()
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame

	var controller := _arena.call("get_light_bridge_controller") as Node3D
	var vfx := get_first_node_in_group(&"momentum_circuit_mechanism_vfx")
	var teleporters := _arena.call("get_random_teleporters") as Array
	if controller == null or vfx == null or teleporters.size() != 4:
		_fail("Current light-bridge/teleporter fixture is incomplete")
		await _finish()
		return
	controller.set_physics_process(false)

	var active := controller.call("get_debug_state") as Dictionary
	var active_vfx := vfx.call("get_debug_state") as Dictionary
	_assert(String(active.get("state", "")) == "ACTIVE", "Map must open with one complete active bridge")
	_assert(String(active.get("active_bridge_id", "")) == "bridge_hole_02", "Opening bridge must span hole 2")
	_assert((active.get("collision_enabled_ids", []) as Array).size() == 1, "ACTIVE must expose one usable bridge")
	_assert(int(active_vfx.get("bridge_visual_count", 0)) == 3, "All three bridge locations need visible endpoint language")
	_assert(int(active_vfx.get("endpoint_socket_count", 0)) == 6, "Six permanent bridge sockets are required")
	_assert(int(active_vfx.get("cooldown_ring_segments", 0)) == 8, "Teleport pads need eight-segment cooldown language")
	_assert(int(active_vfx.get("literal_arrow_count", -1)) == 0, "First-play language must not depend on arrows")
	_assert(int(active_vfx.get("text_node_count", -1)) == 0, "First-play language must not depend on text")

	controller.call("test_step", 8.0)
	await process_frame
	var warning := controller.call("get_debug_state") as Dictionary
	_assert(String(warning.get("state", "")) == "WARNING", "Eight stable seconds must enter the orange warning phase")
	_assert((warning.get("collision_enabled_ids", []) as Array).size() == 1, "Bridge remains safely usable throughout warning")
	_assert(String(warning.get("next_bridge_id", "")) == "bridge_hole_01", "Next bridge must be previewed at hole 1")

	controller.call("test_step", 2.0)
	await process_frame
	var switching := controller.call("get_debug_state") as Dictionary
	_assert(String(switching.get("state", "")) == "SWITCHING", "Warning must resolve into a visible bridge handoff")
	_assert((switching.get("collision_enabled_ids", []) as Array).is_empty(), "Switching gap must contain no hidden bridge collision")
	print("OK  lavender bridge, orange warning, visible handoff, and cyan segmented teleport pads are distinct")
	await _finish()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if is_instance_valid(_arena):
		current_scene = null
		_arena.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)
	if _failures.is_empty():
		print("RESULT momentum_circuit_first_play_language passed=true failures=0")
		print("[Momentum Circuit First-Play Language Verifier] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_first_play_language passed=false failures=%d" % _failures.size())
	for failure: String in _failures:
		print("- ", failure)
	quit(1)
