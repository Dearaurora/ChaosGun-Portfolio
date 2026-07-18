extends CanvasLayer
## 选角界面 —— 参考 Gun Mayhem 风格
## 4 个槽位，可添加 HUMAN / AI，底部 Back + START

const COL_SURFACE := Color("#0c0c1f")
const COL_PANEL := Color("#1d1d37")
const COL_PANEL_HIGH := Color("#23233f")
const COL_PRIMARY := Color("#cafd00")
const COL_SECONDARY := Color("#ff7441")
const COL_HEART := Color("#ff6e81")
const COL_TEXT := Color("#e5e3ff")
const COL_DIM := Color("#74738b")

const MAX_SLOTS := 4
const PLAYER_COLORS := [
	Color(0.2, 0.45, 1.0),    # 蓝
	Color(1.0, 0.4, 0.25),    # 橙
	Color(0.3, 0.85, 0.4),    # 绿
	Color(0.9, 0.3, 0.8),     # 紫
]

# 每个槽位的状态
var _slots: Array = []
var _map_label: Label = null

func _ready() -> void:
	MatchConfig.configure_local_match()
	# 初始化时从 MatchConfig 读取
	_slots = MatchConfig.slots.duplicate()
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	# 全屏背景
	var bg = ColorRect.new()
	bg.color = COL_SURFACE
	bg.size = vp
	add_child(bg)

	# 标题栏
	var header = Panel.new()
	header.position = Vector2(0, 0)
	header.size = Vector2(vp.x, 64)
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = COL_PANEL
	h_style.border_width_bottom = 2
	h_style.border_color = Color(COL_PRIMARY.r, COL_PRIMARY.g, COL_PRIMARY.b, 0.3)
	header.add_theme_stylebox_override("panel", h_style)
	add_child(header)

	var title = Label.new()
	title.text = "CUSTOM GAME"
	title.position = Vector2(32, 0)
	title.size = Vector2(400, 64)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	# 4 个槽位
	var slot_w: float = (vp.x - 32 * 5) / 4.0
	var slot_h: float = vp.y - 64 - 80 - 32
	var slot_y := 64 + 16.0

	for i in range(MAX_SLOTS):
		var slot_x = 32 + i * (slot_w + 32)
		var slot = _build_slot(i, slot_x, slot_y, slot_w, slot_h)
		add_child(slot)

	# 底栏
	var bottom_y = vp.y - 72.0

	# Back 按钮
	var back_btn = _create_btn("← BACK", COL_HEART, 32, bottom_y, 140, 56)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	# 地图选择器（居中）
	var map_center_x: float = vp.x / 2.0
	var map_btn_w := 40.0
	var has_multiple_maps := MatchConfig.MAPS.size() > 1

	var map_prev = _create_btn("◀", COL_TEXT, map_center_x - 140, bottom_y + 8, map_btn_w, map_btn_w)
	map_prev.pressed.connect(_on_map_prev)
	map_prev.visible = has_multiple_maps
	map_prev.disabled = not has_multiple_maps
	add_child(map_prev)

	_map_label = Label.new()
	_map_label.text = MatchConfig.get_selected_map_name()
	_map_label.position = Vector2(map_center_x - 90, bottom_y)
	_map_label.size = Vector2(180, 56)
	_map_label.add_theme_font_size_override("font_size", 16)
	_map_label.add_theme_color_override("font_color", COL_PRIMARY)
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_map_label)

	var map_next = _create_btn("▶", COL_TEXT, map_center_x + 100, bottom_y + 8, map_btn_w, map_btn_w)
	map_next.pressed.connect(_on_map_next)
	map_next.visible = has_multiple_maps
	map_next.disabled = not has_multiple_maps
	add_child(map_next)

	# START 按钮
	var start_btn = _create_btn("START!", COL_PRIMARY, vp.x - 200 - 32, bottom_y, 200, 56)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

# ------------------------------------------------------------------
#  构建单个槽位
# ------------------------------------------------------------------
func _build_slot(index: int, x: float, y: float, w: float, h: float) -> Control:
	var root = Control.new()
	root.position = Vector2(x, y)
	root.size = Vector2(w, h)

	# 背景
	var bg = Panel.new()
	bg.size = Vector2(w, h)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COL_PANEL_HIGH.r, COL_PANEL_HIGH.g, COL_PANEL_HIGH.b, 0.6)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	var accent = PLAYER_COLORS[index] if _slots[index] != MatchConfig.SlotType.EMPTY else COL_DIM
	style.border_color = Color(accent.r, accent.g, accent.b, 0.4)
	bg.add_theme_stylebox_override("panel", style)
	root.add_child(bg)

	if _slots[index] == MatchConfig.SlotType.EMPTY:
		_build_empty_slot(root, index, w, h)
	else:
		_build_filled_slot(root, index, w, h)

	return root

