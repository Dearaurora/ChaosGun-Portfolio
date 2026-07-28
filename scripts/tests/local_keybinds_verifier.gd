extends SceneTree

const SCENE_PATH := "res://scenes/ui/keybinds_screen.tscn"
const ACTION_SUFFIXES := [
	"move_forward",
	"move_backward",
	"move_left",
	"move_right",
	"fire",
	"jump",
	"target_cycle",
	"drop_weapon",
]

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Local Keybinds Verifier]")
	print("==================================================")
	root.size = Vector2i(1536, 960)
	_verify_input_actions()
	_verify_default_keyboard_conflicts()

	var match_config := root.get_node_or_null("MatchConfig")
	var input_prefixes = match_config.get("INPUT_PREFIXES") as Array if match_config else []
	if input_prefixes != ["p1_", "p2_", "p3_", "p4_"]:
		_fail("MatchConfig must expose four local-player input prefixes")

	var packed := load(SCENE_PATH) as PackedScene
	var screen = packed.instantiate() if packed else null
	if screen == null:
		_fail("Could not instantiate keybinds screen")
		await _finish(null)
		return
	root.add_child(screen)
	await process_frame
	await process_frame

	var toggle := screen.find_child("ExtraPlayersToggle", true, false) as Button
	var section := screen.find_child("ExtraPlayersSection", true, false) as Control
	var content := screen.find_child("KeybindContent", true, false) as Control
	if toggle == null or section == null or content == null:
		_fail("Player 3/4 collapsible controls are incomplete")
		await _finish(screen)
		return
	if section.visible:
		_fail("Player 3/4 keybind section must start collapsed")
	if not toggle.toggle_mode or not toggle.text.contains("P3 / P4"):
		_fail("Player 3/4 expand button is not configured")

	for player_index in range(1, 5):
		var prefix := "p%d_" % player_index
		var drop_button := screen.find_child("Bind_%sdrop_weapon" % prefix, true, false) as Button
		var drop_label := screen.find_child("Label_%sdrop_weapon" % prefix, true, false) as Label
		var target_button := screen.find_child("Bind_%starget_cycle" % prefix, true, false) as Button
		var target_label := screen.find_child("Label_%starget_cycle" % prefix, true, false) as Label
		if drop_button == null or drop_button.text in ["???", "未绑定", "未配置"]:
			_fail("Player %d drop-weapon binding is unavailable" % player_index)
		if drop_label == null or drop_label.text != "丢弃武器":
			_fail("Player %d still exposes the old switch-weapon label" % player_index)
		if target_button == null or target_button.text in ["???", "未绑定", "未配置"]:
			_fail("Player %d target-cycle binding is unavailable" % player_index)
		if target_label == null or target_label.text != "切换目标":
			_fail("Player %d target-cycle label is unavailable" % player_index)

	var collapsed_height := content.custom_minimum_size.y
	toggle.button_pressed = true
	await process_frame
	if not section.visible:
		_fail("Player 3/4 section did not expand")
	if content.custom_minimum_size.y <= collapsed_height:
		_fail("Expanded keybind content did not grow for scrolling")
	if not toggle.text.begins_with("收起"):
		_fail("Expanded Player 3/4 control is missing its state indicator")

	toggle.button_pressed = false
	await process_frame
	if section.visible:
		_fail("Player 3/4 section did not collapse again")
	await _finish(screen)


func _verify_input_actions() -> void:
	for player_index in range(1, 5):
		for suffix in ACTION_SUFFIXES:
			var action := "p%d_%s" % [player_index, suffix]
			if not InputMap.has_action(action):
				_fail("Missing local-player action: %s" % action)
		if InputMap.has_action("p%d_weapon_cycle" % player_index):
			_fail("Obsolete weapon-cycle action remains for Player %d" % player_index)


func _verify_default_keyboard_conflicts() -> void:
	var key_owners := {}
	for player_index in range(1, 5):
		for suffix in ACTION_SUFFIXES:
			var action := "p%d_%s" % [player_index, suffix]
			for event in InputMap.action_get_events(action):
				if not (event is InputEventKey):
					continue
				var key := event as InputEventKey
				var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
				if code == 0:
					continue
				if key_owners.has(code):
					_fail("Default key conflict: %s and %s" % [key_owners[code], action])
				else:
					key_owners[code] = action


func _finish(screen: Node) -> void:
	if screen and is_instance_valid(screen):
		screen.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OK  four complete and conflict-free local input maps")
		print("OK  Player 3/4 keybind controls collapse and expand")
		print("[Local Keybinds Verifier] PASS")
		quit(0)
		return
	print("[Local Keybinds Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
