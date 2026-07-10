extends SceneTree

const PRESET_SCRIPT_PATH := "res://scripts/playtest/a1_reference_playtest_preset.gd"
const EXPECTED_MAP_PATH := "res://scenes/maps/a1_reference_basin.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[A1 Reference Playtest Preset Verifier]")
	print("==================================================")

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		await _finish()
		return

	var preset_script = load(PRESET_SCRIPT_PATH) as Script
	if preset_script == null:
		_fail("Could not load preset script: %s" % PRESET_SCRIPT_PATH)
		await _finish()
		return

	var preset = preset_script.new()
	if preset == null or not preset.has_method("apply_default_preset"):
		_fail("Preset is missing apply_default_preset")
		await _finish()
		return

	preset.call("apply_default_preset", match_config)

	var slots = match_config.get("slots") as Array
	if slots.size() != 4:
		_fail("Expected 4 slots, got %d" % slots.size())
	elif slots[0] != match_config.SlotType.HUMAN:
		_fail("Slot 1 should be human")
	elif slots[1] != match_config.SlotType.AI or slots[2] != match_config.SlotType.AI or slots[3] != match_config.SlotType.AI:
		_fail("Slots 2-4 should be AI")
	else:
		print("OK  slots -> ", slots)

	var map_path = match_config.call("get_selected_map_path")
	if map_path != EXPECTED_MAP_PATH:
		_fail("Expected map %s, got %s" % [EXPECTED_MAP_PATH, map_path])
	else:
		print("OK  map -> ", map_path)

	await _finish()

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
	print("FAIL ", message)

func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print("[A1 Reference Playtest Preset Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[A1 Reference Playtest Preset Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
