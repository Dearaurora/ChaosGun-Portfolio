extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const KEYBIND_ROW_SCENE = preload("res://scenes/ui/components/keybind_row.tscn")

const P1_BINDS := [
	["向上移动", "p1_move_forward"],
	["向下移动", "p1_move_backward"],
	["向左移动", "p1_move_left"],
	["向右移动", "p1_move_right"],
	["射击", "p1_fire"],
	["跳跃", "p1_jump"],
	["切换目标", "p1_target_cycle"],
	["丢弃武器", "p1_drop_weapon"],
]
const P2_BINDS := [
	["向上移动", "p2_move_forward"],
	["向下移动", "p2_move_backward"],
	["向左移动", "p2_move_left"],
	["向右移动", "p2_move_right"],
	["射击", "p2_fire"],
	["跳跃", "p2_jump"],
	["切换目标", "p2_target_cycle"],
	["丢弃武器", "p2_drop_weapon"],
]
const P3_BINDS := [
	["向上移动", "p3_move_forward"],
	["向下移动", "p3_move_backward"],
	["向左移动", "p3_move_left"],
	["向右移动", "p3_move_right"],
	["射击", "p3_fire"],
	["跳跃", "p3_jump"],
	["切换目标", "p3_target_cycle"],
	["丢弃武器", "p3_drop_weapon"],
]
const P4_BINDS := [
	["向上移动", "p4_move_forward"],
	["向下移动", "p4_move_backward"],
	["向左移动", "p4_move_left"],
	["向右移动", "p4_move_right"],
	["射击", "p4_fire"],
	["跳跃", "p4_jump"],
	["切换目标", "p4_target_cycle"],
	["丢弃武器", "p4_drop_weapon"],
]

@onready var _page: Control = $KeybindsRoot/SafeArea/Page
@onready var _scroll: ScrollContainer = $KeybindsRoot/SafeArea/Page/KeybindScroll
@onready var _content: VBoxContainer = $KeybindsRoot/SafeArea/Page/KeybindScroll/KeybindContent
@onready var _extra_players_root: HBoxContainer = $KeybindsRoot/SafeArea/Page/KeybindScroll/KeybindContent/ExtraPlayersSection
@onready var _extra_players_toggle: Button = $KeybindsRoot/SafeArea/Page/KeybindScroll/KeybindContent/ExtraPlayersToggle
@onready var _back_button: Button = $KeybindsRoot/SafeArea/Page/Footer/BackButton
@onready var _capture_hint: Label = $KeybindsRoot/SafeArea/Page/Footer/CaptureHint

var _rebinding_action := ""
var _rebinding_button: Button = null
var _key_buttons: Dictionary = {}
var _ui_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_scale = TOY_UI.ui_scale(get_viewport().get_visible_rect().size)
	_build_column($KeybindsRoot/SafeArea/Page/KeybindScroll/KeybindContent/PrimaryPlayers/Player1Column, "PLAYER 1", P1_BINDS, TOY_UI.player_color(0))
	_build_column($KeybindsRoot/SafeArea/Page/KeybindScroll/KeybindContent/PrimaryPlayers/Player2Column, "PLAYER 2", P2_BINDS, TOY_UI.player_color(1))
	_build_column($KeybindsRoot/SafeArea/Page/KeybindScroll/KeybindContent/ExtraPlayersSection/Player3Column, "PLAYER 3", P3_BINDS, TOY_UI.player_color(2))
	_build_column($KeybindsRoot/SafeArea/Page/KeybindScroll/KeybindContent/ExtraPlayersSection/Player4Column, "PLAYER 4", P4_BINDS, TOY_UI.player_color(3))
	_extra_players_toggle.toggled.connect(_on_extra_players_toggled)
	_back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	TOY_UI.apply_button(_extra_players_toggle, TOY_UI.CREAM_DIM, false, 16)
	TOY_UI.apply_button(_back_button, TOY_UI.CORAL, false, 16)
	_extra_players_root.visible = false
	_content.custom_minimum_size.y = 480.0 * _ui_scale
	_back_button.grab_focus()
	_play_enter_transition()


func _build_column(parent: PanelContainer, header_text: String, binds: Array, accent: Color) -> void:
	var header := parent.get_node("Content/Header") as Label
	var accent_line := parent.get_node("Content/AccentLine") as ColorRect
	var rows := parent.get_node("Content/Rows") as VBoxContainer
	header.text = header_text
	header.add_theme_color_override("font_color", accent)
	accent_line.color = accent
	parent.add_theme_stylebox_override("panel", TOY_UI.panel_style(accent, 0.62, 12, 1, 2))
	for bind in binds:
		var row := KEYBIND_ROW_SCENE.instantiate() as HBoxContainer
		var display_name := String(bind[0])
		var action := String(bind[1])
		var action_label := row.get_node("ActionLabel") as Label
		var key_button := row.get_node("KeyButton") as Button
		action_label.name = "Label_%s" % action
		action_label.text = display_name
		key_button.name = "Bind_%s" % action
		key_button.text = _get_action_key_name(action)
		TOY_UI.apply_button(key_button, accent, false, 14)
		key_button.pressed.connect(_on_start_rebind.bind(action, key_button))
		rows.add_child(row)
		_key_buttons[action] = key_button


func _on_extra_players_toggled(expanded: bool) -> void:
	_cancel_rebind()
	_extra_players_root.visible = expanded
	_extra_players_toggle.text = "收起 P3 / P4" if expanded else "展开 P3 / P4"
	_content.custom_minimum_size.y = (900.0 if expanded else 480.0) * _ui_scale


func _on_start_rebind(action: String, button: Button) -> void:
	if _rebinding_button and _rebinding_button != button:
		_rebinding_button.text = _get_action_key_name(_rebinding_action)
	_rebinding_action = action
	_rebinding_button = button
	button.text = "按下新按键…"
	_capture_hint.text = "正在捕获：%s · ESC 取消" % action
	_capture_hint.add_theme_color_override("font_color", TOY_UI.GOLD)


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
	_reset_capture_hint()


func _cancel_rebind() -> void:
	if _rebinding_button:
		_rebinding_button.text = _get_action_key_name(_rebinding_action)
	_rebinding_action = ""
	_rebinding_button = null
	_reset_capture_hint()


func _reset_capture_hint() -> void:
	_capture_hint.text = "选择一项后按下新按键 · ESC 取消捕获"
	_capture_hint.add_theme_color_override("font_color", TOY_UI.CREAM_DIM)


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


func _play_enter_transition() -> void:
	_page.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_page, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
