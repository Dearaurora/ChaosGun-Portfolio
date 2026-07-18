extends SceneTree

const OPEN_RINGOUT_SCENE := "res://scenes/maps/open_ringout_slice.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const KEYBINDS_SCENE := "res://scenes/ui/keybinds_screen.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const RINGOUT_HUD_SCRIPT = preload("res://scripts/ui/ringout_hud.gd")
const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1536, 960),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const PLAYER_PANEL_NAMES := [
	"PlayerPanel1",
	"PlayerPanel2",
	"PlayerPanel3",
	"PlayerPanel4",
]
const REQUIRED_PANEL_CHILDREN := [
	"PlayerAccent",
	"Avatar",
	"PlayerTag",
	"LifeLabel",
	"InformationDivider",
	"WeaponSilhouette",
	"WeaponName",
	"AmmoLabel",
]

var _failures: Array[String] = []


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	_configure_roster()
	await _verify_open_ringout_hud()
	await _verify_screen_text_and_theme(MENU_SCENE, "main menu")
	await _verify_screen_text_and_theme(KEYBINDS_SCENE, "keybinds")
	await _verify_screen_text_and_theme(CHARACTER_SELECT_SCENE, "character select")
	await _finish()


func _verify_open_ringout_hud() -> void:
	root.size = VIEWPORT_SIZES[0]
	var packed := load(OPEN_RINGOUT_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load %s" % OPEN_RINGOUT_SCENE)
		return

	var arena := packed.instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var hud := arena.get_node_or_null("OpenRingoutHUD") as CanvasLayer
	if hud == null:
		_fail("Open Ring-Out HUD was not created")
		await _dispose_scene(arena)
		return

	for viewport_size in VIEWPORT_SIZES:
		root.size = viewport_size
		await process_frame
		await process_frame
		_verify_hud_at_size(hud, Vector2(viewport_size))

	var pause_menu := arena.get_node_or_null("PauseMenu") as CanvasLayer
	_expect(pause_menu != null and pause_menu.has_method("_toggle_pause"), "pause screen keeps its public flow")
	var victory_screen: CanvasLayer = null
	for child in arena.get_children():
		if child is CanvasLayer and child.has_method("show_victory"):
			victory_screen = child as CanvasLayer
			break
	_expect(victory_screen != null, "victory screen keeps show_victory compatibility")
	if victory_screen:
		victory_screen.call("show_victory", "PLAYER 1", Color("#ff6f61"), [])
		await process_frame
		_expect(victory_screen.find_child("ResultTable", true, false) != null, "victory screen exposes the flat result table")
		_expect(_count_named_descendants(victory_screen, "ResultTable") == 1, "victory screen does not nest duplicate result cards")
		paused = false

	await _await_presentation_settled(arena)
	await _dispose_scene(arena)


func _verify_hud_at_size(hud: CanvasLayer, viewport_size: Vector2) -> void:
	var scale_value := TOY_UI.ui_scale(viewport_size)
	_expect(scale_value >= 0.85 and scale_value <= 1.15, "%s HUD scale stays inside 0.85-1.15" % str(viewport_size))
	var occlusion_rects := RINGOUT_HUD_SCRIPT.camera_occlusion_rects(viewport_size, 4)
	_expect(occlusion_rects.size() == 4, "%s exposes four camera occlusion rectangles" % str(viewport_size))

	var panel_rects: Array[Rect2] = []
	for panel_name in PLAYER_PANEL_NAMES:
		var panel := hud.find_child(panel_name, true, false) as Control
		if panel == null:
			_fail("%s is missing at %s" % [panel_name, str(viewport_size)])
			continue
		var rect := panel.get_global_rect()
		panel_rects.append(rect)
		_expect(_rect_inside_viewport(rect, viewport_size), "%s remains inside %s" % [panel_name, str(viewport_size)])
		_expect(rect.size.is_equal_approx(RINGOUT_HUD_SCRIPT.PANEL_SIZE * scale_value), "%s uses the scaled 200x72 footprint" % panel_name)
		for child_name in REQUIRED_PANEL_CHILDREN:
			_expect(panel.get_node_or_null(child_name) != null, "%s contains %s" % [panel_name, child_name])
		for forbidden in ["WeaponBox", "AmmoTrack", "AmmoFill"]:
			_expect(panel.get_node_or_null(forbidden) == null, "%s omits nested %s" % [panel_name, forbidden])

	for i in range(panel_rects.size()):
		for j in range(i + 1, panel_rects.size()):
			_expect(not panel_rects[i].intersects(panel_rects[j]), "%s HUD panels %d and %d do not overlap" % [str(viewport_size), i + 1, j + 1])
		if i < occlusion_rects.size():
			_expect(occlusion_rects[i].encloses(panel_rects[i]), "%s camera rect %d encloses the rendered panel" % [str(viewport_size), i + 1])

	var total_occluded_area := 0.0
	for rect in occlusion_rects:
		total_occluded_area += rect.get_area()
	var viewport_area := viewport_size.x * viewport_size.y
	_expect(total_occluded_area / viewport_area <= 0.075, "%s corner HUD reserves at most 7.5%% of the frame" % str(viewport_size))


func _verify_screen_text_and_theme(scene_path: String, label: String) -> void:
	root.size = Vector2i(1536, 960)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("Could not load %s" % scene_path)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame

	var text_controls := _find_text_controls(scene)
	_expect(not text_controls.is_empty(), "%s exposes readable text controls" % label)
	for control in text_controls:
		var text_value := String(control.get("text"))
		_expect(not _contains_mojibake(text_value), "%s has no corrupted text: %s" % [label, text_value])
		if control is Control:
			var rect := (control as Control).get_global_rect()
			if (control as Control).visible and rect.size != Vector2.ZERO:
				_expect(_rect_inside_viewport(rect, Vector2(root.size)), "%s text stays in frame: %s" % [label, text_value])

	var background := scene.find_child("SunsetBackground", true, false)
	_expect(background != null, "%s uses the shared sunset background" % label)
	await _dispose_scene(scene)


func _find_text_controls(start: Node) -> Array[Node]:
	var found: Array[Node] = []
	var pending: Array[Node] = [start]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node is Label or node is Button:
			found.append(node)
		for child in node.get_children():
			pending.append(child)
	return found


func _contains_mojibake(value: String) -> bool:
	for fragment in ["�", "鈭", "鏍", "绔", "锛", "娓"]:
		if value.contains(fragment):
			return true
	return false


func _rect_inside_viewport(rect: Rect2, viewport_size: Vector2) -> bool:
	const EPSILON := 1.0
	return rect.position.x >= -EPSILON \
		and rect.position.y >= -EPSILON \
		and rect.end.x <= viewport_size.x + EPSILON \
		and rect.end.y <= viewport_size.y + EPSILON


func _count_named_descendants(start: Node, target_name: String) -> int:
	var count := 0
	var pending: Array[Node] = [start]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node.name == target_name:
			count += 1
		for child in node.get_children():
			pending.append(child)
	return count


func _configure_roster() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
		]


func _await_presentation_settled(arena: Node) -> void:
	var presentation := arena.find_child("OpenRingoutMatchPresentation", true, false)
	if presentation == null or not presentation.has_method("get_debug_state"):
		return
	var deadline_msec := Time.get_ticks_msec() + 2200
	while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
		var state := presentation.call("get_debug_state") as Dictionary
		if String(state.get("cue_state", "")) in ["complete", "result_ready"]:
			return
		await create_timer(0.025, true, false, true).timeout


func _dispose_scene(scene: Node) -> void:
	paused = false
	if current_scene == scene:
		current_scene = null
	if scene and is_instance_valid(scene):
		scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("OK  ", label)
	else:
		_fail(label)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	root.set_meta("disable_runtime_audio", false)
	if _failures.is_empty():
		print("[P28 UI System Verifier] PASS")
		quit(0)
		return
	print("[P28 UI System Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
