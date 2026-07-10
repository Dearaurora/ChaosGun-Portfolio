extends CanvasLayer
class_name RingoutHUD

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const WEAPON_ICON_SCRIPT = preload("res://scripts/ui/weapon_silhouette_icon.gd")

const PANEL_SIZE := Vector2(254, 116)
const PANEL_MARGIN := Vector2(18, 18)
const HEART_CODE := 0x2665

var _characters: Array = []
var _panel_data: Array[Dictionary] = []
var _root: Control = null

func set_characters(characters: Array) -> void:
	_characters = characters.duplicate()
	call_deferred("_rebuild")

func _ready() -> void:
	layer = 20
	get_viewport().size_changed.connect(_layout_panels)

func _process(_delta: float) -> void:
	for data in _panel_data:
		var character = data.get("character") as BaseCharacter
		if character == null or not is_instance_valid(character):
			continue
		_update_hearts(data, character.lives)
		_update_life_label(data, character.lives)
		_update_weapon_info(data, character)

func _rebuild() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()

	_panel_data.clear()
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	for i in range(_characters.size()):
		var character = _characters[i] as BaseCharacter
		if character == null:
			continue
		var panel = _build_panel(character, i)
		_root.add_child(panel)
	_layout_panels()

func _build_panel(character: BaseCharacter, index: int) -> Control:
	var accent = _character_color(character, index)
	var panel = Panel.new()
	panel.name = "PlayerPanel%d" % (index + 1)
	panel.size = PANEL_SIZE
	panel.custom_minimum_size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.047, 0.070, 0.86)
	style.border_color = accent.lerp(Color.WHITE, 0.10)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)

	var avatar = Panel.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(12, 16)
	avatar.size = Vector2(70, 70)
	avatar.add_theme_stylebox_override("panel", _round_style(accent.darkened(0.08), accent.lerp(Color.WHITE, 0.38), 35, 3))
	panel.add_child(avatar)

	var avatar_shine = Panel.new()
	avatar_shine.name = "AvatarShine"
	avatar_shine.position = Vector2(12, 9)
	avatar_shine.size = Vector2(32, 15)
	avatar_shine.add_theme_stylebox_override("panel", _round_style(Color(1, 1, 1, 0.20), Color(1, 1, 1, 0.0), 8, 0))
	avatar.add_child(avatar_shine)

	var visor = Panel.new()
	visor.name = "Visor"
	visor.position = Vector2(16, 24)
	visor.size = Vector2(40, 24)
	visor.add_theme_stylebox_override("panel", _round_style(Color("#dff7ff"), Color("#26314a"), 9, 3))
	avatar.add_child(visor)

	var visor_glint = Panel.new()
	visor_glint.name = "VisorGlint"
	visor_glint.position = Vector2(7, 5)
	visor_glint.size = Vector2(22, 6)
	visor_glint.add_theme_stylebox_override("panel", _round_style(Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0), 3, 0))
	visor.add_child(visor_glint)

	var player_tag = _make_label("PlayerTag", _player_tag(index), Vector2(92, 9), Vector2(48, 20), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(player_tag)

	var life_label = _make_label("LifeLabel", "LIFE 4", Vector2(142, 10), Vector2(76, 18), 11, Color("#aeb8c9"), HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(life_label)

	var hearts: Array[Label] = []
	for i in range(_max_lives()):
		var heart = Label.new()
		heart.name = "Heart%d" % i
		heart.text = String.chr(HEART_CODE)
		heart.position = Vector2(92 + i * 25, 26)
		heart.size = Vector2(22, 24)
		heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heart.add_theme_font_size_override("font_size", 23)
		heart.add_theme_color_override("font_color", Color("#ff496a"))
		panel.add_child(heart)
		hearts.append(heart)

	var weapon_box = Panel.new()
	weapon_box.name = "WeaponBox"
	weapon_box.position = Vector2(86, 54)
	weapon_box.size = Vector2(154, 50)
	weapon_box.add_theme_stylebox_override("panel", _round_style(Color(0.014, 0.020, 0.032, 0.80), accent.darkened(0.08), 12, 2))
	panel.add_child(weapon_box)

	var weapon_icon = WEAPON_ICON_SCRIPT.new()
	weapon_icon.name = "WeaponSilhouette"
	weapon_icon.position = Vector2(5, 6)
	weapon_icon.size = Vector2(90, 38)
	weapon_icon.set_weapon("pistol", accent)
	weapon_box.add_child(weapon_icon)

	var weapon_name = _make_label("WeaponName", "PISTOL", Vector2(99, 6), Vector2(49, 16), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	weapon_box.add_child(weapon_name)

	var ammo_label = _make_label("AmmoLabel", "INF", Vector2(99, 25), Vector2(49, 18), 13, Color("#d7e3f4"), HORIZONTAL_ALIGNMENT_LEFT)
	weapon_box.add_child(ammo_label)

	_panel_data.append({
		"character": character,
		"panel": panel,
		"hearts": hearts,
		"life_label": life_label,
		"weapon_icon": weapon_icon,
		"weapon_name": weapon_name,
		"ammo_label": ammo_label,
		"weapon_id": "",
		"ammo_text": "",
		"accent": accent,
	})

	return panel

func _layout_panels() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	for i in range(_panel_data.size()):
		var panel = _panel_data[i].get("panel") as Control
		if panel == null:
			continue
		match i:
			0:
				panel.position = PANEL_MARGIN
			1:
				panel.position = Vector2(viewport_size.x - PANEL_SIZE.x - PANEL_MARGIN.x, PANEL_MARGIN.y)
			2:
				panel.position = Vector2(PANEL_MARGIN.x, viewport_size.y - PANEL_SIZE.y - PANEL_MARGIN.y)
			_:
				panel.position = viewport_size - PANEL_SIZE - PANEL_MARGIN

func _update_hearts(data: Dictionary, lives: int) -> void:
	var hearts = data.get("hearts") as Array
	for i in range(hearts.size()):
		var heart = hearts[i] as Label
		if heart == null:
			continue
		var active = i < lives
		heart.add_theme_color_override(
			"font_color",
			Color("#ff496a") if active else Color(1.0, 0.29, 0.42, 0.20)
		)

func _update_life_label(data: Dictionary, lives: int) -> void:
	var life_label = data.get("life_label") as Label
	if life_label == null:
		return
	life_label.text = "LIFE %d" % max(lives, 0)
	life_label.add_theme_color_override("font_color", Color("#aeb8c9") if lives > 1 else Color("#ff8b62"))

func _update_weapon_info(data: Dictionary, character: BaseCharacter) -> void:
	var weapon_id := "pistol"
	var weapon_name := "PISTOL"
	var ammo_text := "INF"
	var infinite_ammo := true

	if character.weapon_manager and character.weapon_manager.current_weapon and character.weapon_manager.current_weapon.weapon_data:
		var weapon_data = character.weapon_manager.current_weapon.weapon_data
		weapon_id = String(weapon_data.weapon_id)
		weapon_name = _weapon_display_name(weapon_data.weapon_name, weapon_id)
		infinite_ammo = weapon_data.has_infinite_ammo or weapon_data.magazine_size < 0
		if infinite_ammo:
			ammo_text = "INF"
		else:
			var ammo = max(character.weapon_manager.get_current_ammo(), 0)
			ammo_text = "%d/%d" % [ammo, weapon_data.magazine_size]

	var weapon_name_label = data.get("weapon_name") as Label
	if weapon_name_label != null:
		weapon_name_label.text = weapon_name

	var ammo_label = data.get("ammo_label") as Label
	if ammo_label != null:
		ammo_label.text = ammo_text
		ammo_label.add_theme_color_override("font_color", Color("#d7e3f4") if infinite_ammo else Color.WHITE)

	if data.get("weapon_id", "") == weapon_id:
		return
	data["weapon_id"] = weapon_id
	data["ammo_text"] = ammo_text
	var icon = data.get("weapon_icon") as Control
	if icon == null:
		return
	if icon.has_method("set_weapon"):
		icon.call("set_weapon", weapon_id, data.get("accent") as Color)

func _make_label(name: String, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.name = name
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.40))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _round_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _character_color(character: BaseCharacter, index: int) -> Color:
	var match_config = _match_config()
	if match_config != null:
		var colors = match_config.get("PLAYER_COLORS")
		if colors is Array and index < colors.size():
			return colors[index]
	var visual = character.get_node_or_null("Visual")
	if visual:
		var body_color = visual.get("body_color")
		if body_color is Color:
			return body_color
	return Color.WHITE

func _match_config() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("MatchConfig")
	return null

func _player_tag(index: int) -> String:
	return "P1" if index == 0 else "BOT %d" % (index + 1)

func _weapon_display_name(raw_name: String, weapon_id: String) -> String:
	var name = raw_name.strip_edges()
	if name.is_empty():
		match weapon_id:
			"smg":
				name = "SMG"
			"ak_rifle":
				name = "AK RIFLE"
			"sniper":
				name = "SNIPER"
			_:
				name = "PISTOL"
	return name.to_upper()

func _weapon_color(weapon_id: String, accent: Color) -> Color:
	match weapon_id:
		"smg":
			return Color("#65ff49")
		"ak_rifle":
			return Color("#ffb13b")
		"sniper":
			return Color("#5ce3ff")
		_:
			return Color("#ff6b72")

func _max_lives() -> int:
	return 4
