extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const TEST_VIEWPORT_SIZE := Vector2i(1152, 648)
const CLUSTER_POSITIONS := [
	Vector3(-3.0, 1.1, -2.0),
	Vector3(3.0, 1.1, -2.0),
	Vector3(-3.0, 1.1, 3.0),
	Vector3(3.0, 1.1, 3.0),
]
const EAST_ISLAND_POSITIONS := [
	Vector3(38.5, 1.1, -1.5),
	Vector3(42.5, 1.1, -1.0),
	Vector3(39.0, 1.1, 4.0),
	Vector3(43.0, 1.1, 4.5),
]
const OUTER_ISLAND_POSITIONS := [
	Vector3(-3.0, 1.1, -32.0),
	Vector3(43.0, 1.1, 1.0),
	Vector3(13.0, 1.1, 31.0),
	Vector3(-43.0, 1.1, 8.0),
]

var _failures: Array[String] = []

func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	root.size = TEST_VIEWPORT_SIZE
	_configure_roster()

	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		_finish()
		return

	var arena := scene.instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var director := arena.get_node_or_null("OpenRingoutCameraDirector")
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	var characters = arena.get("_characters") as Array
	if director == null or camera == null or characters.size() != 4:
		_fail("Camera verifier requires the director, camera, and four characters")
		_finish()
		return

	for item in characters:
		var character := item as BaseCharacter
		character.freeze = true
		character.linear_velocity = Vector3.ZERO
		character.process_mode = Node.PROCESS_MODE_DISABLED

	_stage(characters, CLUSTER_POSITIONS)
	_step_camera(arena, 180)
	var cluster_state := arena.call("get_runtime_camera_debug") as Dictionary
	var cluster_size := float(cluster_state.get("current_size", 0.0))
	if cluster_size < 35.5 or cluster_size > 40.5:
		_fail("Clustered combat should push in near size 36, got %.2f" % cluster_size)
	else:
		print("OK  clustered combat zoom: %.2f" % cluster_size)
	_verify_small_motion_response(arena, characters)
	_verify_constant_motion_smoothness(arena, director, characters)
	_verify_continuous_zoom_solver(director)

	_stage(characters, CLUSTER_POSITIONS)
	_step_camera(arena, 180)
	cluster_state = arena.call("get_runtime_camera_debug") as Dictionary

	var cluster_focus := cluster_state.get("current_focus", Vector3.ZERO) as Vector3
	_stage(characters, EAST_ISLAND_POSITIONS)
	_step_camera(arena, 1)
	var first_follow_state := arena.call("get_runtime_camera_debug") as Dictionary
	var first_follow_focus := first_follow_state.get("current_focus", Vector3.ZERO) as Vector3
	var east_target := first_follow_state.get("target_focus", Vector3.ZERO) as Vector3
	if east_target.x < 38.0:
		_fail("Camera target did not follow combat to the east island: %s" % str(east_target))
	elif first_follow_focus.x <= cluster_focus.x or first_follow_focus.x >= east_target.x - 0.5:
		_fail("Camera follow should advance smoothly without snapping: %s -> %s" % [str(cluster_focus), str(first_follow_focus)])
	else:
		print("OK  smooth east-island follow started")

	_step_camera(arena, 180)
	var east_state := arena.call("get_runtime_camera_debug") as Dictionary
	var east_focus := east_state.get("current_focus", Vector3.ZERO) as Vector3
	if east_focus.x < 37.0:
		_fail("Camera did not settle on the east-island fight: %s" % str(east_focus))
	else:
		print("OK  east-island follow settled: %s" % str(east_focus))

	_stage(characters, OUTER_ISLAND_POSITIONS)
	_step_camera(arena, 240)
	var spread_state := arena.call("get_runtime_camera_debug") as Dictionary
	var spread_size := float(spread_state.get("current_size", 0.0))
	if spread_size < cluster_size + 14.0:
		_fail("Outer-island spread should pull back substantially: cluster %.2f, spread %.2f" % [cluster_size, spread_size])
	elif spread_size > float(spread_state.get("max_size", 0.0)) + 0.1:
		_fail("Spread zoom exceeded its configured maximum: %.2f" % spread_size)
	else:
		print("OK  outer-island overview zoom: %.2f" % spread_size)

	for i in range(characters.size()):
		var character := characters[i] as BaseCharacter
		if bool(director.call("is_world_point_hud_occluded", character.global_position)):
			_fail("Character %d remains under a corner HUD panel after camera settling" % (i + 1))
	if _failures.is_empty():
		print("OK  all active characters clear the HUD occlusion rectangles")

	var ignored := characters[0] as BaseCharacter
	ignored.is_dead = true
	ignored.global_position = Vector3(200.0, -20.0, 200.0)
	_step_camera(arena, 1)
	var dead_state := arena.call("get_runtime_camera_debug") as Dictionary
	if int(dead_state.get("tracked_count", 0)) != 3:
		_fail("Dead or falling characters must be excluded from camera framing")
	else:
		print("OK  dead/falling character ignored")

	ignored.is_dead = false
	ignored.global_position = Vector3(-12.0, 1.1, 18.0)
	var two_character_roster := characters.slice(0, 2)
	for _frame in range(60):
		director.call("update_camera", two_character_roster, 1.0 / 60.0)
	var two_player_state := director.call("get_debug_state") as Dictionary
	if int(two_player_state.get("hud_panel_count", 0)) != 2:
		_fail("Two-character matches should reserve only the two HUD panels that exist")
	else:
		print("OK  two-character HUD occlusion profile")

	_verify_unscaled_camera_motion(arena, characters)
	_verify_screen_shake_isolation(camera)

	_finish()

