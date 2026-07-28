extends SceneTree

const OPEN_RINGOUT_SCENE := "res://scenes/maps/open_ringout_slice.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const KEYBINDS_SCENE := "res://scenes/ui/keybinds_screen.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("P28 UI capture needs a render-capable display driver")
		quit(1)
		return

	var viewport_size := _requested_size()
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	var state := _argument_value("--state=", "gameplay")
	var scene_path := (
		MENU_SCENE if state == "menu"
		else KEYBINDS_SCENE if state.begins_with("keybinds")
		else CHARACTER_SELECT_SCENE if state == "character_select"
		else OPEN_RINGOUT_SCENE
	)
	var packed := load(scene_path) as PackedScene
	var scene = packed.instantiate() if packed else null
	if scene == null:
		push_error("Could not instantiate P28 capture scene: %s" % scene_path)
		quit(1)
		return

	if scene_path == OPEN_RINGOUT_SCENE:
		_configure_roster()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	match state:
		"gameplay":
			await _await_match_presentation_settled(scene)
		"pause":
			await _await_match_presentation_settled(scene)
			var pause_menu := scene.get_node_or_null("PauseMenu")
			if pause_menu:
				pause_menu.call("_toggle_pause")
			await process_frame
		"result":
			await _await_match_presentation_settled(scene)
			var characters := scene.get("_characters") as Array
			var winner := characters[0] as BaseCharacter
			var match_config := root.get_node_or_null("MatchConfig")
			scene.call("_present_match_result", winner, winner.name, match_config.PLAYER_COLORS[0])
			await create_timer(0.84, true, false, true).timeout
		"keybinds_expanded":
			var toggle := scene.find_child("ExtraPlayersToggle", true, false) as Button
			if toggle:
				toggle.button_pressed = true
			await process_frame
		_:
			await process_frame

	var image := root.get_texture().get_image()
	var output := _argument_value("--output=", "res://reports/p28_%s.png" % state)
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save P28 UI screenshot: %d" % error)
		paused = false
		quit(1)
		return
	print("Saved screenshot: %s" % ProjectSettings.globalize_path(output))
	paused = false
	quit(0)


func _await_match_presentation_settled(scene: Node) -> void:
	var presentation := scene.find_child("OpenRingoutMatchPresentation", true, false)
	if presentation == null or not presentation.has_method("get_debug_state"):
		await create_timer(2.2, true, false, true).timeout
		return
	var deadline_msec := Time.get_ticks_msec() + 3200
	while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
		var state := presentation.call("get_debug_state") as Dictionary
		if String(state.get("cue_state", "")) == "complete":
			await create_timer(0.18, true, false, true).timeout
			return
		await create_timer(0.025, true, false, true).timeout


func _configure_roster() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
		]


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
