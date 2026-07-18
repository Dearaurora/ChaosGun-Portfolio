extends CanvasLayer
class_name VictoryScreen

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

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
		_root.queue_free()

	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := TOY_UI.ui_scale(viewport_size)
	_root = Control.new()
	_root.name = "VictoryRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var wash := ColorRect.new()
	wash.name = "VictoryWash"
	wash.color = TOY_UI.make_screen_wash(0.38)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(wash)

	var accent_line := ColorRect.new()
	accent_line.name = "WinnerAccent"
	accent_line.color = winner_color
	accent_line.position = Vector2(viewport_size.x * 0.5 - 76.0 * ui_scale, viewport_size.y * 0.16)
	accent_line.size = Vector2(152.0 * ui_scale, 4.0 * ui_scale)
	_root.add_child(accent_line)

	var kicker := Label.new()
	kicker.name = "WinnerKicker"
	kicker.text = "MATCH WINNER"
	kicker.position = Vector2(0.0, viewport_size.y * 0.18)
	kicker.size = Vector2(viewport_size.x, 24.0 * ui_scale)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(kicker, roundi(14.0 * ui_scale), TOY_UI.CREAM_DIM)
	_root.add_child(kicker)

	var winner_label := Label.new()
	winner_label.name = "WinnerName"
	winner_label.text = "%s WINS!" % winner_name
	winner_label.position = Vector2(0.0, viewport_size.y * 0.21)
	winner_label.size = Vector2(viewport_size.x, 58.0 * ui_scale)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(winner_label, roundi(36.0 * ui_scale), winner_color.lightened(0.12), roundi(5.0 * ui_scale))
	_root.add_child(winner_label)

	var valid_characters: Array = []
	for character in characters:
		if is_instance_valid(character):
			valid_characters.append(character)

	var table_width := 390.0 * ui_scale
	var row_height := 27.0 * ui_scale
	var table_height := (44.0 + maxf(valid_characters.size(), 1) * 27.0) * ui_scale
	var table := Panel.new()
	table.name = "ResultTable"
	table.position = Vector2((viewport_size.x - table_width) * 0.5, viewport_size.y * 0.36)
	table.size = Vector2(table_width, table_height)
	table.add_theme_stylebox_override("panel", TOY_UI.panel_style(winner_color, 0.56, TOY_UI.PANEL_RADIUS, 1, 0))
	_root.add_child(table)

	var header := Label.new()
	header.text = "PLAYER                         KO      FALL"
	header.position = Vector2(16.0, 8.0) * ui_scale
	header.size = Vector2(table_width - 32.0 * ui_scale, 22.0 * ui_scale)
	TOY_UI.apply_label(header, roundi(10.0 * ui_scale), TOY_UI.CREAM_DIM)
	table.add_child(header)

	if valid_characters.is_empty():
		var no_stats := Label.new()
		no_stats.text = "NO MATCH DATA"
		no_stats.position = Vector2(16.0, 35.0) * ui_scale
		no_stats.size = Vector2(table_width - 32.0 * ui_scale, row_height)
		no_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		TOY_UI.apply_label(no_stats, roundi(12.0 * ui_scale), TOY_UI.CREAM_DIM)
		table.add_child(no_stats)
	else:
		for index in range(valid_characters.size()):
			var character = valid_characters[index]
			var row := Label.new()
			var character_name := String(character.name).left(14)
			row.text = "%-18s      %2d       %2d" % [character_name, character.kills, character.deaths]
			row.position = Vector2(16.0 * ui_scale, (35.0 * ui_scale) + row_height * index)
			row.size = Vector2(table_width - 32.0 * ui_scale, row_height)
			TOY_UI.apply_label(row, roundi(13.0 * ui_scale), TOY_UI.CREAM if not character.is_game_over else TOY_UI.CREAM_DIM)
			table.add_child(row)

	var button_width := 220.0 * ui_scale
	var button_height := 42.0 * ui_scale
	var button_x := (viewport_size.x - button_width) * 0.5
	var button_y := minf(table.position.y + table.size.y + 22.0 * ui_scale, viewport_size.y - 116.0 * ui_scale)

	var restart_button := _create_btn("REMATCH", TOY_UI.GOLD, button_x, button_y, button_width, button_height, true)
	restart_button.pressed.connect(func(): MatchConfig.restart_current_match(get_tree()))
	_root.add_child(restart_button)

	var menu_button := _create_btn("MAIN MENU", TOY_UI.CORAL, button_x, button_y + 50.0 * ui_scale, button_width, button_height, false)
	menu_button.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	_root.add_child(menu_button)


func _create_btn(text: String, color: Color, x: float, y: float, width: float, height: float, filled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(width, height)
	TOY_UI.apply_button(button, color, filled, roundi(15.0 * TOY_UI.ui_scale(get_viewport().get_visible_rect().size)))
	return button