func _configure_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		return
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	]

func _stage(characters: Array, positions: Array) -> void:
	for i in range(mini(characters.size(), positions.size())):
		var character := characters[i] as BaseCharacter
		character.global_position = positions[i] as Vector3
		character.linear_velocity = Vector3.ZERO

func _step_camera(arena: Node, frame_count: int) -> void:
	for _frame in range(frame_count):
		arena.call("_update_map_runtime_camera", 1.0 / 60.0)

func _verify_small_motion_response(arena: Node, characters: Array) -> void:
	var before := arena.call("get_runtime_camera_debug") as Dictionary
	var before_target := before.get("target_focus", Vector3.ZERO) as Vector3
	for item in characters:
		var character := item as BaseCharacter
		character.global_position += Vector3(0.20, 0.0, 0.0)
	_step_camera(arena, 1)
	var after := arena.call("get_runtime_camera_debug") as Dictionary
	var after_target := after.get("target_focus", Vector3.ZERO) as Vector3
	if after_target.x - before_target.x < 0.15:
		_fail("Camera target still has a sticky sub-unit dead zone")
	else:
		print("OK  sub-unit movement updates camera target continuously")

func _verify_constant_motion_smoothness(arena: Node, director: Node, characters: Array) -> void:
	_stage(characters, CLUSTER_POSITIONS)
	_step_camera(arena, 180)
	var velocity := Vector3(6.0, 0.0, 0.0)
	for item in characters:
		(item as BaseCharacter).linear_velocity = velocity

	var previous_focus := (arena.call("get_runtime_camera_debug") as Dictionary).get("current_focus", Vector3.ZERO) as Vector3
	var frame_steps: Array[float] = []
	for frame in range(360):
		if frame % 2 == 0:
			for item in characters:
				(item as BaseCharacter).global_position += velocity / 60.0
		director.call("update_camera", characters, 1.0 / 120.0)
		var state := director.call("get_debug_state") as Dictionary
		var focus := state.get("current_focus", Vector3.ZERO) as Vector3
		if frame >= 180:
			frame_steps.append(focus.x - previous_focus.x)
		previous_focus = focus

	for item in characters:
		(item as BaseCharacter).linear_velocity = Vector3.ZERO
	var average_step := 0.0
	for step in frame_steps:
		average_step += step
	average_step /= maxf(float(frame_steps.size()), 1.0)
	var max_deviation := 0.0
	for step in frame_steps:
		max_deviation = maxf(max_deviation, absf(step - average_step))
	var ripple := max_deviation / maxf(absf(average_step), 0.0001)
	if average_step <= 0.0 or ripple > 0.16:
		_fail("Camera velocity pulses under 60 Hz physics / 120 Hz rendering: %.3f" % ripple)
	else:
		print("OK  stepped-physics camera velocity ripple: %.3f" % ripple)

