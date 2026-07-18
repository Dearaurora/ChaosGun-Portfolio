extends CanvasLayer
class_name PartyShooterMatchPresentation

const DEFAULT_INTRO_REVEAL_DURATION := 1.35
const DEFAULT_WINNER_FOCUS_DELAY := 0.78
const DEFAULT_WINNER_CAMERA_DURATION := 0.72
const DEFAULT_HUD_FOCUS_ALPHA := 0.22
const DEFAULT_READY_COLOR := Color("#fff4d6")
const DEFAULT_GO_COLOR := Color("#ffd24a")
const DEFAULT_INK_COLOR := Color("#251a35")

var _arena: Node3D = null
var _camera_director: Node = null
var _characters: Array = []
var _profile: Dictionary = {}
var _intro_started := false
var _result_started := false
var _spawn_burst_count := 0
var _cue_state: StringName = &"idle"
var _cue_root: Control = null
var _cue_label: Label = null
var _cue_lines: Array[ColorRect] = []
var _hud_targets: Array[Control] = []


func _ready() -> void:
	layer = 58
	process_mode = Node.PROCESS_MODE_ALWAYS


func configure(
	arena: Node3D,
	camera_director: Node,
	characters: Array,
	profile: Dictionary = {}
) -> void:
	_arena = arena
	_camera_director = camera_director
	_characters = characters.duplicate()
	_profile = _default_profile()
	for key: Variant in profile:
		_profile[key] = profile[key]


func start_intro() -> void:
	if _intro_started:
		return
	_intro_started = true
	if _camera_director and _camera_director.has_method("begin_arena_reveal"):
		_camera_director.call("begin_arena_reveal", _intro_reveal_duration())
	for index in range(_characters.size()):
		var character := _characters[index] as BaseCharacter
		if character == null or not is_instance_valid(character):
			continue
		var color := _color_for_slot(index)
		character.play_match_spawn_presentation(color)
		_spawn_burst_count += 1
	_build_intro_cue()
	_play_intro_cue()


func present_result(winner: BaseCharacter, winner_color: Color) -> void:
	if _result_started:
		return
	_result_started = true
	_cue_state = &"winner_focus" if winner else &"draw_hold"
	_fade_match_hud()
	if winner and is_instance_valid(winner):
		if _camera_director and _camera_director.has_method("begin_winner_focus"):
			_camera_director.call("begin_winner_focus", winner, _winner_camera_duration())
		winner.play_match_winner_presentation(winner_color)
		await _wait_unscaled(_winner_focus_delay())
	else:
		await _wait_unscaled(float(_profile.get("draw_hold_duration", 0.28)))
	_cue_state = &"result_ready"


func get_debug_state() -> Dictionary:
	return {
		"profile_id": String(_profile.get("profile_id", "party_shooter")),
		"intro_started": _intro_started,
		"result_started": _result_started,
		"spawn_burst_count": _spawn_burst_count,
		"cue_state": String(_cue_state),
		"cue_visible": is_instance_valid(_cue_root) and _cue_root.visible,
		"character_count": _characters.size(),
		"intro_reveal_duration": _intro_reveal_duration(),
		"winner_focus_delay": _winner_focus_delay(),
		"winner_camera_duration": _winner_camera_duration(),
		"hud_focus_alpha": float(_profile.get("hud_focus_alpha", DEFAULT_HUD_FOCUS_ALPHA)),
		"hud_target_count": _hud_targets.size(),
	}


func _default_profile() -> Dictionary:
	return {
		"profile_id": "party_shooter",
		"intro_reveal_duration": DEFAULT_INTRO_REVEAL_DURATION,
		"winner_focus_delay": DEFAULT_WINNER_FOCUS_DELAY,
		"winner_camera_duration": DEFAULT_WINNER_CAMERA_DURATION,
		"draw_hold_duration": 0.28,
		"hud_focus_alpha": DEFAULT_HUD_FOCUS_ALPHA,
		"hud_fade_duration": 0.22,
		"hud_root_names": ["HUDRoot", "GameHUD"],
		"ready_color": DEFAULT_READY_COLOR,
		"go_color": DEFAULT_GO_COLOR,
		"ink_color": DEFAULT_INK_COLOR,
	}


func _intro_reveal_duration() -> float:
	return float(_profile.get("intro_reveal_duration", DEFAULT_INTRO_REVEAL_DURATION))


func _winner_focus_delay() -> float:
	return float(_profile.get("winner_focus_delay", DEFAULT_WINNER_FOCUS_DELAY))


func _winner_camera_duration() -> float:
	return float(_profile.get("winner_camera_duration", DEFAULT_WINNER_CAMERA_DURATION))


