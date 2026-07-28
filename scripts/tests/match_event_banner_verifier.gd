extends SceneTree

const BANNER_SCENE := preload("res://scenes/ui/components/match_event_banner.tscn")
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1536, 960),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	root.size = VIEWPORTS[0]
	await process_frame
	for viewport_size in VIEWPORTS:
		await _verify_viewport(viewport_size)
	_finish()


func _verify_viewport(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	await process_frame
	var banner := BANNER_SCENE.instantiate()
	root.add_child(banner)
	await process_frame

	var colors := [
		Color("#4da4ff"),
		Color("#ff6248"),
		Color("#d66bdc"),
		Color("#77cf6b"),
	]
	banner.call("set_placement", 0)
	banner.call("set_event", "READY", "", "", Color("#fff4d6"), colors, false)
	await process_frame
	_expect(banner.visible, "%s READY banner is visible" % viewport_size)
	_expect(_inside_viewport(banner, viewport_size), "%s centered banner stays inside the viewport" % viewport_size)
	var ready_state := banner.call("get_debug_state") as Dictionary
	_expect(String(ready_state.get("title", "")) == "READY", "%s READY title is data-driven" % viewport_size)
	_expect(int(ready_state.get("pip_count", 0)) == 4, "%s READY banner exposes four player colors" % viewport_size)

	banner.call("set_placement", 1)
	banner.call("set_event", "涨潮  2", "离开低洼区", "TWIN BAYS", Color("#f8c84f"), [], false)
	await process_frame
	var warning_state := banner.call("get_debug_state") as Dictionary
	_expect(_inside_viewport(banner, viewport_size), "%s warning banner stays inside the viewport" % viewport_size)
	_expect(String(warning_state.get("title", "")) == "涨潮  2", "%s warning title is localized" % viewport_size)
	_expect(String(warning_state.get("subtitle", "")) == "离开低洼区", "%s warning includes an action cue" % viewport_size)
	_expect(int(warning_state.get("pip_count", -1)) == 0, "%s warning hides player pips" % viewport_size)

	banner.call("hide_event", false)
	_expect(not banner.visible, "%s banner supports immediate teardown" % viewport_size)
	banner.queue_free()
	await process_frame


func _inside_viewport(control: Control, viewport_size: Vector2i) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 \
		and rect.position.y >= -0.5 \
		and rect.end.x <= float(viewport_size.x) + 0.5 \
		and rect.end.y <= float(viewport_size.y) + 0.5


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("OK  ", label)
	else:
		_failures.append(label)
		push_error(label)


func _finish() -> void:
	if _failures.is_empty():
		print("[Match Event Banner Verifier] PASS")
		quit(0)
		return
	print("[Match Event Banner Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
