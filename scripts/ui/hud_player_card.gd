extends Panel
class_name HudPlayerCard

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

var _character: BaseCharacter = null
var _slot_index := 0
var _accent := Color.WHITE
var _weapon_id := ""

@onready var _avatar: TextureRect = $Avatar
@onready var _player_tag: Label = $PlayerTag
@onready var _life_label: Label = $LifeLabel
@onready var _hearts: Label = $Hearts
@onready var _weapon_icon: TextureRect = $WeaponSilhouette
@onready var _weapon_name: Label = $WeaponName
@onready var _ammo_label: Label = $AmmoLabel
@onready var _accent_rail: ColorRect = $PlayerAccent


func configure(character: BaseCharacter, slot_index: int) -> void:
	_character = character
	_slot_index = slot_index
	_accent = TOY_UI.player_color(slot_index)
	_accent_rail.color = _accent
	add_theme_stylebox_override("panel", TOY_UI.panel_style(_accent, 0.82, 12, 1, 4))
	_avatar.texture = load("res://assets/ui/generated/characters/character_p%d_pistol.png" % (slot_index + 1))
	var is_ai := character is AICharacter or character.is_in_group("ai")
	_player_tag.text = "P%d  %s" % [slot_index + 1, "AI" if is_ai else "玩家"]
	_player_tag.add_theme_color_override("font_color", _accent.lightened(0.12))
	_update_character_state()


func _process(_delta: float) -> void:
	_update_character_state()


func _update_character_state() -> void:
	if _character == null or not is_instance_valid(_character):
		return
	var lives := maxi(_character.lives, 0)
	_life_label.text = "x%d" % lives
	_life_label.add_theme_color_override("font_color", TOY_UI.CORAL if lives <= 1 else TOY_UI.CREAM_DIM)
	var filled := "♥".repeat(mini(lives, 4))
	var empty := "♡".repeat(maxi(4 - lives, 0))
	_hearts.text = filled + empty
	_hearts.add_theme_color_override("font_color", TOY_UI.CORAL if lives > 1 else TOY_UI.GOLD)
	_update_weapon()


func _update_weapon() -> void:
	var weapon_id := "pistol"
	var display_name := "手枪"
	var ammo_text := "INF"
	var ammo := -1
	var magazine := -1
	if _character.weapon_manager and _character.weapon_manager.current_weapon and _character.weapon_manager.current_weapon.weapon_data:
		var data = _character.weapon_manager.current_weapon.weapon_data
		weapon_id = String(data.weapon_id)
		display_name = _weapon_display_name(weapon_id, String(data.weapon_name))
		magazine = int(data.magazine_size)
		if not data.has_infinite_ammo and magazine >= 0:
			ammo = maxi(_character.weapon_manager.get_current_ammo(), 0)
			ammo_text = "%d/%d" % [ammo, magazine]
	_weapon_name.text = display_name
	_ammo_label.text = ammo_text
	if ammo >= 0 and magazine > 0 and ammo <= ceili(float(magazine) * 0.25):
		_ammo_label.add_theme_color_override("font_color", TOY_UI.CORAL if ammo == 0 else TOY_UI.GOLD)
	else:
		_ammo_label.add_theme_color_override("font_color", TOY_UI.CREAM)
	if _weapon_id == weapon_id:
		return
	_weapon_id = weapon_id
	var texture_path := "res://assets/ui/generated/weapons/%s.png" % weapon_id
	if _weapon_icon.has_method("set_weapon"):
		_weapon_icon.call("set_weapon", weapon_id, _accent)
	else:
		_weapon_icon.texture = load(texture_path) if ResourceLoader.exists(texture_path) else load("res://assets/ui/generated/weapons/pistol.png")


func _weapon_display_name(weapon_id: String, fallback: String) -> String:
	match weapon_id:
		"pistol":
			return "手枪"
		"smg":
			return "冲锋枪"
		"ak_rifle":
			return "突击步枪"
		"sniper":
			return "狙击枪"
		"shotgun":
			return "霰弹枪"
		"gatling":
			return "加特林"
		_:
			return fallback if not fallback.is_empty() else weapon_id.to_upper()
