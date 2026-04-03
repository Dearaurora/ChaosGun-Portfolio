extends CanvasLayer
## 临时调试 HUD：武器信息 + 生命数

var _weapon_label: Label
var _life_label: Label
var _game_over_label: Label

func _ready() -> void:
	# 武器信息（左上角）
	_weapon_label = Label.new()
	_weapon_label.position = Vector2(20, 20)
	_weapon_label.add_theme_font_size_override("font_size", 28)
	_weapon_label.add_theme_color_override("font_color", Color.WHITE)
	_weapon_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_weapon_label.add_theme_constant_override("shadow_offset_x", 2)
	_weapon_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_weapon_label)

	# 生命数（左上角第二行）
	_life_label = Label.new()
	_life_label.position = Vector2(20, 60)
	_life_label.add_theme_font_size_override("font_size", 24)
	_life_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_life_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_life_label.add_theme_constant_override("shadow_offset_x", 2)
	_life_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_life_label)

	# Game Over（屏幕中央，默认隐藏）
	_game_over_label = Label.new()
	_game_over_label.text = "GAME OVER"
	_game_over_label.add_theme_font_size_override("font_size", 72)
	_game_over_label.add_theme_color_override("font_color", Color.RED)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.anchors_preset = Control.PRESET_CENTER
	_game_over_label.visible = false
	add_child(_game_over_label)

func _process(_delta: float) -> void:
	var player = get_parent() as PlayerCharacter
	if not player:
		return

	# 武器信息
	if player.weapon_manager:
		var wm = player.weapon_manager
		var weapon_name = wm.get_current_weapon_name()
		var ammo = wm.get_current_ammo()
		var ammo_text = "∞" if ammo == -1 else str(ammo)
		var slot_text = "[1]" if wm.current_weapon == wm.sidearm else "[2]"
		_weapon_label.text = "%s  %s  %s" % [slot_text, weapon_name, ammo_text]

	# 生命数
	_life_label.text = "❤ %d / 10" % player.lives

	# Game Over
	if player.is_game_over:
		_game_over_label.visible = true
		_weapon_label.visible = false
