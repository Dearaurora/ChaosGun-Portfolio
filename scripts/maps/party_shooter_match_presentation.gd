extends CanvasLayer
class_name PartyShooterMatchPresentation

signal intro_completed

const MATCH_EVENT_BANNER_SCENE = preload("res://scenes/ui/components/match_event_banner.tscn")
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
var _cue_banner = null
var _cue_label: Label = null
var _cue_lines: Array[ColorRect] = []
var _hud_targets: Array[Control] = []
var _intro_tween: Tween = null


func _ready() -> void:
	layer = 58
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null


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
		if _camera_director and _camera_director.has_method("settle_winner_focus"):
			_camera_director.call("settle_winner_focus")
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
	for grouped_node in get_tree().get_nodes_in_group("party_shooter_match_hud"):
		if grouped_node is Control and (_arena == grouped_node or _arena.is_ancestor_of(grouped_node)):
			var grouped_control := grouped_node as Control
			_append_unique_control(result, grouped_control)
			for child in grouped_control.get_children():
				if child is Control:
					_append_unique_control(result, child as Control)
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
	_cue_lines.clear()
	var ready_color := _profile.get("ready_color", DEFAULT_READY_COLOR) as Color
	var active_colors: Array = []
	for index in range(mini(_characters.size(), _player_colors().size())):
		active_colors.append(_color_for_slot(index))
	_cue_banner = MATCH_EVENT_BANNER_SCENE.instantiate()
	_cue_banner.name = "MatchIntroCue"
	add_child(_cue_banner)
	_cue_banner.call("set_placement", 0)
	_cue_banner.call("set_event", "READY", "", "", ready_color, active_colors, false)
	_cue_root = _cue_banner
	_cue_label = _cue_banner.call("get_title_label") as Label
	_cue_label.pivot_offset = _cue_label.size * 0.5
	_cue_lines = _cue_banner.call("get_accent_lines") as Array[ColorRect]
	_cue_root.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _play_intro_cue() -> void:
	var ready_color := _profile.get("ready_color", DEFAULT_READY_COLOR) as Color
	var go_color := _profile.get("go_color", DEFAULT_GO_COLOR) as Color
	_cue_state = &"ready"
	_set_cue_word("READY", ready_color)
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_interval(0.08)
	_intro_tween.tween_property(_cue_root, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.parallel().tween_property(_cue_label, "scale", Vector2.ONE, 0.18).from(Vector2(0.86, 0.86)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_interval(0.38)
	_intro_tween.tween_callback(_show_go_cue.bind(go_color))
	_intro_tween.tween_property(_cue_label, "scale", Vector2.ONE, 0.20).from(Vector2(1.24, 1.24)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for line in _cue_lines:
		if is_instance_valid(line):
			_intro_tween.parallel().tween_property(line, "color", go_color, 0.10)
	_intro_tween.tween_interval(0.30)
	_intro_tween.tween_property(_cue_root, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_intro_tween.parallel().tween_property(_cue_label, "scale", Vector2(1.10, 1.10), 0.20)
	_intro_tween.tween_callback(_complete_intro_cue)


func _show_go_cue(go_color: Color) -> void:
	if not is_instance_valid(_cue_root):
		return
	_cue_state = &"go"
	_set_cue_word("GO!", go_color)


func _complete_intro_cue() -> void:
	if is_instance_valid(_cue_root):
		_cue_root.queue_free()
	_cue_root = null
	_cue_banner = null
	_cue_label = null
	_cue_lines.clear()
	_cue_state = &"complete"
	_intro_tween = null
	intro_completed.emit()


func _set_cue_word(word: String, color: Color) -> void:
	if not is_instance_valid(_cue_label):
		return
	if is_instance_valid(_cue_banner):
		_cue_banner.call("set_title", word, color, false)
	else:
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
