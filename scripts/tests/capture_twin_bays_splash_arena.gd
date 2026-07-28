extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const MatchPresentationScript = preload("res://scripts/maps/party_shooter_match_presentation.gd")
const ArtV3ReviewScript = preload("res://scripts/maps/twin_bays_art_v3_review.gd")
const ArtV4ReviewScript = preload("res://scripts/maps/twin_bays_art_v4_review.gd")
const ArtV5ReviewScript = preload("res://scripts/maps/twin_bays_art_v5_review.gd")
const ArtV6ReviewScript = preload("res://scripts/maps/twin_bays_art_v6_review.gd")
const ArtV7ReviewScript = preload("res://scripts/maps/twin_bays_art_v7_review.gd")
const ArtV8ReviewScript = preload("res://scripts/maps/twin_bays_art_v8_review.gd")
const ArtV9ReviewScript = preload("res://scripts/maps/twin_bays_art_v9_review.gd")
const ArtV10ReviewScript = preload("res://scripts/maps/twin_bays_art_v10_review.gd")
const ART_V3_PROFILE_PATH := "res://resources/maps/twin_bays_art_v3.json"
const ART_V4_PROFILE_PATH := "res://resources/maps/twin_bays_art_v4.json"
const ART_V5_PROFILE_PATH := "res://resources/maps/twin_bays_art_v5.json"
const ART_V6_PROFILE_PATH := "res://resources/maps/twin_bays_art_v6.json"
const ART_V7_PROFILE_PATH := "res://resources/maps/twin_bays_art_v7.json"
const ART_V8_PROFILE_PATH := "res://resources/maps/twin_bays_art_v8.json"
const ART_V9_PROFILE_PATH := "res://resources/maps/twin_bays_art_v9.json"
const ART_V10_PROFILE_PATH := "res://resources/maps/twin_bays_art_v10.json"
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
	"tide_dry", "tide_warning", "tide_rising", "tide_high", "tide_falling",
	"tide_drain_0", "tide_drain_9", "tide_drain_18", "tide_high_battle", "tide_mobile",
	"art_v3_hero_dry", "art_v3_hero_high", "art_v3_hero_drain_0",
	"art_v3_hero_drain_9", "art_v3_hero_battle",
	"art_v3_full_dry", "art_v3_full_high", "art_v3_full_drain_0",
	"art_v3_full_drain_9", "art_v3_full_battle", "art_v3_full_mobile",
	"art_v4_dry", "art_v4_high", "art_v4_drain_0", "art_v4_drain_9",
	"art_v4_battle", "art_v4_portal", "art_v4_mobile",
	"art_v5_dry", "art_v5_high", "art_v5_drain_0", "art_v5_drain_9",
	"art_v5_battle", "art_v5_dry_battle", "art_v5_drain_9_battle",
	"art_v5_portal", "art_v5_portal_close",
	"art_v5_mobile",
	"art_v6_dry", "art_v6_high", "art_v6_drain_9_battle",
	"art_v6_portal", "art_v6_portal_close", "art_v6_mobile",
	"art_v7_high", "art_v7_drain_9_battle",
	"art_v7_portal", "art_v7_portal_close", "art_v7_bay_close",
	"art_v8_high", "art_v8_drain_9_battle",
	"art_v8_portal_close",
	"art_v9_high", "art_v9_drain_9_battle", "art_v9_cap_close",
	"art_v10_high", "art_v10_drain_9_battle",
]

var _arena: Node3D = null
var _capture_viewport: SubViewport = null


