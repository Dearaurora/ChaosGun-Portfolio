extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const SKY_TEXTURE = preload("res://assets/textures/generated/sunset_toy_sky_islands/sunset_sky_backplate_v1.png")


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := TOY_UI.ui_scale(viewport_size)

	var backdrop := TextureRect.new()
	backdrop.name = "SunsetBackground"
	backdrop.texture = SKY_TEXTURE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var wash := ColorRect.new()
	wash.name = "MenuWash"
	wash.color = Color(TOY_UI.INK.r, TOY_UI.INK.g, TOY_UI.INK.b, 0.25)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)

	var title := Label.new()
	title.name = "GameTitle"
	title.text = "CHAOS GUN"
	title.position = Vector2(0.0, viewport_size.y * 0.13)
	title.size = Vector2(viewport_size.x, 68.0 * ui_scale)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(title, roundi(54.0 * ui_scale), TOY_UI.CREAM, roundi(7.0 * ui_scale))
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "GameSubtitle"
	subtitle.text = "浮岛乱斗"
	subtitle.position = Vector2(0.0, viewport_size.y * 0.13 + 66.0 * ui_scale)
	subtitle.size = Vector2(viewport_size.x, 26.0 * ui_scale)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(subtitle, roundi(15.0 * ui_scale), TOY_UI.GOLD, roundi(3.0 * ui_scale))
	add_child(subtitle)

	var color_bar_width := 34.0 * ui_scale
	var color_bar_gap := 8.0 * ui_scale
	var player_colors := MatchConfig.PLAYER_COLORS
	var total_bar_width := player_colors.size() * color_bar_width + (player_colors.size() - 1) * color_bar_gap
	for index in range(player_colors.size()):
		var bar := ColorRect.new()
		bar.name = "PlayerColor%d" % (index + 1)
		bar.color = player_colors[index]
		bar.position = Vector2((viewport_size.x - total_bar_width) * 0.5 + index * (color_bar_width + color_bar_gap), viewport_size.y * 0.27)
		bar.size = Vector2(color_bar_width, 4.0 * ui_scale)
		add_child(bar)

	var button_width := 300.0 * ui_scale
	var button_height := 52.0 * ui_scale
	var button_gap := 13.0 * ui_scale
	var button_x := (viewport_size.x - button_width) * 0.5
	var button_y := viewport_size.y * 0.43

	var ai_button := _create_button("快速对战", TOY_UI.GOLD, button_x, button_y, button_width, button_height, true)
	ai_button.pressed.connect(_on_vs_ai)
	add_child(ai_button)

	var local_button := _create_button("本地对战", TOY_UI.SKY, button_x, button_y + button_height + button_gap, button_width, button_height, false)
	local_button.pressed.connect(_on_local_battle)
	add_child(local_button)

	var keys_button := _create_button("按键设置", TOY_UI.CREAM_DIM, button_x, button_y + (button_height + button_gap) * 2.0, button_width, button_height, false)
	keys_button.pressed.connect(_on_keybinds)
	add_child(keys_button)

	var hint := Label.new()
	hint.text = "P28 VISUAL SLICE"
	hint.position = Vector2(0.0, viewport_size.y - 34.0 * ui_scale)
	hint.size = Vector2(viewport_size.x, 18.0 * ui_scale)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(hint, roundi(9.0 * ui_scale), Color(TOY_UI.CREAM_DIM.r, TOY_UI.CREAM_DIM.g, TOY_UI.CREAM_DIM.b, 0.66), 2)
	add_child(hint)


func _create_button(text: String, accent: Color, x: float, y: float, width: float, height: float, filled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(width, height)
	TOY_UI.apply_button(button, accent, filled, roundi(18.0 * TOY_UI.ui_scale(get_viewport().get_visible_rect().size)))
	return button


func _on_vs_ai() -> void:
	MatchConfig.configure_quick_ai_match()
	get_tree().change_scene_to_file(MatchConfig.get_selected_map_path())


func _on_local_battle() -> void:
	MatchConfig.configure_local_match()
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")


func _on_keybinds() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/keybinds_screen.tscn")
