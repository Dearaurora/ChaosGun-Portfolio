extends CanvasLayer
## 键位设置界面 —— 点击行进入重绑定，按键即绑定

const COL_SURFACE := Color("#0c0c1f")
const COL_PANEL := Color("#1d1d37")
const COL_PRIMARY := Color("#cafd00")
const COL_SECONDARY := Color("#ff7441")
const COL_HEART := Color("#ff6e81")
const COL_TEXT := Color("#e5e3ff")
const COL_DIM := Color("#74738b")
const COL_ACTIVE := Color("#ffffff")

## 每个绑定项: [显示名, InputMap action 名]
var P1_BINDS := [
	["向上移动", "p1_move_forward"],
	["向下移动", "p1_move_backward"],
	["向左移动", "p1_move_left"],
	["向右移动", "p1_move_right"],
	["射击", "p1_fire"],
	["跳跃", "p1_jump"],
	["切换武器", "p1_weapon_cycle"],
]

var P2_BINDS := [
	["向上移动", "p2_move_forward"],
	["向下移动", "p2_move_backward"],
	["向左移动", "p2_move_left"],
	["向右移动", "p2_move_right"],
	["射击", "p2_fire"],
	["跳跃", "p2_jump"],
	["切换武器", "p2_weapon_cycle"],
]

## 正在重绑定的 action（空字符串 = 未激活）
var _rebinding_action := ""
## 当前高亮的按钮引用
var _rebinding_btn: Button = null
## action -> 显示按键的 Label 的映射
var _key_labels := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var vp = get_viewport().get_visible_rect().size

	var bg = ColorRect.new()
	bg.color = COL_SURFACE
	bg.size = vp
	add_child(bg)

	# 标题栏
	var header = Panel.new()
	header.size = Vector2(vp.x, 64)
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = COL_PANEL
	h_style.border_width_bottom = 2
	h_style.border_color = Color(COL_PRIMARY.r, COL_PRIMARY.g, COL_PRIMARY.b, 0.3)
	header.add_theme_stylebox_override("panel", h_style)
	add_child(header)

	var title = Label.new()
	title.text = "KEY BINDINGS"
	title.position = Vector2(32, 0)
	title.size = Vector2(400, 64)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_PRIMARY)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	var hint = Label.new()
	hint.text = "点击按键区域进入设置，然后按下新按键即可绑定"
	hint.position = Vector2(vp.x - 450, 0)
	hint.size = Vector2(420, 64)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COL_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(hint)

	# 两列布局
	var margin := 48.0
	var col_gap := 40.0
	var content_w: float = vp.x - margin * 2
	var col_w: float = (content_w - col_gap) / 2.0
	var start_y := 88.0

	_build_column("PLAYER 1", P1_BINDS, COL_PRIMARY, margin, start_y, col_w)
	_build_column("PLAYER 2", P2_BINDS, COL_SECONDARY, margin + col_w + col_gap, start_y, col_w)

	# BACK 按钮
	var back_btn = _create_nav_btn("← BACK", COL_HEART, 32, vp.y - 72, 140, 56)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(back_btn)

func _build_column(header_text: String, binds: Array, accent: Color, x: float, y: float, w: float) -> void:
	var header = Label.new()
	header.text = header_text
	header.position = Vector2(x, y)
	header.size = Vector2(w, 30)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", accent)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	var line = ColorRect.new()
	line.color = Color(accent.r, accent.g, accent.b, 0.3)
	line.position = Vector2(x, y + 34)
	line.size = Vector2(w, 2)
	add_child(line)

	var row_y := y + 48.0
	var row_h := 50.0
	for bind in binds:
		_build_row(bind[0], bind[1], accent, x, row_y, w)
		row_y += row_h

func _build_row(display_name: String, action: String, accent: Color, x: float, y: float, w: float) -> void:
	# 操作名标签
	var action_label = Label.new()
	action_label.text = display_name
	action_label.position = Vector2(x + 12, y + 4)
	action_label.size = Vector2(w * 0.45, 38)
	action_label.add_theme_font_size_override("font_size", 14)
	action_label.add_theme_color_override("font_color", COL_TEXT)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(action_label)

	# 可点击的按键按钮
	var key_btn = Button.new()
	key_btn.text = _get_action_key_name(action)
	key_btn.position = Vector2(x + w * 0.45, y + 2)
	key_btn.size = Vector2(w * 0.55 - 12, 42)

	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(COL_PANEL.r, COL_PANEL.g, COL_PANEL.b, 0.7)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.2)
	key_btn.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	key_btn.add_theme_stylebox_override("hover", hover)

	# 激活态（正在等待按键）
	var focus = normal.duplicate()
	focus.bg_color = Color(accent.r, accent.g, accent.b, 0.2)
	focus.border_color = accent
	key_btn.add_theme_stylebox_override("pressed", focus)

	key_btn.add_theme_font_size_override("font_size", 14)
	key_btn.add_theme_color_override("font_color", accent)
	key_btn.add_theme_color_override("font_hover_color", COL_ACTIVE)
	key_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	key_btn.pressed.connect(_on_start_rebind.bind(action, key_btn, accent))
	add_child(key_btn)

	_key_labels[action] = key_btn

## 点击按键按钮 → 进入重绑定状态
func _on_start_rebind(action: String, btn: Button, accent: Color) -> void:
	# 取消之前的绑定状态
	if _rebinding_btn and _rebinding_btn != btn:
		_rebinding_btn.text = _get_action_key_name(_rebinding_action)

	_rebinding_action = action
	_rebinding_btn = btn
	btn.text = "[ 按下新按键... ]"

func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action == "":
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# ESC 取消绑定
		if event.keycode == KEY_ESCAPE:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
			return

		# 执行重绑定
		_rebind_action(_rebinding_action, event)
		get_viewport().set_input_as_handled()

func _rebind_action(action: String, event: InputEventKey) -> void:
	# 清除该 action 的所有键盘事件
	var events = InputMap.action_get_events(action)
	for e in events:
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)

	# 添加新键
	var new_event = InputEventKey.new()
	new_event.physical_keycode = event.physical_keycode
	new_event.keycode = event.keycode
	InputMap.action_add_event(action, new_event)

	# 更新显示
	_rebinding_btn.text = _get_action_key_name(action)
	_rebinding_action = ""
	_rebinding_btn = null

func _cancel_rebind() -> void:
	if _rebinding_btn:
		_rebinding_btn.text = _get_action_key_name(_rebinding_action)
	_rebinding_action = ""
	_rebinding_btn = null

## 获取 action 当前绑定的第一个键盘键名
func _get_action_key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "???"
	var events = InputMap.action_get_events(action)
	for e in events:
		if e is InputEventKey:
			var key = e as InputEventKey
			if key.physical_keycode != 0:
				return OS.get_keycode_string(key.physical_keycode)
			elif key.keycode != 0:
				return OS.get_keycode_string(key.keycode)
		elif e is InputEventMouseButton:
			var mb = e as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_LEFT: return "鼠标左键"
				MOUSE_BUTTON_RIGHT: return "鼠标右键"
				MOUSE_BUTTON_MIDDLE: return "鼠标中键"
				MOUSE_BUTTON_WHEEL_UP: return "滚轮↑"
				MOUSE_BUTTON_WHEEL_DOWN: return "滚轮↓"
	return "未绑定"

func _create_nav_btn(text: String, color: Color, x: float, y: float, w: float, h: float) -> Button:
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
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn
