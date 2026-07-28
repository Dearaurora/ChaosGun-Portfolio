extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const DEFAULT_OUT_PATH := "res://reports/open_ringout_slice_screenshot.png"
const VIEWPORT_SIZE := Vector2i(960, 540)
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
	var ringout_motion_frame := OS.get_cmdline_user_args().has("--ringout-motion")
	var authored_motion_frame := OS.get_cmdline_user_args().has("--authored-motion")
	var feedback_frame := OS.get_cmdline_user_args().has("--feedback-frame") or ringout_motion_frame or authored_motion_frame
	if not _stage_showcase_shots(arena, not feedback_frame):
		return
	if authored_motion_frame:
		await _stage_authored_motion_frame(arena)
	elif ringout_motion_frame:
		_stage_ringout_motion_feedback(arena)
	elif feedback_frame:
		_stage_combat_feedback(arena)
	_apply_detail_camera_if_requested(arena)
	if OS.get_cmdline_user_args().has("--outer-spread"):
		await create_timer(1.4).timeout
	elif OS.get_cmdline_user_args().has("--combat-frame"):
		await process_frame
	elif feedback_frame and not authored_motion_frame:
		await create_timer(0.065).timeout
	else:
		await create_timer(0.18).timeout
	await process_frame
	if OS.get_cmdline_user_args().has("--debug-background"):
		_print_background_projection(arena)

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

func _print_background_projection(arena: Node) -> void:
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	var p14_root := arena.get_node_or_null("OpenRingoutBlenderVisuals/P14SunsetEnvironment")
	if camera == null or p14_root == null:
		return
	print("BACKGROUND_VIEW  viewport=%s camera_size=%.2f camera_position=%s" % [root.size, camera.size, camera.global_position])
	for child in _background_nodes(p14_root):
		var child_name := String(child.name)
		if child_name.begins_with("P14CloudBank") or (child_name.begins_with("P14DistantIsland") and child_name.ends_with("Cliff")) or child_name in ["P14HotAirBalloonEnvelope", "P14HotAirBalloonBasket"]:
			print("BACKGROUND_PROJECTION  %s -> %s" % [child.name, camera.unproject_position(child.global_position)])
	var blender_root := arena.get_node_or_null("OpenRingoutBlenderVisuals")
	for child in _background_nodes(blender_root):
		if String(child.name) in ["V3HotAirBalloonBody", "V3HotAirBalloonBasket"]:
			print("BACKGROUND_PROJECTION  %s -> %s" % [child.name, camera.unproject_position(child.global_position)])

func _background_nodes(node: Node) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if node == null:
		return nodes
	if node is Node3D:
		nodes.append(node as Node3D)
	for child in node.get_children():
		nodes.append_array(_background_nodes(child))
	return nodes

func _resolve_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested := argument.trim_prefix("--output=").strip_edges()
			if requested.begins_with("res://") and requested.ends_with(".png"):
				return requested
			push_warning("Ignoring invalid screenshot output path: %s" % requested)
	return DEFAULT_OUT_PATH

func _apply_detail_camera_if_requested(arena: Node) -> void:
	var character_closeup := OS.get_cmdline_user_args().has("--character-closeup")
	var hero_slice := OS.get_cmdline_user_args().has("--hero-slice")
	var west_bridge_detail := OS.get_cmdline_user_args().has("--west-bridge-detail")
	if not OS.get_cmdline_user_args().has("--detail") and not character_closeup and not hero_slice and not west_bridge_detail:
		return
	if arena.has_method("set_runtime_camera_enabled"):
		arena.call("set_runtime_camera_enabled", false)
	if hero_slice or west_bridge_detail:
		for hud_name in ["OpenRingoutHUD", "HUDRoot"]:
			var hud := arena.find_child(hud_name, true, false)
			if hud:
				hud.set("visible", false)
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		return
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	if west_bridge_detail:
		camera.position = Vector3(-5.0, 31.0, 42.0)
		camera.look_at(Vector3(-29.0, 0.0, 2.0), Vector3.UP)
		camera.size = 23.0
	elif hero_slice:
		camera.position = Vector3(26.0, 31.0, 24.0)
		camera.look_at(Vector3(3.0, 0.0, -16.0), Vector3.UP)
		camera.size = 31.0
	else:
		camera.position = Vector3(22.0, 28.0, 31.0) if character_closeup else Vector3(34.0, 43.0, 48.0)
		camera.look_at(Vector3(0.0, 0.0, 1.0), Vector3.UP)
		camera.size = 20.0 if character_closeup else 38.0

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

