extends SceneTree

const WEAPON_CASES := [
	{"id": &"pistol", "factory": "create_pistol", "min_length": 0.20, "max_length": 0.30},
	{"id": &"smg", "factory": "create_smg", "min_length": 0.14, "max_length": 0.22},
	{"id": &"ak_rifle", "factory": "create_ak_rifle", "min_length": 0.28, "max_length": 0.38},
	{"id": &"sniper", "factory": "create_sniper", "min_length": 0.65, "max_length": 0.90},
	{"id": &"gatling", "factory": "create_gatling", "min_length": 0.08, "max_length": 0.15},
	{"id": &"shotgun", "factory": "create_shotgun", "min_length": 0.52, "max_length": 0.66},
]

var _failures: Array[String] = []


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	print("==================================================")
	print("[Combat Audio Feedback Verifier]")
	print("==================================================")
	_verify_weapon_audio_assets()
	_verify_weapon_feedback_hierarchy()
	_verify_hit_feedback_profiles_and_coalescing()
	await _verify_directional_camera_kick()
	_finish()


func _verify_weapon_audio_assets() -> void:
	var resource_paths: Dictionary = {}
	for weapon_case in WEAPON_CASES:
		var factory := Callable(WeaponData, String(weapon_case["factory"]))
		var data := factory.call() as WeaponData
		if data == null or data.shoot_sound == null:
			_fail("%s is missing its generated shot sound" % weapon_case["id"])
			continue
		var path := data.shoot_sound.resource_path
		if not path.begins_with("res://assets/audio/generated/combat/"):
			_fail("%s still points at a legacy shared shot sound" % weapon_case["id"])
		if resource_paths.has(path):
			_fail("%s shares a shot sound with %s" % [weapon_case["id"], resource_paths[path]])
		resource_paths[path] = weapon_case["id"]
		var length := data.shoot_sound.get_length()
		if length < float(weapon_case["min_length"]) or length > float(weapon_case["max_length"]):
			_fail("%s shot sound length %.3f is outside its cadence budget" % [weapon_case["id"], length])
	if resource_paths.size() == WEAPON_CASES.size():
		print("OK  six unique cadence-safe weapon sounds")


func _verify_weapon_feedback_hierarchy() -> void:
	var weapon := Weapon.new()
	var pistol := weapon.get_shot_feedback_profile_debug(&"pistol")
	var smg := weapon.get_shot_feedback_profile_debug(&"smg")
	var ak := weapon.get_shot_feedback_profile_debug(&"ak_rifle")
	var sniper := weapon.get_shot_feedback_profile_debug(&"sniper")
	var gatling := weapon.get_shot_feedback_profile_debug(&"gatling")
	var shotgun := weapon.get_shot_feedback_profile_debug(&"shotgun")
	if float(sniper["kick"]) <= float(ak["kick"]) or float(shotgun["kick"]) <= float(ak["kick"]):
		_fail("Sniper and shotgun camera kick must exceed the AK")
	if float(ak["kick"]) <= float(pistol["kick"]):
		_fail("AK camera kick must exceed the pistol")
	if float(gatling["shake"]) >= float(smg["shake"]):
		_fail("Gatling micro-shake should remain below SMG shake")
	if float(sniper["volume_db"]) <= float(gatling["volume_db"]):
		_fail("Sniper report should be louder than sustained gatling fire")
	else:
		print("OK  weapon-specific loudness, shake, and directional kick hierarchy")
	weapon.free()


func _verify_hit_feedback_profiles_and_coalescing() -> void:
	var character := BaseCharacter.new()
	var smg := character.get_hit_feedback_profile_debug(&"smg", 12.0)
	var sniper := character.get_hit_feedback_profile_debug(&"sniper", 80.0)
	var shotgun := character.get_hit_feedback_profile_debug(&"shotgun", 5.0)
	var gatling := character.get_hit_feedback_profile_debug(&"gatling", 5.0)
	if bool(smg["heavy"]) or not bool(sniper["heavy"]) or not bool(shotgun["heavy"]):
		_fail("Impact sound weight does not match the weapon silhouette")
	if float(gatling["hitstop"]) > 0.0001:
		_fail("Gatling impacts must not create continuous hitstop")
	for _pellet in range(5):
		character.call("_play_hit_feedback", &"shotgun", 5.0, Vector3.RIGHT * 12.0)
	var debug := character.get_hit_feedback_debug()
	if int(debug.get("serial", 0)) != 1:
		_fail("A shotgun pellet cluster should coalesce into one audiovisual impact event")
	else:
		print("OK  weapon-weighted impacts with shotgun pellet coalescing")
	character.free()

	var priority_character := BaseCharacter.new()
	priority_character.call("_play_hit_feedback", &"smg", 12.0, Vector3.RIGHT * 5.0)
	priority_character.call("_play_hit_feedback", &"sniper", 80.0, Vector3.RIGHT * 20.0)
	var priority_debug := priority_character.get_hit_feedback_debug()
	if int(priority_debug.get("serial", 0)) != 2 or int(priority_debug.get("last_feedback_weight", 0)) != 2:
		_fail("A heavy impact inside the coalescing window must override a light impact")
	else:
		print("OK  heavy impacts override recent light feedback without duplicating pellets")
	priority_character.free()
	Engine.time_scale = 1.0


func _verify_directional_camera_kick() -> void:
	var game_feel := root.get_node_or_null("GameFeel")
	if game_feel == null:
		_fail("GameFeel autoload is missing")
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	camera.current = true
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(8.0, 12.0, 16.0), Vector3.ZERO, Vector3.UP)
	await process_frame
	game_feel.call("_process", 0.30)
	var original_position := camera.position
	var original_h_offset := camera.h_offset
	var original_v_offset := camera.v_offset
	game_feel.call("camera_kick", Vector3.RIGHT, 0.20, 0.10)
	game_feel.call("_process", 0.016)
	var debug := game_feel.call("get_camera_feedback_debug") as Dictionary
	var kick_offset := debug.get("kick_offset", Vector2.ZERO) as Vector2
	if kick_offset.length() < 0.01:
		_fail("Directional camera kick did not create a presentation offset")
	if not camera.position.is_equal_approx(original_position):
		_fail("Directional kick must not overwrite camera-director position")
	game_feel.call("_process", 0.20)
	if not is_equal_approx(camera.h_offset, original_h_offset) or not is_equal_approx(camera.v_offset, original_v_offset):
		_fail("Directional camera kick did not restore cleanly")
	else:
		print("OK  directional camera kick is isolated and self-restoring")
	stage.queue_free()
	await process_frame


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	Engine.time_scale = 1.0
	if _failures.is_empty():
		print("[Combat Audio Feedback Verifier] PASS")
		quit(0)
		return
	print("[Combat Audio Feedback Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
