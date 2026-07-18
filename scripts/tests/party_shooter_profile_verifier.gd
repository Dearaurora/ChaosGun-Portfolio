extends SceneTree

const PROFILE_LOADER := preload("res://scripts/globals/combat_profile_loader.gd")
const OPEN_RINGOUT_SCENE := "res://scenes/maps/open_ringout_slice.tscn"
const TWIN_BAYS_SCENE := "res://scenes/maps/twin_bays_splash_arena.tscn"

const EXPECTED_CONFIG := {
	"default_lives": 4,
	"respawn_delay": 1.15,
	"invincible_duration": 1.5,
	"fall_threshold": -16.0,
	"control_mode": "lock_on",
	"character_speed": 620.0,
	"character_horizontal_damp": 2.4,
	"character_air_horizontal_damp": 0.25,
	"character_gravity_scale": 24.0,
	"bullet_speed_multiplier": 1.0,
	"knockback_multiplier": 1.35,
	"knockback_lift_ratio": 0.24,
	"max_recoil_impulse": 9.5,
}

const EXPECTED_WEAPONS := {
	"pistol": [92.0, 14.0, 1.45],
	"smg": [68.0, 7.0, 1.25],
	"ak_rifle": [92.0, 13.0, 1.55],
	"sniper": [330.0, 42.0, 1.9],
	"gatling": [58.0, 5.0, 1.25],
	"shotgun": [25.0, 4.5, 0.85],
}

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Party Shooter v1 Profile Verifier]")
	print("==================================================")
	var game_config := root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload is missing")
		_finish()
		return

	# Simulate a previous map leaving unrelated values behind.
	game_config.set("character_speed", 1.0)
	game_config.set("knockback_multiplier", 99.0)
	game_config.set("weapon_feel_overrides", {"stale": {"damage": 999.0}})
	if not PROFILE_LOADER.apply_party_shooter_v1(game_config):
		_fail("party_shooter_v1 could not be applied")
		_finish()
		return

	for key: String in EXPECTED_CONFIG:
		var actual = game_config.get(key)
		var expected = EXPECTED_CONFIG[key]
		if expected is float and not is_equal_approx(float(actual), float(expected)):
			_fail("%s expected %.3f, got %s" % [key, float(expected), actual])
		elif expected is int and int(actual) != int(expected):
			_fail("%s expected %d, got %s" % [key, int(expected), actual])
		elif expected is String and String(actual) != String(expected):
			_fail("%s expected %s, got %s" % [key, expected, actual])

	var overrides = game_config.get("weapon_feel_overrides")
	if not (overrides is Dictionary):
		_fail("weapon_feel_overrides was not applied as a Dictionary")
	else:
		if (overrides as Dictionary).has("stale"):
			_fail("profile application retained stale weapon overrides")
		for weapon_id: String in EXPECTED_WEAPONS:
			var values = (overrides as Dictionary).get(weapon_id, {})
			if not (values is Dictionary):
				_fail("missing override for %s" % weapon_id)
				continue
			var expected := EXPECTED_WEAPONS[weapon_id] as Array
			for index in range(3):
				var field: String = ["knockback_power", "damage", "bullet_lifetime"][index]
				if not is_equal_approx(float(values.get(field, -1.0)), float(expected[index])):
					_fail("%s.%s does not match the approved baseline" % [weapon_id, field])

	if String(game_config.get_meta("combat_profile_id", "")) != "party_shooter_v1":
		_fail("combat_profile_id metadata was not recorded")

	_verify_open_twin_open_reentry(game_config)
	_finish()

func _verify_open_twin_open_reentry(game_config: Node) -> void:
	var sequence := [
		["Open Ring-Out first entry", OPEN_RINGOUT_SCENE],
		["Twin Bays entry", TWIN_BAYS_SCENE],
		["Open Ring-Out return entry", OPEN_RINGOUT_SCENE],
	]
	for index in range(sequence.size()):
		var label := String(sequence[index][0])
		var scene_path := String(sequence[index][1])
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail("%s could not load %s" % [label, scene_path])
			continue
		var arena := packed.instantiate()
		if arena == null or not arena.has_method("_apply_shared_runtime_config"):
			_fail("%s does not expose the shared match-entry profile hook" % label)
			if arena:
				arena.free()
			continue

		_poison_profile(game_config, index)
		arena.call("_apply_shared_runtime_config")
		_verify_profile_contract(game_config, "%s shared entry" % label, true)
		# Map-local configuration may only reapply the approved lives/respawn/fall
		# values; movement, knockback, and weapon behavior must remain shared.
		arena.call("_configure_map_runtime")
		_verify_profile_contract(game_config, "%s post map overrides" % label, false)
		arena.free()

	if _failures.is_empty():
		print("OK  Open -> Twin -> Open reapplies party_shooter_v1 without cross-map pollution")

func _poison_profile(game_config: Node, index: int) -> void:
	for key: String in EXPECTED_CONFIG:
		var expected = EXPECTED_CONFIG[key]
		if expected is String:
			game_config.set(key, "stale_map_%d" % index)
		elif expected is int:
			game_config.set(key, -1000 - index)
		else:
			game_config.set(key, -1000.0 - float(index))
	game_config.set("weapon_feel_overrides", {
		"foreign_map_%d" % index: {
			"damage": 9999.0,
			"knockback_power": 9999.0,
			"bullet_lifetime": 9999.0,
		},
	})
	game_config.set_meta("combat_profile_id", "stale_map_%d" % index)

func _verify_profile_contract(game_config: Node, label: String, require_full_game_config: bool) -> void:
	for key: String in EXPECTED_CONFIG:
		if not require_full_game_config and key in [
			"default_lives",
			"respawn_delay",
			"invincible_duration",
			"fall_threshold",
		]:
			continue
		var actual = game_config.get(key)
		var expected = EXPECTED_CONFIG[key]
		if expected is float and not is_equal_approx(float(actual), float(expected)):
			_fail("%s retained cross-map value for %s" % [label, key])
		elif expected is int and int(actual) != int(expected):
			_fail("%s retained cross-map value for %s" % [label, key])
		elif expected is String and String(actual) != String(expected):
			_fail("%s retained cross-map value for %s" % [label, key])

	var overrides = game_config.get("weapon_feel_overrides")
	if not (overrides is Dictionary):
		_fail("%s did not restore weapon overrides" % label)
		return
	if (overrides as Dictionary).size() != EXPECTED_WEAPONS.size():
		_fail("%s retained or omitted weapon override entries" % label)
	for weapon_id: String in EXPECTED_WEAPONS:
		var values = (overrides as Dictionary).get(weapon_id, {})
		if not (values is Dictionary):
			_fail("%s is missing %s override" % [label, weapon_id])
			continue
		var expected_values := EXPECTED_WEAPONS[weapon_id] as Array
		for index in range(3):
			var field: String = ["knockback_power", "damage", "bullet_lifetime"][index]
			if not is_equal_approx(float(values.get(field, -1.0)), float(expected_values[index])):
				_fail("%s has polluted %s.%s" % [label, weapon_id, field])
	if String(game_config.get_meta("combat_profile_id", "")) != "party_shooter_v1":
		_fail("%s did not restore combat_profile_id" % label)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	print("==================================================")
	if _failures.is_empty():
		print("[Party Shooter v1 Profile Verifier] PASS")
		quit(0)
		return
	print("[Party Shooter v1 Profile Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
