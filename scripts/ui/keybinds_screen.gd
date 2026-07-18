extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const SKY_TEXTURE = preload("res://assets/textures/generated/sunset_toy_sky_islands/sunset_sky_backplate_v1.png")

const P1_BINDS := [
	["向上移动", "p1_move_forward"],
	["向下移动", "p1_move_backward"],
	["向左移动", "p1_move_left"],
	["向右移动", "p1_move_right"],
	["射击", "p1_fire"],
	["跳跃", "p1_jump"],
	["丢弃武器", "p1_drop_weapon"],
]
const P2_BINDS := [
	["向上移动", "p2_move_forward"],
	["向下移动", "p2_move_backward"],
	["向左移动", "p2_move_left"],
	["向右移动", "p2_move_right"],
	["射击", "p2_fire"],
	["跳跃", "p2_jump"],
	["丢弃武器", "p2_drop_weapon"],
]
const P3_BINDS := [
	["向上移动", "p3_move_forward"],
	["向下移动", "p3_move_backward"],
	["向左移动", "p3_move_left"],
	["向右移动", "p3_move_right"],
	["射击", "p3_fire"],
	["跳跃", "p3_jump"],
	["丢弃武器", "p3_drop_weapon"],
]
const P4_BINDS := [
	["向上移动", "p4_move_forward"],
	["向下移动", "p4_move_backward"],
	["向左移动", "p4_move_left"],
	["向右移动", "p4_move_right"],
	["射击", "p4_fire"],
	["跳跃", "p4_jump"],
	["丢弃武器", "p4_drop_weapon"],
]

var _rebinding_action := ""
var _rebinding_button: Button = null
var _key_buttons: Dictionary = {}
var _scroll: ScrollContainer = null
var _content: Control = null
var _extra_players_root: Control = null
var _extra_players_toggle: Button = null
var _ui_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_ui_scale = TOY_UI.ui_scale(viewport_size)

	var backdrop := TextureRect.new()
	backdrop.name = "SunsetBackground"
	backdrop.texture = SKY_TEXTURE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var wash := ColorRect.new()
	wash.color = Color(TOY_UI.INK.r, TOY_UI.INK.g, TOY_UI.INK.b, 0.52)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)

	var title := Label.new()
	title.text = "按键设置"
	title.position = Vector2(28.0, 14.0) * _ui_scale
	title.size = Vector2(280.0, 42.0) * _ui_scale
	TOY_UI.apply_label(title, roundi(27.0 * _ui_scale), TOY_UI.CREAM, roundi(4.0 * _ui_scale))
	add_child(title)

	var scope_label := Label.new()
	scope_label.text = "本地输入 / 4 名玩家"
	scope_label.position = Vector2(viewport_size.x - 290.0 * _ui_scale, 20.0 * _ui_scale)
	scope_label.size = Vector2(260.0, 28.0) * _ui_scale
	scope_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	TOY_UI.apply_label(scope_label, roundi(11.0 * _ui_scale), TOY_UI.CREAM_DIM, 2)
	add_child(scope_label)

	_scroll = ScrollContainer.new()
	_scroll.name = "KeybindScroll"
	_scroll.position = Vector2(0.0, 66.0 * _ui_scale)
	_scroll.size = Vector2(viewport_size.x, maxf(300.0, viewport_size.y - 132.0 * _ui_scale))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_content = Control.new()
	_content.name = "KeybindContent"
	_content.custom_minimum_size = Vector2(viewport_size.x, 480.0 * _ui_scale)
	_scroll.add_child(_content)

	var margin := 42.0 * _ui_scale
	var column_gap := 30.0 * _ui_scale
	var content_width := viewport_size.x - margin * 2.0
	var column_width := (content_width - column_gap) * 0.5
	_build_column(_content, "PLAYER 1", P1_BINDS, MatchConfig.PLAYER_COLORS[0], margin, 10.0 * _ui_scale, column_width)
	_build_column(_content, "PLAYER 2", P2_BINDS, MatchConfig.PLAYER_COLORS[1], margin + column_width + column_gap, 10.0 * _ui_scale, column_width)

	var toggle_y := 378.0 * _ui_scale
	_extra_players_toggle = _create_navigation_button("展开 P3 / P4", TOY_UI.CREAM_DIM, margin, toggle_y, content_width, 42.0 * _ui_scale)
	_extra_players_toggle.name = "ExtraPlayersToggle"
	_extra_players_toggle.toggle_mode = true
	_extra_players_toggle.toggled.connect(_on_extra_players_toggled)
	_content.add_child(_extra_players_toggle)

	_extra_players_root = Control.new()
	_extra_players_root.name = "ExtraPlayersSection"
	_extra_players_root.position = Vector2(0.0, toggle_y + 54.0 * _ui_scale)
	_extra_players_root.size = Vector2(viewport_size.x, 360.0 * _ui_scale)
	_extra_players_root.visible = false
	_content.add_child(_extra_players_root)
	_build_column(_extra_players_root, "PLAYER 3", P3_BINDS, MatchConfig.PLAYER_COLORS[2], margin, 0.0, column_width)
	_build_column(_extra_players_root, "PLAYER 4", P4_BINDS, MatchConfig.PLAYER_COLORS[3], margin + column_width + column_gap, 0.0, column_width)

	var back_button := _create_navigation_button("返回", TOY_UI.CORAL, 28.0 * _ui_scale, viewport_size.y - 54.0 * _ui_scale, 124.0 * _ui_scale, 40.0 * _ui_scale)
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(back_button)