func _initialize() -> void:
	var is_headless := DisplayServer.get_name().to_lower() == "headless"
	var hide_physical_window := "--hide-window" in OS.get_cmdline_user_args()
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
	# Never let a visual capture take over the user's desktop. High-resolution
	# evidence must use an off-screen viewport instead of enlarging this window.
	var safe_window_size := Vector2i(mini(viewport_size.x, 960), mini(viewport_size.y, 540))
	root.size = safe_window_size
	if not is_headless:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
		DisplayServer.window_set_size(safe_window_size)
		if hide_physical_window:
			root.visible = false
	if test_window_policy != null and test_window_policy.has_method("enforce_now"):
		test_window_policy.call("enforce_now")
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "TwinBaysCaptureViewport"
	_capture_viewport.size = viewport_size
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_capture_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_capture_viewport.transparent_bg = false
	root.add_child(_capture_viewport)
	current_scene = _capture_viewport
	_configure_slots(mode)

	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	if _arena == null:
		_fail("Could not instantiate production scene")
		return
	_capture_viewport.add_child(_arena)
	await process_frame
	await process_frame
	await physics_frame
	_configure_capture_runtime(mode)
	if mode.begins_with("art_v3_"):
		_enable_art_v3_review(&"full_map" if mode.begins_with("art_v3_full_") else &"hero")
	elif mode.begins_with("art_v4_"):
		_enable_art_v4_review()
	elif mode.begins_with("art_v5_"):
		_enable_art_v5_review()
	elif mode.begins_with("art_v6_"):
		_enable_art_v6_review()
	elif mode.begins_with("art_v7_"):
		_enable_art_v7_review()
	elif mode.begins_with("art_v8_"):
		_enable_art_v8_review()
	elif mode.begins_with("art_v9_"):
		_enable_art_v9_review()
	elif mode.begins_with("art_v10_"):
		_enable_art_v10_review()
	_configure_geometry_view(mode)
	if _is_battle_capture(mode):
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
	if mode.begins_with("tide_") or mode.begins_with("art_v3_") \
			or mode.begins_with("art_v4_") or mode.begins_with("art_v5_") \
			or mode.begins_with("art_v6_") or mode.begins_with("art_v7_") \
			or mode.begins_with("art_v8_") or mode.begins_with("art_v9_") \
			or mode.begins_with("art_v10_"):
		await _prepare_tide_frame(mode)
		if mode.begins_with("art_v7_"):
			var v7_tide := _arena.get_node_or_null("TwinBaysTideController")
			if v7_tide and v7_tide.has_method("get_debug_state"):
				print("V7 tide visual state: ", v7_tide.call("get_debug_state"))
		_hide_review_overlays(_arena)
	if mode in [
		"portal", "art_v4_portal", "art_v5_portal", "art_v5_portal_close",
		"art_v6_portal", "art_v6_portal_close",
		"art_v7_portal", "art_v7_portal_close",
		"art_v8_portal_close",
	]:
		_trigger_portal_review_bursts()
		await create_timer(0.10).timeout
	if _is_battle_capture(mode) and mode != "winner":
		await _freeze_battle_capture_frame()
	await _await_render_frame()
	if _is_geometry_view(mode):
		if not _verify_geometry_view(mode, viewport_size):
			return
	elif mode == "winner":
		if not _verify_winner_framing(viewport_size):
			return
	elif not _verify_framing(viewport_size):
		return

	var image := _capture_viewport.get_texture().get_image()
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
	print("TWIN_BAYS_CAPTURE_PASS mode=%s size=%dx%d output=%s" % [
		mode,
		viewport_size.x,
		viewport_size.y,
		ProjectSettings.globalize_path(output_path),
	])
	if mode == "winner":
		# The static winner capture follows the proven terminal-frame lifecycle:
		# once the synchronized PNG is written, let SceneTree own teardown.
		quit(0)
		return
	await _cleanup_capture_scene()
	# The PNG and framing evidence are complete. Drain deferred viewport/resource
	# frees without awaiting frame_post_draw on an empty current_scene; on Windows
	# that notification may never arrive and can leave a successful capture alive.
	RenderingServer.force_sync()
	await create_timer(0.35, true, false, true).timeout
	RenderingServer.force_sync()
	await process_frame
	quit(0)


func _await_render_frame() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		await process_frame
		return
	await RenderingServer.frame_post_draw


func _configure_slots(mode: String) -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		return
	if _is_battle_capture(mode):
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


func _prepare_tide_frame(mode: String) -> void:
	var tide := _arena.get_node_or_null("TwinBaysTideController") as TwinBaysTideController
	if tide == null:
		_fail("Tide evidence requires TwinBaysTideController")
		return
	match mode:
		"tide_dry", "art_v3_hero_dry", "art_v3_full_dry", "art_v4_dry", "art_v4_portal", \
		"art_v5_dry", "art_v5_dry_battle", "art_v5_portal", "art_v5_portal_close", \
		"art_v6_dry", "art_v6_portal", "art_v6_portal_close", \
		"art_v7_portal", "art_v7_portal_close", "art_v8_portal_close", \
		"art_v9_cap_close":
			tide.set_debug_phase(&"dry_hold", 0.5)
		"tide_warning":
			tide.set_debug_phase(&"warning", 0.42)
		"tide_rising":
			tide.set_debug_phase(&"rising", 0.72)
		"tide_high", "tide_high_battle", "tide_mobile", "art_v3_hero_high", "art_v3_hero_battle", \
		"art_v3_full_high", "art_v3_full_battle", "art_v3_full_mobile", "art_v4_high", \
		"art_v4_battle", "art_v4_mobile", "art_v5_high", "art_v5_battle", "art_v5_mobile", \
		"art_v6_high", "art_v6_mobile", "art_v7_high", "art_v8_high", \
		"art_v9_high", "art_v10_high":
			tide.set_debug_phase(&"high", 0.5)
		"art_v7_bay_close":
			tide.set_debug_phase(&"high", 0.5)
		"tide_falling":
			tide.set_debug_phase(&"falling", 0.62)
		"tide_drain_0", "art_v3_hero_drain_0", "art_v3_full_drain_0", "art_v4_drain_0", \
		"art_v5_drain_0":
			tide.set_debug_phase(&"draining", 0.0)
		"tide_drain_9", "art_v3_hero_drain_9", "art_v3_full_drain_9", "art_v4_drain_9", \
		"art_v5_drain_9", "art_v5_drain_9_battle", "art_v6_drain_9_battle":
			tide.set_debug_phase(&"draining", 0.5)
		"art_v7_drain_9_battle":
			tide.set_debug_phase(&"draining", 0.5)
		"art_v8_drain_9_battle":
			tide.set_debug_phase(&"draining", 0.5)
		"art_v9_drain_9_battle":
			tide.set_debug_phase(&"draining", 0.5)
		"art_v10_drain_9_battle":
			tide.set_debug_phase(&"draining", 0.5)
		"tide_drain_18":
			tide.set_debug_phase(&"draining", 1.0)
	await process_frame
	await _await_render_frame()


