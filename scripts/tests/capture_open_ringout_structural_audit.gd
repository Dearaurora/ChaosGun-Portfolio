extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const VIEWPORT_SIZE := Vector2i(1536, 960)

const AUDIT_VIEWS := [
	{
		"name": "overview",
		"position": Vector3(48.0, 52.0, 62.0),
		"target": Vector3(2.0, -1.2, 2.0),
		"size": 72.0,
	},
	{
		"name": "main_south_underbody",
		"position": Vector3(35.0, 24.0, 49.0),
		"target": Vector3(1.0, -2.3, 10.5),
		"size": 28.0,
	},
	{
		"name": "main_east_underbody",
		"position": Vector3(50.0, 23.0, 20.0),
		"target": Vector3(17.0, -2.4, 0.5),
		"size": 27.0,
	},
	{
		"name": "west_bridge",
		"position": Vector3(-53.0, 26.0, 31.0),
		"target": Vector3(-29.0, -0.6, 2.0),
		"size": 22.0,
	},
	{
		"name": "east_bridge",
		"position": Vector3(57.0, 25.0, 30.0),
		"target": Vector3(31.0, -0.6, 2.0),
		"size": 22.0,
	},
	{
		"name": "north_bridge",
		"position": Vector3(30.0, 25.0, -50.0),
		"target": Vector3(4.0, -0.6, -19.0),
		"size": 22.0,
	},
	{
		"name": "south_bridge",
		"position": Vector3(31.0, 25.0, 54.0),
		"target": Vector3(7.0, -0.6, 19.0),
		"size": 22.0,
	},
	{
		"name": "west_island",
		"position": Vector3(-54.0, 24.0, 31.0),
		"target": Vector3(-40.0, -2.0, 3.0),
		"size": 23.0,
	},
	{
		"name": "east_island",
		"position": Vector3(60.0, 24.0, 29.0),
		"target": Vector3(42.0, -2.0, 2.0),
		"size": 23.0,
	},
	{
		"name": "north_island",
		"position": Vector3(31.0, 24.0, -56.0),
		"target": Vector3(4.0, -2.0, -30.0),
		"size": 23.0,
	},
	{
		"name": "south_island",
		"position": Vector3(33.0, 24.0, 60.0),
		"target": Vector3(7.0, -2.0, 31.0),
		"size": 23.0,
	},
]


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Structural art audit capture requires a render-capable display driver")
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
		push_error("Structural art audit requires GlobalCamera")
		quit(1)
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var phase := _capture_phase()
	for view in AUDIT_VIEWS:
		camera.position = view["position"]
		camera.look_at(view["target"], Vector3.UP)
		camera.size = view["size"]
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		var path := "res://reports/structural_audit_%s_%s.png" % [phase, view["name"]]
		if not _save_frame(path):
			return
	print("Saved %d Open Ring-Out structural audit views (%s)" % [AUDIT_VIEWS.size(), phase])
	quit(0)


func _capture_phase() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="):
			var requested := argument.trim_prefix("--phase=").strip_edges().to_lower()
			if requested in ["before", "after"]:
				return requested
	return "before"


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
