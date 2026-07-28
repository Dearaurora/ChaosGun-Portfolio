extends PanelContainer
class_name PlayerSlotCard

signal slot_change_requested(slot_index: int, slot_type: int)

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

@export_range(0, 3) var slot_index := 0

@onready var _player_label: Label = $Content/Header/PlayerLabel
@onready var _type_label: Label = $Content/Header/TypeLabel
@onready var _remove_button: Button = $Content/Header/RemoveButton
@onready var _portrait: TextureRect = $Content/HeroArea/Portrait
@onready var _empty_state: CenterContainer = $Content/HeroArea/EmptyState
@onready var _empty_label: Label = $Content/HeroArea/EmptyState/EmptyContent/EmptyLabel
@onready var _human_button: Button = $Content/Actions/HumanButton
@onready var _ai_button: Button = $Content/Actions/AIButton
@onready var _accent_line: ColorRect = $Content/AccentLine


func _ready() -> void:
	_human_button.pressed.connect(_request_change.bind(MatchConfig.SlotType.HUMAN))
	_ai_button.pressed.connect(_request_change.bind(MatchConfig.SlotType.AI))
	_remove_button.pressed.connect(_request_change.bind(MatchConfig.SlotType.EMPTY))


func configure(index: int, slot_type: int) -> void:
	slot_index = index
	var accent := TOY_UI.player_color(index)
	var active := slot_type != MatchConfig.SlotType.EMPTY
	_player_label.text = "P%d" % (index + 1)
	_player_label.add_theme_color_override("font_color", accent)
	_accent_line.color = accent
	var panel_style := TOY_UI.panel_style(accent, 0.60 if active else 0.42, 14, 1, 4)
	if active and index < 2:
		panel_style.bg_color = Color(TOY_UI.INK.r, TOY_UI.INK.g, TOY_UI.INK.b, 0.14)
		panel_style.border_width_left = 0
		panel_style.border_width_top = 0
		panel_style.border_width_right = 0
		panel_style.border_width_bottom = 0
		panel_style.shadow_size = 0
	add_theme_stylebox_override("panel", panel_style)

	_portrait.visible = active
	_empty_state.visible = not active
	_remove_button.visible = active
	_human_button.visible = not active
	_ai_button.visible = not active
	_type_label.visible = true
	_type_label.text = "玩家" if slot_type == MatchConfig.SlotType.HUMAN else ("AI" if active else "空位")
	_empty_label.text = "空位"

	if active:
		_portrait.texture = load("res://assets/ui/generated/characters/character_p%d_pistol.png" % (index + 1))
		TOY_UI.apply_button(_remove_button, accent, false, 13)
	else:
		TOY_UI.apply_button(_human_button, accent, false, 14)
		TOY_UI.apply_button(_ai_button, accent, false, 14)


func _request_change(slot_type: int) -> void:
	slot_change_requested.emit(slot_index, slot_type)
