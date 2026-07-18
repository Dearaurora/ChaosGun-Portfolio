extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const MatchPresentationScript = preload("res://scripts/maps/party_shooter_match_presentation.gd")
const CAPTURE_PRESENTATION_PROFILE := {
	"profile_id": "twin_bays_splash_arena_capture",
	"intro_reveal_duration": 1.35,
	"winner_focus_delay": 0.78,
	"winner_camera_duration": 0.72,
	"hud_focus_alpha": 0.22,
	"hud_root_names": ["GameHUD"],
	"ready_color": Color("#FFF4DC"),
	"go_color": Color("#FFD447"),
	"ink_color": Color("#073E57"),
}
const CAPTURE_MODES := [
	"empty", "battle", "portal", "mobile",
	"left_portal", "right_portal",
	"north_west", "north_east", "south_west", "south_east", "center",
	"ambient_start", "ambient_end", "intro_ready", "intro_go", "winner",
]

var _arena: Node3D = null


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Twin Bays production capture requires a render-capable display driver")
		return
	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene is missing: %s" % SCENE_PATH)
		return

	var mode := _argument_value("--mode=", "empty").to_lower()
	if mode not in CAPTURE_MODES:
		_fail("Unknown capture mode '%s'; expected %s" % [mode, CAPTURE_MODES])
		return
	var default_size := _default_size_for_mode(mode)
	var viewport_size := Vector2i(
		maxi(640, int(_argument_value("--width=", str(default_size.x)))),
		maxi(360, int(_argument_value("--height=", str(default_size.y))))
	)
	var output_path := _argument_value("--output=", _default_output_for_mode(mode))
	if not output_path.begins_with("res://reports/") or not output_path.to_lower().ends_with(".png"):
		_fail("Capture output must be a PNG under res://reports/: %s" % output_path)
		return

	seed(20260716)
	root.set_meta("disable_runtime_audio", true)
	var test_window_policy := root.get_node_or_null("TestWindowPolicy")
	# A decorated 1920x1080 window is clamped to the Windows work area and yields
	# a 1920x1061 viewport. Borderless capture preserves the requested pixel gate.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_position(Vector2i.ZERO)
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	if test_window_policy != null and test_window_policy.has_method("enforce_now"):
		test_window_policy.call("enforce_now")
	_configure_slots(mode)

	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	if _arena == null:
		_fail("Could not instantiate production scene")
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame
	_configure_capture_runtime(mode)
	_configure_geometry_view(mode)
	if mode in ["battle", "mobile", "intro_ready", "intro_go", "winner"]:
		_prepare_review_characters()
	_hide_review_overlays(_arena)

	# Imported foreground + four hero/weapon rigs need several Forward+ frames to
	# compile every material pipeline; shorter captures can contain false black meshes.
	var settle_seconds := float(_argument_value("--settle=", "4.0"))
	await create_timer(maxf(settle_seconds, 0.2)).timeout
	if mode in ["ambient_start", "ambient_end"]:
		await _set_deterministic_ambient_frame(0.0 if mode == "ambient_start" else 3.0)
	if mode in ["intro_ready", "intro_go", "winner"]:
		await _prepare_presentation_frame(mode)
		_hide_review_overlays(_arena)
	if mode == "portal":
		_trigger_portal_review_bursts()
		await create_timer(0.10).timeout
	await process_frame
	if _is_geometry_view(mode):
		if not _verify_geometry_view(mode, viewport_size):
			return
	elif mode == "winner":
		if not _verify_winner_framing(viewport_size):
			return
	elif not _verify_framing(viewport_size):
		return

	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport screenshot is empty")
		return
	if image.get_width() != viewport_size.x or image.get_height() != viewport_size.y:
		_fail("Capture size mismatch: image=%dx%d requested=%dx%d" % [
			image.get_width(), image.get_height(), viewport_size.x, viewport_size.y,
		])
		return
	var error := image.save_png(output_path)
	if error != OK:
		_fail("Could not save screenshot %s (error %d)" % [output_path, error])
		return
	await _cleanup_capture_scene()
	print("TWIN_BAYS_CAPTURE_PASS mode=%s size=%dx%d output=%s" % [
		mode,
		viewport_size.x,
		viewport_size.y,
		ProjectSettings.globalize_path(output_path),
	])
	quit(0)


