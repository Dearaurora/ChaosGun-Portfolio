extends SceneTree

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const KEYBINDS_SCENE := "res://scenes/ui/keybinds_screen.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const OPEN_RINGOUT_SCENE := "res://scenes/maps/open_ringout_slice.tscn"
const TWIN_BAYS_SCENE := "res://scenes/maps/twin_bays_splash_arena.tscn"


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("ChaosGun UI capture requires a render-capable display driver.")
		quit(1)
		return
	var viewport_size := _requested_size()
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	root.set_meta("disable_runtime_audio", true)

	var state := _argument_value("--state=", "gameplay")
	var map_id := _argument_value("--map=", "open")
	var player_count := clampi(int(_argument_value("--players=", "4")), 2, 4)
	_configure_roster(player_count)
	var scene_path := _scene_path_for(state, map_id)
	var packed := load(scene_path) as PackedScene
	var scene = packed.instantiate() if packed else null
	if scene == null:
		push_error("Could not instantiate UI capture scene: %s" % scene_path)
		quit(1)
		return
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	match state:
		"ready":
			await create_timer(0.14, true, false, true).timeout
		"gameplay":
			await _await_match_presentation_settled(scene)
		"low_ammo":
			await _await_match_presentation_settled(scene)
			_apply_low_ammo_state(scene)
			await process_frame
		"last_life":
			await _await_match_presentation_settled(scene)
			_apply_last_life_state(scene)
			await process_frame
		"tide_warning":
			await _await_match_presentation_settled(scene)
			var tide := scene.find_child("TwinBaysTideController", true, false)
			if tide and tide.has_method("set_debug_phase"):
				tide.call("set_debug_phase", &"warning", 0.42)
			await create_timer(0.22, true, false, true).timeout
		"pause":
			await _await_match_presentation_settled(scene)
			var pause_menu := scene.find_child("PauseMenu", true, false)
			if pause_menu:
				pause_menu.call("_toggle_pause")
			await create_timer(0.22, true, false, true).timeout
		"result", "draw":
			await _await_match_presentation_settled(scene)
			var characters := scene.get("_characters") as Array
			var winner = null if state == "draw" else characters[0] as BaseCharacter
			var winner_name := "DRAW" if winner == null else String(winner.name)
			var match_config := root.get_node_or_null("MatchConfig")
			var winner_color := Color.WHITE if winner == null else match_config.PLAYER_COLORS[0] as Color
			scene.call("_present_match_result", winner, winner_name, winner_color)
			await create_timer(1.0, true, false, true).timeout
		"keybinds_expanded":
			var toggle := scene.find_child("ExtraPlayersToggle", true, false) as Button
			if toggle:
				toggle.button_pressed = true
			await process_frame
		_:
			await process_frame

	var image := root.get_texture().get_image()
	var fallback := "res://reports/ui_redesign/%s_%s_%dp.png" % [map_id, state, player_count]
	var output := _argument_value("--output=", fallback)
	var error := image.save_png(output)
	paused = false
	root.set_meta("disable_runtime_audio", false)
	if error != OK:
		push_error("Could not save ChaosGun UI screenshot: %d" % error)
		quit(1)
		return
	print("Saved screenshot: %s" % ProjectSettings.globalize_path(output))
	quit(0)


func _scene_path_for(state: String, map_id: String) -> String:
	if state == "menu":
		return MENU_SCENE
	if state == "character_select":
		return CHARACTER_SELECT_SCENE
	if state.begins_with("keybinds"):
		return KEYBINDS_SCENE
	return TWIN_BAYS_SCENE if map_id == "twin" else OPEN_RINGOUT_SCENE


func _configure_roster(player_count: int) -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI if player_count >= 3 else match_config.SlotType.EMPTY,
		match_config.SlotType.AI if player_count >= 4 else match_config.SlotType.EMPTY,
	]


func _apply_low_ammo_state(scene: Node) -> void:
	var characters := scene.get("_characters") as Array
	if characters.is_empty():
		return
	var character := characters[0] as BaseCharacter
	character.weapon_manager.equip_weapon(WeaponData.create_smg())
	if character.weapon_manager.current_weapon:
		character.weapon_manager.current_weapon.current_ammo = 2


func _apply_last_life_state(scene: Node) -> void:
	var characters := scene.get("_characters") as Array
	if not characters.is_empty():
		(characters[0] as BaseCharacter).lives = 1


func _await_match_presentation_settled(scene: Node) -> void:
	var presentation: Node = null
	for node in _walk(scene):
		if node.has_method("get_debug_state") and String(node.name).contains("MatchPresentation"):
			presentation = node
			break
	if presentation == null:
		await create_timer(2.2, true, false, true).timeout
		return
	var deadline_msec := Time.get_ticks_msec() + 3600
	while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
		var state := presentation.call("get_debug_state") as Dictionary
		if String(state.get("cue_state", "")) in ["complete", "result_ready"]:
			await create_timer(0.16, true, false, true).timeout
			return
		await create_timer(0.025, true, false, true).timeout


func _walk(start: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [start]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		result.append(node)
		for child in node.get_children():
			pending.append(child)
	return result


func _requested_size() -> Vector2i:
	var raw := _argument_value("--size=", "960x540")
	var parts := raw.to_lower().split("x")
	if parts.size() != 2:
		return Vector2i(960, 540)
	return Vector2i(clampi(int(parts[0]), 640, 960), clampi(int(parts[1]), 360, 540))


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback
