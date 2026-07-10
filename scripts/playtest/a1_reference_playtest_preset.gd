extends RefCounted

const A1_MAP_PATH := "res://scenes/maps/a1_reference_basin.tscn"

func apply_default_preset(match_config: Node) -> void:
	if match_config == null:
		return

	match_config.set("slots", [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	])

	var maps = match_config.get("MAPS") as Array
	for i in range(maps.size()):
		var entry = maps[i] as Array
		if entry.size() >= 2 and String(entry[1]) == A1_MAP_PATH:
			match_config.set("selected_map_index", i)
			return