func _verify_framing(viewport_size: Vector2i) -> bool:
	var camera := _active_camera()
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
	for name in ["ControlModeReviewPanel", "VictoryScreen", "DebugOverlay", "MatchIntroCue"]:
		var item := search_root.find_child(name, true, false) as CanvasItem
		if item:
			item.visible = false


func _configure_capture_runtime(mode: String) -> void:
	if _is_battle_capture(mode):
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
		"left_portal", "right_portal", "art_v5_portal_close", "art_v6_portal_close",
		"art_v7_portal_close", "art_v8_portal_close",
		"art_v7_bay_close", "art_v9_cap_close",
		"north_west", "north_east", "south_west", "south_east", "center",
		"art_v3_hero_dry", "art_v3_hero_high", "art_v3_hero_drain_0", "art_v3_hero_drain_9",
	]


func _geometry_view_contract(mode: String) -> Dictionary:
	match mode:
		"left_portal":
			return {"target": _portal_review_target("left_portal"), "size": 18.0}
		"art_v5_portal_close", "art_v6_portal_close", "art_v7_portal_close", \
		"art_v8_portal_close":
			return {
				# Review the authored portal mouth and continuous cascade. The
				# previous target sat on the submerged pipe tail, so the mandatory
				# close-up mostly judged an occluded underside instead of the
				# player-facing portal assembly.
				"target": _portal_review_target("left_portal") + Vector3(-1.6, -0.8, -0.8),
				"size": 22.0,
			}
		"art_v7_bay_close":
			return {
				"target": Vector3(0.0, 1.0, -19.0),
				"size": 30.0,
			}
		"art_v9_cap_close":
			return {
				"target": Vector3(-31.0, 4.0, -22.0),
				"size": 28.0,
			}
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
		"art_v3_hero_dry", "art_v3_hero_high", "art_v3_hero_drain_0", "art_v3_hero_drain_9":
			return {"target": Vector3(38.0, 2.2, -19.0), "size": 34.0}
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
	var camera := _active_camera()
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
	var camera := _active_camera()
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


func _freeze_battle_capture_frame() -> void:
	# Retire live simulation before copying the final frame. Keeping the arena
	# active until after save_png lets AI/animation/particle work overlap Windows
	# Vulkan teardown and can crash after an otherwise valid capture.
	var director := _arena.get_node_or_null("TwinBaysCameraDirector") if _arena else null
	if director and director.has_method("set_enabled"):
		director.call("set_enabled", false)
	for node in _walk(_arena):
		if node is GPUParticles3D:
			(node as GPUParticles3D).speed_scale = 0.0
		elif node is CPUParticles3D:
			(node as CPUParticles3D).speed_scale = 0.0
		elif node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stop()
		elif node is AudioStreamPlayer2D:
			(node as AudioStreamPlayer2D).stop()
		elif node is AudioStreamPlayer3D:
			(node as AudioStreamPlayer3D).stop()
		elif node is AnimationPlayer:
			(node as AnimationPlayer).pause()
		node.set_process(false)
		node.set_physics_process(false)
	paused = true
	await process_frame
	RenderingServer.force_sync()
	await create_timer(0.50, true, false, true).timeout
	RenderingServer.force_sync()


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
	await _await_render_frame()


func _prepare_presentation_frame(mode: String) -> void:
	if mode == "winner":
		await _prepare_static_winner_frame()
		return
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
			# Keep the imported render hierarchy alive until engine shutdown.
			# Hiding three complete hero/weapon trees immediately before Vulkan
			# teardown is unstable on Godot 4.6; move eliminated opponents well
			# outside the frame while marking them ineligible for camera probes.
			opponent.is_dead = true
			opponent.is_game_over = true
			opponent.visible = true
			opponent.global_position = Vector3(0.0, -80.0 - float(index) * 4.0, 0.0)
		# Runtime result behavior is covered by the presentation verifiers. For
		# a still capture, author the same settled framing/HUD/pose directly so
		# no un-awaited result coroutine or transient WinnerBurst survives into
		# engine shutdown.
		director.call("begin_winner_focus", winner, 0.01)
		var winner_visual := winner.get_visual()
		if winner_visual and winner_visual.has_method("animate_match_winner"):
			winner_visual.call("animate_match_winner")
		_set_capture_hud_alpha(0.22)
		await create_timer(0.68, true, false, true).timeout
	else:
		presentation.start_intro()
		await create_timer(0.20 if mode == "intro_ready" else 0.72, true, false, true).timeout
	await _await_render_frame()


