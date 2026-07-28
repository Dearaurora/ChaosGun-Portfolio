extends SceneTree

const PRESET_SCRIPT := preload("res://scripts/playtest/momentum_circuit_demo_preset.gd")


func _initialize() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	var preset := PRESET_SCRIPT.new()
	if not preset.apply_default_preset(match_config):
		push_error("Momentum Circuit Demo requires the MatchConfig autoload")
		quit(1)
		return
	var error := change_scene_to_file(PRESET_SCRIPT.DEMO_MAP_PATH)
	if error != OK:
		push_error("Could not launch Momentum Circuit Demo: %s" % error_string(error))
		quit(1)
