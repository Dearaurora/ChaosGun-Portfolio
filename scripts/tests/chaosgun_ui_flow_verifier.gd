extends SceneTree

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const KEYBINDS_SCENE := "res://scenes/ui/keybinds_screen.tscn"
const MATCH_HUD_SCRIPT = preload("res://scripts/ui/match_hud.gd")
const VIEWPORT_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1536, 960),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _failures: Array[String] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	await _verify_main_menu_focus()
	await _verify_character_select_guard()
	await _verify_screens_at_resolutions()
	_verify_match_hud_contract()
	await _finish()


func _verify_main_menu_focus() -> void:
	var screen := (load(MENU_SCENE) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	var quick := screen.find_child("QuickMatchButton", true, false) as Button
	_expect(quick != null, "main menu exposes the quick-match primary action")
	_expect(root.gui_get_focus_owner() == quick, "main menu defaults focus to quick match")
	screen.queue_free()
	await process_frame


func _verify_character_select_guard() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]
	var screen := (load(CHARACTER_SELECT_SCENE) as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	var start := screen.find_child("StartButton", true, false) as Button
	var reason := screen.find_child("StartReason", true, false) as Label
	_expect(start != null and start.disabled, "start stays disabled below two participants")
	_expect(reason != null and reason.text.contains("2"), "disabled start explains the participant minimum")
	screen.call("_on_set_slot", 1, match_config.SlotType.AI)
	await process_frame
	_expect(not start.disabled, "start enables at two participants")
	_expect(reason.text.is_empty(), "start guard clears after the roster becomes valid")
	screen.queue_free()
	await process_frame


func _verify_match_hud_contract() -> void:
	var viewport_size := Vector2(1920, 1080)
	var rects := MATCH_HUD_SCRIPT.camera_occlusion_rects(viewport_size, 4)
	var hud := MATCH_HUD_SCRIPT.new()
	_expect(hud.has_method("set_characters"), "MatchHUD exposes set_characters")
	hud.free()
	_expect(rects.size() == 4, "MatchHUD exposes four camera occlusion rectangles")
	for rect in rects:
		_expect(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= viewport_size.x and rect.end.y <= viewport_size.y, "MatchHUD camera rect stays in viewport")


func _verify_screens_at_resolutions() -> void:
	for viewport_size in VIEWPORT_SIZES:
		root.size = viewport_size
		for scene_path in [MENU_SCENE, CHARACTER_SELECT_SCENE, KEYBINDS_SCENE]:
			var screen := (load(scene_path) as PackedScene).instantiate()
			root.add_child(screen)
			await process_frame
			await process_frame
			for control in _visible_text_controls(screen):
				var rect := control.get_global_rect()
				_expect(_rect_inside_viewport(rect, Vector2(viewport_size)), "%s keeps %s in %s" % [scene_path.get_file(), control.name, str(viewport_size)])
			if scene_path == CHARACTER_SELECT_SCENE:
				_expect(not _siblings_overlap(screen.find_child("SlotRow", true, false)), "character slots do not overlap at %s" % str(viewport_size))
				_expect(not _siblings_overlap(screen.find_child("RosterStatusRow", true, false)), "roster cards do not overlap at %s" % str(viewport_size))
			elif scene_path == KEYBINDS_SCENE:
				_expect(not _siblings_overlap(screen.find_child("PrimaryPlayers", true, false)), "primary keybind columns do not overlap at %s" % str(viewport_size))
			screen.queue_free()
			await process_frame


func _visible_text_controls(start: Node) -> Array[Control]:
	var result: Array[Control] = []
	var pending: Array[Node] = [start]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if (node is Label or node is Button) and (node as Control).is_visible_in_tree():
			var control := node as Control
			if control.size != Vector2.ZERO:
				result.append(control)
		for child in node.get_children():
			pending.append(child)
	return result


func _siblings_overlap(parent: Node) -> bool:
	if parent == null:
		return true
	var children: Array[Control] = []
	for child in parent.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			children.append(child as Control)
	for index in range(children.size()):
		for other_index in range(index + 1, children.size()):
			if children[index].get_global_rect().intersects(children[other_index].get_global_rect()):
				return true
	return false


func _rect_inside_viewport(rect: Rect2, viewport_size: Vector2) -> bool:
	const EPSILON := 1.0
	return rect.position.x >= -EPSILON \
		and rect.position.y >= -EPSILON \
		and rect.end.x <= viewport_size.x + EPSILON \
		and rect.end.y <= viewport_size.y + EPSILON


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("OK  ", label)
	else:
		_failures.append(label)
		push_error(label)


func _finish() -> void:
	if _failures.is_empty():
		print("[ChaosGun UI Flow Verifier] PASS")
		quit(0)
		return
	print("[ChaosGun UI Flow Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
