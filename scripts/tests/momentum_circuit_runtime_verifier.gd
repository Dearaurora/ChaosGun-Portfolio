extends SceneTree

## Minimal production runtime gate for the shared match lifecycle. Structural
## and mechanism details live in their dedicated verifiers; this script proves
## that the production map still participates in character, pickup, pause,
## respawn, HUD, and result flows.

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const EXPECTED_WEAPON_IDS := [&"ak_rifle", &"gatling", &"shotgun", &"smg", &"sniper"]
const EPSILON := 0.015

var _failures: Array[String] = []
var _arena: Node3D = null


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit Runtime Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	root.size = Vector2i(1280, 720)

	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene is missing: %s" % SCENE_PATH)
		await _finish()
		return
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		await _finish()
		return
	match_config.set("slots", [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	])
	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed != null else null
	if _arena == null:
		_fail("Could not instantiate production scene")
		await _finish()
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame

	var characters := _get_characters()
	_verify_four_character_spawn(characters)
	await _verify_weapon_runtime(characters)
	_verify_hud_and_pause(characters)
	await _verify_fall_and_respawn(characters)
	_verify_victory_result(characters)
	await _finish()


func _verify_four_character_spawn(characters: Array[BaseCharacter]) -> void:
	print("\n--- Four-Character Spawn Runtime ---")
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
		if not _has_safe_ground(character.global_position):
			_fail("Character spawned without safe gameplay floor: %s at %s" % [character.name, character.global_position])
		if character.weapon_manager == null:
			_fail("Character is missing shared WeaponManager: %s" % character.name)
		elif character.weapon_manager.get_current_weapon_name() != "Pistol":
			_fail("Character did not start with shared Pistol: %s" % character.name)
	if human_count != 1 or ai_count != 3:
		_fail("Expected one human and three AI, got human=%d AI=%d" % [human_count, ai_count])
	else:
		print("OK  one human + three AI, grounded, shared base Pistols")


func _verify_weapon_runtime(characters: Array[BaseCharacter]) -> void:
	print("\n--- Shared Weapon Spawn Runtime ---")
	var spawner := _arena.get_node_or_null("WeaponSpawner") as WeaponSpawner
	if spawner == null:
		_fail("Production map is missing WeaponSpawner")
		return
	_assert_close(spawner.initial_delay, 20.0, "WeaponSpawner initial delay")
	_assert_close(spawner.stay_duration, 30.0, "WeaponSpawner stay duration")
	_assert_close(spawner.respawn_cooldown, 10.0, "WeaponSpawner respawn cooldown")
	if spawner.max_active_pickups != 1:
		_fail("WeaponSpawner max_active_pickups must be 1")
	if spawner.custom_spawn_points.size() != 4:
		_fail("WeaponSpawner must expose exactly four candidate points")
	for value: Variant in spawner.custom_spawn_points:
		if not value is Vector3 or not _has_safe_ground(value as Vector3):
			_fail("Weapon candidate is not grounded: %s" % str(value))

	var actual_set: Dictionary = {}
	for weapon_id: Variant in spawner.get_spawn_pool_ids_debug("pooled"):
		actual_set[StringName(weapon_id)] = true
	var expected_set: Dictionary = {}
	for weapon_id in EXPECTED_WEAPON_IDS:
		expected_set[weapon_id] = true
	if actual_set != expected_set:
		_fail("Runtime weapon pool must contain the five normal weapons")

	# Exercise the same pooled spawn path immediately instead of waiting twenty
	# wall seconds. Calling it twice proves the max-one invariant.
	var previous_modes: Dictionary = {}
	for character in characters:
		previous_modes[character.get_instance_id()] = character.process_mode
		character.process_mode = Node.PROCESS_MODE_DISABLED
	spawner.call("_fill_pickups")
	spawner.call("_fill_pickups")
	await process_frame
	var pickups: Array[Node3D] = []
	for node in get_nodes_in_group(&"weapon_pickup"):
		if node is Node3D and _arena.is_ancestor_of(node):
			pickups.append(node as Node3D)
	for character in characters:
		character.process_mode = int(previous_modes[character.get_instance_id()])
	if pickups.size() != 1:
		_fail("Two pooled fill attempts must still create exactly one pickup, got %d" % pickups.size())
	else:
		var pickup := pickups[0]
		var content_id := StringName(pickup.get_meta("pickup_content_id", &""))
		if not actual_set.has(content_id):
			_fail("Runtime pickup used unexpected content id: %s" % content_id)
		if not _contains_near(spawner.custom_spawn_points, pickup.global_position, 0.05):
			_fail("Runtime pickup did not use one of the four configured candidates")
		print("OK  one runtime pickup from four candidates and the five-weapon pool")


func _verify_hud_and_pause(characters: Array[BaseCharacter]) -> void:
	print("\n--- HUD And Pause Flow ---")
	var human: PlayerCharacter = null
	for character in characters:
		if character is PlayerCharacter:
			human = character as PlayerCharacter
			break
	if human == null or human.get_node_or_null("GameHUD") == null:
		_fail("Human player GameHUD is missing")
	else:
		print("OK  human GameHUD")
	var control_mode_panel := _find_script_node(_arena, "res://scripts/ui/control_mode_panel.gd")
	if control_mode_panel == null:
		_fail("Shared control-mode panel is missing")
	var pause_menu := _arena.find_child("PauseMenu", true, false)
	if pause_menu == null or not pause_menu.has_method("_toggle_pause"):
		_fail("Pause flow is missing")
		return
	pause_menu.call("_toggle_pause")
	if not paused:
		_fail("PauseMenu did not pause SceneTree")
	pause_menu.call("_toggle_pause")
	if paused:
		_fail("PauseMenu did not resume SceneTree")
	else:
		print("OK  pause/resume and shared control panel")


