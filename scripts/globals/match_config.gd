extends Node
## 全局对战配置 —— 在选角界面和对战场景之间传递数据

## 槽位类型
enum SlotType { EMPTY, HUMAN, AI }
enum MatchMode { LOCAL_CUSTOM, QUICK_AI }

## 每个槽位的配置
var slots: Array = [SlotType.HUMAN, SlotType.AI, SlotType.EMPTY, SlotType.EMPTY]

## 玩家颜色
var PLAYER_COLORS: Array = [
	Color("#ef3f3f"), # P1 红
	Color("#78d23d"), # P2 绿
	Color("#24a9e8"), # P3 青
	Color("#f2bf27"), # P4 黄
]

## 四名本地玩家的输入前缀映射
var INPUT_PREFIXES: Array = ["p1_", "p2_", "p3_", "p4_"]

## 可选地图列表 [显示名, 场景路径]
var MAPS: Array = [
	["Open Ring-Out Slice", "res://scenes/maps/open_ringout_slice.tscn"],
]

## 当前选择的地图索引
var selected_map_index: int = 0
var match_mode: MatchMode = MatchMode.LOCAL_CUSTOM

func get_selected_map_path() -> String:
	_normalize_selected_map_index()
	return MAPS[selected_map_index][1]

func get_selected_map_name() -> String:
	_normalize_selected_map_index()
	return MAPS[selected_map_index][0]

func select_default_playable_map() -> void:
	selected_map_index = 0

func select_random_playable_map(forced_roll: int = -1) -> void:
	if MAPS.is_empty():
		selected_map_index = 0
		return
	var roll := forced_roll if forced_roll >= 0 else randi()
	selected_map_index = posmod(roll, MAPS.size())

func configure_quick_ai_match(forced_roll: int = -1) -> void:
	match_mode = MatchMode.QUICK_AI
	slots = [SlotType.HUMAN, SlotType.AI, SlotType.EMPTY, SlotType.EMPTY]
	select_random_playable_map(forced_roll)

func configure_local_match() -> void:
	match_mode = MatchMode.LOCAL_CUSTOM

func restart_current_match(scene_tree: SceneTree, forced_roll: int = -1) -> Error:
	scene_tree.paused = false
	if match_mode == MatchMode.QUICK_AI:
		select_random_playable_map(forced_roll)
		return scene_tree.change_scene_to_file(get_selected_map_path())
	return scene_tree.reload_current_scene()

func _normalize_selected_map_index() -> void:
	if MAPS.is_empty():
		selected_map_index = 0
		return
	selected_map_index = clampi(selected_map_index, 0, MAPS.size() - 1)

## 获取活跃槽位数量
func get_active_count() -> int:
	var count := 0
	for s in slots:
		if s != SlotType.EMPTY:
			count += 1
	return count

## 获取第 n 个 human 玩家的输入前缀（按槽位顺序分配 p1_ - p4_）
func get_human_input_prefix(slot_index: int) -> String:
	var human_idx := 0
	for i in range(slot_index):
		if slots[i] == SlotType.HUMAN:
			human_idx += 1
	if human_idx < INPUT_PREFIXES.size():
		return INPUT_PREFIXES[human_idx]
	return ""