func _prepare_static_winner_frame() -> void:
	var director := _arena.get_node_or_null("TwinBaysCameraDirector")
	var characters := _arena.get("_characters") as Array
	var camera := _active_camera()
	if director == null or characters.size() != 4 or camera == null:
		_fail("Static winner capture requires the shared director, camera, and four characters")
		return
	var winner := characters[0] as BaseCharacter
	winner.global_position = Vector3(-4.0, 1.15, 1.0)
	winner.visible = true
	winner.is_dead = false
	winner.is_game_over = false
	for index in range(1, characters.size()):
		var opponent := characters[index] as BaseCharacter
		opponent.is_dead = true
		opponent.is_game_over = true
		opponent.visible = true
		opponent.global_position = Vector3(0.0, -80.0 - float(index) * 4.0, 0.0)
	director.call("release_presentation_override")
	director.set_process(false)
	# Preserve the approved Twin Bays angle and translate the orthographic rig
	# to the authored winner focus. This is the settled endpoint verified by
	# the runtime presentation tests, without retaining a live winner target.
	camera.global_position += Vector3(winner.global_position.x, 0.0, winner.global_position.z)
	camera.size = 38.5
	_set_capture_hud_alpha(0.22)
	await process_frame
	await _await_render_frame()


func _set_capture_hud_alpha(alpha: float) -> void:
	var hud := _arena.find_child("GameHUD", true, false) if _arena else null
	if hud == null:
		return
	for node in _walk(hud):
		if node is Control:
			(node as Control).modulate.a = alpha


func _verify_winner_framing(viewport_size: Vector2i) -> bool:
	var camera := _active_camera()
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
	# WinnerBurst queues itself for deletion at the end of its authored tween.
	# Let that callback and the character deformation tween retire before the
	# scene is frozen for shutdown; pausing on the exact completion frame can
	# leave a queued material tween referencing a freed render resource.
	var transition_deadline_msec := Time.get_ticks_msec() + 1200
	while _arena and is_instance_valid(_arena) and Time.get_ticks_msec() < transition_deadline_msec:
		var active_transition := _arena.find_child("WinnerBurst", true, false)
		if active_transition == null:
			break
		await create_timer(0.05, true, false, true).timeout
	for _frame_index in range(4):
		await process_frame
	RenderingServer.force_sync()
	var director := _arena.get_node_or_null("TwinBaysCameraDirector") if _arena else null
	if director and director.has_method("release_presentation_override"):
		director.call("release_presentation_override")
		await process_frame
	paused = true
	# Battle captures can finish with AI, particles, audio players, and short
	# presentation tweens still active. Quiesce the scene, but leave ownership
	# with SceneTree: manually killing bound tweens and queue-freeing the arena
	# before engine shutdown can trigger a native use-after-free in Vulkan.
	if _arena and is_instance_valid(_arena):
		for node in _walk(_arena):
			if node is GPUParticles3D:
				(node as GPUParticles3D).emitting = false
			elif node is CPUParticles3D:
				(node as CPUParticles3D).emitting = false
			elif node is AudioStreamPlayer:
				(node as AudioStreamPlayer).stop()
			elif node is AudioStreamPlayer2D:
				(node as AudioStreamPlayer2D).stop()
			elif node is AudioStreamPlayer3D:
				(node as AudioStreamPlayer3D).stop()
			elif node is AnimationPlayer:
				(node as AnimationPlayer).stop()
			node.set_process(false)
			node.set_physics_process(false)
	await process_frame
	RenderingServer.force_sync()


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


func _active_camera() -> Camera3D:
	return _capture_viewport.get_camera_3d() if _capture_viewport else null


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _default_size_for_mode(mode: String) -> Vector2i:
	if mode.begins_with("art_v3_hero_") and mode != "art_v3_hero_battle":
		return Vector2i(1536, 1024)
	if mode in ["art_v3_full_dry", "art_v3_full_high", "art_v3_full_drain_0", "art_v3_full_drain_9"]:
		return Vector2i(1536, 1024)
	if mode in ["art_v4_dry", "art_v4_high", "art_v4_drain_0", "art_v4_drain_9"]:
		return Vector2i(1536, 1024)
	if mode in ["art_v5_dry", "art_v5_high", "art_v5_drain_0", "art_v5_drain_9"]:
		return Vector2i(1536, 1024)
	if mode in ["art_v6_dry", "art_v6_high"]:
		return Vector2i(1536, 1024)
	if mode in ["art_v7_high", "art_v8_high", "art_v9_high", "art_v10_high"]:
		return Vector2i(1536, 1024)
	if mode == "empty" or (mode.begins_with("tide_") and mode not in ["tide_high_battle", "tide_mobile"]):
		return Vector2i(1536, 1024)
	if mode in [
		"mobile", "tide_mobile", "art_v3_full_mobile", "art_v4_mobile",
		"art_v5_mobile", "art_v6_mobile",
	]:
		return Vector2i(1280, 720)
	if mode in [
		"art_v5_portal_close", "art_v6_portal_close", "art_v7_portal_close",
		"art_v8_portal_close",
	]:
		return Vector2i(1920, 1080)
	if _is_geometry_view(mode):
		return Vector2i(1024, 1024)
	return Vector2i(1920, 1080)


