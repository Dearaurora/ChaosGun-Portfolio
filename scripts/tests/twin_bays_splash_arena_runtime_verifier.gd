extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const LAYOUT_PATH := "res://resources/maps/twin_bays_layout_v1.json"

var _failures: Array[String] = []
var _arena: Node3D = null
var _layout: Dictionary = {}


func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Splash Arena Runtime Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	_layout = _load_layout()
	if _layout.is_empty() or not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene or layout is missing")
		await _finish()
		return
	var match_config := root.get_node_or_null("MatchConfig")
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	]
	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	if _arena == null:
		_fail("Could not instantiate production scene")
		await _finish()
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame

	var characters := _get_characters()
	_verify_character_spawn_and_sidearms(characters)
	_verify_runtime_profile()
	await _verify_weapon_spawn_contract()
	_verify_hud_result_and_pause(characters)
	await _verify_fall_respawn_and_sidearm_reset(characters)
	await _finish()


func _verify_character_spawn_and_sidearms(characters: Array[BaseCharacter]) -> void:
	print("\n--- Four-Character Runtime ---")
	if characters.size() != 4:
		_fail("Expected one human and three AI, got %d characters" % characters.size())
		return
	var human_count := 0
	var ai_count := 0
	for character in characters:
		if character is PlayerCharacter:
			human_count += 1
		elif character is AICharacter:
			ai_count += 1
		if not _has_ground_at(character.global_position):
			_fail("Character spawned without ground: %s at %s" % [character.name, character.global_position])
		if character.weapon_manager == null or character.weapon_manager.get_current_weapon_name() != "Pistol":
			_fail("Character did not start with shared Pistol: %s" % character.name)
	if human_count != 1 or ai_count != 3:
		_fail("Expected one human and three AI, got human=%d AI=%d" % [human_count, ai_count])
	else:
		print("OK  one human + three AI, grounded, shared base Pistols")


func _verify_runtime_profile() -> void:
	print("\n--- Map Runtime Profile ---")
	var game_config := root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload is missing")
		return
	var runtime: Dictionary = _layout.get("runtime", {})
	for key in ["default_lives", "respawn_delay", "invincible_duration", "fall_threshold"]:
		var expected := float(runtime.get(key, 0.0))
		var actual := float(game_config.get(key))
		if absf(actual - expected) > 0.001:
			_fail("Runtime value %s drifted: actual=%.3f expected=%.3f" % [key, actual, expected])
	if _failures.is_empty():
		print("OK  lives, respawn, invincibility, and fall threshold")


