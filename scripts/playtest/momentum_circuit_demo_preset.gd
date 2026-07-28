extends RefCounted

const DEMO_MAP_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const PRESET_ID := "momentum_circuit_public_demo_v3"


func apply_default_preset(match_config: Node) -> bool:
	if match_config == null:
		return false
	match_config.set("slots", [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	])
	match_config.set("match_mode", match_config.MatchMode.LOCAL_CUSTOM)
	var maps := match_config.get("MAPS") as Array
	for index in range(maps.size()):
		var entry := maps[index] as Array
		if entry.size() >= 2 and String(entry[1]) == DEMO_MAP_PATH:
			match_config.set("selected_map_index", index)
			break
	match_config.set_meta("playtest_preset_id", PRESET_ID)
	return true
