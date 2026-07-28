extends RefCounted
class_name ToySunsetUI

const INK := Color("#21142f")
const INK_SOFT := Color("#3b2548")
const PANEL := Color(0.105, 0.055, 0.165, 0.78)
const PANEL_SOLID := Color("#2c1738")
const PANEL_RAISED := Color("#472b55")
const CREAM := Color("#fff1cf")
const CREAM_DIM := Color("#dfccb8")
const GOLD := Color("#f8c84f")
const CORAL := Color("#ff6248")
const PEACH := Color("#f49a5a")
const SKY := Color("#4da4ff")
const VIOLET := Color("#d66bdc")
const SUCCESS := Color("#77cf6b")
const DISABLED := Color("#786b80")
const PLAYER_COLORS := [SKY, CORAL, VIOLET, SUCCESS]

const PANEL_RADIUS := 12
const CONTROL_RADIUS := 10
const SMALL_RADIUS := 8


static func ui_scale(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y / 960.0, 0.85, 1.15)


static func panel_style(
	accent: Color = GOLD,
	alpha: float = 0.72,
	radius: int = PANEL_RADIUS,
	border_width: int = 1,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL.r, PANEL.g, PANEL.b, alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.58)
	_set_border_width(style, border_width)
	_set_radius(style, radius)
	if shadow_size > 0:
		style.shadow_color = Color(INK.r, INK.g, INK.b, 0.32)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0.0, 2.0)
	return style


static func inset_style(
	background: Color = PANEL_SOLID,
	accent: Color = CREAM_DIM,
	alpha: float = 0.82,
	radius: int = SMALL_RADIUS,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(background.r, background.g, background.b, alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.30)
	_set_border_width(style, border_width)
	_set_radius(style, radius)
	return style


static func apply_button(button: Button, accent: Color = GOLD, filled: bool = false, font_size: int = 16) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.88) if filled else Color(PANEL_SOLID.r, PANEL_SOLID.g, PANEL_SOLID.b, 0.90)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	_set_border_width(normal, 1)
	_set_radius(normal, CONTROL_RADIUS)
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.lightened(0.08) if filled else Color(PANEL_RAISED.r, PANEL_RAISED.g, PANEL_RAISED.b, 0.96)
	hover.border_color = accent.lightened(0.16)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.12) if filled else Color(accent.r, accent.g, accent.b, 0.24)
	pressed.border_color = accent

	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = accent.lightened(0.06) if filled else Color(PANEL_RAISED.r, PANEL_RAISED.g, PANEL_RAISED.b, 0.96)
	focus.border_color = CREAM
	_set_border_width(focus, 2)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(PANEL_SOLID.r, PANEL_SOLID.g, PANEL_SOLID.b, 0.46)
	disabled.border_color = Color(DISABLED.r, DISABLED.g, DISABLED.b, 0.34)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK if filled else CREAM)
	button.add_theme_color_override("font_hover_color", INK if filled else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", INK if filled else Color.WHITE)
	button.add_theme_color_override("font_focus_color", INK if filled else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", DISABLED)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL


static func player_color(index: int) -> Color:
	if index >= 0 and index < PLAYER_COLORS.size():
		return PLAYER_COLORS[index]
	return CREAM


static func apply_label(label: Label, font_size: int, color: Color = CREAM, outline_size: int = 0) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline_size > 0:
		label.add_theme_constant_override("outline_size", outline_size)
		label.add_theme_color_override("font_outline_color", Color(INK.r, INK.g, INK.b, 0.88))


static func make_screen_wash(alpha: float = 0.30) -> Color:
	return Color(INK.r, INK.g, INK.b, alpha)


static func _set_border_width(style: StyleBoxFlat, width: int) -> void:
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width


static func _set_radius(style: StyleBoxFlat, radius: int) -> void:
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