func _default_output_for_mode(mode: String) -> String:
	match mode:
		"art_v3_hero_dry":
			return "res://reports/twin_bays_art_v3_hero_dry_1536x1024.png"
		"art_v3_hero_high":
			return "res://reports/twin_bays_art_v3_hero_high_1536x1024.png"
		"art_v3_hero_drain_0":
			return "res://reports/twin_bays_art_v3_hero_drain_0_1536x1024.png"
		"art_v3_hero_drain_9":
			return "res://reports/twin_bays_art_v3_hero_drain_9_1536x1024.png"
		"art_v3_hero_battle":
			return "res://reports/twin_bays_art_v3_hero_battle_1920x1080.png"
		"art_v3_full_dry":
			return "res://reports/twin_bays_art_v3_full_dry_1536x1024.png"
		"art_v3_full_high":
			return "res://reports/twin_bays_art_v3_full_high_1536x1024.png"
		"art_v3_full_drain_0":
			return "res://reports/twin_bays_art_v3_full_drain_0_1536x1024.png"
		"art_v3_full_drain_9":
			return "res://reports/twin_bays_art_v3_full_drain_9_1536x1024.png"
		"art_v3_full_battle":
			return "res://reports/twin_bays_art_v3_full_battle_1920x1080.png"
		"art_v3_full_mobile":
			return "res://reports/twin_bays_art_v3_full_mobile_1280x720.png"
		"art_v4_dry":
			return "res://reports/twin_bays_art_v4/candidate/v4_dry_1536x1024.png"
		"art_v4_high":
			return "res://reports/twin_bays_art_v4/candidate/v4_high_1536x1024.png"
		"art_v4_drain_0":
			return "res://reports/twin_bays_art_v4/candidate/v4_drain_0_1536x1024.png"
		"art_v4_drain_9":
			return "res://reports/twin_bays_art_v4/candidate/v4_drain_9_1536x1024.png"
		"art_v4_battle":
			return "res://reports/twin_bays_art_v4/candidate/v4_battle_1920x1080.png"
		"art_v4_portal":
			return "res://reports/twin_bays_art_v4/candidate/v4_portal_1920x1080.png"
		"art_v4_mobile":
			return "res://reports/twin_bays_art_v4/candidate/v4_mobile_1280x720.png"
		"art_v5_dry":
			return "res://reports/twin_bays_art_v5/candidate/v5_dry_1536x1024.png"
		"art_v5_high":
			return "res://reports/twin_bays_art_v5/candidate/v5_high_1536x1024.png"
		"art_v5_drain_0":
			return "res://reports/twin_bays_art_v5/candidate/v5_drain_0_1536x1024.png"
		"art_v5_drain_9":
			return "res://reports/twin_bays_art_v5/candidate/v5_drain_9_1536x1024.png"
		"art_v5_battle":
			return "res://reports/twin_bays_art_v5/candidate/v5_battle_1920x1080.png"
		"art_v5_dry_battle":
			return "res://reports/twin_bays_art_v5/candidate/v5_dry_battle_1920x1080.png"
		"art_v5_drain_9_battle":
			return "res://reports/twin_bays_art_v5/candidate/v5_drain_9_battle_1920x1080.png"
		"art_v5_portal":
			return "res://reports/twin_bays_art_v5/candidate/v5_portal_1920x1080.png"
		"art_v5_portal_close":
			return "res://reports/twin_bays_art_v5/candidate/v5_portal_close_1920x1080.png"
		"art_v5_mobile":
			return "res://reports/twin_bays_art_v5/candidate/v5_mobile_1280x720.png"
		"art_v6_dry":
			return "res://reports/twin_bays_art_v6/candidate/v6_dry_1536x1024.png"
		"art_v6_high":
			return "res://reports/twin_bays_art_v6/candidate/v6_high_1536x1024.png"
		"art_v6_drain_9_battle":
			return "res://reports/twin_bays_art_v6/candidate/v6_drain_9_battle_1920x1080.png"
		"art_v6_portal":
			return "res://reports/twin_bays_art_v6/candidate/v6_portal_1920x1080.png"
		"art_v6_portal_close":
			return "res://reports/twin_bays_art_v6/candidate/v6_portal_close_1920x1080.png"
		"art_v6_mobile":
			return "res://reports/twin_bays_art_v6/candidate/v6_mobile_1280x720.png"
		"art_v7_high":
			return "res://reports/twin_bays_art_v7/candidate/v7_high_1536x1024.png"
		"art_v7_drain_9_battle":
			return "res://reports/twin_bays_art_v7/candidate/v7_drain_9_battle_1920x1080.png"
		"art_v7_portal":
			return "res://reports/twin_bays_art_v7/candidate/v7_portal_1920x1080.png"
		"art_v7_portal_close":
			return "res://reports/twin_bays_art_v7/candidate/v7_portal_close_1920x1080.png"
		"art_v7_bay_close":
			return "res://reports/twin_bays_art_v7/candidate/v7_bay_close_1024.png"
		"art_v8_high":
			return "res://reports/twin_bays_art_v8/candidate/v8_high_1536x1024.png"
		"art_v8_drain_9_battle":
			return "res://reports/twin_bays_art_v8/candidate/v8_drain_9_battle_1920x1080.png"
		"art_v8_portal_close":
			return "res://reports/twin_bays_art_v8/candidate/v8_portal_close_1920x1080.png"
		"art_v9_high":
			return "res://reports/twin_bays_art_v9/candidate/v9_high_1536x1024.png"
		"art_v9_drain_9_battle":
			return "res://reports/twin_bays_art_v9/candidate/v9_drain_9_battle_1920x1080.png"
		"art_v9_cap_close":
			return "res://reports/twin_bays_art_v9/candidate/v9_cap_close_1024.png"
		"art_v10_high":
			return "res://reports/twin_bays_art_v10/candidate/v10_high_1536x1024.png"
		"art_v10_drain_9_battle":
			return "res://reports/twin_bays_art_v10/candidate/v10_drain_9_battle_1920x1080.png"
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
		"tide_mobile":
			return "res://reports/twin_bays_tide_mobile_1280x720.png"
		"tide_high_battle":
			return "res://reports/twin_bays_tide_high_battle_1920x1080.png"
		"tide_dry", "tide_warning", "tide_rising", "tide_high", "tide_falling", "tide_drain_0", "tide_drain_9", "tide_drain_18":
			return "res://reports/twin_bays_%s_1536x1024.png" % mode
		"north_west", "north_east", "south_west", "south_east", "center":
			return "res://reports/twin_bays_splash_arena_%s_1024.png" % mode
	return "res://reports/twin_bays_splash_arena_capture.png"