func _configure_slots(mode: String) -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		return
	if mode in ["battle", "mobile", "intro_ready", "intro_go", "winner"]:
		match_config.slots = [
			match_config.SlotType.HUMAN,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
		]
	else:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]


func _verify_framing(viewport_size: Vector2i) -> bool:
	var camera := root.get_camera_3d()
	if camera == null:
		_fail("Production scene has no active Camera3D")
		return false
	var probes: Array[Vector3] = []
	var review_character_count := 0
	for child in _arena.get_children():
		if child is BaseCharacter and not child is CloneCharacter:
			var character := child as BaseCharacter
			review_character_count += 1
			if not character.visible or character.is_dead or character.is_game_over:
				_fail("Battle review character is not alive and visible: %s" % character.name)
				return false
			probes.append(character.global_position + Vector3.UP * 2.0)
	if review_character_count not in [0, 4]:
		_fail("Battle review capture requires four characters, got %d" % review_character_count)
		return false
	if review_character_count == 0:
		if _arena.has_method("_get_spawn_points"):
			for point in _arena.call("_get_spawn_points"):
				probes.append((point as Vector3) + Vector3.UP * 2.0)
		var portals := _arena.get_node_or_null("Portals")
		if portals:
			for portal_name in ["LeftPortal", "RightPortal"]:
				var portal := portals.find_child(portal_name, true, false) as Node3D
				if portal:
					probes.append(portal.global_position + Vector3.UP * 4.5)
		if _arena.has_method("get_twin_bays_layout"):
			var layout := _arena.call("get_twin_bays_layout") as Dictionary
			for pipe_value: Variant in layout.get("portal_pipes", []):
				var pipe := pipe_value as Dictionary
				var path: Array = pipe.get("path", [])
				if not path.is_empty():
					probes.append(_vector3(path[0] as Array))
				probes.append(_vector3(pipe.get("water_entry_position", []) as Array) + Vector3.UP)
			_append_platform_extrema(probes, layout)
		if probes.size() < 14:
			_fail("Static overview probe is incomplete; got %d points" % probes.size())
			return false
	var safe_rect := Rect2(Vector2(12, 12), Vector2(viewport_size) - Vector2(24, 24))
	for point in probes:
		if camera.is_position_behind(point):
			_fail("Gameplay framing probe is behind camera: %s" % point)
			return false
		var screen_point := camera.unproject_position(point)
		if not safe_rect.has_point(screen_point):
			_fail("Gameplay framing probe is outside %dx%d safe frame: world=%s screen=%s" % [
				viewport_size.x, viewport_size.y, point, screen_point,
			])
			return false
		var occluding_hud := _find_occluding_hud_panel(screen_point, viewport_size)
		if occluding_hud:
			_fail("Gameplay framing probe is covered by HUD node %s: world=%s screen=%s" % [
				occluding_hud.get_path(), point, screen_point,
			])
			return false
	if review_character_count == 0:
		print("OK  static overview keeps platform, pipes, spawns, and portals inside the frame")
	else:
		print("OK  dynamic party camera keeps four live characters inside the frame")
	return true


func _append_platform_extrema(probes: Array[Vector3], layout: Dictionary) -> void:
	var platform := layout.get("platform", {}) as Dictionary
	var floor_y := float(platform.get("floor_top_y", 1.0)) + 2.0
	var extrema := [Vector2(INF, 0.0), Vector2(-INF, 0.0), Vector2(0.0, INF), Vector2(0.0, -INF)]
	for point_value: Variant in platform.get("outline", []):
		var point := _vector2(point_value as Array)
		if point.x < extrema[0].x:
			extrema[0] = point
		if point.x > extrema[1].x:
			extrema[1] = point
		if point.y < extrema[2].y:
			extrema[2] = point
		if point.y > extrema[3].y:
			extrema[3] = point
	for point in extrema:
		probes.append(Vector3((point as Vector2).x, floor_y, (point as Vector2).y))


