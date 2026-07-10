extends RefCounted

const COMMERCIAL_SLICE_MAP_PATH := "res://scenes/maps/commercial_slice_a.tscn"

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
		if entry.size() >= 2 and String(entry[1]) == COMMERCIAL_SLICE_MAP_PATH:
			match_config.set("selected_map_index", i)
			return

func apply_feel_profile(game_config: Node, profile_path: String) -> bool:
	if game_config == null:
		return false
	if profile_path.is_empty():
		return true
	if not FileAccess.file_exists(profile_path):
		push_error("Feel profile not found: %s" % profile_path)
		return false
	var file = FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		push_error("Could not open feel profile: %s" % profile_path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Feel profile is not a JSON object: %s" % profile_path)
		return false
	var profile = parsed as Dictionary
	game_config.set_meta("feel_profile_id", String(profile.get("id", profile_path.get_file().get_basename())))
	game_config.set_meta("feel_profile_label", String(profile.get("label", game_config.get_meta("feel_profile_id"))))
	game_config.set_meta("feel_profile_path", profile_path)
	var config_values = profile.get("game_config", {})
	if config_values is Dictionary:
		for key in config_values.keys():
			if String(key) in game_config:
				game_config.set(String(key), config_values[key])
	var weapon_overrides = profile.get("weapon_feel_overrides", {})
	if weapon_overrides is Dictionary:
		game_config.set("weapon_feel_overrides", weapon_overrides)
	return true
