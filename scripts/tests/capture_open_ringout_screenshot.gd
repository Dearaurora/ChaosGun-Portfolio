extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const DEFAULT_OUT_PATH := "res://reports/open_ringout_slice_screenshot.png"
const VIEWPORT_SIZE := Vector2i(1536, 960)
const RENDER_DRIVER_REQUIRED_MESSAGE := "Open Ring-Out screenshot capture cannot run with --headless: Godot's headless DisplayServer disables rendering and window management, so root.get_texture() cannot provide a screenshot. Run this gate from a render-capable display driver, for example the Windows console Godot executable without --headless."

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail(RENDER_DRIVER_REQUIRED_MESSAGE)
		return

	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE

	var scene = load(SCENE_PATH) as PackedScene
	if scene == null:
		push_error("Could not load %s" % SCENE_PATH)
		quit(1)
		return
	if not _configure_showcase_roster():
		return

	var arena = scene.instantiate()
	root.add_child(arena)
	current_scene = arena

	await process_frame
	await process_frame
	await create_timer(0.65).timeout
	if not _stage_showcase_shots(arena):
		return
	_apply_detail_camera_if_requested(arena)
	await create_timer(0.18).timeout
	await process_frame

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("Viewport screenshot texture is unavailable. %s" % RENDER_DRIVER_REQUIRED_MESSAGE)
		return

	var image = viewport_texture.get_image()
	if image == null or image.is_empty():
		_fail("Viewport screenshot image is empty. %s" % RENDER_DRIVER_REQUIRED_MESSAGE)
		return

	var out_path := _resolve_output_path()
	var err = image.save_png(out_path)
	if err != OK:
		push_error("Could not save screenshot to %s, error %d" % [out_path, err])
		quit(1)
		return

	print("Saved screenshot: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)

func _resolve_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested := argument.trim_prefix("--output=").strip_edges()
			if requested.begins_with("res://") and requested.ends_with(".png"):
				return requested
			push_warning("Ignoring invalid screenshot output path: %s" % requested)
	return DEFAULT_OUT_PATH

func _apply_detail_camera_if_requested(arena: Node) -> void:
	if not OS.get_cmdline_user_args().has("--detail"):
		return
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(34.0, 43.0, 48.0)
	camera.look_at(Vector3(0.0, 0.0, 1.0), Vector3.UP)
	camera.size = 38.0

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _configure_showcase_roster() -> bool:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		return false
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
	return true

func _stage_showcase_shots(arena: Node) -> bool:
	var chars = arena.get("_characters") as Array
	if chars.size() < 4:
		_fail("Open Ring-Out screenshot staging expected 4 characters, found %d" % chars.size())
		return false
	var poses = [
		{"pos": Vector3(-16.5, 1.15, -8.5), "look": Vector3(8.0, 1.15, 5.0), "weapon": &"pistol"},
		{"pos": Vector3(17.5, 1.15, -7.0), "look": Vector3(32.0, 1.15, 8.0), "weapon": &"smg"},
		{"pos": Vector3(-15.0, 1.15, 11.0), "look": Vector3(3.0, 1.15, 20.0), "weapon": &"sniper"},
		{"pos": Vector3(12.0, 1.15, 12.0), "look": Vector3(26.0, 1.15, 24.0), "weapon": &"ak_rifle"},
	]
	for i in range(4):
		var character := chars[i] as BaseCharacter
		if character == null:
			_fail("Open Ring-Out screenshot staging character %d is not a BaseCharacter" % i)
			return false
		_pose_character(character, poses[i])
	_fire_forward(chars[0] as BaseCharacter)
	_fire_forward(chars[1] as BaseCharacter)
	_fire_forward(chars[2] as BaseCharacter)
	_fire_forward(chars[3] as BaseCharacter)
	return true

func _pose_character(character: BaseCharacter, pose: Dictionary) -> void:
	if character == null:
		return
	character.freeze = true
	character.sleeping = true
	character.visible = true
	character.linear_velocity = Vector3.ZERO
	character.angular_velocity = Vector3.ZERO
	character.global_position = pose["pos"]
	_face_character(character, pose["look"])
	_equip_showcase_weapon(character, String(pose["weapon"]))
	var visual = character.get_visual()
	if visual:
		visual.set_weapon_visual(pose["weapon"])
	if character.weapon_manager:
		character.weapon_manager.is_switching = false

func _face_character(character: BaseCharacter, target: Vector3) -> void:
	var dir = target - character.global_position
	dir.y = 0
	if dir.length_squared() <= 0.001:
		return
	character.transform.basis = Basis.looking_at(dir.normalized(), Vector3.UP)

func _equip_showcase_weapon(character: BaseCharacter, weapon_id: String) -> void:
	if character.weapon_manager == null:
		return
	match weapon_id:
		"smg":
			character.weapon_manager.equip_weapon(WeaponData.create_smg())
		"ak_rifle":
			character.weapon_manager.equip_weapon(WeaponData.create_ak_rifle())
		"sniper":
			character.weapon_manager.equip_weapon(WeaponData.create_sniper())
		_:
			if character.weapon_manager.sidearm:
				character.weapon_manager.current_weapon = character.weapon_manager.sidearm
	character.weapon_manager.is_switching = false
	if character.weapon_manager.current_weapon:
		character.weapon_manager.current_weapon.fire_cooldown = 0.0

func _fire_forward(shooter: BaseCharacter) -> void:
	if shooter == null:
		return
	if shooter.weapon_manager == null or shooter.weapon_point == null:
		return
	shooter.weapon_manager.is_switching = false
	if shooter.weapon_manager.current_weapon:
		shooter.weapon_manager.current_weapon.fire_cooldown = 0.0
	var dir = -shooter.global_transform.basis.z.normalized()
	dir.y = 0.02
	dir = dir.normalized()
	shooter.weapon_manager.try_fire(shooter.weapon_point, dir, shooter)
