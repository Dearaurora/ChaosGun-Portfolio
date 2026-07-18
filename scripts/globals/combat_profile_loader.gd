extends RefCounted
class_name CombatProfileLoader

const PARTY_SHOOTER_V1_PATH := "res://resources/feel_profiles/party_shooter_v1.json"

static func apply_party_shooter_v1(game_config: Node) -> bool:
	return apply_profile(game_config, PARTY_SHOOTER_V1_PATH)

static func apply_profile(game_config: Node, profile_path: String) -> bool:
	if game_config == null:
		push_error("Combat profile cannot be applied without GameConfig.")
		return false
	if not FileAccess.file_exists(profile_path):
		push_error("Combat profile not found: %s" % profile_path)
		return false

	var file := FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		push_error("Combat profile could not be opened: %s" % profile_path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Combat profile is not a JSON object: %s" % profile_path)
		return false

	var profile := parsed as Dictionary
	var config_values = profile.get("game_config", {})
	if not (config_values is Dictionary):
		push_error("Combat profile game_config must be an object: %s" % profile_path)
		return false
	for raw_key in config_values.keys():
		var key := String(raw_key)
		if key not in game_config:
			push_error("Combat profile contains unknown GameConfig property: %s" % key)
			return false
		game_config.set(key, config_values[raw_key])

	var weapon_overrides = profile.get("weapon_feel_overrides", {})
	if not (weapon_overrides is Dictionary):
		push_error("Combat profile weapon_feel_overrides must be an object: %s" % profile_path)
		return false
	game_config.set("weapon_feel_overrides", (weapon_overrides as Dictionary).duplicate(true))
	game_config.set_meta("combat_profile_id", String(profile.get("id", profile_path.get_file().get_basename())))
	game_config.set_meta("combat_profile_path", profile_path)
	return true