func _is_battle_capture(mode: String) -> bool:
	return mode in [
		"battle", "mobile", "intro_ready", "intro_go", "winner",
		"tide_high_battle", "tide_mobile", "art_v3_hero_battle",
		"art_v3_full_battle", "art_v3_full_mobile",
		"art_v4_battle", "art_v4_mobile", "art_v5_battle", "art_v5_dry_battle",
		"art_v5_drain_9_battle", "art_v5_mobile",
		"art_v6_drain_9_battle", "art_v6_mobile",
		"art_v7_drain_9_battle", "art_v8_drain_9_battle",
		"art_v9_drain_9_battle",
		"art_v10_drain_9_battle",
	]


func _enable_art_v3_review(scope: StringName = &"hero") -> void:
	var file := FileAccess.open(ART_V3_PROFILE_PATH, FileAccess.READ)
	if file == null:
		_fail("Art V3 review profile is missing")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Art V3 review profile is invalid JSON")
		return
	var profile := parsed as Dictionary
	var review := ArtV3ReviewScript.new() as TwinBaysArtV3Review
	_arena.add_child(review)
	review.configure(_arena, profile, scope)
	var review_state: Dictionary = review.get_debug_state()
	var visual_ready := bool(review_state.get("full_map_foreground_loaded", false)) \
		if scope == &"full_map" else int(review_state.get("overridden_surfaces", 0)) > 0
	if not visual_ready or int(review_state.get("collision_nodes", -1)) != 0:
		_fail("Art V3 review material contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V3 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", profile)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V3 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", profile)
	print("OK  Art V3 review enabled: ", review_state)


func _enable_art_v4_review() -> void:
	var file := FileAccess.open(ART_V4_PROFILE_PATH, FileAccess.READ)
	if file == null:
		_fail("Art V4 review profile is missing")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Art V4 review profile is invalid JSON")
		return
	var profile := parsed as Dictionary
	var review := ArtV4ReviewScript.new() as TwinBaysArtV4Review
	_arena.add_child(review)
	review.configure(_arena, profile)
	var review_state: Dictionary = review.get_debug_state()
	if not bool(review_state.get("full_map_foreground_loaded", false)) \
		or int(review_state.get("collision_nodes", -1)) != 0:
		_fail("Art V4 review foreground contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V4 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", profile)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V4 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", profile)
	print("OK  Art V4 review enabled: ", review_state)


func _enable_art_v5_review() -> void:
	var file := FileAccess.open(ART_V5_PROFILE_PATH, FileAccess.READ)
	if file == null:
		_fail("Art V5 review profile is missing")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Art V5 review profile is invalid JSON")
		return
	var profile := parsed as Dictionary
	var review: Node = ArtV5ReviewScript.new()
	_arena.add_child(review)
	review.configure(_arena, profile)
	var review_state: Dictionary = review.get_debug_state()
	if not bool(review_state.get("full_map_foreground_loaded", false)) \
		or int(review_state.get("collision_nodes", -1)) != 0 \
		or int(review_state.get("art_version", 0)) != 5:
		_fail("Art V5 review foreground contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V5 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", profile)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V5 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", profile)
	for portal_vfx in _arena.find_children("*", "TwinBaysPortalVFX", true, false):
		if portal_vfx.has_method("apply_art_profile"):
			portal_vfx.call("apply_art_profile", profile)
	print("OK  Art V5 review enabled: ", review_state)


