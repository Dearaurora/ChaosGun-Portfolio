extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const PAUSE_OVERLAY_SCENE = preload("res://scenes/ui/components/pause_overlay.tscn")

var _is_paused := false
var _overlay: Control
var _surface: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = PAUSE_OVERLAY_SCENE.instantiate()
	add_child(_overlay)
	_surface = _overlay.get_node("Center/PauseSurface")
	var resume_button := _overlay.get_node("Center/PauseSurface/Content/ResumeButton") as Button
	var restart_button := _overlay.get_node("Center/PauseSurface/Content/RestartButton") as Button
	var menu_button := _overlay.get_node("Center/PauseSurface/Content/MainMenuButton") as Button
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_main_menu)
	TOY_UI.apply_button(resume_button, TOY_UI.GOLD, true, 18)
	TOY_UI.apply_button(restart_button, TOY_UI.PEACH, false, 16)
	TOY_UI.apply_button(menu_button, TOY_UI.CORAL, false, 16)
	_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and _is_paused:
			_on_restart()
			get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	_is_paused = not _is_paused
	if _is_paused:
		_overlay.visible = true
		_overlay.modulate.a = 1.0
		_surface.scale = Vector2(0.96, 0.96)
		_surface.pivot_offset = _surface.size * 0.5
		get_tree().paused = true
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(_surface, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var resume_button := _overlay.get_node("Center/PauseSurface/Content/ResumeButton") as Button
		resume_button.grab_focus()
	else:
		get_tree().paused = false
		_overlay.visible = false


func _on_resume() -> void:
	_toggle_pause()


func _on_restart() -> void:
	MatchConfig.restart_current_match(get_tree())


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
