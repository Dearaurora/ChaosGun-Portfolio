extends SceneTree

const PresentationScript = preload("res://scripts/maps/party_shooter_match_presentation.gd")

var _failures: Array[String] = []


class CameraDirectorProbe extends Node:
	var reveal_calls := 0
	var reveal_duration := 0.0
	var winner_calls := 0

	func begin_arena_reveal(duration: float) -> void:
		reveal_calls += 1
		reveal_duration = duration

	func begin_winner_focus(_winner: Node3D, _duration: float) -> void:
		winner_calls += 1


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	var arena := Node3D.new()
	arena.name = "PresentationContractArena"
	root.add_child(arena)
	current_scene = arena

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	arena.add_child(hud_layer)
	var hud_root := Control.new()
	hud_root.name = "HUDRoot"
	hud_layer.add_child(hud_root)
	var director := CameraDirectorProbe.new()
	director.name = "CameraDirectorProbe"
	arena.add_child(director)
	var presentation := PresentationScript.new() as PartyShooterMatchPresentation
	presentation.name = "PartyShooterMatchPresentation"
	arena.add_child(presentation)
	await process_frame
	presentation.configure(arena, director, [], {
		"profile_id": "contract_probe",
		"draw_hold_duration": 0.05,
		"ready_color": Color("#D9FCFF"),
		"go_color": Color("#2DE5FF"),
		"ink_color": Color("#073E57"),
	})
	presentation.start_intro()

	var state := presentation.get_debug_state()
	_expect(String(state.get("profile_id", "")) == "contract_probe", "configure applies the supplied presentation profile")
	_expect(is_equal_approx(float(state.get("intro_reveal_duration", 0.0)), 1.35), "shared intro duration defaults to 1.35 seconds")
	_expect(is_equal_approx(float(state.get("winner_focus_delay", 0.0)), 0.78), "shared winner handoff defaults to 0.78 seconds")
	_expect(is_equal_approx(float(state.get("winner_camera_duration", 0.0)), 0.72), "shared winner camera move defaults to 0.72 seconds")
	_expect(is_equal_approx(float(state.get("hud_focus_alpha", 0.0)), 0.22), "shared winner focus targets 22 percent HUD opacity")
	_expect(director.reveal_calls == 1 and is_equal_approx(director.reveal_duration, 1.35), "start_intro requests one 1.35-second arena reveal")
	_expect(String(state.get("cue_state", "")) == "ready", "READY is the first shared cue state")
	var cue_word := presentation.find_child("CueWord", true, false) as Label
	_expect(cue_word != null and cue_word.text == "READY", "shared cue renders READY before GO")
	if cue_word:
		_expect(cue_word.get_theme_color("font_color").is_equal_approx(Color("#D9FCFF")), "map profile colors the shared READY cue")

	presentation.present_result(null, Color.WHITE)
	await create_timer(0.28, true, false, true).timeout
	state = presentation.get_debug_state()
	_expect(String(state.get("cue_state", "")) == "result_ready", "draw hold hands control back to the result flow")
	_expect(int(state.get("hud_target_count", 0)) == 1, "shared controller discovers the configured HUD root")
	_expect(director.winner_calls == 0, "draw results do not request a winner camera focus")

	presentation.start_intro()
	state = presentation.get_debug_state()
	_expect(director.reveal_calls == 1, "start_intro remains idempotent")
	await _wait_for_cue_state(presentation, ["complete"], 1.8)
	if current_scene == arena:
		current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("OK  ", label)
	else:
		_failures.append(label)
		push_error(label)


func _wait_for_cue_state(presentation: Node, expected_states: Array, timeout_seconds: float) -> void:
	var deadline_msec := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
		var state := presentation.call("get_debug_state") as Dictionary
		if String(state.get("cue_state", "")) in expected_states:
			return
		await create_timer(0.025, true, false, true).timeout


func _finish() -> void:
	if _failures.is_empty():
		print("[Party Shooter Match Presentation Verifier] PASS")
		quit(0)
		return
	print("[Party Shooter Match Presentation Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
