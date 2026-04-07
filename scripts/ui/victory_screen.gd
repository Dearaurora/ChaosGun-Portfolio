extends CanvasLayer
## 结算画面 —— 某角色获胜时弹出

const COL_SURFACE := Color("#0c0c1f")
const COL_PANEL := Color("#1d1d37")
const COL_PRIMARY := Color("#cafd00")
const COL_SECONDARY := Color("#ff7441")
const COL_HEART := Color("#ff6e81")
const COL_TEXT := Color("#e5e3ff")

var _overlay: Control

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

## 显示结算画面
func show_victory(winner_name: String, winner_color: Color) -> void:
	visible = true
	get_tree().paused = true
	_build_ui(winner_name, winner_color)

func _build_ui(winner_name: String, winner_color: Color) -> void:
	var vp = get_viewport().get_visible_rect().size

	# 蒙版
	var mask = ColorRect.new()
	mask.color = Color(0, 0, 0, 0.7)
	mask.size = vp
	add_child(mask)

	# 中央卡片
	var card_w := 400.0
	var card_h := 320.0
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

	# "GAME SET" 标题
	var title = Label.new()
	title.text = "GAME SET"
	title.position = Vector2(0, 20)
	title.size = Vector2(card_w, 40)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)

	# 胜者名
	var winner_label = Label.new()
	winner_label.text = winner_name
	winner_label.position = Vector2(0, 70)
	winner_label.size = Vector2(card_w, 36)
	winner_label.add_theme_font_size_override("font_size", 28)
	winner_label.add_theme_color_override("font_color", winner_color)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(winner_label)

	# "WINS!" 标签
	var wins_label = Label.new()
	wins_label.text = "WINS!"
	wins_label.position = Vector2(0, 108)
	wins_label.size = Vector2(card_w, 24)
	wins_label.add_theme_font_size_override("font_size", 18)
	wins_label.add_theme_color_override("font_color", COL_TEXT)
	wins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(wins_label)

	# 按钮区域
	var btn_w := 240.0
	var btn_h := 48.0
	var btn_x := (card_w - btn_w) / 2.0

	var restart_btn = _create_btn("↻  REMATCH", COL_PRIMARY, btn_x, 160, btn_w, btn_h)
	restart_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	card.add_child(restart_btn)

	var menu_btn = _create_btn("⌂  MAIN MENU", COL_HEART, btn_x, 220, btn_w, btn_h)
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
