extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Local Match Roster Verifier]")
	print("==================================================")

	root.set_meta("disable_runtime_audio", true)
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		await _finish()
		return

	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.HUMAN,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]

	var scene = load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	var arena = scene.instantiate()
	root.add_child(arena)
	current_scene = arena

	await process_frame
	await process_frame

	_verify_match_config_preserved(match_config)
	_verify_spawned_roster(arena)
	await _finish()

func _verify_match_config_preserved(match_config: Node) -> void:
	var slots = match_config.get("slots") as Array
	var expected = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.HUMAN,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]
	if slots != expected:
		_fail("Open ringout map must not overwrite local match slots, got %s" % str(slots))
	else:
		print("OK  local match slots preserved")

func _verify_spawned_roster(arena: Node) -> void:
	var characters: Array[BaseCharacter] = []
	var human_count := 0
	var ai_count := 0
	for child in arena.get_children():
		if child is BaseCharacter:
			characters.append(child as BaseCharacter)
			if child is PlayerCharacter:
				human_count += 1
			elif child is AICharacter:
				ai_count += 1

	if characters.size() != 2:
		_fail("Expected exactly 2 spawned characters for two active local slots, got %d" % characters.size())
	if human_count != 2:
		_fail("Expected 2 human players, got %d" % human_count)
	if ai_count != 0:
		_fail("Expected 0 AI players when no AI slots are selected, got %d" % ai_count)
	if _failures.is_empty():
		print("OK  spawned roster matches local slots")

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	await process_frame
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	root.set_meta("disable_runtime_audio", false)

	print("\n==================================================")
	if _failures.is_empty():
		print("[Local Match Roster Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Local Match Roster Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
