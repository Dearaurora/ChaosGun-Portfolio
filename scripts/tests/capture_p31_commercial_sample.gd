extends SceneTree

## Deterministic P31 commercial capture of the production Open Ring-Out scene.
## The controller only stages actors; collection, fire, projectile, hit, and
## ring-out visuals are all created by the shipping gameplay code.

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const PICKUP_SCENE: PackedScene = preload("res://scenes/weapons/weapon_pickup.tscn")
const FPS := 60
const CLIP_SECONDS := 5.0
const TOTAL_FRAMES := int(CLIP_SECONDS * FPS)
const START_FRAME := 30
const PICKUP_FRAME := 96
const FIRE_FRAME := 132
const ACTION_FRAME := 150
const FORCE_RINGOUT_FRAME := 206
const END_FRAME := 288

var _arena: Node3D
var _characters: Array[BaseCharacter] = []
var _winner: BaseCharacter
var _target: BaseCharacter
var _pickup: WeaponPickup
var _camera: Camera3D
var _camera_transform: Transform3D
var _frame := 0
var _pickup_seen := false
var _shot_seen := false
var _projectile_seen := false
var _hit_seen := false
var _fall_seen := false
var _shot_fired := false
var _ringout_staged := false
var _threshold_forced := false
var _start_saved := false
var _action_saved := false
var _end_saved := false
var _focus_valid := true
var _failed := false


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("P31 commercial capture requires a render-capable display driver")
		return
	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production Open Ring-Out scene is missing: %s" % SCENE_PATH)
		return

	var viewport_size := Vector2i(
		maxi(320, int(_argument_value("--width=", "1920"))),
		maxi(180, int(_argument_value("--height=", "1080")))
	)
	if absf(float(viewport_size.x) / float(viewport_size.y) - 16.0 / 9.0) > 0.002:
		_fail("P31 capture must be 16:9, got %dx%d" % [viewport_size.x, viewport_size.y])
		return

	seed(31031)
	var capture_audio := _argument_value("--audio=", "false").to_lower() in ["1", "true", "yes"]
	root.set_meta("disable_runtime_audio", not capture_audio)
	var window_policy := root.get_node_or_null("TestWindowPolicy")
	if window_policy:
		window_policy.set_process(false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_position(Vector2i.ZERO)
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	_configure_slots()

	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	if _arena == null:
		_fail("Could not instantiate production scene: %s" % SCENE_PATH)
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame
	if not _prepare_production_stage():
		return

	# Material compilation is outside the authored five seconds.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if not await _acquire_capture_focus():
		return
	await _run_timeline()
	if _failed:
		return
	_finish()


func _configure_slots() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		return
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.HUMAN,
		match_config.SlotType.HUMAN,
		match_config.SlotType.HUMAN,
	]
	match_config.PLAYER_COLORS = [
		Color("#ef3f3f"),
		Color("#78d23d"),
		Color("#24a9e8"),
		Color("#f2bf27"),
	]


func _prepare_production_stage() -> bool:
	var raw_characters := _arena.get("_characters") as Array
	for item in raw_characters:
		if item is BaseCharacter:
			_characters.append(item as BaseCharacter)
	if _characters.size() != 4:
		_fail("Production scene did not create four characters (got %d)" % _characters.size())
		return false
	if _arena.get_node_or_null("OpenRingoutHUD") == null:
		_fail("Production Ring-Out HUD is missing")
		return false

	var spawner := _arena.get_node_or_null("WeaponSpawner")
	if spawner:
		spawner.set_process(false)
		spawner.set_physics_process(false)
		spawner.set("max_active_pickups", 0)
	for node in get_nodes_in_group(&"weapon_pickup"):
		node.queue_free()

	# This fixed overview is intentionally held for the full five seconds.
	_camera = _arena.get_node_or_null("GlobalCamera") as Camera3D
	if _camera == null:
		_fail("Production scene has no GlobalCamera")
		return false
	if _arena.has_method("set_runtime_camera_enabled"):
		_arena.call("set_runtime_camera_enabled", false)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 82.0
	_camera.global_position = Vector3(0.0, 61.0, 59.0)
	_camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	_camera.current = true
	_camera_transform = _camera.global_transform

	# The four color silhouettes are shown on the real arena from the first frame.
	var positions := [
		Vector3(-17.0, 1.25, -8.0),
		Vector3(2.0, 1.25, -8.0),
		Vector3(-16.0, 1.25, 11.0),
		Vector3(17.0, 1.25, 10.0),
	]
	for index in range(_characters.size()):
		var character := _characters[index]
		character.global_position = positions[index]
		character.linear_velocity = Vector3.ZERO
		character.angular_velocity = Vector3.ZERO
		character.freeze = true
		character.visible = true
		character.lives = 4
		character.current_hp = character.max_hp
		_face(character, Vector3.ZERO)
		var visual := character.get_visual()
		if visual:
			visual.call("animate_locomotion", Vector3.ZERO, -character.global_transform.basis.z, 0.0, 0.0)

	_winner = _characters[0]
	_target = _characters[1]
	_target.lives = 1 # End the staged fall with the normal no-respawn game-over path.
	_spawn_pickup()
	return true


