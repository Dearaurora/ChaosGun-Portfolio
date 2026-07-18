extends SceneTree

## Deterministic P31 tail: invokes the production winner-focus and result UI flow.

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const FPS := 60
const CLIP_SECONDS := 2.5
const TOTAL_FRAMES := int(CLIP_SECONDS * FPS)

var _arena: Node3D
var _winner: BaseCharacter
var _characters: Array[BaseCharacter] = []
var _frame := 0
var _result_requested := false
var _winner_focus_seen := false
var _result_ui_seen := false
var _focus_valid := true
var _offline_movie_capture := false
var _failed := false


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("P31 match-tail capture requires a render-capable display driver")
		return
	seed(31032)
	_offline_movie_capture = OS.has_feature("movie")
	var capture_audio := _argument_value("--audio=", "false").to_lower() in ["1", "true", "yes"]
	root.set_meta("disable_runtime_audio", not capture_audio)
	var viewport_size := Vector2i(maxi(320, int(_argument_value("--width=", "1920"))), maxi(180, int(_argument_value("--height=", "1080"))))
	if absf(float(viewport_size.x) / float(viewport_size.y) - 16.0 / 9.0) > 0.002:
		_fail("P31 tail must be 16:9")
		return
	var window_policy := root.get_node_or_null("TestWindowPolicy")
	if window_policy:
		window_policy.set_process(false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	_configure_slots()
	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	if _arena == null:
		_fail("Could not instantiate production Open Ring-Out")
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame
	if not _stage_winner():
		return
	if not await _acquire_capture_focus():
		return
	while _frame < TOTAL_FRAMES:
		await physics_frame
		_frame += 1
		if not DisplayServer.window_is_focused():
			_focus_valid = false
			if not _offline_movie_capture:
				_fail("P31 match-tail window lost desktop focus")
				return
		if _frame == 12:
			_request_production_result()
		_observe()
		if _failed:
			return
	await _finish()


func _configure_slots() -> void:
	var config := root.get_node_or_null("MatchConfig")
	if config == null:
		_fail("MatchConfig autoload is missing")
		return
	config.slots = [config.SlotType.HUMAN, config.SlotType.HUMAN, config.SlotType.HUMAN, config.SlotType.HUMAN]
	config.PLAYER_COLORS = [Color("#ef3f3f"), Color("#78d23d"), Color("#24a9e8"), Color("#f2bf27")]


func _stage_winner() -> bool:
	var raw_characters := _arena.get("_characters") as Array
	for item in raw_characters:
		if item is BaseCharacter:
			_characters.append(item as BaseCharacter)
	if _characters.size() != 4:
		_fail("P31 tail requires four production characters")
		return false
	var positions := [Vector3(-5.0, 1.25, -2.0), Vector3(18.0, 1.25, -7.0), Vector3(-17.0, 1.25, 9.0), Vector3(16.0, 1.25, 10.0)]
	for index in range(_characters.size()):
		var character := _characters[index]
		character.global_position = positions[index]
		character.freeze = true
		character.visible = index == 0
		character.is_game_over = index != 0
	_winner = _characters[0]
	var camera := _arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera:
		camera.global_position = Vector3(0.0, 48.0, 42.0)
		camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	return true


func _request_production_result() -> void:
	if _arena == null or _winner == null:
		_fail("P31 tail cannot request production result without a winner")
		return
	_result_requested = true
	var color := Color("#ef3f3f")
	_arena.call("_present_match_result", _winner, _winner.name, color)


func _acquire_capture_focus() -> bool:
	for _attempt in range(12):
		DisplayServer.window_move_to_foreground()
		await process_frame
		if DisplayServer.window_is_focused():
			return true
	if _offline_movie_capture:
		_focus_valid = false
		return true
	_fail("P31 match-tail window could not acquire desktop focus before the sample")
	return false


func _observe() -> void:
	var presentation := _arena.get_node_or_null("OpenRingoutMatchPresentation")
	if presentation and presentation.has_method("get_debug_state"):
		var state := presentation.call("get_debug_state") as Dictionary
		_winner_focus_seen = _winner_focus_seen or String(state.get("cue_state", "")) in ["winner_focus", "result_ready"]
	var victory := _arena.get("_victory_screen") as CanvasLayer
	_result_ui_seen = _result_ui_seen or (victory != null and victory.visible and victory.get_node_or_null("VictoryRoot") != null)


func _finish() -> void:
	var passed := _result_requested and _winner_focus_seen and _result_ui_seen and (_focus_valid or _offline_movie_capture)
	var report := {
		"sample": "p31_match_tail",
		"duration_seconds": CLIP_SECONDS,
		"fps": FPS,
		"winner_focus": _winner_focus_seen,
		"result_ui": _result_ui_seen,
		"focus_valid": _focus_valid,
		"offline_movie_capture": _offline_movie_capture,
		"pass": passed,
	}
	_write_report(report)
	if not passed:
		_fail("P31 production match-tail contract failed: %s" % JSON.stringify(report))
		return
	print("P31_MATCH_TAIL_PASS|winner_focus=%s|result_ui=%s" % [_winner_focus_seen, _result_ui_seen])
	paused = false
	current_scene = null
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()
	for _frame_index in range(4):
		await process_frame
	RenderingServer.force_sync()
	quit(0)


func _write_report(report: Dictionary) -> void:
	var requested := _argument_value("--report=", "")
	if requested.is_empty():
		return
	var absolute := ProjectSettings.globalize_path(requested) if requested.begins_with("res://") else requested
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()


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
	print("P31_MATCH_TAIL_FAIL|%s" % message)
	quit(1)
