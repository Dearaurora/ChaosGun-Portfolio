extends CanvasLayer
## 主菜单 —— NEON KINETIC 风格
## 两个入口：人 vs AI（快速测试） / 本地对战（进入选角）

const COL_SURFACE := Color("#0c0c1f")
const COL_PANEL := Color("#1d1d37")
const COL_PRIMARY := Color("#cafd00")
const COL_SECONDARY := Color("#ff7441")
const COL_TEXT := Color("#e5e3ff")
const COL_DARK := Color("#0a0a18")

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	# 全屏背景
	var bg = ColorRect.new()
	bg.color = COL_SURFACE
	bg.size = vp
	add_child(bg)

	# 装饰圆环
	var ring = Panel.new()
	var ring_size := 500.0
	ring.position = Vector2((vp.x - ring_size) / 2.0, (vp.y - ring_size) / 2.0 - 30)
	ring.size = Vector2(ring_size, ring_size)
	var ring_style = StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_width_left = 3
	ring_style.border_width_right = 3
	ring_style.border_width_top = 3
	ring_style.border_width_bottom = 3
	ring_style.border_color = Color(COL_PRIMARY.r, COL_PRIMARY.g, COL_PRIMARY.b, 0.08)
	ring_style.corner_radius_top_left = 250
	ring_style.corner_radius_top_right = 250
	ring_style.corner_radius_bottom_left = 250
	ring_style.corner_radius_bottom_right = 250
	ring.add_theme_stylebox_override("panel", ring_style)
	add_child(ring)

	# 标题
	var title = Label.new()
	title.text = "CHAOS GUN"
	title.position = Vector2(0, vp.y * 0.15)
	title.size = Vector2(vp.x, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	add_child(title)

	# 副标题
	var subtitle = Label.new()
	subtitle.text = "KNOCKBACK  SHOOTER"
	subtitle.position = Vector2(0, vp.y * 0.15 + 75)
	subtitle.size = Vector2(vp.x, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", COL_TEXT)
	add_child(subtitle)

	# 按钮容器
	var btn_y: float = vp.y * 0.48
	var btn_w := 320.0
	var btn_h := 70.0
	var btn_gap := 24.0
	var btn_x: float = (vp.x - btn_w) / 2.0

	# 人 vs AI 按钮
	var btn_ai = _create_button("⚔  人 vs AI", COL_PRIMARY, btn_x, btn_y, btn_w, btn_h)
	btn_ai.pressed.connect(_on_vs_ai)
	add_child(btn_ai)

	# 本地对战按钮
	var btn_local = _create_button("🎮  本地对战", COL_SECONDARY, btn_x, btn_y + btn_h + btn_gap, btn_w, btn_h)
	btn_local.pressed.connect(_on_local_battle)
	add_child(btn_local)

	# 键位设置按钮
	var btn_keys = _create_button("⌨  键位设置", COL_TEXT, btn_x, btn_y + (btn_h + btn_gap) * 2, btn_w, btn_h)
	btn_keys.pressed.connect(_on_keybinds)
	add_child(btn_keys)

	# 底部提示
	var hint = Label.new()
	hint.text = "v0.1 DEMO"
	hint.position = Vector2(0, vp.y - 50)
	hint.size = Vector2(vp.x, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 0.3))
	add_child(hint)

func _create_button(text: String, accent: Color, x: float, y: float, w: float, h: float) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)

	# 正常状态
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.85)
	normal.corner_radius_top_left = 16
	normal.corner_radius_top_right = 16
	normal.corner_radius_bottom_left = 16
	normal.corner_radius_bottom_right = 16
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.1)
	normal.shadow_size = 8
	btn.add_theme_stylebox_override("normal", normal)

	# 悬停
	var hover = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	hover.border_color = accent
	hover.shadow_size = 16
	btn.add_theme_stylebox_override("hover", hover)

	# 按下
	var pressed = normal.duplicate()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.25)
	pressed.border_color = accent
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	return btn

# ------------------------------------------------------------------
func _on_vs_ai() -> void:
	get_tree().change_scene_to_file("res://scenes/maps/demo_arena.tscn")

func _on_local_battle() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")

func _on_keybinds() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/keybinds_screen.tscn")
