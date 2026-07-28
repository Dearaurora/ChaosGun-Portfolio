extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const BANNER_SCRIPT_PATH := "res://scripts/ui/match_event_banner.gd"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var _failures: Array[String] = []


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	await process_frame
	root.size = VIEWPORT_SIZE
	await process_frame
	_configure_roster()
	var packed := load(SCENE_PATH) as PackedScene
	var arena := packed.instantiate() if packed else null
	if arena == null:
		_fail("Could not instantiate Twin Bays")
		_finish()
		return
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var intro_banner := arena.find_child("MatchIntroCue", true, false)
	_expect(_uses_banner_script(intro_banner), "READY/GO uses the shared MatchEventBanner scene")
	if intro_banner:
		var intro_state := intro_banner.call("get_debug_state") as Dictionary
		_expect(String(intro_state.get("title", "")) == "READY", "intro begins with READY")
		_expect(int(intro_state.get("pip_count", 0)) == 4, "intro carries four player-color pips")

	var tide := arena.find_child("TwinBaysTideController", true, false)
	_expect(tide != null, "Twin Bays exposes its tide controller")
	if tide:
		tide.call("set_debug_phase", &"warning", 0.42)
		await create_timer(0.22, true, false, true).timeout
		var warning_banner := arena.find_child("HighTideCountdown", true, false)
		_expect(_uses_banner_script(warning_banner), "high tide uses the shared MatchEventBanner scene")
		if warning_banner:
			var warning_state := warning_banner.call("get_debug_state") as Dictionary
			_expect(bool(warning_state.get("visible", false)), "high-tide banner is visible during warning")
			_expect(String(warning_state.get("title", "")).begins_with("涨潮"), "high-tide title is localized")
			_expect(String(warning_state.get("subtitle", "")) == "离开低洼区", "high-tide banner includes an action cue")
			_expect(_inside_viewport(warning_banner as Control), "high-tide banner stays inside the 1280x720 safe area")

		tide.call("set_debug_phase", &"rising", 0.1)
		await create_timer(0.20, true, false, true).timeout
		var hidden_state := warning_banner.call("get_debug_state") as Dictionary if warning_banner else {}
		_expect(not bool(hidden_state.get("visible", true)), "high-tide banner dismisses after warning")

	current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	_finish()


func _configure_roster() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	]


func _uses_banner_script(node: Node) -> bool:
	if node == null or node.get_script() == null:
		return false
	return String(node.get_script().resource_path) == BANNER_SCRIPT_PATH


func _inside_viewport(control: Control) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 \
		and rect.position.y >= -0.5 \
		and rect.end.x <= float(VIEWPORT_SIZE.x) + 0.5 \
		and rect.end.y <= float(VIEWPORT_SIZE.y) + 0.5


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
		print("[Twin Bays Match Event Banner Verifier] PASS")
		quit(0)
		return
	print("[Twin Bays Match Event Banner Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
