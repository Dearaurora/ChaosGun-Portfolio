extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const DEFAULT_PREFIX := "p25_ambient_motion"
const VIEWPORT_SIZE := Vector2i(960, 540)


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("P25 ambient-motion capture requires a render-capable display driver")
		quit(1)
		return

	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	_configure_empty_roster()

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

	if arena.has_method("set_runtime_camera_enabled"):
		arena.call("set_runtime_camera_enabled", false)
	_hide_gameplay_ui(arena)
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		push_error("P25 capture requires GlobalCamera")
		quit(1)
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 56.0, 58.0)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.size = 66.0

	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var prefix := _resolve_output_prefix()
	var start_path := "res://reports/%s_start.png" % prefix
	var end_path := "res://reports/%s_end.png" % prefix
	if not _save_frame(start_path):
		quit(1)
		return

	await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	if not _save_frame(end_path):
		quit(1)
		return

	print("P25 motion debug: ", arena.call("get_environment_motion_debug"))
	print("Saved P25 ambient-motion evidence:")
	print(ProjectSettings.globalize_path(start_path))
	print(ProjectSettings.globalize_path(end_path))
	quit(0)


func _configure_empty_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]


func _hide_gameplay_ui(arena: Node) -> void:
	for node_name in ["OpenRingoutHUD", "HUDRoot", "PauseMenu"]:
		var ui_node := arena.find_child(node_name, true, false)
		if ui_node is CanvasItem:
			(ui_node as CanvasItem).visible = false


func _resolve_output_prefix() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="):
			var requested := argument.trim_prefix("--prefix=").strip_edges()
			var sanitized := requested.validate_filename().replace(" ", "_")
			if not sanitized.is_empty():
				return sanitized
	return DEFAULT_PREFIX


func _save_frame(path: String) -> bool:
	var texture := root.get_texture()
	if texture == null:
		push_error("Viewport texture is unavailable")
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image is empty")
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s, error %d" % [path, error])
		return false
	return true
