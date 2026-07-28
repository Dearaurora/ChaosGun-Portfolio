extends SceneTree

const SCENE_PATH := "res://scenes/maps/momentum_circuit_whitebox.tscn"
const DEFAULT_OUT_PATH := "res://reports/momentum_circuit_whitebox.png"
const VIEWPORT_SIZE := Vector2i(960, 540)


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Momentum Circuit capture requires a render-capable display driver")
		return

	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE

	var match_config := root.get_node_or_null("MatchConfig")
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
	_isolate_capture(arena)
	await create_timer(0.45).timeout
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport screenshot image is empty")
		return
	if image.get_size() != VIEWPORT_SIZE:
		_fail("Capture size differs: %s != %s" % [str(image.get_size()), str(VIEWPORT_SIZE)])
		return

	var out_path := _resolve_output_path()
	var absolute_out_path := ProjectSettings.globalize_path(out_path) if out_path.begins_with("res://") else out_path
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_out_path.get_base_dir())
	if directory_error != OK:
		_fail("Could not create capture output directory, error %d" % directory_error)
		return
	var error := image.save_png(absolute_out_path)
	if error != OK:
		_fail("Could not save screenshot to %s, error %d" % [absolute_out_path, error])
		return
	print(
		"MOMENTUM_CIRCUIT_CAPTURE_OK|path=%s|width=%d|height=%d"
		% [absolute_out_path, image.get_width(), image.get_height()]
	)
	quit(0)


func _isolate_capture(arena: Node) -> void:
	for node: Node in arena.find_children("*", "", true, false):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
	for player: Node in get_nodes_in_group(&"player"):
		player.queue_free()

	var spawner := arena.get_node_or_null("WeaponSpawner")
	if spawner != null:
		spawner.set_process(false)
		spawner.set_physics_process(false)
		if _has_property(spawner, &"max_active_pickups"):
			spawner.set("max_active_pickups", 0)
		if spawner is Node3D:
			(spawner as Node3D).visible = false

	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera != null:
		camera.current = true


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _resolve_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested := argument.trim_prefix("--output=").strip_edges()
			if requested.ends_with(".png"):
				return requested
	return DEFAULT_OUT_PATH


func _fail(message: String) -> void:
	push_error(message)
	print("MOMENTUM_CIRCUIT_CAPTURE_ERROR|message=%s" % message.replace("|", "/"))
	quit(1)
