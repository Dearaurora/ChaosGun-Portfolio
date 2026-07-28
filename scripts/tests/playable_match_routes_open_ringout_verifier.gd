extends SceneTree

const APPROVED_MAP_NAME := "Open Ring-Out Slice"
const APPROVED_MAP_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const TWIN_BAYS_MAP_NAME := "Twin Bays Splash Arena"
const TWIN_BAYS_MAP_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const MOMENTUM_MAP_NAME := "Momentum Circuit"
const MOMENTUM_MAP_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const PLAYABLE_MAP_PATHS := [
	APPROVED_MAP_PATH,
	TWIN_BAYS_MAP_PATH,
	MOMENTUM_MAP_PATH,
]
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const PAUSE_MENU_SCRIPT_PATH := "res://scripts/ui/pause_menu.gd"
const VICTORY_SCREEN_SCRIPT_PATH := "res://scripts/ui/victory_screen.gd"
const SCENE_SURFACE_SETTLE_SECONDS := 0.35
const MAX_SCENE_REPLACEMENT_FRAMES := 240
const MAX_RESTART_SURFACE_READY_FRAMES := 240
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
	if maps.size() != 3:
		_fail("Exactly three finished player-facing maps should be selectable; got %d maps" % maps.size())
		return
	var open_entry := maps[0] as Array
	var twin_entry := maps[1] as Array
	var momentum_entry := maps[2] as Array
	if open_entry.size() < 2 or open_entry[0] != APPROVED_MAP_NAME or open_entry[1] != APPROVED_MAP_PATH:
		_fail("Open Ring-Out must remain the first playable map, got %s" % str(open_entry))
	elif twin_entry.size() < 2 or twin_entry[0] != TWIN_BAYS_MAP_NAME or twin_entry[1] != TWIN_BAYS_MAP_PATH:
		_fail("Twin Bays Splash Arena must be the second playable map, got %s" % str(twin_entry))
	elif momentum_entry.size() < 2 or momentum_entry[0] != MOMENTUM_MAP_NAME or momentum_entry[1] != MOMENTUM_MAP_PATH:
		_fail("Momentum Circuit must be the third playable map, got %s" % str(momentum_entry))
	else:
		print("OK  player-facing maps expose Open Ring-Out, Twin Bays, then Momentum Circuit")

func _verify_quick_ai_route(match_config: Node) -> void:
	match_config.configure_quick_ai_match(0)
	if match_config.get_selected_map_path() != APPROVED_MAP_PATH:
		_fail("Forced random roll 0 should select Open Ring-Out")
	match_config.configure_quick_ai_match(1)
	if match_config.get_selected_map_path() != TWIN_BAYS_MAP_PATH:
		_fail("Forced random roll 1 should select Twin Bays")
	match_config.configure_quick_ai_match(2)
	if match_config.get_selected_map_path() != MOMENTUM_MAP_PATH:
		_fail("Forced random roll 2 should select Momentum Circuit")

	var menu_scene := load(MAIN_MENU_SCENE) as PackedScene
	if menu_scene == null:
		_fail("Could not load %s" % MAIN_MENU_SCENE)
		return

	var menu := menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame

	var previous_scene_id := menu.get_instance_id()
	menu.call("_on_vs_ai")
	if not await _wait_for_scene_replacement(previous_scene_id):
		_fail("Quick AI route did not replace the main menu scene")
		return
	await _settle_match_presentation()

	if current_scene == null:
		_fail("Quick AI route did not create a current scene")
		return
	if current_scene.scene_file_path not in PLAYABLE_MAP_PATHS:
		_fail("Quick AI should route to a registered playable map, got %s" % current_scene.scene_file_path)
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
	previous_scene_id = _current_scene_instance_id()
	match_config.restart_current_match(self, 1)
	if not await _wait_for_scene_replacement(previous_scene_id, TWIN_BAYS_MAP_PATH):
		_fail("Quick AI rematch roll 1 did not replace the arena with Twin Bays")
		return
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != TWIN_BAYS_MAP_PATH:
		_fail("Quick AI rematch roll 1 should route to Twin Bays")
	_complete_test_tweens()
	previous_scene_id = _current_scene_instance_id()
	match_config.restart_current_match(self, 2)
	if not await _wait_for_scene_replacement(previous_scene_id, MOMENTUM_MAP_PATH):
		_fail("Quick AI rematch roll 2 did not replace the arena with Momentum Circuit")
		return
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != MOMENTUM_MAP_PATH:
		_fail("Quick AI rematch roll 2 should route to Momentum Circuit")
	_complete_test_tweens()
	previous_scene_id = _current_scene_instance_id()
	match_config.restart_current_match(self, 0)
	if not await _wait_for_scene_replacement(previous_scene_id, APPROVED_MAP_PATH):
		_fail("Quick AI rematch roll 0 did not replace the arena with Open Ring-Out")
		return
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != APPROVED_MAP_PATH:
		_fail("Quick AI rematch roll 0 should route to Open Ring-Out")
	else:
		print("OK  quick AI rematch reselects across the full three-map pool")

	for surface: String in [
		"pause_menu",
		"victory_rematch",
		"victory_keyboard",
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

	if match_config.get("selected_map_index") != 2:
		_fail("Character select should clamp an oversized index to Momentum Circuit (index 2)")
	if int(match_config.get("match_mode")) != int(match_config.MatchMode.LOCAL_CUSTOM):
		_fail("Character select should mark the match as LOCAL_CUSTOM")
	var map_label := select_screen.get_node_or_null(
		"CharacterSelectRoot/SafeArea/Page/FooterRail/MapSelector/MapContent/MapInfo/MapLabel"
	) as Label
	if map_label == null or map_label.text != MOMENTUM_MAP_NAME.to_upper():
		_fail("Character select should visibly present Momentum Circuit at index 2")

	select_screen.call("_on_map_next")
	await process_frame
	if match_config.get("selected_map_index") != 0:
		_fail("Map selector should wrap from Momentum Circuit to Open Ring-Out")
	select_screen.call("_on_map_prev")
	await process_frame
	if match_config.get("selected_map_index") != 2:
		_fail("Map selector should wrap back from Open Ring-Out to Momentum Circuit")

	var previous_scene_id := _current_scene_instance_id()
	select_screen.call("_on_start")
	if not await _wait_for_scene_replacement(previous_scene_id, MOMENTUM_MAP_PATH):
		_fail("Local custom start did not replace character select with Momentum Circuit")
		return
	await _settle_match_presentation()

	if current_scene == null:
		_fail("Local custom route did not create a current scene")
		return
	if current_scene.scene_file_path != MOMENTUM_MAP_PATH:
		_fail("Local custom route should load selected Momentum Circuit map, got %s" % current_scene.scene_file_path)
	else:
		print("OK  local selector visibly cycles all maps and launches Momentum Circuit")

	_complete_test_tweens()
	previous_scene_id = _current_scene_instance_id()
	match_config.restart_current_match(self, 0)
	if not await _wait_for_scene_replacement(previous_scene_id, MOMENTUM_MAP_PATH):
		_fail("Local custom rematch did not replace the Momentum Circuit arena")
		return
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != MOMENTUM_MAP_PATH:
		_fail("Local custom rematch should preserve the player-selected Momentum Circuit map")
	else:
		print("OK  local rematch preserves the manually selected map")

	await _load_match_scene(match_config, MOMENTUM_MAP_PATH, false)
	if not await _wait_for_restart_surface("pause_menu"):
		_fail("Local custom pause-menu restart surface did not become ready")
		return
	previous_scene_id = _current_scene_instance_id()
	if not _invoke_restart_surface("pause_menu"):
		return
	if not await _wait_for_scene_replacement(previous_scene_id, MOMENTUM_MAP_PATH):
		_fail("Local custom pause-menu restart did not replace the Momentum Circuit arena")
		return
	await _settle_match_presentation()
	if current_scene == null or current_scene.scene_file_path != MOMENTUM_MAP_PATH:
		_fail("Local custom pause-menu restart should preserve Momentum Circuit")
	elif int(match_config.get("selected_map_index")) != 2:
		_fail("Local custom pause-menu restart changed the selected map index")
	else:
		print("OK  local restart surface preserves the manually selected map")

func _verify_quick_restart_surface(match_config: Node, surface: String) -> void:
	await _load_match_scene(match_config, MOMENTUM_MAP_PATH, true)
	if current_scene == null:
		_fail("Could not prepare Momentum Circuit for quick restart surface %s" % surface)
		return
	if not await _wait_for_restart_surface(surface):
		_fail("Quick restart surface %s did not become ready" % surface)
		return

	# An invalid sentinel proves that the real UI handler asked MatchConfig to
	# reselect from the playable pool instead of merely reloading the arena.
	match_config.set("selected_map_index", 99)
	var previous_scene_id := _current_scene_instance_id()
	if not _invoke_restart_surface(surface):
		return
	if not await _wait_for_scene_replacement(previous_scene_id):
		_fail("Quick restart surface %s did not replace the current arena" % surface)
		return
	await _settle_match_presentation()

	if current_scene == null:
		_fail("Quick restart surface %s did not load a scene" % surface)
		return
	var selected_index := int(match_config.get("selected_map_index"))
	var playable_count := (match_config.get("MAPS") as Array).size()
	if selected_index < 0 or selected_index >= playable_count:
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
	var selected_index := PLAYABLE_MAP_PATHS.find(path)
	if selected_index < 0:
		_fail("Cannot prepare unknown playable map path %s" % path)
		return
	if quick_ai:
		match_config.configure_quick_ai_match(selected_index)
	else:
		match_config.configure_local_match()
		match_config.set("selected_map_index", selected_index)
		match_config.set("slots", [
			match_config.SlotType.HUMAN,
			match_config.SlotType.HUMAN,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		])
	_complete_test_tweens()
	var previous_scene_id := _current_scene_instance_id()
	var change_error := change_scene_to_file(path)
	if change_error != OK:
		_fail("Could not request match scene %s: error %d" % [path, change_error])
		return
	if not await _wait_for_scene_replacement(previous_scene_id, path):
		_fail("Match scene replacement did not settle on %s" % path)
		return
	await _settle_match_presentation()

func _current_scene_instance_id() -> int:
	if current_scene == null or not is_instance_valid(current_scene):
		return 0
	return current_scene.get_instance_id()

func _wait_for_scene_replacement(previous_scene_id: int, expected_path: String = "") -> bool:
	for _frame in range(MAX_SCENE_REPLACEMENT_FRAMES):
		await process_frame
		if current_scene == null or not is_instance_valid(current_scene):
			continue
		if current_scene.get_instance_id() == previous_scene_id:
			continue
		if not expected_path.is_empty() and current_scene.scene_file_path != expected_path:
			continue
		return true
	return false

func _wait_for_restart_surface(surface: String) -> bool:
	for _frame in range(MAX_RESTART_SURFACE_READY_FRAMES):
		if _restart_surface_is_ready(surface):
			return true
		await process_frame
	return false

func _restart_surface_is_ready(surface: String) -> bool:
	if current_scene == null or not is_instance_valid(current_scene):
		return false
	match surface:
		"pause_menu":
			return _find_node_with_script(current_scene, PAUSE_MENU_SCRIPT_PATH) != null
		"victory_rematch", "victory_keyboard":
			return _find_node_with_script(current_scene, VICTORY_SCREEN_SCRIPT_PATH) != null
	return false

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
		"victory_keyboard":
			var keyboard_victory := _find_node_with_script(current_scene, VICTORY_SCREEN_SCRIPT_PATH)
			if keyboard_victory == null:
				_fail("Victory keyboard restart surface is missing")
				return false
			keyboard_victory.call("show_victory", "TEST", Color.WHITE, [])
			var event := InputEventKey.new()
			event.pressed = true
			event.keycode = KEY_R
			keyboard_victory.call("_unhandled_input", event)
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
	# Map routing is the contract under test here; intro/result timing has its
	# own real-time presentation verifiers. Give the deferred scene replacement
	# a short real-time window, but do not custom-step every processed Tween:
	# unrelated HUD auto-hide Tweens would also finish and remove the restart
	# surfaces this verifier is explicitly checking.
	await create_timer(SCENE_SURFACE_SETTLE_SECONDS, true, false, true).timeout
	await process_frame

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	_complete_test_tweens()
	if current_scene and is_instance_valid(current_scene):
		# Do not queue-free a live arena immediately after the final restart.
		# Twin Bays can still own Vulkan particle/material work from its intro,
		# and forcing that ownership graph down before SceneTree shutdown can
		# strand the headless process after every assertion has already passed.
		for _frame in range(4):
			await process_frame
		RenderingServer.force_sync()
		_quiesce_scene_for_shutdown(current_scene)
		paused = true
		await process_frame
		RenderingServer.force_sync()
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

func _quiesce_scene_for_shutdown(scene: Node) -> void:
	var pending: Array[Node] = [scene]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		for child: Node in node.get_children():
			pending.append(child)
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = false
		elif node is CPUParticles3D:
			(node as CPUParticles3D).emitting = false
		elif node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stop()
		elif node is AudioStreamPlayer2D:
			(node as AudioStreamPlayer2D).stop()
		elif node is AudioStreamPlayer3D:
			(node as AudioStreamPlayer3D).stop()
		elif node is AnimationPlayer:
			(node as AnimationPlayer).stop()
		node.set_process(false)
		node.set_physics_process(false)