func _verify_weapon_spawn_contract() -> void:
	print("\n--- Ordinary Four-Point + Center Special Spawn Contract ---")
	var ordinary := _arena.get_node_or_null("WeaponSpawner") as WeaponSpawner
	var special := _arena.get_node_or_null("TwinBaysSpecialWeaponSpawner") as WeaponSpawner
	if ordinary == null or special == null:
		_fail("Twin Bays must expose separate ordinary and center-special weapon spawners")
		return
	var runtime: Dictionary = _layout.get("runtime", {})
	var ordinary_properties := {
		"initial_delay": "pickup_initial_delay",
		"stay_duration": "pickup_stay_duration",
		"respawn_cooldown": "pickup_respawn_cooldown",
		"max_active_pickups": "pickup_max_active",
	}
	for property_name in ordinary_properties:
		var expected := float(runtime.get(ordinary_properties[property_name], -1.0))
		var actual := float(ordinary.get(property_name))
		if absf(actual - expected) > 0.001:
			_fail("Ordinary WeaponSpawner %s drifted: actual=%.3f expected=%.3f" % [property_name, actual, expected])
	var special_properties := {
		"initial_delay": "special_pickup_initial_delay",
		"stay_duration": "special_pickup_stay_duration",
		"fixed_spawn_interval": "special_pickup_interval",
		"max_active_pickups": "special_pickup_max_active",
	}
	for property_name in special_properties:
		var expected := float(runtime.get(special_properties[property_name], -1.0))
		var actual := float(special.get(property_name))
		if absf(actual - expected) > 0.001:
			_fail("Special WeaponSpawner %s drifted: actual=%.3f expected=%.3f" % [property_name, actual, expected])

	if ordinary.max_active_pickups != 1:
		_fail("Four ordinary points must allow exactly one active weapon")
	if not ordinary.fixed_spawn_points.is_empty() or not ordinary.random_spawn_points.is_empty():
		_fail("Ordinary points must retain pooled cooldown scheduling")
	var configured: Array[Vector3] = []
	for value in ordinary.custom_spawn_points:
		configured.append(value as Vector3)
	var expected_markers: Array = _layout.get("pickup_markers", [])
	if configured.size() != 4:
		_fail("Expected exactly four ordinary candidate points, got %d" % configured.size())
	for raw_entry in expected_markers:
		var entry := raw_entry as Dictionary
		var values: Array = entry.get("spawn_position", [])
		var expected := Vector3(float(values[0]), float(values[1]), float(values[2]))
		if not _contains_near(configured, expected, 0.01):
			_fail("Ordinary candidate point is not configured at %s" % expected)
		elif not _has_ground_at(expected):
			_fail("Ordinary candidate point is not safely grounded: %s" % expected)
	var ordinary_pool := _spawn_pool_strings(ordinary, "pooled")
	if ordinary_pool != ["ak_rifle", "shotgun", "smg"]:
		_fail("Ordinary Twin Bays pool must be SMG/AK/Shotgun, got %s" % ordinary_pool)

	var special_marker := _layout.get("special_pickup_marker", {}) as Dictionary
	var special_values: Array = special_marker.get("spawn_position", [])
	var special_position := Vector3(float(special_values[0]), float(special_values[1]), float(special_values[2]))
	if special.fixed_spawn_points.size() != 1 or (special.fixed_spawn_points[0] as Vector3).distance_to(special_position) > 0.01:
		_fail("Center special spawner must own exactly the fixed layout point")
	if special.center_powerups_enabled:
		_fail("Twin Bays center special point must not spawn powerups")
	var special_pool := _spawn_pool_strings(special, "fixed")
	if special_pool != ["gatling", "sniper"]:
		_fail("Center special pool must be Gatling/Sniper only, got %s" % special_pool)
	for offset in [Vector3.ZERO, Vector3(1.82, 0.0, 0.0), Vector3(-1.82, 0.0, 0.0), Vector3(0.0, 0.0, 1.82), Vector3(0.0, 0.0, -1.82)]:
		if not _has_ground_at(special_position + offset):
			_fail("Center premium pedestal footprint is not safely grounded at %s" % (special_position + offset))

	var characters := _get_characters()
	for character in characters:
		character.process_mode = Node.PROCESS_MODE_DISABLED
	await create_timer(float(runtime.get("pickup_initial_delay", 2.5)) + 0.30).timeout
	var ordinary_active := 0
	var special_active := 0
	var total_active := 0
	for node in get_nodes_in_group("weapon_pickup"):
		if not node is Node3D or not _arena.is_ancestor_of(node):
			continue
		total_active += 1
		var spawn_kind := String(node.get_meta("spawn_kind", ""))
		var content_id := String(node.get_meta("pickup_content_id", ""))
		if spawn_kind == "pooled":
			ordinary_active += 1
			if content_id not in ordinary_pool:
				_fail("Ordinary point spawned non-ordinary weapon: %s" % content_id)
		elif spawn_kind == "fixed":
			special_active += 1
			if content_id not in special_pool:
				_fail("Center point spawned non-special weapon: %s" % content_id)
	for character in characters:
		character.process_mode = Node.PROCESS_MODE_INHERIT
	if ordinary_active != 1 or special_active != 1 or total_active != 2:
		_fail("Expected one ordinary plus one special pickup, got ordinary=%d special=%d total=%d" % [ordinary_active, special_active, total_active])
	else:
		print("OK  four ordinary candidates share one weapon; center independently spawns Gatling/Sniper")