func _fade_match_hud() -> void:
	_hud_targets = _find_hud_targets()
	var target_alpha := float(_profile.get("hud_focus_alpha", DEFAULT_HUD_FOCUS_ALPHA))
	var fade_duration := float(_profile.get("hud_fade_duration", 0.22))
	for hud_target in _hud_targets:
		if not is_instance_valid(hud_target):
			continue
		var tween := create_tween()
		tween.tween_property(hud_target, "modulate:a", target_alpha, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _find_hud_targets() -> Array[Control]:
	var result: Array[Control] = []
	if _arena == null or not is_instance_valid(_arena):
		return result
	var root_names := _profile.get("hud_root_names", ["HUDRoot", "GameHUD"]) as Array
	for root_name_value: Variant in root_names:
		var matches: Array[Node] = []
		_collect_named_nodes(_arena, String(root_name_value), matches)
		for match_node in matches:
			if match_node is Control:
				_append_unique_control(result, match_node as Control)
			elif match_node is CanvasLayer:
				for child in match_node.get_children():
					if child is Control:
						_append_unique_control(result, child as Control)
	return result


func _collect_named_nodes(node: Node, target_name: String, output: Array[Node]) -> void:
	if String(node.name) == target_name:
		output.append(node)
	for child in node.get_children():
		_collect_named_nodes(child, target_name, output)


func _append_unique_control(output: Array[Control], item: Control) -> void:
	if item not in output:
		output.append(item)


func _build_intro_cue() -> void:
	if is_instance_valid(_cue_root):
		_cue_root.queue_free()
	_cue_root = Control.new()
	_cue_root.name = "MatchIntroCue"
	_cue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cue_root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_cue_root)

	var center := Control.new()
	center.name = "CenterBeat"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchor(SIDE_LEFT, 0.5)
	center.set_anchor(SIDE_TOP, 0.5)
	center.set_anchor(SIDE_RIGHT, 0.5)
	center.set_anchor(SIDE_BOTTOM, 0.5)
	center.offset_left = -260.0
	center.offset_top = -48.0
	center.offset_right = 260.0
	center.offset_bottom = 48.0
	_cue_root.add_child(center)

	var ready_color := _profile.get("ready_color", DEFAULT_READY_COLOR) as Color
	var ink_color := _profile.get("ink_color", DEFAULT_INK_COLOR) as Color
	for x_range in [Vector2(0.0, 162.0), Vector2(358.0, 520.0)]:
		var shadow_line := ColorRect.new()
		shadow_line.color = Color(ink_color.r, ink_color.g, ink_color.b, 0.72)
		shadow_line.position = Vector2(x_range.x, 48.0)
		shadow_line.size = Vector2(x_range.y - x_range.x, 5.0)
		shadow_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(shadow_line)
		var line := ColorRect.new()
		line.color = ready_color
		line.position = Vector2(x_range.x, 46.0)
		line.size = Vector2(x_range.y - x_range.x, 3.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(line)
		_cue_lines.append(line)

	_cue_label = Label.new()
	_cue_label.name = "CueWord"
	_cue_label.position = Vector2(160.0, 13.0)
	_cue_label.size = Vector2(200.0, 58.0)
	_cue_label.pivot_offset = _cue_label.size * 0.5
	_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cue_label.add_theme_font_size_override("font_size", 38)
	_cue_label.add_theme_constant_override("outline_size", 8)
	_cue_label.add_theme_color_override("font_outline_color", Color(ink_color.r, ink_color.g, ink_color.b, 0.92))
	_cue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_cue_label)

	var player_colors := _player_colors()
	var active_count := mini(_characters.size(), player_colors.size())
	var pip_width := 34.0
	var pip_gap := 8.0
	var total_width := float(active_count) * pip_width + float(maxi(active_count - 1, 0)) * pip_gap
	for index in range(active_count):
		var pip := ColorRect.new()
		pip.name = "PlayerColor_%d" % (index + 1)
		pip.color = _color_for_slot(index)
		pip.position = Vector2((520.0 - total_width) * 0.5 + float(index) * (pip_width + pip_gap), 82.0)
		pip.size = Vector2(pip_width, 4.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(pip)


func _play_intro_cue() -> void:
	var ready_color := _profile.get("ready_color", DEFAULT_READY_COLOR) as Color
	var go_color := _profile.get("go_color", DEFAULT_GO_COLOR) as Color
	_cue_state = &"ready"
	_set_cue_word("READY", ready_color)
	await _wait_unscaled(0.08)
	if not is_instance_valid(_cue_root):
		return
	var ready_in := create_tween().set_parallel(true)
	ready_in.tween_property(_cue_root, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ready_in.tween_property(_cue_label, "scale", Vector2.ONE, 0.18).from(Vector2(0.86, 0.86)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await ready_in.finished
	await _wait_unscaled(0.38)
	if not is_instance_valid(_cue_root):
		return
	_cue_state = &"go"
	_set_cue_word("GO!", go_color)
	var go_pulse := create_tween().set_parallel(true)
	go_pulse.tween_property(_cue_label, "scale", Vector2.ONE, 0.20).from(Vector2(1.24, 1.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for line in _cue_lines:
		if is_instance_valid(line):
			go_pulse.tween_property(line, "color", go_color, 0.10)
	await go_pulse.finished
	await _wait_unscaled(0.30)
	if not is_instance_valid(_cue_root):
		return
	var cue_out := create_tween().set_parallel(true)
	cue_out.tween_property(_cue_root, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	cue_out.tween_property(_cue_label, "scale", Vector2(1.10, 1.10), 0.20)
	await cue_out.finished
	if is_instance_valid(_cue_root):
		_cue_root.queue_free()
	_cue_root = null
	_cue_label = null
	_cue_lines.clear()
	_cue_state = &"complete"


func _set_cue_word(word: String, color: Color) -> void:
	if not is_instance_valid(_cue_label):
		return
	_cue_label.text = word
	_cue_label.add_theme_color_override("font_color", color)


func _color_for_slot(index: int) -> Color:
	var player_colors := _player_colors()
	if index >= 0 and index < player_colors.size():
		return player_colors[index] as Color
	return Color.WHITE


func _player_colors() -> Array:
	var match_config := get_node_or_null("/root/MatchConfig")
	if match_config:
		return match_config.get("PLAYER_COLORS") as Array
	return []


func _wait_unscaled(duration: float) -> Signal:
	return get_tree().create_timer(duration, true, false, true).timeout
