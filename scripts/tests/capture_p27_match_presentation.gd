extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const VIEWPORT_SIZE := Vector2i(960, 540)


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("P27 match-presentation capture requires a render-capable display driver")
		quit(1)
		return
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	_configure_roster()
	var packed := load(SCENE_PATH) as PackedScene
	var arena = packed.instantiate() if packed else null
	if arena == null:
		push_error("Could not instantiate %s" % SCENE_PATH)
		quit(1)
		return
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	var characters := arena.get("_characters") as Array
	for item in characters:
		var character := item as BaseCharacter
		if character:
			character.freeze = true
			character.linear_velocity = Vector3.ZERO

	await create_timer(0.20, true, false, true).timeout
	await RenderingServer.frame_post_draw
	if not _save_frame("res://reports/p27_match_intro_ready.png"):
		return
	await create_timer(0.44, true, false, true).timeout
	await RenderingServer.frame_post_draw
	if not _save_frame("res://reports/p27_match_intro_go.png"):
		return

	await create_timer(0.72, true, false, true).timeout
	var presentation := arena.get_node_or_null("OpenRingoutMatchPresentation")
	if presentation == null or characters.is_empty():
		push_error("P27 capture is missing its presentation controller or winner")
		quit(1)
		return
	var winner := characters[0] as BaseCharacter
	winner.global_position = Vector3(-4.0, 1.15, 1.0)
	winner.visible = true
	for index in range(1, characters.size()):
		var opponent := characters[index] as BaseCharacter
		if opponent:
			opponent.visible = false
			opponent.is_game_over = true
	var match_config = root.get_node_or_null("MatchConfig")
	presentation.call("present_result", winner, match_config.PLAYER_COLORS[0])
	await create_timer(0.68, true, false, true).timeout
	await RenderingServer.frame_post_draw
	if not _save_frame("res://reports/p27_winner_focus.png"):
		return
	print("Saved P27 match-presentation evidence")
	quit(0)


func _configure_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
		]
		match_config.PLAYER_COLORS = [
			Color("#ef3f3f"),
			Color("#78d23d"),
			Color("#24a9e8"),
			Color("#f2bf27"),
		]


func _save_frame(path: String) -> bool:
	var texture := root.get_texture()
	if texture == null:
		push_error("Viewport texture is unavailable")
		quit(1)
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image is empty")
		quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s, error %d" % [path, error])
		quit(1)
		return false
	print(ProjectSettings.globalize_path(path))
	return true