func _spawn_pickup() -> void:
	_pickup = PICKUP_SCENE.instantiate() as WeaponPickup
	if _pickup == null:
		_fail("Could not instantiate production WeaponPickup")
		return
	_pickup.name = "P31ProductionPickup"
	_arena.add_child(_pickup)
	_pickup.global_position = Vector3(-7.2, 1.55, -8.0)
	_pickup.setup(WeaponData.create_pistol())
	_pickup.monitoring = false


func _run_timeline() -> void:
	while _frame < TOTAL_FRAMES:
		await physics_frame
		_frame += 1
		_drive_frame(_frame)
		if not DisplayServer.window_is_focused():
			_focus_valid = false
			_fail("Capture window lost desktop focus or was minimized")
			return
		_observe_production_events()
		if _frame in [START_FRAME, ACTION_FRAME, END_FRAME]:
			await process_frame
			await RenderingServer.frame_post_draw
			_save_requested_keyframe(_frame)
		if _failed:
			return


func _acquire_capture_focus() -> bool:
	# Automated GUI launches do not reliably receive foreground focus on Windows.
	# Request it before authored time starts; focus loss during the clip still fails.
	for _attempt in range(12):
		DisplayServer.window_move_to_foreground()
		await process_frame
		if DisplayServer.window_is_focused():
			return true
	_fail("Capture window could not acquire desktop focus before the sample")
	return false


func _drive_frame(frame: int) -> void:
	if frame >= 58 and frame <= 90:
		var move_t := clampf(float(frame - 58) / 32.0, 0.0, 1.0)
		_winner.global_position = Vector3(-17.0, 1.25, -8.0).lerp(Vector3(-7.2, 1.25, -8.0), move_t)
		var visual := _winner.get_visual()
		if visual:
			visual.call("animate_locomotion", Vector3.RIGHT, Vector3.RIGHT, 0.86, 1.0 / FPS)
	if frame == PICKUP_FRAME:
		if _pickup == null or not is_instance_valid(_pickup):
			_fail("Production pickup vanished before the pickup beat")
			return
		_pickup.monitoring = true
		_pickup.call("_on_body_entered", _winner)
		_pickup_seen = true
	if frame == 116:
		# Releasing only the target lets the real hit impulse determine its fall.
		_target.freeze = false
		_target.linear_velocity = Vector3.ZERO
		_target.angular_velocity = Vector3.ZERO
	if frame == FIRE_FRAME:
		_fire_production_weapon()
	if frame == 154 and _hit_seen and not _ringout_staged:
		# The production hit supplied the impulse; staging moves the struck actor
		# over Open Ring-Out's edge so the normal fall/ring-out presentation finishes.
		_target.global_position = Vector3(52.0, 1.25, -8.0)
		_ringout_staged = true
	if frame == FORCE_RINGOUT_FRAME and _ringout_staged and not _target.is_dead:
		# Keep the visible fall in the clip, then cross the production threshold so
		# the shipping _check_fall -> _die -> eliminated path finishes in time.
		_target.global_position.y = -17.0
		_threshold_forced = true
		_target.call("_check_fall")


func _fire_production_weapon() -> void:
	if _winner == null or _target == null or _winner.weapon_manager == null or _winner.weapon_point == null:
		_fail("Decisive exchange is missing a production character or weapon manager")
		return
	var direction := (_target.global_position + Vector3.UP * 1.35 - _winner.weapon_point.global_position).normalized()
	_face(_winner, direction)
	var fired := _winner.weapon_manager.try_fire(_winner.weapon_point, direction, _winner)
	if not fired:
		_fail("Production WeaponManager refused the staged decisive shot")
		return
	_shot_fired = true


