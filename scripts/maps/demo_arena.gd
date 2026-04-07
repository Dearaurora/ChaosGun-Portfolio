extends Node3D
## demo_arena 的胜负判定脚本 —— 挂在 DemoArena 根节点

var _characters: Array = []
var _victory_screen: CanvasLayer = null
var _match_ended := false

func _ready() -> void:
	# 等一帧让子节点都 ready
	await get_tree().process_frame
	_setup_victory_screen()
	_connect_characters()

func _setup_victory_screen() -> void:
	var vs_script = load("res://scripts/ui/victory_screen.gd")
	_victory_screen = CanvasLayer.new()
	_victory_screen.set_script(vs_script)
	add_child(_victory_screen)

func _connect_characters() -> void:
	for child in get_children():
		if child is BaseCharacter:
			child.eliminated.connect(_on_character_eliminated)
			_characters.append(child)

func _on_character_eliminated(character: BaseCharacter) -> void:
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
