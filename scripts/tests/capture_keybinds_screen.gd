extends SceneTree

const SCENE_PATH := "res://scenes/ui/keybinds_screen.tscn"
const VIEWPORT_SIZE := Vector2i(1536, 960)

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Keybind screenshot capture needs a render-capable display driver")
		quit(1)
		return
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var packed := load(SCENE_PATH) as PackedScene
	var screen = packed.instantiate() if packed else null
	if screen == null:
		push_error("Could not instantiate keybinds screen")
		quit(1)
		return
	root.add_child(screen)
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--expanded"):
		var toggle = screen.find_child("ExtraPlayersToggle", true, false) as Button
		var scroll = screen.find_child("KeybindScroll", true, false) as ScrollContainer
		if toggle:
			toggle.button_pressed = true
		await process_frame
		if scroll:
			scroll.scroll_vertical = 420
		await process_frame
	var image := root.get_texture().get_image()
	var output := _output_path()
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save keybind screenshot: %d" % error)
		quit(1)
		return
	print("Saved screenshot: %s" % ProjectSettings.globalize_path(output))
	quit(0)

func _output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return argument.trim_prefix("--output=")
	return "res://reports/keybinds_screen.png"