func _enable_art_v6_review() -> void:
	var base_profile := _load_json_dictionary(ART_V5_PROFILE_PATH)
	var override_profile := _load_json_dictionary(ART_V6_PROFILE_PATH)
	if base_profile.is_empty() or override_profile.is_empty():
		_fail("Art V6 review requires valid V5 base and V6 override profiles")
		return
	var expected_base_hash := String(override_profile.get("base_profile_sha256", ""))
	var actual_base_hash := FileAccess.get_sha256(ART_V5_PROFILE_PATH)
	if expected_base_hash != actual_base_hash:
		_fail("Art V6 base profile hash is stale")
		return
	var profile := _deep_merge_dictionary(base_profile, override_profile)
	var review: Node = ArtV6ReviewScript.new()
	_arena.add_child(review)
	review.configure(_arena, profile)
	var review_state: Dictionary = review.get_debug_state()
	if not bool(review_state.get("full_map_foreground_loaded", false)) \
		or int(review_state.get("collision_nodes", -1)) != 0 \
		or int(review_state.get("art_version", 0)) != 6:
		_fail("Art V6 review foreground contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V6 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", profile)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V6 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", profile)
	for portal_vfx in _arena.find_children("*", "TwinBaysPortalVFX", true, false):
		if portal_vfx.has_method("apply_art_profile"):
			portal_vfx.call("apply_art_profile", profile)
	print("OK  Art V6 review enabled: ", review_state)


func _enable_art_v7_review() -> void:
	var v5_profile := _load_json_dictionary(ART_V5_PROFILE_PATH)
	var v6_profile := _load_json_dictionary(ART_V6_PROFILE_PATH)
	var v7_profile := _load_json_dictionary(ART_V7_PROFILE_PATH)
	if v5_profile.is_empty() or v6_profile.is_empty() or v7_profile.is_empty():
		_fail("Art V7 review requires valid V5, V6, and V7 profiles")
		return
	if String(v6_profile.get("base_profile_sha256", "")) \
			!= FileAccess.get_sha256(ART_V5_PROFILE_PATH):
		_fail("Art V6 base profile hash is stale")
		return
	if String(v7_profile.get("base_profile_sha256", "")) \
			!= FileAccess.get_sha256(ART_V6_PROFILE_PATH):
		_fail("Art V7 base profile hash is stale")
		return
	var profile := _deep_merge_dictionary(
		_deep_merge_dictionary(v5_profile, v6_profile),
		v7_profile
	)
	var review: Node = ArtV7ReviewScript.new()
	_arena.add_child(review)
	review.configure(_arena, profile)
	var review_state: Dictionary = review.get_debug_state()
	if not bool(review_state.get("full_map_foreground_loaded", false)) \
			or int(review_state.get("collision_nodes", -1)) != 0 \
			or int(review_state.get("art_version", 0)) != 7:
		_fail("Art V7 review foreground contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V7 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", profile)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V7 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", profile)
	for portal_vfx in _arena.find_children("*", "TwinBaysPortalVFX", true, false):
		if portal_vfx.has_method("apply_art_profile"):
			portal_vfx.call("apply_art_profile", profile)
	print("OK  Art V7 review enabled: ", review_state)


func _enable_art_v8_review() -> void:
	var v5_profile := _load_json_dictionary(ART_V5_PROFILE_PATH)
	var v6_profile := _load_json_dictionary(ART_V6_PROFILE_PATH)
	var v7_profile := _load_json_dictionary(ART_V7_PROFILE_PATH)
	var v8_profile := _load_json_dictionary(ART_V8_PROFILE_PATH)
	if v5_profile.is_empty() or v6_profile.is_empty() \
			or v7_profile.is_empty() or v8_profile.is_empty():
		_fail("Art V8 review requires valid V5, V6, V7, and V8 profiles")
		return
	if String(v6_profile.get("base_profile_sha256", "")) \
			!= FileAccess.get_sha256(ART_V5_PROFILE_PATH):
		_fail("Art V6 base profile hash is stale")
		return
	if String(v7_profile.get("base_profile_sha256", "")) \
			!= FileAccess.get_sha256(ART_V6_PROFILE_PATH):
		_fail("Art V7 base profile hash is stale")
		return
	if String(v8_profile.get("base_profile_sha256", "")) \
			!= FileAccess.get_sha256(ART_V7_PROFILE_PATH):
		_fail("Art V8 base profile hash is stale")
		return
	var profile := _deep_merge_dictionary(
		_deep_merge_dictionary(
			_deep_merge_dictionary(v5_profile, v6_profile),
			v7_profile
		),
		v8_profile
	)
	var review: Node = ArtV8ReviewScript.new()
	_arena.add_child(review)
	review.configure(_arena, profile)
	var review_state: Dictionary = review.get_debug_state()
	if not bool(review_state.get("full_map_foreground_loaded", false)) \
			or int(review_state.get("collision_nodes", -1)) != 0 \
			or int(review_state.get("art_version", 0)) != 8:
		_fail("Art V8 review foreground contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V8 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", profile)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V8 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", profile)
	for portal_vfx in _arena.find_children("*", "TwinBaysPortalVFX", true, false):
		if portal_vfx.has_method("apply_art_profile"):
			portal_vfx.call("apply_art_profile", profile)
	print("OK  Art V8 review enabled: ", review_state)