func _vector2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1])) if values.size() >= 2 else Vector2.ZERO


func _vector3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2])) if values.size() >= 3 else Vector3.ZERO


func _find_occluding_hud_panel(screen_point: Vector2, viewport_size: Vector2i) -> Control:
	var viewport_area := float(viewport_size.x * viewport_size.y)
	for node in _walk(root):
		if not node is Control:
			continue
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		var area := rect.size.x * rect.size.y
		# Ignore labels/icons and full-screen layout containers; medium panels are
		# the opaque HUD regions that can actually hide a spawn or portal.
		if rect.size.x < 80.0 or rect.size.y < 30.0 or area < 1000.0 or area > viewport_area * 0.25:
			continue
		if rect.has_point(screen_point):
			return control
	return null


func _hide_review_overlays(search_root: Node) -> void:
	for name in ["ControlModeReviewPanel", "VictoryScreen", "DebugOverlay"]:
		var item := search_root.find_child(name, true, false) as CanvasItem
		if item:
			item.visible = false


func _configure_capture_runtime(mode: String) -> void:
	if mode in ["battle", "mobile", "intro_ready", "intro_go", "winner"]:
		return
	if _arena.has_method("set_runtime_camera_enabled"):
		# Structural and portal-review captures use the authored overview. Battle
		# and mobile captures intentionally leave the shared director running.
		_arena.call("set_runtime_camera_enabled", false)
	for node in _walk(_arena):
		if node is WeaponSpawner:
			# Keep structural and portal-review captures genuinely empty even though
			# their longer shader warm-up crosses either pickup initial delay.
			(node as WeaponSpawner).max_active_pickups = 0
		if node is WeaponPickup or node is WeaponSpawnPedestal or node.is_in_group("weapon_pickup"):
			node.queue_free()


func _is_geometry_view(mode: String) -> bool:
	return mode in [
		"left_portal", "right_portal",
		"north_west", "north_east", "south_west", "south_east", "center",
	]


func _geometry_view_contract(mode: String) -> Dictionary:
	match mode:
		"left_portal":
			return {"target": _portal_review_target("left_portal"), "size": 18.0}
		"right_portal":
			return {"target": _portal_review_target("right_portal"), "size": 18.0}
		"north_west":
			return {"target": Vector3(-42.0, 3.0, -24.0), "size": 25.0}
		"north_east":
			return {"target": Vector3(42.0, 3.0, -24.0), "size": 25.0}
		"south_west":
			return {"target": Vector3(-42.0, 3.0, 24.0), "size": 25.0}
		"south_east":
			return {"target": Vector3(42.0, 3.0, 24.0), "size": 25.0}
		"center":
			return {"target": Vector3(0.0, 1.1, -4.0), "size": 40.0}
	return {}


func _portal_review_target(portal_id: String) -> Vector3:
	if _arena == null or not _arena.has_method("get_twin_bays_layout"):
		return Vector3.ZERO
	var layout := _arena.call("get_twin_bays_layout") as Dictionary
	for raw_portal: Variant in layout.get("portals", []):
		var portal := raw_portal as Dictionary
		if String(portal.get("id", "")) != portal_id:
			continue
		var values: Array = portal.get("position", [])
		if values.size() >= 3:
			return Vector3(float(values[0]), float(values[1]) + 4.35, float(values[2]))
	return Vector3.ZERO


func _configure_geometry_view(mode: String) -> void:
	if not _is_geometry_view(mode):
		return
	var camera := root.get_camera_3d()
	var contract := _geometry_view_contract(mode)
	if camera == null or contract.is_empty():
		_fail("Geometry review camera contract is unavailable: %s" % mode)
		return
	var target := contract["target"] as Vector3
	# Keep local geometry review shots on the production map's authored yaw and
	# global party-shooter pitch instead of maintaining a second hard-coded view.
	var view_direction := -camera.global_transform.basis.z.normalized()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.global_position = target - view_direction * 42.0
	camera.look_at(target, Vector3.UP)
	camera.size = float(contract["size"])
	camera.current = true


