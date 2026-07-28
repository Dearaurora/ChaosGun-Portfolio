extends Control
class_name MatchEventBanner

enum Placement { CENTER, TOP }

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

@onready var _surface: PanelContainer = $Stack/MainRow/Surface
@onready var _kicker: Label = $Stack/MainRow/Surface/Content/Kicker
@onready var _title: Label = $Stack/MainRow/Surface/Content/CueWord
@onready var _subtitle: Label = $Stack/MainRow/Surface/Content/Subtitle
@onready var _accent_left: ColorRect = $Stack/MainRow/LeftRail/AccentLine
@onready var _accent_right: ColorRect = $Stack/MainRow/RightRail/AccentLine
@onready var _pips_center: CenterContainer = $Stack/PipsCenter
@onready var _pips: HBoxContainer = $Stack/PipsCenter/Pips

var _visibility_tween: Tween = null
var _pulse_tween: Tween = null
var _accent := TOY_UI.GOLD
var _is_hiding := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_accent(_accent)
	_pips_center.visible = false
	visible = false
	call_deferred("_sync_pivot")


func set_placement(placement: Placement) -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -300.0
	offset_right = 300.0
	if placement == Placement.TOP:
		anchor_top = 0.0
		anchor_bottom = 0.0
		offset_top = 42.0
		offset_bottom = 174.0
	else:
		anchor_top = 0.5
		anchor_bottom = 0.5
		offset_top = -66.0
		offset_bottom = 66.0
	_sync_pivot()


func set_event(
	title: String,
	subtitle: String = "",
	kicker: String = "",
	accent: Color = TOY_UI.GOLD,
	pip_colors: Array = [],
	animate_entry: bool = true
) -> void:
	var was_visible := visible
	var title_changed := _title.text != title
	if _is_hiding:
		_kill_visibility_tween()
		_is_hiding = false
		modulate.a = 1.0
		scale = Vector2.ONE
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()
	_kicker.text = kicker
	_kicker.visible = not kicker.is_empty()
	_apply_accent(accent)
	_set_pips(pip_colors)
	if not was_visible:
		if animate_entry:
			_animate_in()
		else:
			visible = true
			modulate.a = 1.0
			scale = Vector2.ONE
	elif title_changed:
		_pulse_update()


func set_title(title: String, accent: Color = Color.TRANSPARENT, pulse: bool = false) -> void:
	var title_changed := _title.text != title
	_title.text = title
	_apply_accent(_accent if accent.a <= 0.0 else accent)
	if pulse and title_changed and visible:
		_pulse_update()


func hide_event(animated: bool = true) -> void:
	if not visible or _is_hiding:
		return
	_kill_visibility_tween()
	_kill_pulse_tween()
	if not animated:
		_is_hiding = false
		visible = false
		modulate.a = 0.0
		scale = Vector2.ONE
		return
	_is_hiding = true
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_visibility_tween.parallel().tween_property(self, "scale", Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_visibility_tween.tween_callback(_finish_hide)


func get_title_label() -> Label:
	return _title


func get_accent_lines() -> Array[ColorRect]:
	return [_accent_left, _accent_right]


func get_debug_state() -> Dictionary:
	return {
		"visible": visible,
		"title": _title.text,
		"subtitle": _subtitle.text,
		"kicker": _kicker.text,
		"pip_count": _pips.get_child_count(),
		"accent": _accent,
	}


func _apply_accent(accent: Color) -> void:
	_accent = accent
	_surface.add_theme_stylebox_override("panel", TOY_UI.panel_style(accent, 0.92, 14, 2, 12))
	_kicker.add_theme_color_override("font_color", accent)
	_title.add_theme_color_override("font_color", accent)
	_accent_left.color = accent
	_accent_right.color = accent


func _set_pips(colors: Array) -> void:
	for child in _pips.get_children():
		child.queue_free()
	for index in range(colors.size()):
		var pip := ColorRect.new()
		pip.name = "PlayerColor_%d" % (index + 1)
		pip.custom_minimum_size = Vector2(34.0, 4.0)
		pip.color = colors[index] as Color
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(pip)
	_pips_center.visible = not colors.is_empty()


func _animate_in() -> void:
	_kill_visibility_tween()
	_kill_pulse_tween()
	_is_hiding = false
	visible = true
	# High-priority match information must remain readable on its first frame.
	modulate.a = 0.78
	scale = Vector2(0.96, 0.96)
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visibility_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pulse_update() -> void:
	_kill_pulse_tween()
	scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", Vector2(1.035, 1.035), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _finish_hide() -> void:
	_is_hiding = false
	visible = false
	scale = Vector2.ONE
	_visibility_tween = null


func _sync_pivot() -> void:
	pivot_offset = size * 0.5


func _kill_visibility_tween() -> void:
	if _visibility_tween and _visibility_tween.is_valid():
		_visibility_tween.kill()
	_visibility_tween = null


func _kill_pulse_tween() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