func _stage_showcase_shots(arena: Node, fire_shots: bool = true) -> bool:
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
	if OS.get_cmdline_user_args().has("--expanded-weapons"):
		poses = [
			{"pos": Vector3(-16.5, 1.15, -8.5), "look": Vector3(8.0, 1.15, 5.0), "weapon": &"gatling"},
			{"pos": Vector3(17.5, 1.15, -7.0), "look": Vector3(32.0, 1.15, 8.0), "weapon": &"shotgun"},
			{"pos": Vector3(-15.0, 1.15, 11.0), "look": Vector3(3.0, 1.15, 20.0), "weapon": &"smg"},
			{"pos": Vector3(12.0, 1.15, 12.0), "look": Vector3(26.0, 1.15, 24.0), "weapon": &"ak_rifle"},
		]
	if OS.get_cmdline_user_args().has("--character-closeup"):
		poses = [
			{"pos": Vector3(-4.8, 1.15, -3.5), "look": Vector3(0.0, 1.15, 1.0), "weapon": &"gatling"},
			{"pos": Vector3(4.8, 1.15, -3.5), "look": Vector3(0.0, 1.15, 1.0), "weapon": &"shotgun"},
			{"pos": Vector3(-4.8, 1.15, 5.0), "look": Vector3(0.0, 1.15, 0.0), "weapon": &"pistol"},
			{"pos": Vector3(4.8, 1.15, 5.0), "look": Vector3(0.0, 1.15, 0.0), "weapon": &"sniper"},
		]
	if OS.get_cmdline_user_args().has("--outer-spread"):
		poses = [
			{"pos": Vector3(-3.0, 1.15, -32.0), "look": Vector3(2.0, 1.15, 2.0), "weapon": &"gatling"},
			{"pos": Vector3(43.0, 1.15, 1.0), "look": Vector3(2.0, 1.15, 2.0), "weapon": &"shotgun"},
			{"pos": Vector3(13.0, 1.15, 31.0), "look": Vector3(2.0, 1.15, 2.0), "weapon": &"smg"},
			{"pos": Vector3(-43.0, 1.15, 8.0), "look": Vector3(2.0, 1.15, 2.0), "weapon": &"ak_rifle"},
		]
	for i in range(4):
		var character := chars[i] as BaseCharacter
		if character == null:
			_fail("Open Ring-Out screenshot staging character %d is not a BaseCharacter" % i)
			return false
		_pose_character(character, poses[i])
	if fire_shots:
		_fire_forward(chars[0] as BaseCharacter)
		_fire_forward(chars[1] as BaseCharacter)
		_fire_forward(chars[2] as BaseCharacter)
		_fire_forward(chars[3] as BaseCharacter)
	return true

func _stage_combat_feedback(arena: Node) -> void:
	var chars = arena.get("_characters") as Array
	if chars.size() < 4:
		return
	var shielded := chars[0] as BaseCharacter
	var hit_character := chars[1] as BaseCharacter
	var respawn_source := chars[2] as BaseCharacter
	var ringout_source := chars[3] as BaseCharacter
	var shield := shielded.get_node_or_null("CombatFeedback") as CharacterCombatFeedback
	if shield:
		shield.set_shield_active(true)
	var hit_feedback := hit_character.get_node_or_null("CombatFeedback") as CharacterCombatFeedback
	if hit_feedback:
		hit_feedback.play_hit(Vector3(-10.0, 0.0, 5.0), 1.15)
	var visual := hit_character.get_visual()
	if visual:
		visual.animate_hit(Vector3(-10.0, 0.0, 5.0), 1.15)
	respawn_source.call("_spawn_character_transition", &"respawn", Color("#6ee7ff"), 1.15)
	ringout_source.call("_spawn_character_transition", &"ringout", Color("#ff4d62"), 1.45)

func _stage_ringout_motion_feedback(arena: Node) -> void:
	var chars = arena.get("_characters") as Array
	if chars.size() < 4:
		return
	var launched := chars[0] as BaseCharacter
	var edge_warning := chars[1] as BaseCharacter
	var falling := chars[2] as BaseCharacter
	var ringout := chars[3] as BaseCharacter
	launched.set_process(false)
	edge_warning.set_process(false)
	falling.set_process(false)
	var launched_feedback := launched.get_node_or_null("CombatFeedback") as CharacterCombatFeedback
	var edge_feedback := edge_warning.get_node_or_null("CombatFeedback") as CharacterCombatFeedback
	var falling_feedback := falling.get_node_or_null("CombatFeedback") as CharacterCombatFeedback
	if launched_feedback:
		launched_feedback.update_motion_feedback(Vector3(18.0, 4.0, -7.0), true, false)
	if edge_feedback:
		edge_feedback.update_motion_feedback(Vector3(-10.0, 0.0, -5.0), false, true)
	if falling_feedback:
		falling_feedback.update_motion_feedback(Vector3(14.0, -8.0, 5.0), true, true)
	ringout.call("_spawn_character_transition", &"ringout", Color("#ff4d62"), 1.45)
	ringout.visible = false

func _stage_authored_motion_frame(arena: Node) -> void:
	var chars = arena.get("_characters") as Array
	if chars.size() < 4:
		return
	for character_node in chars:
		var character := character_node as BaseCharacter
		if character != null:
			character.set_physics_process(false)
	var hit_triggered := false
	for frame in range(60):
		var elapsed := float(frame) / 60.0
		for index in range(4):
			var character := chars[index] as BaseCharacter
			var visual := character.get_visual() if character != null else null
			if visual == null:
				continue
			match index:
				0:
					var starts_now := elapsed >= 0.80
					visual.animate_locomotion(Vector3.FORWARD if starts_now else Vector3.ZERO, Vector3.FORWARD, 1.0 if starts_now else 0.0, 1.0 / 60.0)
				1:
					visual.animate_locomotion(Vector3.FORWARD, Vector3.FORWARD, 1.0, 1.0 / 60.0)
				2:
					var still_running := elapsed < 0.80
					visual.animate_locomotion(Vector3.FORWARD if still_running else Vector3.ZERO, Vector3.FORWARD, 1.0 if still_running else 0.0, 1.0 / 60.0)
				3:
					visual.animate_locomotion(Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0 / 60.0)
					if elapsed >= 0.90 and not hit_triggered:
						visual.animate_hit(Vector3.RIGHT, 1.0)
						hit_triggered = true
		await create_timer(1.0 / 60.0).timeout

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
		"gatling":
			character.weapon_manager.equip_weapon(WeaponData.create_gatling())
		"shotgun":
			character.weapon_manager.equip_weapon(WeaponData.create_shotgun())
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