func _enable_art_v9_review() -> void:
	var profiles := [
		_load_json_dictionary(ART_V5_PROFILE_PATH),
		_load_json_dictionary(ART_V6_PROFILE_PATH),
		_load_json_dictionary(ART_V7_PROFILE_PATH),
		_load_json_dictionary(ART_V8_PROFILE_PATH),
		_load_json_dictionary(ART_V9_PROFILE_PATH),
	]
	for profile_value: Variant in profiles:
		if (profile_value as Dictionary).is_empty():
			_fail("Art V9 review requires valid V5 through V9 profiles")
			return
	var paths := [
		ART_V5_PROFILE_PATH,
		ART_V6_PROFILE_PATH,
		ART_V7_PROFILE_PATH,
		ART_V8_PROFILE_PATH,
		ART_V9_PROFILE_PATH,
	]
	for index in range(1, profiles.size()):
		var profile := profiles[index] as Dictionary
		if String(profile.get("base_profile_sha256", "")) \
				!= FileAccess.get_sha256(String(paths[index - 1])):
			_fail("Art V%d base profile hash is stale" % (index + 5))
			return
	var resolved := {} as Dictionary
	for profile_value: Variant in profiles:
		resolved = _deep_merge_dictionary(
			resolved,
			profile_value as Dictionary
		)
	var review: Node = ArtV9ReviewScript.new()
	_arena.add_child(review)
	review.configure(_arena, resolved)
	var review_state: Dictionary = review.get_debug_state()
	if not bool(review_state.get("full_map_foreground_loaded", false)) \
			or int(review_state.get("collision_nodes", -1)) != 0 \
			or int(review_state.get("art_version", 0)) != 9:
		_fail("Art V9 review foreground contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V9 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", resolved)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V9 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", resolved)
	for portal_vfx in _arena.find_children("*", "TwinBaysPortalVFX", true, false):
		if portal_vfx.has_method("apply_art_profile"):
			portal_vfx.call("apply_art_profile", resolved)
	print("OK  Art V9 review enabled: ", review_state)


func _enable_art_v10_review() -> void:
	var profiles := [
		_load_json_dictionary(ART_V5_PROFILE_PATH),
		_load_json_dictionary(ART_V6_PROFILE_PATH),
		_load_json_dictionary(ART_V7_PROFILE_PATH),
		_load_json_dictionary(ART_V8_PROFILE_PATH),
		_load_json_dictionary(ART_V9_PROFILE_PATH),
		_load_json_dictionary(ART_V10_PROFILE_PATH),
	]
	for profile_value: Variant in profiles:
		if (profile_value as Dictionary).is_empty():
			_fail("Art V10 review requires valid V5 through V10 profiles")
			return
	var paths := [
		ART_V5_PROFILE_PATH,
		ART_V6_PROFILE_PATH,
		ART_V7_PROFILE_PATH,
		ART_V8_PROFILE_PATH,
		ART_V9_PROFILE_PATH,
		ART_V10_PROFILE_PATH,
	]
	for index in range(1, profiles.size()):
		var profile := profiles[index] as Dictionary
		if String(profile.get("base_profile_sha256", "")) \
				!= FileAccess.get_sha256(String(paths[index - 1])):
			_fail("Art V%d base profile hash is stale" % (index + 5))
			return
	var resolved := {} as Dictionary
	for profile_value: Variant in profiles:
		resolved = _deep_merge_dictionary(
			resolved,
			profile_value as Dictionary
		)
	var review: Node = ArtV10ReviewScript.new()
	_arena.add_child(review)
	review.configure(_arena, resolved)
	var review_state: Dictionary = review.get_debug_state()
	if not bool(review_state.get("full_map_foreground_loaded", false)) \
			or int(review_state.get("collision_nodes", -1)) != 0 \
			or int(review_state.get("art_version", 0)) != 10:
		_fail("Art V10 review foreground contract failed: %s" % review_state)
		return
	var tide := _arena.get_node_or_null("TwinBaysTideController")
	if tide == null or not tide.has_method("apply_art_review_profile"):
		_fail("Art V10 review requires the tide visual bridge")
		return
	tide.call("apply_art_review_profile", resolved)
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false)
	if backdrop == null or not backdrop.has_method("apply_art_review_profile"):
		_fail("Art V10 review requires the backdrop visual bridge")
		return
	backdrop.call("apply_art_review_profile", resolved)
	for portal_vfx in _arena.find_children("*", "TwinBaysPortalVFX", true, false):
		if portal_vfx.has_method("apply_art_profile"):
			portal_vfx.call("apply_art_profile", resolved)
	print("OK  Art V10 review enabled: ", review_state)


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _deep_merge_dictionary(parent: Dictionary, override: Dictionary) -> Dictionary:
	var merged := parent.duplicate(true)
	for key: Variant in override:
		var value: Variant = override[key]
		if value is Dictionary and merged.get(key) is Dictionary:
			merged[key] = _deep_merge_dictionary(
				merged[key] as Dictionary,
				value as Dictionary
			)
		else:
			merged[key] = value
	return merged


func _fail(message: String) -> void:
	push_error("TWIN_BAYS_CAPTURE_FAIL %s" % message)
	quit(1)
