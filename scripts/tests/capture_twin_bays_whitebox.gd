extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_whitebox.tscn"
const DEFAULT_OUT_PATH := "res://reports/twin_bays_whitebox.png"
const VIEWPORT_SIZE := Vector2i(960, 540)

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Twin Bays capture requires a render-capable display driver; do not use --headless.")
		return

	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		return
	match_config.slots = [
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]

	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		return
	var arena := packed_scene.instantiate()
	root.add_child(arena)
	current_scene = arena

	await process_frame
	await process_frame
	var review_panel := arena.find_child("ControlModeReviewPanel", true, false) as CanvasItem
	if review_panel:
		review_panel.visible = false
	await create_timer(0.45).timeout
	await process_frame

	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport screenshot image is empty")
		return
	var out_path := _resolve_output_path()
	var error := image.save_png(out_path)
	if error != OK:
		_fail("Could not save screenshot to %s, error %d" % [out_path, error])
		return
	print("Saved screenshot: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)

func _resolve_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested := argument.trim_prefix("--output=").strip_edges()
			if requested.begins_with("res://") and requested.ends_with(".png"):
				return requested
	return DEFAULT_OUT_PATH

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
