extends Node
## 全局对战配置 —— 在选角界面和对战场景之间传递数据

## 槽位类型
enum SlotType { EMPTY, HUMAN, AI }

## 每个槽位的配置
var slots: Array = [SlotType.HUMAN, SlotType.AI, SlotType.EMPTY, SlotType.EMPTY]

## 玩家颜色
var PLAYER_COLORS: Array = [
	Color(0.2, 0.45, 1.0),    # P1 蓝
	Color(1.0, 0.4, 0.25),    # P2 橙
	Color(0.3, 0.85, 0.4),    # P3 绿
	Color(0.9, 0.3, 0.8),     # P4 紫
]

## P1/P2 的输入前缀映射
var INPUT_PREFIXES: Array = ["p1_", "p2_", "", ""]

## 获取活跃槽位数量
func get_active_count() -> int:
	var count := 0
	for s in slots:
		if s != SlotType.EMPTY:
			count += 1
	return count

## 获取第 n 个 human 玩家的输入前缀（按槽位顺序分配 p1_, p2_）
func get_human_input_prefix(slot_index: int) -> String:
	var human_idx := 0
	for i in range(slot_index):
		if slots[i] == SlotType.HUMAN:
			human_idx += 1
	if human_idx < INPUT_PREFIXES.size():
		return INPUT_PREFIXES[human_idx]
	return ""
