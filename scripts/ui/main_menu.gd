extends CanvasLayer

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")

@onready var _content: Control = $MainMenuRoot/SafeArea/Layout
@onready var _quick_button: Button = $MainMenuRoot/SafeArea/Layout/MenuColumn/MenuCard/MenuButtons/QuickMatchButton
@onready var _local_button: Button = $MainMenuRoot/SafeArea/Layout/MenuColumn/MenuCard/MenuButtons/LocalMatchButton
@onready var _keys_button: Button = $MainMenuRoot/SafeArea/Layout/MenuColumn/MenuCard/MenuButtons/KeybindsButton


func _ready() -> void:
	_quick_button.pressed.connect(_on_vs_ai)
	_local_button.pressed.connect(_on_local_battle)
	_keys_button.pressed.connect(_on_keybinds)
	TOY_UI.apply_button(_quick_button, TOY_UI.GOLD, true, 20)
	TOY_UI.apply_button(_local_button, TOY_UI.SKY, false, 18)
	TOY_UI.apply_button(_keys_button, TOY_UI.CREAM_DIM, false, 18)
	_quick_button.grab_focus()
	_play_enter_transition()


func _play_enter_transition() -> void:
	_content.modulate.a = 0.0
	_content.position.y += 18.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_content, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_content, "position:y", _content.position.y - 18.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_vs_ai() -> void:
	MatchConfig.configure_quick_ai_match()
	get_tree().change_scene_to_file(MatchConfig.get_selected_map_path())


func _on_local_battle() -> void:
	MatchConfig.configure_local_match()
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")


func _on_keybinds() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/keybinds_screen.tscn")
