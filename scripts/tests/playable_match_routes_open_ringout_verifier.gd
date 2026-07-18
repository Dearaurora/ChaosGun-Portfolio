extends SceneTree

const APPROVED_MAP_NAME := "Open Ring-Out Slice"
const APPROVED_MAP_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const TWIN_BAYS_MAP_NAME := "Twin Bays Splash Arena"
const TWIN_BAYS_MAP_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const CONTROL_MODE_PANEL_SCRIPT_PATH := "res://scripts/ui/control_mode_panel.gd"
const GAME_HUD_SCRIPT_PATH := "res://scripts/ui/game_hud.gd"
const PAUSE_MENU_SCRIPT_PATH := "res://scripts/ui/pause_menu.gd"
const VICTORY_SCREEN_SCRIPT_PATH := "res://scripts/ui/victory_screen.gd"
const MATCH_PRESENTATION_SETTLE_SECONDS := 1.5

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
	if maps.size() != 2:
		_fail("Exactly two finished player-facing maps should be selectable; got %d maps" % maps.size())
		return
	var open_entry := maps[0] as Array
	var twin_entry := maps[1] as Array
	if open_entry.size() < 2 or open_entry[0] != APPROVED_MAP_NAME or open_entry[1] != APPROVED_MAP_PATH:
		_fail("Open Ring-Out must remain the first playable map, got %s" % str(open_entry))
	elif twin_entry.size() < 2 or twin_entry[0] != TWIN_BAYS_MAP_NAME or twin_entry[1] != TWIN_BAYS_MAP_PATH:
		_fail("Twin Bays Splash Arena must be the second playable map, got %s" % str(twin_entry))
	else:
		print("OK  player-facing maps expose Open Ring-Out then Twin Bays")

func _verify_quick_ai_route(match_config: Node) -> void:
	match_config.configure_quick_ai_match(0)
	if match_config.get_selected_map_path() != APPROVED_MAP_PATH:
		_fail("Forced random roll 0 should select Open Ring-Out")
	match_config.configure_quick_ai_match(1)
	if match_config.get_selected_map_path() != TWIN_BAYS_MAP_PATH:
		_fail("Forced random roll 1 should select Twin Bays")

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
	await _settle_match_presentation()

	if current_scene == null:
		_fail("Quick AI route did not create a current scene")
		return
	var playable_paths := [APPROVED_MAP_PATH, TWIN_BAYS_MAP_PATH]
	if current_scene.scene_file_path not in playable_paths:
		_fail("Quick AI should route to one of the two playable maps, got %s" % current_scene.scene_file_path)
	if int(match_config.get("match_mode")) != int(match_config.MatchMode.QUICK_AI):
		_fail("Quick AI entry should mark the match as QUICK_AI")

	var slots := match_config.get("slots") as Array
	var expected := [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]
	if slots != expected:
		_fail("Quick AI should configure exactly one human and one AI, got %s" % str(slots))
	else:
		print("OK  quick AI randomly routes to a playable map with one human and one AI")

	_complete_test_tweens()
	match_config.restart_current_match(self, 1)
	await process_frame
	await process_frame
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != TWIN_BAYS_MAP_PATH:
		_fail("Quick AI rematch roll 1 should route to Twin Bays")
	_complete_test_tweens()
	match_config.restart_current_match(self, 0)
	await process_frame
	await process_frame
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != APPROVED_MAP_PATH:
		_fail("Quick AI rematch roll 0 should route to Open Ring-Out")
	else:
		print("OK  quick AI rematch reselects from the same two-map pool")

	for surface: String in [
		"pause_menu",
		"control_mode_panel",
		"game_hud_button",
		"game_hud_keyboard",
		"victory_rematch",
	]:
		await _verify_quick_restart_surface(match_config, surface)

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

	if match_config.get("selected_map_index") != 1:
		_fail("Character select should clamp an oversized index to Twin Bays (index 1)")
	if int(match_config.get("match_mode")) != int(match_config.MatchMode.LOCAL_CUSTOM):
		_fail("Character select should mark the match as LOCAL_CUSTOM")

	select_screen.call("_on_map_next")
	await process_frame
	if match_config.get("selected_map_index") != 0:
		_fail("Map selector should wrap from Twin Bays to Open Ring-Out")
	select_screen.call("_on_map_prev")
	await process_frame
	if match_config.get("selected_map_index") != 1:
		_fail("Map selector should wrap back from Open Ring-Out to Twin Bays")

	select_screen.call("_on_start")
	await process_frame
	await process_frame
	await _settle_match_presentation()

	if current_scene == null:
		_fail("Local custom route did not create a current scene")
		return
	if current_scene.scene_file_path != TWIN_BAYS_MAP_PATH:
		_fail("Local custom route should load selected Twin Bays map, got %s" % current_scene.scene_file_path)
	else:
		print("OK  local selector cycles maps and launches Twin Bays")

	_complete_test_tweens()
	match_config.restart_current_match(self, 0)
	await process_frame
	await process_frame
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != TWIN_BAYS_MAP_PATH:
		_fail("Local custom rematch should preserve the player-selected Twin Bays map")
	else:
		print("OK  local rematch preserves the manually selected map")

	await _load_match_scene(match_config, TWIN_BAYS_MAP_PATH, false)
	if not _invoke_restart_surface("pause_menu"):
		return
	await process_frame
	await process_frame
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != TWIN_BAYS_MAP_PATH:
		_fail("Local custom pause-menu restart should preserve Twin Bays")
	elif int(match_config.get("selected_map_index")) != 1:
		_fail("Local custom pause-menu restart changed the selected map index")
	else:
		print("OK  local restart surface preserves the manually selected map")

