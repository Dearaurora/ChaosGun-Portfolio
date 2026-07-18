extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

var _is_paused := false
var _overlay: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := TOY_UI.ui_scale(viewport_size)

	_overlay = Control.new()
	_overlay.name = "PauseOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var wash := ColorRect.new()
	wash.name = "PauseWash"
	wash.color = TOY_UI.make_screen_wash(0.34)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(wash)

	var surface_width := 296.0 * ui_scale
	var surface_height := 248.0 * ui_scale
	var surface := Panel.new()
	surface.name = "PauseSurface"
	surface.position = (viewport_size - Vector2(surface_width, surface_height)) * 0.5
	surface.size = Vector2(surface_width, surface_height)
	surface.add_theme_stylebox_override("panel", TOY_UI.panel_style(TOY_UI.GOLD, 0.78, TOY_UI.PANEL_RADIUS, 1, 4))
	_overlay.add_child(surface)

	var accent := ColorRect.new()
	accent.color = TOY_UI.GOLD
	accent.position = Vector2(72.0, 14.0) * ui_scale
	accent.size = Vector2(152.0, 3.0) * ui_scale
	surface.add_child(accent)

	var title := Label.new()
	title.text = "PAUSED"
	title.position = Vector2(0.0, 22.0) * ui_scale
	title.size = Vector2(surface_width, 34.0 * ui_scale)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(title, roundi(24.0 * ui_scale), TOY_UI.CREAM)
	surface.add_child(title)

	var button_width := 220.0 * ui_scale
	var button_height := 40.0 * ui_scale
	var button_x := (surface_width - button_width) * 0.5
	var button_y := 68.0 * ui_scale
	var button_gap := 10.0 * ui_scale

	var resume_button := _create_btn("RESUME", TOY_UI.GOLD, button_x, button_y, button_width, button_height, true)
	resume_button.pressed.connect(_on_resume)
	surface.add_child(resume_button)

	var restart_button := _create_btn("RESTART", TOY_UI.PEACH, button_x, button_y + button_height + button_gap, button_width, button_height, false)
	restart_button.pressed.connect(_on_restart)
	surface.add_child(restart_button)

	var menu_button := _create_btn("MAIN MENU", TOY_UI.CORAL, button_x, button_y + (button_height + button_gap) * 2.0, button_width, button_height, false)
	menu_button.pressed.connect(_on_main_menu)
	surface.add_child(menu_button)

	var hint := Label.new()
	hint.text = "ESC TO RESUME"
	hint.position = Vector2(0.0, surface_height - 28.0 * ui_scale)
	hint.size = Vector2(surface_width, 16.0 * ui_scale)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(hint, roundi(9.0 * ui_scale), Color(TOY_UI.CREAM_DIM.r, TOY_UI.CREAM_DIM.g, TOY_UI.CREAM_DIM.b, 0.72))
	surface.add_child(hint)


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
	MatchConfig.restart_current_match(get_tree())


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _create_btn(text: String, color: Color, x: float, y: float, width: float, height: float, filled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(width, height)
	TOY_UI.apply_button(button, color, filled, roundi(14.0 * TOY_UI.ui_scale(get_viewport().get_visible_rect().size)))
	return button
