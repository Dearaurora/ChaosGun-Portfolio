extends SceneTree

const PRESET_SCRIPT := preload("res://scripts/playtest/momentum_circuit_demo_preset.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		_finish()
		return
	var previous_slots: Array = match_config.slots.duplicate()
	var previous_mode: int = match_config.match_mode
	var had_previous_preset := match_config.has_meta("playtest_preset_id")
	var previous_preset: Variant = null
	if had_previous_preset:
		previous_preset = match_config.get_meta("playtest_preset_id")

	var preset := PRESET_SCRIPT.new()
	if not preset.apply_default_preset(match_config):
		_fail("Demo preset rejected a valid MatchConfig")
	_verify_slots(match_config)
	if String(match_config.get_meta("playtest_preset_id", "")) != PRESET_SCRIPT.PRESET_ID:
		_fail("Demo preset identity was not recorded")
	if not FileAccess.file_exists(PRESET_SCRIPT.DEMO_MAP_PATH):
		_fail("Demo map scene is missing")
	var pool_indices: Array[int] = []
	for index in range(match_config.MAPS.size()):
		var entry_variant: Variant = match_config.MAPS[index]
		var entry := entry_variant as Array
		if entry.size() >= 2 and String(entry[1]) == PRESET_SCRIPT.DEMO_MAP_PATH:
			pool_indices.append(index)
	if pool_indices != [2]:
		_fail("Momentum Circuit must appear exactly once at map index 2")
	elif String((match_config.MAPS[2] as Array)[0]) != "Momentum Circuit":
		_fail("Momentum Circuit map-pool display name is incorrect")
	if int(match_config.selected_map_index) != 2:
		_fail("Demo preset must select Momentum Circuit at map index 2")

	match_config.slots = previous_slots
	match_config.match_mode = previous_mode
	if had_previous_preset:
		match_config.set_meta("playtest_preset_id", previous_preset)
	else:
		match_config.remove_meta("playtest_preset_id")
	_finish()


func _verify_slots(match_config: Node) -> void:
	var slots := match_config.slots as Array
	if slots.size() != 4:
		_fail("Demo preset must provide exactly four slots")
		return
	if slots[0] != match_config.SlotType.HUMAN:
		_fail("Demo slot 1 must be human")
	for index in range(1, 4):
		if slots[index] != match_config.SlotType.AI:
			_fail("Demo slots 2-4 must be AI")
	if match_config.match_mode != match_config.MatchMode.LOCAL_CUSTOM:
		_fail("Demo preset must use the stable local-match flow")


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT momentum_circuit_demo_preset passed=true failures=0 slots=1+3AI map_pool=index2")
		quit(0)
		return
	print("RESULT momentum_circuit_demo_preset passed=false failures=%d" % _failures.size())
	quit(1)