func _verify_quick_restart_surface(match_config: Node, surface: String) -> void:
	await _load_match_scene(match_config, TWIN_BAYS_MAP_PATH, true)
	if current_scene == null:
		_fail("Could not prepare Twin Bays for quick restart surface %s" % surface)
		return

	# An invalid sentinel proves that the real UI handler asked MatchConfig to
	# reselect from the playable pool instead of merely reloading the arena.
	match_config.set("selected_map_index", 99)
	if not _invoke_restart_surface(surface):
		return
	await process_frame
	await process_frame
	await process_frame
	await _settle_match_presentation()

	if current_scene == null:
		_fail("Quick restart surface %s did not load a scene" % surface)
		return
	var selected_index := int(match_config.get("selected_map_index"))
	if selected_index < 0 or selected_index >= 2:
		_fail("Quick restart surface %s did not reselect a playable map" % surface)
		return
	var expected_path := String((match_config.get("MAPS") as Array)[selected_index][1])
	if current_scene.scene_file_path != expected_path:
		_fail("Quick restart surface %s loaded %s instead of selected %s" % [
			surface, current_scene.scene_file_path, expected_path,
		])
	elif int(match_config.get("match_mode")) != int(match_config.MatchMode.QUICK_AI):
		_fail("Quick restart surface %s changed the match mode" % surface)
	else:
		print("OK  quick restart surface reselects playable map: ", surface)

func _load_match_scene(match_config: Node, path: String, quick_ai: bool) -> void:
	if quick_ai:
		match_config.configure_quick_ai_match(1)
	else:
		match_config.configure_local_match()
		match_config.set("selected_map_index", 1)
		match_config.set("slots", [
			match_config.SlotType.HUMAN,
			match_config.SlotType.HUMAN,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		])
	_complete_test_tweens()
	change_scene_to_file(path)
	await process_frame
	await process_frame
	await process_frame
	await _settle_match_presentation()

func _invoke_restart_surface(surface: String) -> bool:
	if current_scene == null:
		_fail("Cannot invoke restart surface %s without a current match" % surface)
		return false

	_complete_test_tweens()
	match surface:
		"pause_menu":
			var pause_menu := _find_node_with_script(current_scene, PAUSE_MENU_SCRIPT_PATH)
			if pause_menu == null:
				_fail("Pause-menu restart surface is missing")
				return false
			pause_menu.call("_on_restart")
		"control_mode_panel":
			var control_panel := _find_node_with_script(current_scene, CONTROL_MODE_PANEL_SCRIPT_PATH)
			if control_panel == null:
				_fail("Control-mode restart surface is missing")
				return false
			control_panel.call("_restart_match")
		"game_hud_button":
			var button_hud := _find_node_with_script(current_scene, GAME_HUD_SCRIPT_PATH)
			var restart_button := _find_button_containing(button_hud, "RESTART")
			if restart_button == null:
				_fail("Game HUD restart button surface is missing")
				return false
			restart_button.pressed.emit()
		"game_hud_keyboard":
			var keyboard_hud := _find_node_with_script(current_scene, GAME_HUD_SCRIPT_PATH)
			if keyboard_hud == null:
				_fail("Game HUD keyboard restart surface is missing")
				return false
			var game_over_container := keyboard_hud.get("_game_over_container") as Control
			if game_over_container == null:
				_fail("Game HUD has no game-over container for keyboard restart")
				return false
			game_over_container.visible = true
			var event := InputEventKey.new()
			event.pressed = true
			event.keycode = KEY_R
			keyboard_hud.call("_unhandled_input", event)
		"victory_rematch":
			var victory := _find_node_with_script(current_scene, VICTORY_SCREEN_SCRIPT_PATH)
			if victory == null:
				_fail("Victory rematch surface is missing")
				return false
			victory.call("show_victory", "TEST", Color.WHITE, [])
			var rematch_button := _find_button_containing(victory, "REMATCH")
			if rematch_button == null:
				_fail("Victory screen REMATCH button is missing")
				return false
			rematch_button.pressed.emit()
		_:
			_fail("Unknown restart surface: %s" % surface)
			return false
	return true

func _find_node_with_script(start: Node, expected_script_path: String) -> Node:
	if start == null:
		return null
	var pending: Array[Node] = [start]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		var script := node.get_script() as Script
		if script and script.resource_path == expected_script_path:
			return node
		for child: Node in node.get_children():
			pending.append(child)
	return null

func _find_button_containing(start: Node, fragment: String) -> Button:
	if start == null:
		return null
	var pending: Array[Node] = [start]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node is Button and (node as Button).text.contains(fragment):
			return node as Button
		for child: Node in node.get_children():
			pending.append(child)
	return null

func _complete_test_tweens() -> void:
	# Match presentation awaits several sequential tween.finished signals. Advance
	# them to completion instead of killing them, which would strand the awaiting
	# coroutine and its Tween reference when this fast route test swaps scenes.
	for _pass in range(8):
		var active := get_processed_tweens()
		if active.is_empty():
			return
		for tween: Tween in active:
			if tween and tween.is_valid():
				tween.custom_step(10.0)

func _settle_match_presentation() -> void:
	await create_timer(MATCH_PRESENTATION_SETTLE_SECONDS, true, false, true).timeout
	await process_frame

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	_complete_test_tweens()
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
		for _frame in range(4):
			await process_frame
	_complete_test_tweens()
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
