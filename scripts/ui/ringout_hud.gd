extends CanvasLayer
class_name RingoutHUD

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const WEAPON_ICON_SCRIPT = preload("res://scripts/ui/weapon_silhouette_icon.gd")
const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

const PANEL_SIZE := Vector2(200, 72)
const PANEL_MARGIN := Vector2(12, 12)
const CAMERA_OCCLUSION_GUTTER := 8.0
const HEART_CODE := 0x2665

var _characters: Array = []
var _panel_data: Array[Dictionary] = []
var _root: Control = null

static func camera_occlusion_rects(viewport_size: Vector2, panel_count: int = 4) -> Array[Rect2]:
	var ui_scale := TOY_UI.ui_scale(viewport_size)
	var footprint := (PANEL_MARGIN + PANEL_SIZE + Vector2.ONE * CAMERA_OCCLUSION_GUTTER) * ui_scale
	var right := maxf(viewport_size.x - footprint.x, 0.0)
	var bottom := maxf(viewport_size.y - footprint.y, 0.0)
	var all_rects: Array[Rect2] = [
		Rect2(Vector2.ZERO, footprint),
		Rect2(Vector2(right, 0.0), footprint),
		Rect2(Vector2(0.0, bottom), footprint),
		Rect2(Vector2(right, bottom), footprint),
	]
	return all_rects.slice(0, clampi(panel_count, 0, all_rects.size()))

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

	var style := TOY_UI.panel_style(accent, 0.72, TOY_UI.PANEL_RADIUS, 1, 3)
	panel.add_theme_stylebox_override("panel", style)

	var accent_rail := ColorRect.new()
	accent_rail.name = "PlayerAccent"
	accent_rail.position = Vector2(3, 6)
	accent_rail.size = Vector2(4, 60)
	accent_rail.color = accent
	accent_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent_rail)

	var avatar = Panel.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(11, 15)
	avatar.size = Vector2(42, 42)
	avatar.add_theme_stylebox_override("panel", _round_style(accent.darkened(0.06), TOY_UI.CREAM, 21, 1))
	panel.add_child(avatar)

	var visor = Panel.new()
	visor.name = "Visor"
	visor.position = Vector2(8, 14)
	visor.size = Vector2(27, 15)
	visor.add_theme_stylebox_override("panel", _round_style(TOY_UI.INK, Color(TOY_UI.CREAM.r, TOY_UI.CREAM.g, TOY_UI.CREAM.b, 0.22), 5, 1))
	avatar.add_child(visor)

	for eye_index in range(2):
		var eye := Panel.new()
		eye.name = "Eye%d" % (eye_index + 1)
		eye.position = Vector2(7 + eye_index * 10, 4)
		eye.size = Vector2(3, 7)
		eye.add_theme_stylebox_override("panel", _round_style(TOY_UI.GOLD, Color.TRANSPARENT, 2, 0))
		visor.add_child(eye)

	var player_tag = _make_label("PlayerTag", _player_tag(index), Vector2(59, 4), Vector2(82, 16), 13, TOY_UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(player_tag)

	var life_label = _make_label("LifeLabel", "x4", Vector2(155, 4), Vector2(34, 16), 9, TOY_UI.CREAM_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(life_label)

	var hearts: Array[Label] = []
	for i in range(_max_lives()):
		var heart = Label.new()
		heart.name = "Heart%d" % i
		heart.text = String.chr(HEART_CODE)
		heart.position = Vector2(58 + i * 18, 20)
		heart.size = Vector2(17, 18)
		heart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heart.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		heart.add_theme_font_size_override("font_size", 16)
		heart.add_theme_color_override("font_color", TOY_UI.CORAL)
		panel.add_child(heart)
		hearts.append(heart)

	var divider := ColorRect.new()
	divider.name = "InformationDivider"
	divider.position = Vector2(58, 41)
	divider.size = Vector2(131, 1)
	divider.color = Color(TOY_UI.CREAM.r, TOY_UI.CREAM.g, TOY_UI.CREAM.b, 0.14)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(divider)

	var weapon_icon = WEAPON_ICON_SCRIPT.new()
	weapon_icon.name = "WeaponSilhouette"
	weapon_icon.position = Vector2(58, 45)
	weapon_icon.size = Vector2(66, 21)
	weapon_icon.set_weapon("pistol", accent)
	panel.add_child(weapon_icon)

	var weapon_name = _make_label("WeaponName", "PISTOL", Vector2(127, 43), Vector2(62, 11), 8, TOY_UI.CREAM_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(weapon_name)

	var ammo_label = _make_label("AmmoLabel", "INF", Vector2(127, 53), Vector2(62, 15), 11, TOY_UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	panel.add_child(ammo_label)

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
	var ui_scale := TOY_UI.ui_scale(viewport_size)
	var scaled_panel_size := PANEL_SIZE * ui_scale
	var scaled_margin := PANEL_MARGIN * ui_scale
	for i in range(_panel_data.size()):
		var panel = _panel_data[i].get("panel") as Control
		if panel == null:
			continue
		panel.scale = Vector2.ONE * ui_scale
		match i:
			0:
				panel.position = scaled_margin
			1:
				panel.position = Vector2(viewport_size.x - scaled_panel_size.x - scaled_margin.x, scaled_margin.y)
			2:
				panel.position = Vector2(scaled_margin.x, viewport_size.y - scaled_panel_size.y - scaled_margin.y)
			_:
				panel.position = viewport_size - scaled_panel_size - scaled_margin

func _update_hearts(data: Dictionary, lives: int) -> void:
	var hearts = data.get("hearts") as Array
	for i in range(hearts.size()):
		var heart = hearts[i] as Label
		if heart == null:
			continue
		var active = i < lives
		heart.add_theme_color_override(
			"font_color",
			TOY_UI.CORAL if active else Color(TOY_UI.CORAL.r, TOY_UI.CORAL.g, TOY_UI.CORAL.b, 0.20)
		)

func _update_life_label(data: Dictionary, lives: int) -> void:
	var life_label = data.get("life_label") as Label
	if life_label == null:
		return
	life_label.text = "x%d" % max(lives, 0)
	life_label.add_theme_color_override("font_color", TOY_UI.CREAM_DIM if lives > 1 else TOY_UI.CORAL)

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
		ammo_label.add_theme_color_override("font_color", TOY_UI.CREAM_DIM if infinite_ammo else TOY_UI.CREAM)

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
	label.add_theme_color_override("font_shadow_color", Color(TOY_UI.INK.r, TOY_UI.INK.g, TOY_UI.INK.b, 0.28))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _round_style(bg: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	return TOY_UI.inset_style(bg, border, bg.a, radius, border_width)

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
			"gatling":
				name = "GATLING"
			"shotgun":
				name = "SHOTGUN"
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
		"gatling":
			return Color("#ffd34d")
		"shotgun":
			return Color("#d884ff")
		_:
			return Color("#ff6b72")

func _max_lives() -> int:
	return 4
