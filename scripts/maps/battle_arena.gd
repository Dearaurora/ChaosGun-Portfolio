extends Node3D
## 动态对战场景 —— 根据 MatchConfig 生成玩家和 AI

@onready var weapon_spawner = $WeaponSpawner

const PLAYER_SCENE = preload("res://scenes/characters/player.tscn")
const AI_SCENE = preload("res://scenes/characters/ai_character.tscn")

## 出生点（最多 4 个）
var SPAWN_POINTS := [
	Vector3(-15, 0.5, -10),
	Vector3(15, 0.5, -10),
	Vector3(-15, 0.5, 10),
	Vector3(15, 0.5, 10),
]

var _characters: Array = []
var _victory_screen: CanvasLayer = null
var _match_ended := false

func _ready() -> void:
	_spawn_characters()
	_setup_hud()
	_setup_victory_screen()

func _spawn_characters() -> void:
	var human_index := 0

	for i in range(MatchConfig.slots.size()):
		var slot = MatchConfig.slots[i]
		if slot == MatchConfig.SlotType.EMPTY:
			continue

		var character: BaseCharacter
		var spawn_pos = SPAWN_POINTS[i] if i < SPAWN_POINTS.size() else Vector3(i * 8, 0.5, 0)

		if slot == MatchConfig.SlotType.HUMAN:
			var player_instance = PLAYER_SCENE.instantiate()
			player_instance.input_prefix = MatchConfig.INPUT_PREFIXES[human_index] if human_index < MatchConfig.INPUT_PREFIXES.size() else "p1_"
			player_instance.slot_index = i
			human_index += 1
			character = player_instance
		else:
			character = AI_SCENE.instantiate()

		character.transform.origin = spawn_pos
		character.name = _get_character_name(i, slot)

		add_child(character)
		# 连接淘汰信号
		character.eliminated.connect(_on_character_eliminated)
		_apply_color(character, i)
		_characters.append(character)

func _get_character_name(index: int, slot_type: int) -> String:
	if slot_type == MatchConfig.SlotType.HUMAN:
		return "Player %d" % (index + 1)
	else:
		return "AI Bot %d" % (index + 1)

func _apply_color(character: BaseCharacter, slot_index: int) -> void:
	var color = MatchConfig.PLAYER_COLORS[slot_index]
	await get_tree().process_frame
	var visual = character.get_visual()
	if visual and visual.has_method("set_body_color"):
		visual.set_body_color(color)

func _setup_hud() -> void:
	for c in _characters:
		if c is PlayerCharacter:
			break

func _setup_victory_screen() -> void:
	var vs_script = load("res://scripts/ui/victory_screen.gd")
	_victory_screen = CanvasLayer.new()
	_victory_screen.set_script(vs_script)
	add_child(_victory_screen)

# ------------------------------------------------------------------
#  淘汰信号回调
# ------------------------------------------------------------------
func _on_character_eliminated(character: BaseCharacter) -> void:
	if _match_ended:
		return

	# 统计存活者
	var survivors: Array = []
	for c in _characters:
		if not c.is_game_over:
			survivors.append(c)

	if survivors.size() <= 1:
		_match_ended = true
		if survivors.size() == 1:
			var winner = survivors[0]
			var winner_name: String = winner.name
			var slot_index := _characters.find(winner)
			var winner_color: Color = MatchConfig.PLAYER_COLORS[slot_index] if slot_index < MatchConfig.PLAYER_COLORS.size() else Color.WHITE
			_victory_screen.show_victory(winner_name, winner_color)
		else:
			# 全灭（理论上不会发生）
			_victory_screen.show_victory("DRAW", Color.WHITE)