func _verify_geometry_view(mode: String, viewport_size: Vector2i) -> bool:
	var camera := root.get_camera_3d()
	var contract := _geometry_view_contract(mode)
	if camera == null or contract.is_empty():
		_fail("Geometry review camera is missing: %s" % mode)
		return false
	var target := contract["target"] as Vector3
	if camera.is_position_behind(target):
		_fail("Geometry review target is behind the camera: %s" % mode)
		return false
	var screen_point := camera.unproject_position(target)
	var center := Vector2(viewport_size) * 0.5
	if screen_point.distance_to(center) > minf(viewport_size.x, viewport_size.y) * 0.08:
		_fail("Geometry review target is not centered: %s screen=%s" % [mode, screen_point])
		return false
	print("OK  local geometry review centered: ", mode)
	return true


func _prepare_review_characters() -> void:
	var characters: Array[BaseCharacter] = []
	for child in _arena.get_children():
		if child is BaseCharacter and not child is CloneCharacter:
			characters.append(child as BaseCharacter)
	if characters.size() != 4:
		_fail("Could not prepare four live review characters; got %d" % characters.size())
		return
	var spawn_points: Array = _arena.call("_get_spawn_points") if _arena.has_method("_get_spawn_points") else []
	var weapon_factories: Array[Callable] = [
		Callable(),
		WeaponData.create_smg,
		WeaponData.create_shotgun,
		WeaponData.create_gatling,
	]
	for index in range(characters.size()):
		var character := characters[index]
		var spawn := spawn_points[index] as Vector3 if index < spawn_points.size() else character.global_position
		spawn.x *= 0.92
		spawn.z *= 0.90
		character.set_process(false)
		character.set_physics_process(false)
		character.set_process_input(false)
		character.set_process_unhandled_input(false)
		character.freeze = true
		character.is_dead = false
		character.is_game_over = false
		character.visible = true
		character.linear_velocity = Vector3.ZERO
		character.angular_velocity = Vector3.ZERO
		character.global_position = spawn
		character.look_at(Vector3(0.0, spawn.y, -4.0), Vector3.UP)
		character.reset_physics_interpolation()
		if index > 0 and character.weapon_manager:
			var factory := weapon_factories[index]
			character.weapon_manager.equip_weapon(factory.call() as WeaponData)


func _set_deterministic_ambient_frame(target_time: float) -> void:
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("rebuild") or not backdrop.has_method("advance_ambient_motion"):
		_fail("Ambient evidence requires the production backdrop motion controller")
		return
	backdrop.call("rebuild")
	backdrop.set_process(false)
	if target_time > 0.0:
		backdrop.call("advance_ambient_motion", target_time)
	await process_frame
	await RenderingServer.frame_post_draw


func _prepare_presentation_frame(mode: String) -> void:
	var old_presentation := _arena.find_child("PartyShooterMatchPresentation", true, false)
	if old_presentation:
		old_presentation.queue_free()
		await process_frame
	var director := _arena.get_node_or_null("TwinBaysCameraDirector")
	var characters := _arena.get("_characters") as Array
	if director == null or characters.size() != 4:
		_fail("Presentation capture requires the shared director and four characters")
		return
	var presentation := MatchPresentationScript.new() as PartyShooterMatchPresentation
	presentation.name = "PartyShooterMatchPresentation"
	_arena.add_child(presentation)
	presentation.configure(_arena, director, characters, CAPTURE_PRESENTATION_PROFILE)
	_arena.set("_match_presentation", presentation)
	if mode == "winner":
		var winner := characters[0] as BaseCharacter
		winner.global_position = Vector3(-4.0, 1.15, 1.0)
		winner.visible = true
		winner.is_dead = false
		winner.is_game_over = false
		for index in range(1, characters.size()):
			var opponent := characters[index] as BaseCharacter
			opponent.visible = false
		var match_config := root.get_node_or_null("MatchConfig")
		presentation.present_result(winner, match_config.PLAYER_COLORS[0])
		await create_timer(0.68, true, false, true).timeout
	else:
		presentation.start_intro()
		await create_timer(0.20 if mode == "intro_ready" else 0.72, true, false, true).timeout
	await RenderingServer.frame_post_draw


