extends SceneTree

## Deterministic P31 commercial capture of the production Open Ring-Out scene.
## The controller only stages actors; collection, fire, projectile, hit, and
## ring-out visuals are all created by the shipping gameplay code.

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const PICKUP_SCENE: PackedScene = preload("res://scenes/weapons/weapon_pickup.tscn")
const FPS := 60
const CLIP_SECONDS := 5.0
const TOTAL_FRAMES := int(CLIP_SECONDS * FPS)
const START_FRAME := 24
const CAMERA_PUSH_START_FRAME := 48
const CAMERA_PUSH_END_FRAME := 120
const PICKUP_FRAME := 116
const RETURN_FIRE_FRAME := 138
const FIRE_FRAME := 150
const RINGOUT_STAGE_FRAME := 188
const FORCE_RINGOUT_FRAME := 236
const END_FRAME := 288

var _arena: Node3D
var _characters: Array[BaseCharacter] = []
var _winner: BaseCharacter
var _target: BaseCharacter
var _pickup: WeaponPickup
var _camera: Camera3D
var _camera_start_transform: Transform3D
var _camera_close_transform: Transform3D
var _camera_expected_transform: Transform3D
var _frame := 0
var _pickup_seen := false
var _pickup_equipped := false
var _projectile_seen := false
var _hit_seen := false
var _hit_frame := -1
var _fall_seen := false
var _shot_fired := false
var _return_shot_fired := false
var _ringout_staged := false
var _threshold_forced := false
var _start_saved := false
var _action_saved := false
var _end_saved := false
var _focus_valid := true
var _camera_motion_valid := true
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
	await _finish()


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

	# Begin on the full arena, then make a single authored push toward the east lane.
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
	_camera_start_transform = _camera.global_transform
	_camera_close_transform = Transform3D(_camera_start_transform.basis, Vector3(-2.0, 61.0, 52.0))
	_camera_expected_transform = _camera_start_transform

	# The four color silhouettes are shown on the real arena from the first frame.
	var positions := [
		Vector3(-2.0, 1.25, 2.0),
		Vector3(-2.0, 1.25, -15.0),
		Vector3(-14.0, 1.25, 8.0),
		Vector3(12.0, 1.25, 8.0),
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
	_pickup.global_position = Vector3(-2.0, 1.55, -5.0)
	_pickup.setup(WeaponData.create_smg())
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
		var keyframe_beat := ""
		if _frame == START_FRAME:
			keyframe_beat = "start"
		elif _hit_seen and not _action_saved:
			keyframe_beat = "action"
		elif _frame == END_FRAME:
			keyframe_beat = "end"
		if not keyframe_beat.is_empty():
			await process_frame
			await RenderingServer.frame_post_draw
			_save_requested_keyframe(keyframe_beat)
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
	_drive_camera(frame)
	if frame >= 82 and frame <= 110:
		var move_t := smoothstep(0.0, 1.0, clampf(float(frame - 82) / 28.0, 0.0, 1.0))
		_winner.global_position = Vector3(-2.0, 1.25, 2.0).lerp(Vector3(-2.0, 1.25, -5.0), move_t)
		var visual := _winner.get_visual()
		if visual:
			visual.call("animate_locomotion", Vector3.FORWARD, Vector3.FORWARD, 0.86, 1.0 / FPS)
	if frame == PICKUP_FRAME:
		if _pickup == null or not is_instance_valid(_pickup):
			_fail("Production pickup vanished before the pickup beat")
			return
		_pickup.monitoring = true
		_pickup.call("_on_body_entered", _winner)
		_pickup_seen = true
		_pickup_equipped = (
			_winner.weapon_manager != null
			and _winner.weapon_manager.current_weapon != null
			and _winner.weapon_manager.current_weapon.weapon_data != null
			and _winner.weapon_manager.current_weapon.weapon_data.weapon_id == &"smg"
		)
	if frame == 130:
		# Releasing only the target lets the real hit impulse determine its fall.
		_target.freeze = false
		_target.linear_velocity = Vector3.ZERO
		_target.angular_velocity = Vector3.ZERO
	if frame == RETURN_FIRE_FRAME:
		_return_shot_fired = _fire_production_weapon(_target, _winner, true)
	if frame in [FIRE_FRAME, FIRE_FRAME + 8, FIRE_FRAME + 16]:
		var fired := _fire_production_weapon(_winner, _target, frame == FIRE_FRAME)
		_shot_fired = _shot_fired or fired
	if frame == RINGOUT_STAGE_FRAME and _hit_seen and not _ringout_staged and not _target.is_dead:
		# The production hit supplied the impulse; staging moves the struck actor
		# only to the nearest open edge so its fall remains legible in the close shot.
		_target.global_position.z = minf(_target.global_position.z, -19.0)
		_ringout_staged = true
	if frame == FORCE_RINGOUT_FRAME and _hit_seen and not _target.is_dead:
		# Keep the visible fall in the clip, then cross the production threshold so
		# the shipping _check_fall -> _die -> eliminated path finishes in time.
		_target.global_position.y = -17.0
		_threshold_forced = true
		_target.call("_check_fall")


func _drive_camera(frame: int) -> void:
	var push_t := smoothstep(
		0.0,
		1.0,
		clampf(float(frame - CAMERA_PUSH_START_FRAME) / float(CAMERA_PUSH_END_FRAME - CAMERA_PUSH_START_FRAME), 0.0, 1.0)
	)
	_camera_expected_transform = _camera_start_transform.interpolate_with(_camera_close_transform, push_t)
	_camera.global_transform = _camera_expected_transform
	_camera.size = lerpf(82.0, 38.0, push_t)


func _fire_production_weapon(shooter: BaseCharacter, target: BaseCharacter, required: bool) -> bool:
	if shooter == null or target == null or shooter.weapon_manager == null or shooter.weapon_point == null:
		if required:
			_fail("Commercial exchange is missing a production character or weapon manager")
		return false
	var direction := (target.global_position + Vector3.UP * 1.35 - shooter.weapon_point.global_position).normalized()
	_face(shooter, direction)
	var fired := shooter.weapon_manager.try_fire(shooter.weapon_point, direction, shooter)
	if required and not fired:
		_fail("Production WeaponManager refused a required commercial shot")
	return fired


func _observe_production_events() -> void:
	if _camera and not _camera.global_transform.is_equal_approx(_camera_expected_transform):
		_camera_motion_valid = false
		_fail("Capture camera deviated from the authored commercial move")
		return
	if _target and _target.get_hit_feedback_debug().get("serial", 0) > 0:
		if not _hit_seen:
			_hit_frame = _frame
		_hit_seen = true
	for node in _walk(_arena):
		if node is Projectile:
			_projectile_seen = true
			break
	if _target and (_target.global_position.y < -1.0 or _target.is_dead):
		_fall_seen = true


func _save_requested_keyframe(beat: String) -> void:
	var requested := _argument_value("--still=", "")
	var frames_dir := _argument_value("--frames-dir=", "")
	var name := ""
	if beat == "start":
		_start_saved = true
		name = "p31_start.png"
	elif beat == "action":
		_action_saved = true
		name = "p31_action_apex.png"
		if requested == "action":
			name = ""
	elif beat == "end":
		_end_saved = true
		name = "p31_end.png"
	if not frames_dir.is_empty() and not name.is_empty():
		if not _save_viewport_png(frames_dir.path_join(name)):
			_fail("Could not save keyframe %s" % name)
			return
	if not requested.is_empty() and requested == beat:
		var output := _argument_value("--output=", "")
		if output.is_empty() or not _save_viewport_png(output):
			_fail("Could not save requested P31 %s still" % requested)


func _finish() -> void:
	var all_four_visible := _characters.size() == 4
	for character in _characters:
		all_four_visible = all_four_visible and is_instance_valid(character)
	var no_respawn := _target != null and _target.is_game_over and _target.is_dead
	var passed := all_four_visible and _pickup_seen and _pickup_equipped and _return_shot_fired and _shot_fired and _projectile_seen and _hit_seen and _fall_seen and no_respawn and _focus_valid and _camera_motion_valid and _start_saved and _action_saved and _end_saved
	var report := {
		"sample": "p31_commercial",
		"attempt": int(_argument_value("--attempt=", "0")),
		"duration_seconds": CLIP_SECONDS,
		"fps": FPS,
		"frame_count": TOTAL_FRAMES,
		"scene": SCENE_PATH,
		"four_character_reveal": all_four_visible,
		"pickup": _pickup_seen,
		"pickup_equipped_smg": _pickup_equipped,
		"return_shot": _return_shot_fired,
		"shot": _shot_fired,
		"projectile": _projectile_seen,
		"hit": _hit_seen,
		"hit_frame": _hit_frame,
		"fall": _fall_seen,
		"ringout_staged_after_hit": _ringout_staged,
		"production_threshold_crossed": _threshold_forced,
		"target_lives": _target.lives if _target else -1,
		"target_deaths": _target.deaths if _target else -1,
		"target_dead": _target.is_dead if _target else false,
		"target_game_over": _target.is_game_over if _target else false,
		"no_respawn": no_respawn,
		"camera_stable": _camera_motion_valid and _camera != null and _camera.global_transform.is_equal_approx(_camera_expected_transform),
		"camera_authored_push": true,
		"focus_valid": _focus_valid,
		"keyframes": {"start": _start_saved, "action_apex": _action_saved, "end": _end_saved},
		"pass": passed,
	}
	_write_report(report)
	if not passed:
		_fail("P31 commercial capture contract failed: %s" % JSON.stringify(report))
		return
	print("P31_COMMERCIAL_CAPTURE_PASS|attempt=%d|shot=%s|hit=%s|fall=%s|duration=%.2f" % [report["attempt"], _shot_fired, _hit_seen, _fall_seen, CLIP_SECONDS])
	await _release_capture_scene()
	quit(0)


func _release_capture_scene() -> void:
	# Movie Writer may still own active pickup/impact tweens on the authored end
	# frame. Release the production scene outside the five-second edit before quit.
	paused = false
	current_scene = null
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()
	for _frame_index in range(4):
		await process_frame
	RenderingServer.force_sync()


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
