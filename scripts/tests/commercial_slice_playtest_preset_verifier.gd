extends SceneTree

const PRESET_SCRIPT_PATH := "res://scripts/playtest/commercial_slice_playtest_preset.gd"
const EXPECTED_MAP_PATH := "res://scenes/maps/commercial_slice_a.tscn"
const EXPECTED_PROFILES := [
	{
		"path": "res://resources/feel_profiles/ringout_push.json",
		"weapon": "pistol",
		"knockback_power": 145.0,
	},
	{
		"path": "res://resources/feel_profiles/candidate_v1.json",
		"weapon": "pistol",
		"knockback_power": 138.0,
	},
]

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Commercial Slice Playtest Preset Verifier]")
	print("==================================================")

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		await _finish()
		return

	var preset_script = load(PRESET_SCRIPT_PATH)
	if preset_script == null:
		_fail("Could not load %s" % PRESET_SCRIPT_PATH)
		await _finish()
		return

	var preset = preset_script.new()
	if preset == null:
		_fail("Could not instantiate Commercial Slice playtest preset")
		await _finish()
		return

	if not preset.has_method("apply_default_preset"):
		_fail("Preset is missing apply_default_preset")
		await _finish()
		return
	if not preset.has_method("apply_feel_profile"):
		_fail("Preset is missing apply_feel_profile")
		await _finish()
		return

	preset.call("apply_default_preset", match_config)

	var expected_slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	]
	if match_config.slots != expected_slots:
		_fail("Playtest preset slots do not match expected human-vs-AI layout")
	else:
		print("OK  slots -> ", match_config.slots)

	var selected_map_path = match_config.call("get_selected_map_path") as String
	if selected_map_path != EXPECTED_MAP_PATH:
		_fail("Playtest preset did not select Commercial Slice A")
	else:
		print("OK  map -> ", selected_map_path)

	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload missing")
		await _finish()
		return

	for expected_profile in EXPECTED_PROFILES:
		_verify_profile_application(preset, game_config, expected_profile)

	await _finish()

func _verify_profile_application(preset: RefCounted, game_config: Node, expected_profile: Dictionary) -> void:
	var profile_path = String(expected_profile.get("path", ""))
	preset.call("apply_feel_profile", game_config, profile_path)
	var overrides = game_config.get("weapon_feel_overrides")
	if not (overrides is Dictionary):
		_fail("Profile did not apply weapon_feel_overrides: %s" % profile_path)
		return
	var weapon_id = String(expected_profile.get("weapon", ""))
	var weapon_values = overrides.get(weapon_id, {})
	var expected_knockback = float(expected_profile.get("knockback_power", 0.0))
	if not (weapon_values is Dictionary) or not is_equal_approx(float(weapon_values.get("knockback_power", 0.0)), expected_knockback):
		_fail("Profile did not apply %s knockback for %s" % [weapon_id, profile_path])
	else:
		print("OK  profile -> ", profile_path)
	var expected_id = profile_path.get_file().get_basename()
	if String(game_config.get_meta("feel_profile_id", "")) != expected_id:
		_fail("Profile did not set feel_profile_id metadata for %s" % profile_path)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print("[Commercial Slice Playtest Preset Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Commercial Slice Playtest Preset Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