func _verify_fall_and_respawn(characters: Array[BaseCharacter]) -> void:
	print("\n--- Fall And Respawn Flow ---")
	var probe: BaseCharacter = null
	for character in characters:
		if character is AICharacter:
			probe = character
			break
	if probe == null or probe.weapon_manager == null:
		_fail("Respawn probe requires an AI with WeaponManager")
		return
	for character in characters:
		if character != probe:
			character.process_mode = Node.PROCESS_MODE_DISABLED
	probe.weapon_manager.equip_weapon(WeaponData.create_smg())
	await create_timer(0.25).timeout
	if not probe.weapon_manager.has_primary():
		_fail("Respawn probe could not equip shared SMG")
		return
	var game_config := root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload is missing")
		return
	var fall_threshold := float(game_config.get("fall_threshold"))
	var respawn_delay := float(game_config.get("respawn_delay"))
	probe.lives = 2
	probe.is_dead = false
	probe.is_game_over = false
	probe.is_invincible = false
	probe.global_position = Vector3(0.0, fall_threshold - 2.0, 0.0)
	await physics_frame
	await physics_frame
	if not probe.is_dead or probe.lives != 1:
		_fail("Falling below threshold did not cost exactly one life")
		return
	await create_timer(respawn_delay + 0.30).timeout
	await physics_frame
	if probe.is_dead:
		_fail("Character did not respawn after configured delay")
	elif not _has_safe_ground(probe.global_position):
		_fail("Respawn returned character to ungrounded position: %s" % probe.global_position)
	elif probe.weapon_manager.has_primary() or probe.weapon_manager.get_current_weapon_name() != "Pistol":
		_fail("Respawn did not restore the shared base Pistol")
	else:
		print("OK  fall costs one life, delayed grounded respawn, Pistol restored")
	for character in characters:
		character.process_mode = Node.PROCESS_MODE_INHERIT


func _verify_victory_result(characters: Array[BaseCharacter]) -> void:
	print("\n--- Victory And Result Flow ---")
	if characters.size() != 4:
		return
	var survivor: BaseCharacter = null
	for character in characters:
		if character is PlayerCharacter and survivor == null:
			survivor = character
		else:
			character.is_game_over = true
	if survivor == null:
		_fail("Victory probe requires a human survivor")
		return
	var victory_screen: CanvasLayer = null
	for child in _arena.get_children():
		if child is CanvasLayer and child.has_method("show_victory"):
			victory_screen = child as CanvasLayer
			break
	if victory_screen == null:
		_fail("Victory/result screen is missing")
		return
	_arena.call("_on_character_eliminated", characters[1])
	if not bool(_arena.get("_match_ended")):
		_fail("Final-survivor elimination event did not end the match")
	if not victory_screen.visible or victory_screen.find_child("VictoryRoot", true, false) == null:
		_fail("Victory flow did not render its result UI")
	if not paused:
		_fail("Victory flow must pause the completed match")
	else:
		print("OK  final survivor triggers visible result UI and pauses match")
	paused = false


func _get_characters() -> Array[BaseCharacter]:
	var result: Array[BaseCharacter] = []
	for node in _walk(_arena):
		if node is BaseCharacter and not node is CloneCharacter:
			result.append(node as BaseCharacter)
	return result


func _has_safe_ground(position: Vector3) -> bool:
	if _arena == null or _arena.get_world_3d() == null:
		return false
	var exclusions: Array[RID] = []
	for character in _get_characters():
		exclusions.append(character.get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 5.0,
		position + Vector3.DOWN * 8.0
	)
	query.exclude = exclusions
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit := _arena.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var normal := hit.get("normal", Vector3.ZERO) as Vector3
	return normal.dot(Vector3.UP) >= 0.55


func _contains_near(points: Array, expected: Vector3, tolerance: float) -> bool:
	for value: Variant in points:
		if value is Vector3 and (value as Vector3).distance_to(expected) <= tolerance:
			return true
	return false


func _find_script_node(search_root: Node, path: String) -> Node:
	for node in _walk(search_root):
		var script := node.get_script() as Script
		if script != null and script.resource_path == path:
			return node
	return null


func _walk(search_root: Node) -> Array[Node]:
	var result: Array[Node] = [search_root]
	for child in search_root.get_children():
		result.append_array(_walk(child))
	return result


func _assert_close(actual: float, expected: float, label: String) -> void:
	if not is_finite(actual) or absf(actual - expected) > EPSILON:
		_fail("%s differs: %.4f != %.4f" % [label, actual, expected])


func _cleanup_audio(search_root: Node) -> void:
	for node in _walk(search_root):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.stop()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	paused = false
	Engine.time_scale = 1.0
	if _arena != null and is_instance_valid(_arena):
		_cleanup_audio(_arena)
		current_scene = null
		_arena.queue_free()
		await process_frame
		await process_frame
	root.set_meta("disable_runtime_audio", false)
	print("==================================================")
	if _failures.is_empty():
		print("RESULT momentum_circuit_runtime passed=true failures=0")
		print("[Momentum Circuit Runtime Verifier] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_runtime passed=false failures=%d" % _failures.size())
	print("[Momentum Circuit Runtime Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
