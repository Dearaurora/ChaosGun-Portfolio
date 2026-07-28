extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const MAX_SLOTS := 4

@onready var _page: Control = $CharacterSelectRoot/SafeArea/Page
@onready var _map_label: Label = $CharacterSelectRoot/SafeArea/Page/FooterRail/MapSelector/MapContent/MapInfo/MapLabel
@onready var _map_dots: Label = $CharacterSelectRoot/SafeArea/Page/FooterRail/MapSelector/MapContent/MapInfo/MapDots
@onready var _start_button: Button = $CharacterSelectRoot/SafeArea/Page/FooterRail/StartBlock/StartButton
@onready var _start_reason: Label = $CharacterSelectRoot/SafeArea/Page/FooterRail/StartBlock/StartReason
@onready var _back_button: Button = $CharacterSelectRoot/SafeArea/Page/FooterRail/BackButton
@onready var _previous_button: Button = $CharacterSelectRoot/SafeArea/Page/FooterRail/MapSelector/MapContent/PreviousButton
@onready var _next_button: Button = $CharacterSelectRoot/SafeArea/Page/FooterRail/MapSelector/MapContent/NextButton

var _slots: Array = []
var _slot_cards: Array[PlayerSlotCard] = []
var _status_cards: Array[RosterStatusCard] = []


func _ready() -> void:
	MatchConfig.configure_local_match()
	_slots = MatchConfig.slots.duplicate()
	_slot_cards = [
		$CharacterSelectRoot/SafeArea/Page/StageArea/SlotRow/CardP1,
		$CharacterSelectRoot/SafeArea/Page/StageArea/SlotRow/CardP2,
		$CharacterSelectRoot/SafeArea/Page/StageArea/SlotRow/CardP3,
		$CharacterSelectRoot/SafeArea/Page/StageArea/SlotRow/CardP4,
	]
	_status_cards = [
		$CharacterSelectRoot/SafeArea/Page/RosterStatusRow/StatusP1,
		$CharacterSelectRoot/SafeArea/Page/RosterStatusRow/StatusP2,
		$CharacterSelectRoot/SafeArea/Page/RosterStatusRow/StatusP3,
		$CharacterSelectRoot/SafeArea/Page/RosterStatusRow/StatusP4,
	]
	for index in range(MAX_SLOTS):
		_slot_cards[index].slot_change_requested.connect(_on_set_slot)
	_back_button.pressed.connect(_on_back)
	_previous_button.pressed.connect(_on_map_prev)
	_next_button.pressed.connect(_on_map_next)
	_start_button.pressed.connect(_on_start)
	TOY_UI.apply_button(_back_button, TOY_UI.CORAL, false, 16)
	TOY_UI.apply_button(_previous_button, TOY_UI.CREAM_DIM, false, 18)
	TOY_UI.apply_button(_next_button, TOY_UI.CREAM_DIM, false, 18)
	TOY_UI.apply_button(_start_button, TOY_UI.GOLD, true, 20)
	_refresh()
	_start_button.grab_focus()
	_play_enter_transition()


func _refresh() -> void:
	for index in range(MAX_SLOTS):
		_slot_cards[index].configure(index, int(_slots[index]))
		_status_cards[index].configure(index, int(_slots[index]))
	_refresh_map()
	var active_count := _active_count()
	_start_button.disabled = active_count < 2
	_start_reason.text = "" if active_count >= 2 else "至少需要 2 名参赛者"


func _refresh_map() -> void:
	var map_count := MatchConfig.MAPS.size()
	_map_label.text = MatchConfig.get_selected_map_name().to_upper()
	var dots: Array[String] = []
	for index in range(map_count):
		dots.append("●" if index == MatchConfig.selected_map_index else "○")
	_map_dots.text = "  ".join(dots)
	var can_cycle := map_count > 1
	_previous_button.disabled = not can_cycle
	_next_button.disabled = not can_cycle


func _active_count() -> int:
	var count := 0
	for slot in _slots:
		if slot != MatchConfig.SlotType.EMPTY:
			count += 1
	return count


func _on_set_slot(index: int, slot_type: int) -> void:
	_slots[index] = slot_type
	_refresh()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_start() -> void:
	if _active_count() < 2:
		return
	MatchConfig.configure_local_match()
	MatchConfig.slots = _slots.duplicate()
	get_tree().change_scene_to_file(MatchConfig.get_selected_map_path())


func _on_map_prev() -> void:
	if MatchConfig.MAPS.size() <= 1:
		return
	MatchConfig.selected_map_index = posmod(MatchConfig.selected_map_index - 1, MatchConfig.MAPS.size())
	_refresh_map()


func _on_map_next() -> void:
	if MatchConfig.MAPS.size() <= 1:
		return
	MatchConfig.selected_map_index = (MatchConfig.selected_map_index + 1) % MatchConfig.MAPS.size()
	_refresh_map()


func _play_enter_transition() -> void:
	_page.modulate.a = 0.0
	_page.position.y += 14.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_page, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_page, "position:y", _page.position.y - 14.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
