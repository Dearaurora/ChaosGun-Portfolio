extends CanvasLayer
class_name VictoryScreen

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const VICTORY_OVERLAY_SCENE = preload("res://scenes/ui/components/victory_overlay.tscn")

var _root: Control = null


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_victory(winner_name: String, winner_color: Color, characters: Array = []) -> void:
	visible = true
	get_tree().paused = true
	_build_ui(winner_name, winner_color, characters)


func _build_ui(winner_name: String, winner_color: Color, characters: Array) -> void:
	if _root and is_instance_valid(_root):
		_root.free()
	_root = VICTORY_OVERLAY_SCENE.instantiate()
	add_child(_root)
	var result_panel := _root.get_node("Center/ResultPanel") as PanelContainer
	var winner_label := _root.get_node("Center/ResultPanel/Content/WinnerName") as Label
	var accent_line := _root.get_node("Center/ResultPanel/Content/WinnerAccent") as ColorRect
	var table := _root.get_node("Center/ResultPanel/Content/ResultTable") as GridContainer
	var rematch_button := _root.get_node("Center/ResultPanel/Content/Actions/RematchButton") as Button
	var menu_button := _root.get_node("Center/ResultPanel/Content/Actions/MainMenuButton") as Button

	var is_draw := winner_name.to_upper() == "DRAW"
	winner_label.text = "平局  /  DRAW" if is_draw else "%s  WIN" % winner_name
	winner_label.add_theme_color_override("font_color", winner_color if not is_draw else TOY_UI.CREAM)
	accent_line.color = winner_color if not is_draw else TOY_UI.GOLD
	var result_style := TOY_UI.panel_style(winner_color if not is_draw else TOY_UI.GOLD, 0.98, 18, 2, 12)
	result_style.content_margin_left = 36.0
	result_style.content_margin_top = 26.0
	result_style.content_margin_right = 36.0
	result_style.content_margin_bottom = 28.0
	result_panel.add_theme_stylebox_override("panel", result_style)
	_populate_result_table(table, characters)
	TOY_UI.apply_button(rematch_button, TOY_UI.GOLD, true, 18)
	TOY_UI.apply_button(menu_button, TOY_UI.CORAL, false, 16)
	rematch_button.pressed.connect(func(): MatchConfig.restart_current_match(get_tree()))
	menu_button.pressed.connect(_return_to_menu)
	rematch_button.grab_focus()
	_root.modulate.a = 0.0
	result_panel.scale = Vector2(0.96, 0.96)
	result_panel.pivot_offset = result_panel.size * 0.5
	var tween := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_root, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(result_panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _populate_result_table(table: GridContainer, characters: Array) -> void:
	for child in table.get_children():
		child.free()
	for header in ["玩家", "KO", "FALL", "状态"]:
		table.add_child(_make_cell(header, TOY_UI.CREAM_DIM, true))
	var valid_characters: Array = []
	for character in characters:
		if is_instance_valid(character):
			valid_characters.append(character)
	if valid_characters.is_empty():
		table.add_child(_make_cell("暂无比赛数据", TOY_UI.CREAM_DIM))
		table.add_child(_make_cell("—", TOY_UI.CREAM_DIM))
		table.add_child(_make_cell("—", TOY_UI.CREAM_DIM))
		table.add_child(_make_cell("—", TOY_UI.CREAM_DIM))
		return
	for index in range(valid_characters.size()):
		var character = valid_characters[index]
		var color := TOY_UI.player_color(index)
		table.add_child(_make_cell(String(character.name).left(18), color))
		table.add_child(_make_cell(str(character.kills), TOY_UI.CREAM))
		table.add_child(_make_cell(str(character.deaths), TOY_UI.CREAM))
		table.add_child(_make_cell("出局" if character.is_game_over else "存活", TOY_UI.CREAM_DIM))


func _make_cell(text: String, color: Color, header := false) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(100, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13 if header else 15)
	label.add_theme_color_override("font_color", color)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		var active_viewport := get_viewport()
		MatchConfig.restart_current_match(get_tree())
		if active_viewport and is_instance_valid(active_viewport):
			active_viewport.set_input_as_handled()


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
