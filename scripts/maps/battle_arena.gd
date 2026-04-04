extends Node3D
## 动态对战场景 —— 根据 MatchConfig 生成玩家和 AI

@onready var weapon_spawner = $WeaponSpawner

const PLAYER_SCENE = preload("res://scenes/characters/player.tscn")
const AI_SCENE = preload("res://scenes/characters/ai_character.tscn")

## 出生点（最多 4 个）
const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-15, 0.5, -10),
	Vector3(15, 0.5, -10),
	Vector3(-15, 0.5, 10),
	Vector3(15, 0.5, 10),
]

var _characters: Array[BaseCharacter] = []

func _ready() -> void:
	_spawn_characters()
	# HUD 挂在第一个人类玩家身上（如果有的话）
	_setup_hud()

func _spawn_characters() -> void:
	var human_index := 0  # 用于分配输入前缀 p1_, p2_

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
			# AI
			character = AI_SCENE.instantiate()

		character.transform.origin = spawn_pos

		# 设置颜色
		add_child(character)
		_apply_color(character, i)
		_characters.append(character)

func _apply_color(character: BaseCharacter, slot_index: int) -> void:
	var color = MatchConfig.PLAYER_COLORS[slot_index]
	# 延迟设置颜色，等 Visual 节点 ready
	await get_tree().process_frame
	var visual = character.get_visual()
	if visual and visual.has_method("set_body_color"):
		visual.set_body_color(color)

func _setup_hud() -> void:
	# 找到第一个人类玩家，把 HUD 挂上去
	for c in _characters:
		if c is PlayerCharacter:
			# HUD 已经在 player.tscn 里了，不用额外挂
			break
