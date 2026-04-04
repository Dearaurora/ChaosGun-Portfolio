extends CanvasLayer
## 暂停菜单 —— ESC 触发，覆盖游戏画面
## 适用于所有对战场景（demo_arena / battle_arena）
##
## 导航逻辑：
##   Resume  → 关闭暂停，继续游戏
##   Restart → 重新加载当前场景
##   Main Menu → 返回主菜单

const COL_SURFACE := Color("#0c0c1f")
const COL_PANEL := Color("#1d1d37")
const COL_PRIMARY := Color("#cafd00")
const COL_SECONDARY := Color("#ff7441")
const COL_HEART := Color("#ff6e81")
const COL_TEXT := Color("#e5e3ff")

var _is_paused := false
var _overlay: Control

func _ready() -> void:
	# 暂停菜单在最高层
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	_overlay = Control.new()
	_overlay.size = vp
	_overlay.visible = false
	add_child(_overlay)

	# 半透明蒙版
	var mask = ColorRect.new()
	mask.color = Color(0, 0, 0, 0.6)
	mask.size = vp
	_overlay.add_child(mask)

	# 中央卡片
	var card_w := 300.0
	var card_h := 280.0
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
	style.border_color = Color(COL_PRIMARY.r, COL_PRIMARY.g, COL_PRIMARY.b, 0.3)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 20
	card.add_theme_stylebox_override("panel", style)
	_overlay.add_child(card)

	# 标题
	var title = Label.new()
	title.text = "PAUSED"
	title.position = Vector2(0, 16)
	title.size = Vector2(card_w, 40)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)

	# 按钮
	var btn_w := 220.0
	var btn_h := 48.0
	var btn_x := (card_w - btn_w) / 2.0
	var btn_start_y := 72.0
	var btn_gap := 12.0

	var resume_btn = _create_btn("▶  RESUME", COL_PRIMARY, btn_x, btn_start_y, btn_w, btn_h)
	resume_btn.pressed.connect(_on_resume)
	card.add_child(resume_btn)

	var restart_btn = _create_btn("↻  RESTART", COL_SECONDARY, btn_x, btn_start_y + (btn_h + btn_gap), btn_w, btn_h)
	restart_btn.pressed.connect(_on_restart)
	card.add_child(restart_btn)

	var menu_btn = _create_btn("⌂  MAIN MENU", COL_HEART, btn_x, btn_start_y + (btn_h + btn_gap) * 2, btn_w, btn_h)
	menu_btn.pressed.connect(_on_main_menu)
	card.add_child(menu_btn)

	# ESC 提示
	var hint = Label.new()
	hint.text = "ESC to resume"
	hint.position = Vector2(0, card_h - 32)
	hint.size = Vector2(card_w, 20)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 0.4))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	_is_paused = not _is_paused
	_overlay.visible = _is_paused
	get_tree().paused = _is_paused

func _on_resume() -> void:
	_toggle_pause()

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ------------------------------------------------------------------
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

	var pressed = normal.duplicate()
	pressed.bg_color = Color(color.r, color.g, color.b, 0.25)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn
