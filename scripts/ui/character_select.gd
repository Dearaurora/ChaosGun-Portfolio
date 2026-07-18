extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const SKY_TEXTURE = preload("res://assets/textures/generated/sunset_toy_sky_islands/sunset_sky_backplate_v1.png")
const MAX_SLOTS := 4

var _slots: Array = []
var _map_label: Label = null


func _ready() -> void:
	MatchConfig.configure_local_match()
	_slots = MatchConfig.slots.duplicate()
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
	wash.color = Color(TOY_UI.INK.r, TOY_UI.INK.g, TOY_UI.INK.b, 0.38)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)

	var title := Label.new()
	title.text = "本地对战"
	title.position = Vector2(30.0, 18.0) * ui_scale
	title.size = Vector2(340.0, 44.0) * ui_scale
	TOY_UI.apply_label(title, roundi(28.0 * ui_scale), TOY_UI.CREAM, roundi(4.0 * ui_scale))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "配置 2-4 名玩家"
	subtitle.position = Vector2(32.0, 57.0) * ui_scale
	subtitle.size = Vector2(300.0, 22.0) * ui_scale
	TOY_UI.apply_label(subtitle, roundi(12.0 * ui_scale), TOY_UI.GOLD, 2)
	add_child(subtitle)

	var horizontal_margin := 28.0 * ui_scale
	var slot_gap := 14.0 * ui_scale
	var slot_y := 100.0 * ui_scale
	var bottom_height := 76.0 * ui_scale
	var slot_width := (viewport_size.x - horizontal_margin * 2.0 - slot_gap * 3.0) / 4.0
	var slot_height := viewport_size.y - slot_y - bottom_height - 18.0 * ui_scale

	for index in range(MAX_SLOTS):
		var slot_x := horizontal_margin + index * (slot_width + slot_gap)
		add_child(_build_slot(index, slot_x, slot_y, slot_width, slot_height, ui_scale))

	var bottom_y := viewport_size.y - 60.0 * ui_scale
	var back_button := _create_button("返回", TOY_UI.CORAL, 28.0 * ui_scale, bottom_y, 124.0 * ui_scale, 42.0 * ui_scale, false, ui_scale)
	back_button.pressed.connect(_on_back)
	add_child(back_button)

	var center_x := viewport_size.x * 0.5
	var has_multiple_maps := MatchConfig.MAPS.size() > 1
	var previous_button := _create_button("<", TOY_UI.CREAM_DIM, center_x - 142.0 * ui_scale, bottom_y, 42.0 * ui_scale, 42.0 * ui_scale, false, ui_scale)
	previous_button.pressed.connect(_on_map_prev)
	previous_button.visible = has_multiple_maps
	previous_button.disabled = not has_multiple_maps
	add_child(previous_button)

	_map_label = Label.new()
	_map_label.text = MatchConfig.get_selected_map_name()
	_map_label.position = Vector2(center_x - 94.0 * ui_scale, bottom_y)
	_map_label.size = Vector2(188.0 * ui_scale, 42.0 * ui_scale)
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(_map_label, roundi(14.0 * ui_scale), TOY_UI.CREAM, 2)
	add_child(_map_label)

	var next_button := _create_button(">", TOY_UI.CREAM_DIM, center_x + 100.0 * ui_scale, bottom_y, 42.0 * ui_scale, 42.0 * ui_scale, false, ui_scale)
	next_button.pressed.connect(_on_map_next)
	next_button.visible = has_multiple_maps
	next_button.disabled = not has_multiple_maps
	add_child(next_button)

	var start_button := _create_button("开始对战", TOY_UI.GOLD, viewport_size.x - 184.0 * ui_scale, bottom_y, 156.0 * ui_scale, 42.0 * ui_scale, true, ui_scale)
	start_button.pressed.connect(_on_start)
	add_child(start_button)


func _build_slot(index: int, x: float, y: float, width: float, height: float, ui_scale: float) -> Control:
	var root := Control.new()
	root.name = "PlayerSlot%d" % (index + 1)
	root.position = Vector2(x, y)
	root.size = Vector2(width, height)

	var accent: Color = MatchConfig.PLAYER_COLORS[index]
	var active: bool = _slots[index] != MatchConfig.SlotType.EMPTY
	var surface := Panel.new()
	surface.size = root.size
	surface.add_theme_stylebox_override("panel", TOY_UI.panel_style(accent if active else TOY_UI.DISABLED, 0.68, TOY_UI.PANEL_RADIUS, 1, 2))
	root.add_child(surface)

	var player_label := Label.new()
	player_label.text = "P%d" % (index + 1)
	player_label.position = Vector2(14.0, 10.0) * ui_scale
	player_label.size = Vector2(width - 28.0 * ui_scale, 24.0 * ui_scale)
	TOY_UI.apply_label(player_label, roundi(14.0 * ui_scale), accent if active else TOY_UI.CREAM_DIM)
	root.add_child(player_label)

	if active:
		_build_active_slot(root, index, width, height, accent, ui_scale)
	else:
		_build_empty_slot(root, index, width, height, ui_scale)
	return root


func _build_empty_slot(root: Control, index: int, width: float, height: float, ui_scale: float) -> void:
	var label := Label.new()
	label.text = "空槽位"
	label.position = Vector2(0.0, height * 0.25)
	label.size = Vector2(width, 28.0 * ui_scale)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(label, roundi(14.0 * ui_scale), TOY_UI.CREAM_DIM)
	root.add_child(label)

	var button_width := minf(width - 34.0 * ui_scale, 180.0 * ui_scale)
	var button_height := 42.0 * ui_scale
	var button_x := (width - button_width) * 0.5
	var button_y := height * 0.48

	var human_button := _create_button("玩家", TOY_UI.SKY, button_x, button_y, button_width, button_height, false, ui_scale)
	human_button.pressed.connect(_on_set_slot.bind(index, MatchConfig.SlotType.HUMAN))
	root.add_child(human_button)

	var ai_button := _create_button("AI", TOY_UI.GOLD, button_x, button_y + 52.0 * ui_scale, button_width, button_height, false, ui_scale)
	ai_button.pressed.connect(_on_set_slot.bind(index, MatchConfig.SlotType.AI))
	root.add_child(ai_button)


func _build_active_slot(root: Control, index: int, width: float, height: float, accent: Color, ui_scale: float) -> void:
	var is_human: bool = _slots[index] == MatchConfig.SlotType.HUMAN
	var remove_button := _create_button("X", TOY_UI.CORAL, width - 43.0 * ui_scale, 8.0 * ui_scale, 32.0 * ui_scale, 28.0 * ui_scale, false, ui_scale)
	remove_button.tooltip_text = "移除玩家"
	remove_button.pressed.connect(_on_set_slot.bind(index, MatchConfig.SlotType.EMPTY))
	root.add_child(remove_button)

	var type_label := Label.new()
	type_label.text = "玩家" if is_human else "AI"
	type_label.position = Vector2(14.0, 42.0) * ui_scale
	type_label.size = Vector2(width - 28.0 * ui_scale, 22.0 * ui_scale)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(type_label, roundi(12.0 * ui_scale), TOY_UI.CREAM_DIM)
	root.add_child(type_label)

	var avatar_size := minf(width * 0.50, 112.0 * ui_scale)
	var avatar := Panel.new()
	avatar.position = Vector2((width - avatar_size) * 0.5, height * 0.26)
	avatar.size = Vector2(avatar_size, avatar_size)
	avatar.add_theme_stylebox_override("panel", TOY_UI.inset_style(accent, TOY_UI.CREAM, 1.0, roundi(avatar_size * 0.5), 1))
	root.add_child(avatar)

	var visor := Panel.new()
	visor.position = Vector2(avatar_size * 0.20, avatar_size * 0.37)
	visor.size = Vector2(avatar_size * 0.60, avatar_size * 0.30)
	visor.add_theme_stylebox_override("panel", TOY_UI.inset_style(TOY_UI.INK, TOY_UI.CREAM_DIM, 1.0, roundi(avatar_size * 0.09), 1))
	avatar.add_child(visor)

	for eye_index in range(2):
		var eye := Panel.new()
		eye.position = Vector2(avatar_size * (0.18 + eye_index * 0.34), avatar_size * 0.20)
		eye.size = Vector2(avatar_size * 0.09, avatar_size * 0.36)
		eye.add_theme_stylebox_override("panel", TOY_UI.inset_style(TOY_UI.GOLD, Color.TRANSPARENT, 1.0, roundi(avatar_size * 0.04), 0))
		visor.add_child(eye)

	var name_label := Label.new()
	name_label.text = "Player %d" % (index + 1) if is_human else "Bot %d" % (index + 1)
	name_label.position = Vector2(0.0, minf(height * 0.68, avatar.position.y + avatar_size + 16.0 * ui_scale))
	name_label.size = Vector2(width, 30.0 * ui_scale)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TOY_UI.apply_label(name_label, roundi(17.0 * ui_scale), TOY_UI.CREAM)
	root.add_child(name_label)

	var color_bar := ColorRect.new()
	color_bar.color = accent
	color_bar.position = Vector2(14.0 * ui_scale, height - 18.0 * ui_scale)
	color_bar.size = Vector2(width - 28.0 * ui_scale, 4.0 * ui_scale)
	root.add_child(color_bar)


func _create_button(text: String, color: Color, x: float, y: float, width: float, height: float, filled: bool, ui_scale: float) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(x, y)
	button.size = Vector2(width, height)
	TOY_UI.apply_button(button, color, filled, roundi(14.0 * ui_scale))
	return button


func _on_set_slot(index: int, slot_type: int) -> void:
	_slots[index] = slot_type
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_ui()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_start() -> void:
	var active_count := 0
	for slot in _slots:
		if slot != MatchConfig.SlotType.EMPTY:
			active_count += 1
	if active_count < 2:
		return
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
