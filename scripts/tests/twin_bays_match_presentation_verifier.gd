extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const TEST_VIEWPORT_SIZE := Vector2i(1280, 720)

var _failures: Array[String] = []


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	root.size = TEST_VIEWPORT_SIZE
	_configure_roster()
	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load the Twin Bays Splash Arena scene")
		_finish()
		return
	var arena := scene.instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	await process_frame

	var presentation := arena.get_node_or_null("PartyShooterMatchPresentation")
	var director := arena.get_node_or_null("TwinBaysCameraDirector")
	var characters := arena.get("_characters") as Array
	if presentation == null or director == null or characters.size() != 4:
		_fail("Twin Bays presentation requires the shared controller, camera director, and four characters")
		_finish()
		return
	for item in characters:
		var character := item as BaseCharacter
		if character:
			character.freeze = true
			character.linear_velocity = Vector3.ZERO

	var state := presentation.call("get_debug_state") as Dictionary
	_expect(String(state.get("profile_id", "")) == "twin_bays_splash_arena", "Twin Bays supplies its map profile to the shared controller")
	_expect(bool(state.get("intro_started", false)), "Twin Bays starts the shared intro after spawning")
	_expect(int(state.get("spawn_burst_count", 0)) == 4, "Twin Bays plays the shared spawn presentation for all four characters")
	_expect(String(state.get("cue_state", "")) == "ready", "Twin Bays begins with the shared READY cue")

	var camera_state := director.call("get_debug_state") as Dictionary
	_expect(String(camera_state.get("presentation_mode", "")) == "reveal", "Twin Bays camera begins in arena reveal mode")
	_expect(float(camera_state.get("current_size", 0.0)) >= 94.0, "Twin Bays reveal starts from the authored wide overview that keeps both portal pipes visible")

	var spawn_bursts: Array[Node] = []
	_collect_prefixed(arena, "MatchSpawnBurst", spawn_bursts)
	_expect(spawn_bursts.size() == 4, "Twin Bays owns four live shared match-spawn bursts")

	await create_timer(1.44, true, false, true).timeout
	state = presentation.call("get_debug_state") as Dictionary
	_expect(String(state.get("cue_state", "")) == "complete", "Twin Bays READY to GO cue completes without blocking gameplay")

	var winner := characters[0] as BaseCharacter
	var match_config = root.get_node_or_null("MatchConfig")
	var winner_color: Color = match_config.PLAYER_COLORS[0] as Color if match_config else Color.WHITE
	arena.call("_present_match_result", winner, winner.name, winner_color)
	await create_timer(0.92, true, false, true).timeout
	camera_state = director.call("get_debug_state") as Dictionary
	_expect(String(camera_state.get("presentation_mode", "")) == "winner_hold", "Twin Bays winner focus settles before result handoff")
	_expect(absf(float(camera_state.get("current_size", 0.0)) - 38.5) < 0.1, "Twin Bays uses its authored winner framing")

	state = presentation.call("get_debug_state") as Dictionary
	_expect(String(state.get("cue_state", "")) == "result_ready", "Twin Bays shared controller reaches result-ready state")
	_expect(int(state.get("hud_target_count", 0)) >= 3, "Twin Bays shared controller discovers the live duel HUD controls")
	var game_hud := arena.find_child("GameHUD", true, false) as CanvasLayer
	_expect(game_hud != null, "Twin Bays retains the existing GameHUD")
	if game_hud:
		for child in game_hud.get_children():
			if child is Control and (child as Control).visible:
				_expect((child as Control).modulate.a <= 0.23, "visible Twin Bays HUD control %s is subdued during winner focus" % child.name)

	var victory_screen: CanvasLayer = null
	for child in arena.get_children():
		if child.has_method("show_victory"):
			victory_screen = child as CanvasLayer
			break
	_expect(victory_screen != null and victory_screen.visible, "Twin Bays hands the focus back to the existing result screen")
	_expect(paused, "Twin Bays result screen preserves the existing pause behavior")
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
		print("[Twin Bays Match Presentation Verifier] PASS")
		quit(0)
		return
	print("[Twin Bays Match Presentation Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
