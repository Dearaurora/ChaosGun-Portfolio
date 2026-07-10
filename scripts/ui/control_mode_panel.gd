extends CanvasLayer
class_name ControlModePanel

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")

const MODE_LANE := "lane_2d"
const MODE_TWIN_STICK := "twin_stick"
const MODE_LOCK_ON := "lock_on"

const MODES := [
	{"id": MODE_LANE, "label": "2D Gunline", "hint": "Keyboard left/right gunline. Press 1."},
	{"id": MODE_TWIN_STICK, "label": "Twin Stick", "hint": "Move with keyboard, aim with mouse. Press 2."},
	{"id": MODE_LOCK_ON, "label": "Lock On", "hint": "Keyboard movement with target lock assist. Press 3."},
]

var _buttons: Dictionary = {}
var _status_label: Label = null

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			_set_mode(MODE_LANE)
			get_viewport().set_input_as_handled()
		KEY_2:
			_set_mode(MODE_TWIN_STICK)
			get_viewport().set_input_as_handled()
		KEY_3:
			_set_mode(MODE_LOCK_ON)
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var root = Control.new()
	root.name = "ControlModeReviewPanel"
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.offset_left = 12.0
	root.offset_top = 12.0
	root.offset_right = 650.0
	root.offset_bottom = 56.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.055, 0.82)
	style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.add_child(row)

	_status_label = Label.new()
	_status_label.custom_minimum_size = Vector2(132.0, 34.0)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	row.add_child(_status_label)

	for mode in MODES:
		var button = Button.new()
		button.text = mode["label"]
		button.tooltip_text = mode["hint"]
		button.custom_minimum_size = Vector2(112.0, 34.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_mode.bind(mode["id"]))
		row.add_child(button)
		_buttons[mode["id"]] = button

	var restart = Button.new()
	restart.text = "Restart"
	restart.tooltip_text = "Reload the current arena with the selected mode."
	restart.custom_minimum_size = Vector2(82.0, 34.0)
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(_restart_match)
	row.add_child(restart)

func _set_mode(mode: String) -> void:
	var config = RuntimeGlobals.game_config()
	if config:
		config.set("control_mode", mode)
	_refresh()

func _restart_match() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _refresh() -> void:
	var current = _current_mode()
	if _status_label:
		_status_label.text = "Mode: %s" % _label_for_mode(current)
	for mode in _buttons.keys():
		var button = _buttons[mode] as Button
		if button == null:
			continue
		var selected = mode == current
		button.disabled = selected
		button.modulate = Color(1.0, 0.92, 0.25, 1.0) if selected else Color.WHITE

func _current_mode() -> String:
	var config = RuntimeGlobals.game_config()
	if config == null:
		return MODE_LOCK_ON
	var value = config.get("control_mode")
	if value is String:
		return value
	return MODE_LOCK_ON

func _label_for_mode(mode: String) -> String:
	for item in MODES:
		if item["id"] == mode:
			return item["label"]
	return "Lock On"