func _spawn_pool_strings(spawner: WeaponSpawner, spawn_kind: String) -> Array[String]:
	var result: Array[String] = []
	for weapon_id in spawner.get_spawn_pool_ids_debug(spawn_kind):
		result.append(String(weapon_id))
	result.sort()
	return result


func _verify_hud_result_and_pause(characters: Array[BaseCharacter]) -> void:
	print("\n--- HUD / Result / Pause Flow ---")
	var player: PlayerCharacter = null
	for character in characters:
		if character is PlayerCharacter:
			player = character as PlayerCharacter
			break
	if player == null or player.get_node_or_null("GameHUD") == null:
		_fail("Human player HUD is missing")
	else:
		print("OK  human HUD")
	var victory_screen: Node = null
	for child in _arena.get_children():
		if child.has_method("show_victory"):
			victory_screen = child
			break
	if victory_screen == null or not victory_screen.has_method("show_victory"):
		_fail("Victory/result flow is missing")
	else:
		print("OK  victory/result flow")
	var pause_menu := _arena.find_child("PauseMenu", true, false)
	if pause_menu == null or not pause_menu.has_method("_toggle_pause"):
		_fail("Pause flow is missing")
		return
	pause_menu.call("_toggle_pause")
	if not paused:
		_fail("Pause menu did not pause the SceneTree")
	pause_menu.call("_toggle_pause")
	if paused:
		_fail("Pause menu did not resume the SceneTree")
	else:
		print("OK  pause/resume flow")


func _verify_fall_respawn_and_sidearm_reset(characters: Array[BaseCharacter]) -> void:
	print("\n--- Fall / Respawn / Pistol Reset ---")
	if characters.size() < 2:
		return
	var probe := characters[1]
	probe.weapon_manager.equip_weapon(WeaponData.create_smg())
	await create_timer(0.25).timeout
	if not probe.weapon_manager.has_primary():
		_fail("Runtime probe could not equip a shared primary weapon")
		return
	var game_config := root.get_node_or_null("GameConfig")
	var fall_threshold := float(game_config.get("fall_threshold"))
	var respawn_delay := float(game_config.get("respawn_delay"))
	probe.lives = 2
	probe.is_invincible = false
	probe.global_position = Vector3(0.0, fall_threshold - 2.0, 0.0)
	await physics_frame
	await physics_frame
	if not probe.is_dead or probe.lives != 1:
		_fail("Falling below threshold did not cost exactly one life")
		return
	await create_timer(respawn_delay + 0.25).timeout
	await physics_frame
	if probe.is_dead:
		_fail("Character did not respawn after configured delay")
	elif not _has_ground_at(probe.global_position):
		_fail("Respawn returned character to ungrounded position: %s" % probe.global_position)
	elif probe.weapon_manager.has_primary() or probe.weapon_manager.get_current_weapon_name() != "Pistol":
		_fail("Respawn did not restore the shared base Pistol")
	else:
		print("OK  fall costs life, delayed grounded respawn, base Pistol restored")


func _get_characters() -> Array[BaseCharacter]:
	var result: Array[BaseCharacter] = []
	for child in _arena.get_children():
		if child is BaseCharacter and not child is CloneCharacter:
			result.append(child as BaseCharacter)
	return result


func _contains_near(points: Array[Vector3], expected: Vector3, tolerance: float) -> bool:
	for point in points:
		if point.distance_to(expected) <= tolerance:
			return true
	return false


func _has_ground_at(position: Vector3) -> bool:
	var world := root.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(position.x, 8.0, position.z),
		Vector3(position.x, -6.0, position.z)
	)
	return not world.direct_space_state.intersect_ray(query).is_empty()


func _load_layout() -> Dictionary:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	paused = false
	Engine.time_scale = 1.0
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()
	await process_frame
	await process_frame
	root.set_meta("disable_runtime_audio", false)
	print("==================================================")
	if _failures.is_empty():
		print("[Twin Bays Splash Arena Runtime Verifier] PASS")
		quit(0)
		return
	print("[Twin Bays Splash Arena Runtime Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
