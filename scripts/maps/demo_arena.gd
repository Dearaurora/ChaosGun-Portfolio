extends Node3D
## demo_arena 的胜负判定脚本

var _characters: Array = []
var _victory_screen: CanvasLayer = null
var _match_ended := false

const CONTROL_MODE_PANEL_SCRIPT = preload("res://scripts/ui/control_mode_panel.gd")

func _ready() -> void:
	await get_tree().process_frame
	_setup_victory_screen()
	_setup_control_mode_panel()
	_connect_characters()

func _setup_victory_screen() -> void:
	_victory_screen = VictoryScreen.new()
	add_child(_victory_screen)

func _setup_control_mode_panel() -> void:
	var panel = CONTROL_MODE_PANEL_SCRIPT.new()
	add_child(panel)

func _connect_characters() -> void:
	for child in get_children():
		if child is BaseCharacter:
			child.eliminated.connect(_on_character_eliminated)
			_characters.append(child)

func _on_character_eliminated(_character: BaseCharacter) -> void:
	if _match_ended:
		return

	var survivors: Array = []
	for c in _characters:
		if not c.is_game_over:
			survivors.append(c)

	if survivors.size() <= 1:
		_match_ended = true
		if survivors.size() == 1:
			var winner = survivors[0]
			var winner_name: String = "Player" if winner is PlayerCharacter else "AI Bot"
			_victory_screen.show_victory(winner_name, Color(0.2, 0.45, 1.0))
		else:
			_victory_screen.show_victory("DRAW", Color.WHITE)
