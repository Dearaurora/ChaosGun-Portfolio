extends PanelContainer
class_name RosterStatusCard

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

@onready var _portrait: TextureRect = $Content/Portrait
@onready var _player_label: Label = $Content/Info/Top/PlayerLabel
@onready var _slot_label: Label = $Content/Info/Top/SlotLabel
@onready var _hearts: Label = $Content/Info/Hearts
@onready var _weapon_icon: TextureRect = $Content/Info/Weapon/WeaponIcon
@onready var _weapon_name: Label = $Content/Info/Weapon/WeaponName
@onready var _ammo: Label = $Content/Info/Weapon/Ammo


func configure(index: int, slot_type: int) -> void:
	var accent := TOY_UI.player_color(index)
	var active := slot_type != MatchConfig.SlotType.EMPTY
	add_theme_stylebox_override("panel", TOY_UI.panel_style(accent, 0.68 if active else 0.42, 12, 1, 2))
	_player_label.text = "P%d" % (index + 1)
	_player_label.add_theme_color_override("font_color", accent)
	_slot_label.text = "玩家" if slot_type == MatchConfig.SlotType.HUMAN else ("AI" if active else "空位")
	_portrait.visible = active
	_weapon_icon.visible = active
	_hearts.visible = active
	_weapon_name.visible = active
	_ammo.visible = active
	if active:
		_portrait.texture = load("res://assets/ui/generated/characters/character_p%d_pistol.png" % (index + 1))
		_weapon_icon.texture = load("res://assets/ui/generated/weapons/pistol.png")
		_hearts.text = "♥ ♥ ♥ ♥"
		_weapon_name.text = "手枪"
		_ammo.text = "∞"