func _verify_winner_framing(viewport_size: Vector2i) -> bool:
	var camera := root.get_camera_3d()
	var winner: BaseCharacter = null
	for child in _arena.get_children():
		if child is BaseCharacter and not child is CloneCharacter and child.visible and not child.is_game_over:
			winner = child as BaseCharacter
			break
	if camera == null or winner == null:
		_fail("Winner evidence requires one visible winner and the production camera")
		return false
	var point := winner.global_position + Vector3.UP * 2.0
	if camera.is_position_behind(point):
		_fail("Winner is behind the production camera")
		return false
	var screen_point := camera.unproject_position(point)
	var safe_rect := Rect2(Vector2(12, 12), Vector2(viewport_size) - Vector2(24, 24))
	if not safe_rect.has_point(screen_point):
		_fail("Winner focus is outside the safe frame: %s" % screen_point)
		return false
	return true


func _cleanup_capture_scene() -> void:
	var presentation := _arena.find_child("PartyShooterMatchPresentation", true, false) if _arena else null
	if presentation and presentation.has_method("get_debug_state"):
		var deadline_msec := Time.get_ticks_msec() + 1800
		while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
			var state := presentation.call("get_debug_state") as Dictionary
			if String(state.get("cue_state", "idle")) in ["idle", "complete", "result_ready"]:
				break
			await create_timer(0.05, true, false, true).timeout
	if _arena and is_instance_valid(_arena):
		if current_scene == _arena:
			current_scene = null
		_arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame


func _trigger_portal_review_bursts() -> void:
	var portals := _arena.get_node_or_null("Portals")
	if portals == null:
		return
	for portal_name in ["LeftPortal", "RightPortal"]:
		var portal := portals.find_child(portal_name, true, false)
		var vfx := portal.find_child("PortalVFX", true, false) if portal else null
		if vfx and vfx.has_method("play_transfer_burst"):
			vfx.call("play_transfer_burst")


func _walk(search_root: Node) -> Array[Node]:
	var nodes: Array[Node] = [search_root]
	for child in search_root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _default_size_for_mode(mode: String) -> Vector2i:
	if mode == "empty":
		return Vector2i(1536, 1024)
	if mode == "mobile":
		return Vector2i(1280, 720)
	if _is_geometry_view(mode):
		return Vector2i(1024, 1024)
	return Vector2i(1920, 1080)


func _default_output_for_mode(mode: String) -> String:
	match mode:
		"empty":
			return "res://reports/twin_bays_splash_arena_empty_1536x1024.png"
		"battle":
			return "res://reports/twin_bays_splash_arena_battle_1920x1080.png"
		"portal":
			return "res://reports/twin_bays_splash_arena_portal_1920x1080.png"
		"mobile":
			return "res://reports/twin_bays_splash_arena_mobile_1280x720.png"
		"left_portal":
			return "res://reports/twin_bays_splash_arena_left_portal_1024.png"
		"right_portal":
			return "res://reports/twin_bays_splash_arena_right_portal_1024.png"
		"ambient_start":
			return "res://reports/twin_bays_splash_arena_ambient_start_1536x1024.png"
		"ambient_end":
			return "res://reports/twin_bays_splash_arena_ambient_end_1536x1024.png"
		"intro_ready":
			return "res://reports/twin_bays_splash_arena_intro_ready_1920x1080.png"
		"intro_go":
			return "res://reports/twin_bays_splash_arena_intro_go_1920x1080.png"
		"winner":
			return "res://reports/twin_bays_splash_arena_winner_1920x1080.png"
		"north_west", "north_east", "south_west", "south_east", "center":
			return "res://reports/twin_bays_splash_arena_%s_1024.png" % mode
	return "res://reports/twin_bays_splash_arena_capture.png"


func _fail(message: String) -> void:
	push_error("TWIN_BAYS_CAPTURE_FAIL %s" % message)
	quit(1)