func _build_empty_slot(root: Control, index: int, w: float, h: float) -> void:
	# SLOT EMPTY 标题
	var empty_label = Label.new()
	empty_label.text = "SLOT EMPTY"
	empty_label.position = Vector2(0, 24)
	empty_label.size = Vector2(w, 30)
	empty_label.add_theme_font_size_override("font_size", 14)
	empty_label.add_theme_color_override("font_color", COL_HEART)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(empty_label)

	var center_y = h * 0.3
	var btn_w = w * 0.7
	var btn_h = 50.0
	var btn_x = (w - btn_w) / 2.0

	# HUMAN 按钮
	var human_btn = _create_btn("HUMAN", COL_TEXT, btn_x, center_y, btn_w, btn_h)
	human_btn.pressed.connect(_on_set_slot.bind(index, MatchConfig.SlotType.HUMAN))
	root.add_child(human_btn)

	# AI 按钮
	var ai_btn = _create_btn("AI", COL_TEXT, btn_x, center_y + btn_h + 16, btn_w, btn_h)
	ai_btn.pressed.connect(_on_set_slot.bind(index, MatchConfig.SlotType.AI))
	root.add_child(ai_btn)

func _build_filled_slot(root: Control, index: int, w: float, h: float) -> void:
	var is_human = _slots[index] == MatchConfig.SlotType.HUMAN
	var accent = PLAYER_COLORS[index]

	# 清除按钮（右上角 X）
	var clear_btn = _create_btn("✕", COL_HEART, w - 48, 8, 40, 32)
	clear_btn.pressed.connect(_on_set_slot.bind(index, MatchConfig.SlotType.EMPTY))
	root.add_child(clear_btn)

	# 类型标签
	var type_label = Label.new()
	type_label.text = "HUMAN" if is_human else "AI"
	type_label.position = Vector2(16, 16)
	type_label.size = Vector2(w - 72, 24)
	type_label.add_theme_font_size_override("font_size", 13)
	type_label.add_theme_color_override("font_color", accent)
	root.add_child(type_label)

	# 名字
	var name_label = Label.new()
	name_label.text = ("Player %d" % (index + 1)) if is_human else ("AI Bot %d" % (index + 1))
	name_label.position = Vector2(16, 42)
	name_label.size = Vector2(w - 32, 30)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COL_TEXT)
	root.add_child(name_label)

	# 角色预览（彩色大圆）
	var preview_size := minf(w * 0.4, 100.0)
	var preview = Panel.new()
	preview.position = Vector2((w - preview_size) / 2.0, h * 0.35)
	preview.size = Vector2(preview_size, preview_size)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = accent
	var radius = int(preview_size / 2.0)
	p_style.corner_radius_top_left = radius
	p_style.corner_radius_top_right = radius
	p_style.corner_radius_bottom_left = radius
	p_style.corner_radius_bottom_right = radius
	p_style.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	p_style.shadow_size = 12
	preview.add_theme_stylebox_override("panel", p_style)
	root.add_child(preview)

	# 角色文字
	var icon = Label.new()
	icon.text = "P%d" % (index + 1) if is_human else "AI"
	icon.position = preview.position
	icon.size = preview.size
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 24)
	icon.add_theme_color_override("font_color", COL_SURFACE)
	root.add_child(icon)

	# 颜色指示条
	var color_bar = ColorRect.new()
	color_bar.color = accent
	color_bar.position = Vector2(16, h - 50)
	color_bar.size = Vector2(w - 32, 4)
	root.add_child(color_bar)

# ------------------------------------------------------------------
#  通用按钮
# ------------------------------------------------------------------
func _create_btn(text: String, color: Color, x: float, y: float, w: float, h: float) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = Vector2(x, y)
	btn.size = Vector2(w, h)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.9)
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
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

	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn

# ------------------------------------------------------------------
#  槽位操作
# ------------------------------------------------------------------
func _on_set_slot(index: int, type: int) -> void:
	_slots[index] = type
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_ui()

# ------------------------------------------------------------------
#  导航
# ------------------------------------------------------------------
func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_start() -> void:
	var active_count = 0
	for s in _slots:
		if s != MatchConfig.SlotType.EMPTY:
			active_count += 1
	if active_count < 2:
		return

	# 写入全局配置
	MatchConfig.configure_local_match()
	MatchConfig.slots = _slots.duplicate()
	get_tree().change_scene_to_file(MatchConfig.get_selected_map_path())

func _on_map_prev() -> void:
	if MatchConfig.MAPS.size() <= 1:
		_map_label.text = MatchConfig.get_selected_map_name()
		return
	MatchConfig.selected_map_index = (MatchConfig.selected_map_index - 1 + MatchConfig.MAPS.size()) % MatchConfig.MAPS.size()
	_map_label.text = MatchConfig.get_selected_map_name()

func _on_map_next() -> void:
	if MatchConfig.MAPS.size() <= 1:
		_map_label.text = MatchConfig.get_selected_map_name()
		return
	MatchConfig.selected_map_index = (MatchConfig.selected_map_index + 1) % MatchConfig.MAPS.size()
	_map_label.text = MatchConfig.get_selected_map_name()