func _build_column(parent: Control, header_text: String, binds: Array, accent: Color, x: float, y: float, width: float) -> void:
	var surface := Panel.new()
	surface.position = Vector2(x, y)
	surface.size = Vector2(width, 354.0 * _ui_scale)
	surface.add_theme_stylebox_override("panel", TOY_UI.panel_style(accent, 0.56, TOY_UI.PANEL_RADIUS, 1, 0))
	parent.add_child(surface)

	var header := Label.new()
	header.text = header_text
	header.position = Vector2(14.0, 8.0) * _ui_scale
	header.size = Vector2(width - 28.0 * _ui_scale, 26.0 * _ui_scale)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(header, roundi(16.0 * _ui_scale), accent.lightened(0.12))
	surface.add_child(header)

	var line := ColorRect.new()
	line.color = Color(accent.r, accent.g, accent.b, 0.52)
	line.position = Vector2(14.0, 36.0) * _ui_scale
	line.size = Vector2(width - 28.0 * _ui_scale, 2.0 * _ui_scale)
	surface.add_child(line)

	var row_y := 42.0 * _ui_scale
	for bind in binds:
		_build_row(surface, String(bind[0]), String(bind[1]), accent, 10.0 * _ui_scale, row_y, width - 20.0 * _ui_scale)
		row_y += 43.0 * _ui_scale


func _build_row(parent: Control, display_name: String, action: String, accent: Color, x: float, y: float, width: float) -> void:
	var action_label := Label.new()
	action_label.name = "Label_%s" % action
	action_label.text = display_name
	action_label.position = Vector2(x + 4.0 * _ui_scale, y)
	action_label.size = Vector2(width * 0.42, 36.0 * _ui_scale)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(action_label, roundi(12.0 * _ui_scale), TOY_UI.CREAM)
	parent.add_child(action_label)

	var key_button := Button.new()
	key_button.name = "Bind_%s" % action
	key_button.text = _get_action_key_name(action)
	key_button.position = Vector2(x + width * 0.44, y)
	key_button.size = Vector2(width * 0.56 - 4.0 * _ui_scale, 36.0 * _ui_scale)
	TOY_UI.apply_button(key_button, accent, false, roundi(12.0 * _ui_scale))
	key_button.pressed.connect(_on_start_rebind.bind(action, key_button))
	parent.add_child(key_button)
	_key_buttons[action] = key_button


func _on_extra_players_toggled(expanded: bool) -> void:
	_cancel_rebind()
	_extra_players_root.visible = expanded
	_extra_players_toggle.text = "收起 P3 / P4" if expanded else "展开 P3 / P4"
	_content.custom_minimum_size.y = (820.0 if expanded else 480.0) * _ui_scale


func _on_start_rebind(action: String, button: Button) -> void:
	if _rebinding_button and _rebinding_button != button:
		_rebinding_button.text = _get_action_key_name(_rebinding_action)
	_rebinding_action = action
	_rebinding_button = button
	button.text = "按下新按键..."


func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel_rebind()
		else:
			_rebind_action(_rebinding_action, event)
		get_viewport().set_input_as_handled()


func _rebind_action(action: String, event: InputEventKey) -> void:
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey:
			InputMap.action_erase_event(action, existing_event)
	var new_event := InputEventKey.new()
	new_event.physical_keycode = event.physical_keycode
	new_event.keycode = event.keycode
	InputMap.action_add_event(action, new_event)
	_rebinding_button.text = _get_action_key_name(action)
	_rebinding_action = ""
	_rebinding_button = null


func _cancel_rebind() -> void:
	if _rebinding_button:
		_rebinding_button.text = _get_action_key_name(_rebinding_action)
	_rebinding_action = ""
	_rebinding_button = null


func _get_action_key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "未配置"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			if event.physical_keycode != 0:
				return OS.get_keycode_string(event.physical_keycode)
			if event.keycode != 0:
				return OS.get_keycode_string(event.keycode)
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					return "鼠标左键"
				MOUSE_BUTTON_RIGHT:
					return "鼠标右键"
				MOUSE_BUTTON_MIDDLE:
					return "鼠标中键"
				MOUSE_BUTTON_WHEEL_UP:
					return "滚轮向上"
				MOUSE_BUTTON_WHEEL_DOWN:
					return "滚轮向下"
	return "未绑定"


func _create_navigation_button(text: String, color: Color, x: float, y: float, width: float, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(width, height)
	TOY_UI.apply_button(button, color, false, roundi(13.0 * _ui_scale))
	return button
