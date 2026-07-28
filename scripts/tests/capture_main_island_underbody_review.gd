extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const VIEWPORT_SIZE := Vector2i(960, 540)


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Main-island underbody review requires a render-capable display driver")
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
	_hide_ui(arena)
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		push_error("Underbody review requires GlobalCamera")
		quit(1)
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL

	camera.position = Vector3(35.0, 24.0, 49.0)
	camera.look_at(Vector3(1.0, -2.3, 10.5), Vector3.UP)
	camera.size = 28.0
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	if not _save_frame("res://reports/main_island_underbody_south_review.png"):
		return

	camera.position = Vector3(50.0, 23.0, 20.0)
	camera.look_at(Vector3(17.0, -2.4, 0.5), Vector3.UP)
	camera.size = 27.0
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	if not _save_frame("res://reports/main_island_underbody_east_review.png"):
		return
	print("Saved continuous main-island underbody review frames")
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


func _hide_ui(arena: Node) -> void:
	for name in ["OpenRingoutHUD", "MatchIntroCue", "PauseMenu", "ControlModeReviewPanel"]:
		var node := arena.find_child(name, true, false)
		if node is CanvasItem:
			(node as CanvasItem).visible = false


func _save_frame(path: String) -> bool:
	var image := root.get_texture().get_image()
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