func _observe_production_events() -> void:
	if _camera and not _camera.global_transform.is_equal_approx(_camera_transform):
		_fail("Capture camera moved during the supposedly stable commercial shot")
		return
	if _target and _target.get_hit_feedback_debug().get("serial", 0) > 0:
		_hit_seen = true
	for node in _walk(_arena):
		if node is Projectile:
			_projectile_seen = true
			break
	if _target and (_target.global_position.y < -1.0 or _target.is_dead):
		_fall_seen = true


func _save_requested_keyframe(frame: int) -> void:
	var requested := _argument_value("--still=", "")
	var frames_dir := _argument_value("--frames-dir=", "")
	var name := ""
	if frame == START_FRAME:
		_start_saved = true
		name = "p31_start.png"
	elif frame == ACTION_FRAME:
		_action_saved = true
		name = "p31_action_apex.png"
		if requested == "action":
			name = ""
	elif frame == END_FRAME:
		_end_saved = true
		name = "p31_end.png"
	if not frames_dir.is_empty() and not name.is_empty():
		if not _save_viewport_png(frames_dir.path_join(name)):
			_fail("Could not save keyframe %s" % name)
			return
	if not requested.is_empty() and ((requested == "start" and frame == START_FRAME) or (requested == "action" and frame == ACTION_FRAME) or (requested == "end" and frame == END_FRAME)):
		var output := _argument_value("--output=", "")
		if output.is_empty() or not _save_viewport_png(output):
			_fail("Could not save requested P31 %s still" % requested)


func _finish() -> void:
	var all_four_visible := _characters.size() == 4
	for character in _characters:
		all_four_visible = all_four_visible and is_instance_valid(character)
	var no_respawn := _target != null and _target.is_game_over and _target.is_dead
	var passed := all_four_visible and _pickup_seen and _shot_fired and _projectile_seen and _hit_seen and _fall_seen and no_respawn and _focus_valid and _start_saved and _action_saved and _end_saved
	var report := {
		"sample": "p31_commercial",
		"attempt": int(_argument_value("--attempt=", "0")),
		"duration_seconds": CLIP_SECONDS,
		"fps": FPS,
		"frame_count": TOTAL_FRAMES,
		"scene": SCENE_PATH,
		"four_character_reveal": all_four_visible,
		"pickup": _pickup_seen,
		"shot": _shot_fired,
		"projectile": _projectile_seen,
		"hit": _hit_seen,
		"fall": _fall_seen,
		"ringout_staged_after_hit": _ringout_staged,
		"production_threshold_crossed": _threshold_forced,
		"target_lives": _target.lives if _target else -1,
		"target_deaths": _target.deaths if _target else -1,
		"target_dead": _target.is_dead if _target else false,
		"target_game_over": _target.is_game_over if _target else false,
		"no_respawn": no_respawn,
		"camera_stable": _camera != null and _camera.global_transform.is_equal_approx(_camera_transform),
		"focus_valid": _focus_valid,
		"keyframes": {"start": _start_saved, "action_apex": _action_saved, "end": _end_saved},
		"pass": passed,
	}
	_write_report(report)
	if not passed:
		_fail("P31 commercial capture contract failed: %s" % JSON.stringify(report))
		return
	print("P31_COMMERCIAL_CAPTURE_PASS|attempt=%d|shot=%s|hit=%s|fall=%s|duration=%.2f" % [report["attempt"], _shot_fired, _hit_seen, _fall_seen, CLIP_SECONDS])
	quit(0)


func _save_viewport_png(path: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var absolute := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	return image.save_png(absolute) == OK


func _write_report(report: Dictionary) -> void:
	var requested := _argument_value("--report=", "")
	if requested.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(requested) if requested.begins_with("res://") else requested
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		_fail("Could not create P31 report directory")
		return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		_fail("Could not write P31 report: %s" % absolute)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()


func _face(character: BaseCharacter, direction_or_target: Vector3) -> void:
	var direction := direction_or_target
	if direction.length_squared() > 1.1:
		direction = direction_or_target - character.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		character.global_transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), character.global_position)


func _walk(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children():
		result.append_array(_walk(child))
	return result


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	print("P31_COMMERCIAL_CAPTURE_FAIL|%s" % message)
	quit(1)
