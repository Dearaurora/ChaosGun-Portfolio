extends SceneTree

const PRESET_SCRIPT = preload("res://scripts/playtest/commercial_slice_playtest_preset.gd")
const DEFAULT_PROFILE_PATH := "res://resources/feel_profiles/ringout_push.json"

func _initialize() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		push_error("MatchConfig autoload missing")
		quit(1)
		return

	var preset = PRESET_SCRIPT.new()
	preset.apply_default_preset(match_config)
	var profile_path = _get_arg_value("--profile=", DEFAULT_PROFILE_PATH)
	var game_config = root.get_node_or_null("GameConfig")
	if not preset.apply_feel_profile(game_config, profile_path):
		quit(1)
		return
	print("Commercial Slice playtest profile: ", profile_path)

	var scene_path = match_config.call("get_selected_map_path") as String
	if scene_path.is_empty():
		push_error("Commercial Slice playtest preset did not resolve a map path")
		quit(1)
		return

	change_scene_to_file(scene_path)

func _get_arg_value(prefix: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return fallback
