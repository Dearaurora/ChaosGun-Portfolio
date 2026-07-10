extends SceneTree

const APPROVED_MAP_NAME := "Open Ring-Out Slice"
const APPROVED_MAP_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Playable Match Routes Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		await _finish()
		return

	_verify_player_facing_maps(match_config)
	await _verify_quick_ai_route(match_config)
	await _verify_local_custom_route(match_config)
	await _finish()

func _verify_player_facing_maps(match_config: Node) -> void:
	var maps := match_config.get("MAPS") as Array
	if maps.size() != 1:
		_fail("Only finished player-facing maps should be selectable right now; got %d maps" % maps.size())
		return
	var entry := maps[0] as Array
	if entry.size() < 2 or entry[0] != APPROVED_MAP_NAME or entry[1] != APPROVED_MAP_PATH:
		_fail("Playable map list should expose only %s -> %s, got %s" % [APPROVED_MAP_NAME, APPROVED_MAP_PATH, str(entry)])
	else:
		print("OK  player-facing maps are restricted to open ring-out")

func _verify_quick_ai_route(match_config: Node) -> void:
	var menu_scene := load(MAIN_MENU_SCENE) as PackedScene
	if menu_scene == null:
		_fail("Could not load %s" % MAIN_MENU_SCENE)
		return

	var menu := menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame

	menu.call("_on_vs_ai")
	await process_frame
	await process_frame

	if current_scene == null:
		_fail("Quick AI route did not create a current scene")
		return
	if current_scene.scene_file_path != APPROVED_MAP_PATH:
		_fail("Quick AI should route to %s, got %s" % [APPROVED_MAP_PATH, current_scene.scene_file_path])

	var slots := match_config.get("slots") as Array
	var expected := [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]
	if slots != expected:
		_fail("Quick AI should configure exactly one human and one AI, got %s" % str(slots))
	elif current_scene.scene_file_path == APPROVED_MAP_PATH:
		print("OK  quick AI routes to open ring-out with one human and one AI")

func _verify_local_custom_route(match_config: Node) -> void:
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
		current_scene = null

	match_config.set("slots", [
		match_config.SlotType.HUMAN,
		match_config.SlotType.HUMAN,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	])
	match_config.set("selected_map_index", 99)

	var select_scene := load(CHARACTER_SELECT_SCENE) as PackedScene
	if select_scene == null:
		_fail("Could not load %s" % CHARACTER_SELECT_SCENE)
		return

	var select_screen := select_scene.instantiate()
	root.add_child(select_screen)
	current_scene = select_screen
	await process_frame

	if match_config.get("selected_map_index") != 0:
		_fail("Character select should normalize the selected map index to the only playable map")

	select_screen.call("_on_map_next")
	await process_frame
	if match_config.get("selected_map_index") != 0:
		_fail("Single-map selector should stay on the open ring-out map")

	select_screen.call("_on_start")
	await process_frame
	await process_frame

	if current_scene == null:
		_fail("Local custom route did not create a current scene")
		return
	if current_scene.scene_file_path != APPROVED_MAP_PATH:
		_fail("Local custom route should load %s, got %s" % [APPROVED_MAP_PATH, current_scene.scene_file_path])
	else:
		print("OK  local custom route uses the same open ring-out scene")

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	root.set_meta("disable_runtime_audio", false)

	print("\n==================================================")
	if _failures.is_empty():
		print("[Playable Match Routes Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Playable Match Routes Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
