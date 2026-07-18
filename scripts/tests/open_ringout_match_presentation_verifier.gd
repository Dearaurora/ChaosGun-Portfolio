extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const TEST_VIEWPORT_SIZE := Vector2i(1152, 648)

var _failures: Array[String] = []


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	root.size = TEST_VIEWPORT_SIZE
	_configure_roster()
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load the Open Ring-Out scene")
		_finish()
		return
	var arena := scene.instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var presentation := arena.get_node_or_null("OpenRingoutMatchPresentation")
	var director := arena.get_node_or_null("OpenRingoutCameraDirector")
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	var characters := arena.get("_characters") as Array
	if presentation == null or director == null or camera == null or characters.size() != 4:
		_fail("Presentation verifier requires the controller, director, camera, and four characters")
		_finish()
		return

	var presentation_state := presentation.call("get_debug_state") as Dictionary
	_expect(bool(presentation_state.get("intro_started", false)), "intro sequence starts after loadouts are ready")
	_expect(int(presentation_state.get("spawn_burst_count", 0)) == 4, "all four players receive a spawn burst")
	_expect(String(presentation_state.get("cue_state", "")) == "ready", "round cue begins in READY state")

	var camera_state := director.call("get_debug_state") as Dictionary
	_expect(String(camera_state.get("presentation_mode", "")) == "reveal", "camera begins in arena reveal mode")
	_expect(float(camera_state.get("current_size", 0.0)) > 70.0, "arena reveal starts from a readable wide view")

	var spawn_bursts: Array[Node] = []
	_collect_prefixed(arena, "MatchSpawnBurst", spawn_bursts)
	_expect(spawn_bursts.size() == 4, "four live match-spawn effect nodes are present")
	for burst in spawn_bursts:
		var debug := burst.call("get_visual_debug") as Dictionary
		if String(debug.get("mode", "")) != "match_spawn":
			_fail("Spawn burst is using the wrong transition mode")
		if int(debug.get("ring_count", 0)) != 2:
			_fail("Match spawn requires the authored two-ring foot pulse")

	var cue := presentation.get_node_or_null("MatchIntroCue")
	var cue_word := presentation.find_child("CueWord", true, false) as Label
	_expect(cue != null and cue_word != null, "intro cue hierarchy is present")
	if cue_word:
		_expect(cue_word.text == "READY", "intro cue displays READY before GO")
	for index in range(4):
		_expect(presentation.find_child("PlayerColor_%d" % (index + 1), true, false) != null, "intro cue carries player color %d" % (index + 1))

	for _frame in range(100):
		director.call("update_camera", characters, 1.0 / 60.0)
	camera_state = director.call("get_debug_state") as Dictionary
	_expect(String(camera_state.get("presentation_mode", "")) == "none", "reveal hands control back to adaptive gameplay framing")
	_expect(float(camera_state.get("current_size", 0.0)) < 70.0, "reveal visibly settles toward the fight")

	var winner := characters[0] as BaseCharacter
	var match_config = root.get_node_or_null("MatchConfig")
	arena.call("_present_match_result", winner, winner.name, match_config.PLAYER_COLORS[0])
	camera_state = director.call("get_debug_state") as Dictionary
	_expect(String(camera_state.get("presentation_mode", "")) == "winner_focus", "winner result starts a camera focus move")
	await create_timer(0.84, true, false, true).timeout
	camera_state = director.call("get_debug_state") as Dictionary
	_expect(String(camera_state.get("presentation_mode", "")) == "winner_hold", "winner focus settles before the result overlay")
	_expect(absf(float(camera_state.get("current_size", 0.0)) - 29.5) < 0.1, "winner focus uses the authored close framing")
	var hud_root := arena.find_child("HUDRoot", true, false) as Control
	_expect(hud_root != null and hud_root.modulate.a <= 0.23, "winner focus visually subdues the corner HUD")
	var victory_screen: CanvasLayer = null
	for child in arena.get_children():
		if child.has_method("show_victory"):
			victory_screen = child as CanvasLayer
			break
	_expect(victory_screen != null and victory_screen.visible, "winner focus hands off to the result screen")
	_expect(paused, "result screen pauses the finished match")
	paused = false
	_finish()


func _configure_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
		]


func _collect_prefixed(node: Node, prefix: String, output: Array[Node]) -> void:
	if String(node.name).begins_with(prefix):
		output.append(node)
	for child in node.get_children():
		_collect_prefixed(child, prefix, output)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("OK  ", label)
	else:
		_fail(label)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Open Ring-Out Match Presentation Verifier] PASS")
		quit(0)
		return
	print("[Open Ring-Out Match Presentation Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