func _verify_continuous_zoom_solver(director: Node) -> void:
	var previous_size := -1.0
	var max_step := 0.0
	for sample_index in range(161):
		var west_x := lerpf(-20.0, -48.0, float(sample_index) / 160.0)
		var points := [
			Vector3(-3.0, 1.0, -32.0),
			Vector3(43.0, 1.0, 1.0),
			Vector3(13.0, 1.0, 31.0),
			Vector3(west_x, 1.0, 8.0),
		]
		var focus := director.call("_calculate_focus", points, Vector3.ZERO) as Vector3
		var required_size := float(director.call(
			"_calculate_required_size",
			points,
			focus,
			Vector2(TEST_VIEWPORT_SIZE)
		))
		if previous_size >= 0.0:
			max_step = maxf(max_step, absf(required_size - previous_size))
		previous_size = required_size
	if max_step > 0.75:
		_fail("HUD-safe zoom solver still changes in visible size tiers: %.2f" % max_step)
	else:
		print("OK  continuous HUD-safe zoom max step: %.3f" % max_step)

func _verify_unscaled_camera_motion(arena: Node, characters: Array) -> void:
	_stage(characters, CLUSTER_POSITIONS)
	_step_camera(arena, 180)
	var before := arena.call("get_runtime_camera_debug") as Dictionary
	var before_focus := before.get("current_focus", Vector3.ZERO) as Vector3
	_stage(characters, EAST_ISLAND_POSITIONS)
	Engine.time_scale = 0.05
	arena.call("_update_map_runtime_camera", (1.0 / 60.0) * Engine.time_scale)
	Engine.time_scale = 1.0
	var after := arena.call("get_runtime_camera_debug") as Dictionary
	var after_focus := after.get("current_focus", Vector3.ZERO) as Vector3
	if after_focus.x - before_focus.x < 0.08:
		_fail("Camera smoothing nearly freezes during hitstop")
	else:
		print("OK  camera smoothing uses unscaled presentation time")

func _verify_screen_shake_isolation(camera: Camera3D) -> void:
	var game_feel = root.get_node_or_null("GameFeel")
	if game_feel == null:
		_fail("GameFeel autoload missing during camera shake test")
		return
	var original_position := camera.position
	var original_h_offset := camera.h_offset
	var original_v_offset := camera.v_offset
	game_feel.call("screen_shake", 0.4, 0.10)
	game_feel.call("_process", 0.016)
	if not camera.position.is_equal_approx(original_position):
		_fail("Screen shake must not overwrite the camera director transform")
	elif is_equal_approx(camera.h_offset, original_h_offset) and is_equal_approx(camera.v_offset, original_v_offset):
		_fail("Screen shake did not use camera-local presentation offsets")
	else:
		print("OK  screen shake isolated from director transform")
	game_feel.call("_process", 0.20)
	if not is_equal_approx(camera.h_offset, original_h_offset) or not is_equal_approx(camera.v_offset, original_v_offset):
		_fail("Screen shake offsets did not restore after the effect")
	Engine.time_scale = 0.05
	game_feel.call("screen_shake", 0.2, 0.10)
	game_feel.call("_process", 0.006)
	Engine.time_scale = 1.0
	if not is_equal_approx(camera.h_offset, original_h_offset) or not is_equal_approx(camera.v_offset, original_v_offset):
		_fail("Screen shake duration was stretched by hitstop time scale")
	else:
		print("OK  screen shake duration uses unscaled presentation time")

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	if _failures.is_empty():
		print("[Open Ringout Camera Verifier] PASS")
		quit(0)
		return
	print("[Open Ringout Camera Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
