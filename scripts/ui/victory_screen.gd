extends CanvasLayer
class_name VictoryScreen

const COL_PANEL := Color("#1d1d37")
const COL_PRIMARY := Color("#cafd00")
const COL_HEART := Color("#ff6e81")
const COL_TEXT := Color("#e5e3ff")

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_victory(winner_name: String, winner_color: Color, characters: Array = []) -> void:
	visible = true
	get_tree().paused = true
	_build_ui(winner_name, winner_color, characters)

func _build_ui(winner_name: String, winner_color: Color, characters: Array) -> void:
	var vp = get_viewport().get_visible_rect().size
	var has_stats = characters.size() > 0
	var card_h := 280.0 + (characters.size() * 28.0) if has_stats else 280.0

	var mask = ColorRect.new()
	mask.color = Color(0, 0, 0, 0.7)
	mask.size = vp
	add_child(mask)

	var card_w := 420.0
	var card = Panel.new()
	card.position = Vector2((vp.x - card_w) / 2.0, (vp.y - card_h) / 2.0)
	card.size = Vector2(card_w, card_h)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.95)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(winner_color.r, winner_color.g, winner_color.b, 0.5)
	style.shadow_color = Color(winner_color.r, winner_color.g, winner_color.b, 0.15)
	style.shadow_size = 24
	card.add_theme_stylebox_override("panel", style)
	add_child(card)

	var title = Label.new()
	title.text = "GAME SET"
	title.position = Vector2(0, 16)
	title.size = Vector2(card_w, 36)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)

	var winner_label = Label.new()
	winner_label.text = winner_name + "  WINS!"
	winner_label.position = Vector2(0, 56)
	winner_label.size = Vector2(card_w, 30)
	winner_label.add_theme_font_size_override("font_size", 22)
	winner_label.add_theme_color_override("font_color", winner_color)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(winner_label)

	var stats_y := 100.0
	if has_stats:
		var header = Label.new()
		header.text = "                    KO    FALL"
		header.position = Vector2(30, stats_y)
		header.size = Vector2(card_w - 60, 22)
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 0.5))
		card.add_child(header)
		stats_y += 26.0

		for c in characters:
			if not is_instance_valid(c):
				continue
			var row = Label.new()
			var cname: String = c.name if c.name.length() <= 12 else c.name.left(12)
			row.text = "%-16s %3d    %3d" % [cname, c.kills, c.deaths]
			row.position = Vector2(30, stats_y)
			row.size = Vector2(card_w - 60, 24)
			row.add_theme_font_size_override("font_size", 14)
			row.add_theme_color_override("font_color", COL_TEXT if not c.is_game_over else Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 0.4))
			card.add_child(row)
			stats_y += 26.0

	var btn_w := 240.0
	var btn_h := 44.0
	var btn_x := (card_w - btn_w) / 2.0
	var btn_y := stats_y + 16.0

	var restart_btn = _create_btn("REMATCH", COL_PRIMARY, btn_x, btn_y, btn_w, btn_h)
	restart_btn.pressed.connect(func():
		MatchConfig.restart_current_match(get_tree())
	)
	card.add_child(restart_btn)

	var menu_btn = _create_btn("MAIN MENU", COL_HEART, btn_x, btn_y + 54, btn_w, btn_h)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	card.add_child(menu_btn)

func _create_btn(text: String, color: Color, x: float, y: float, w: float, h: float) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.9)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(color.r, color.g, color.b, 0.3)
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color(color.r, color.g, color.b, 0.15)
	hover.border_color = color
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn
