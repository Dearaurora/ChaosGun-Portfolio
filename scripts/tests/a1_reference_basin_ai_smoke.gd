extends SceneTree

const SCENE_PATH := "res://scenes/maps/a1_reference_basin.tscn"
const SIMULATION_SECONDS := 14.0
const PHYSICS_FRAMES := int(SIMULATION_SECONDS * 60.0)

var _failures: Array[String] = []
var _host: Node = null
var _max_active_pickups := 0
var _armed_character_ids: Dictionary = {}
var _tracked_characters: Dictionary = {}
var _total_deaths := 0
var _max_character_displacement := 0.0
var _closest_pickup_distance := INF

func _initialize() -> void:
	print("==================================================")
	print("[A1 Reference Basin AI Smoke]")
	print("==================================================")

	var scene = load(SCENE_PATH)
	if not scene:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		await _finish()
		return

	match_config.slots = [
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	]
	root.set_meta("disable_runtime_audio", true)

	_host = Node.new()
	root.add_child(_host)

	var arena = scene.instantiate()
	var weapon_spawner = arena.get_node_or_null("WeaponSpawner")
	if weapon_spawner:
		weapon_spawner.initial_delay = 0.2
		weapon_spawner.stay_duration = 6.0
		weapon_spawner.respawn_cooldown = 0.75
	_host.add_child(arena)

	await process_frame
	await process_frame
	await physics_frame

	var characters = _get_characters(arena)
	if characters.size() < 4:
		_fail("Expected 4 AI characters, got %d" % characters.size())
		await _finish()
		return

	for character in characters:
		_tracked_characters[character.get_instance_id()] = character.deaths

	for _frame in range(PHYSICS_FRAMES):
		await physics_frame
		_track_frame(arena)

	if _max_active_pickups < 2:
		_fail("Expected at least 2 simultaneous pickups, observed %d" % _max_active_pickups)

	if _armed_character_ids.is_empty():
		_fail("Expected at least one AI to pick up a weapon")

	_print_summary()
	await _finish()

func _get_characters(arena: Node) -> Array[BaseCharacter]:
	var characters: Array[BaseCharacter] = []
	for child in arena.get_children():
		if child is BaseCharacter:
			characters.append(child as BaseCharacter)
	return characters

func _track_frame(arena: Node) -> void:
	for character in _get_characters(arena):
		var id = character.get_instance_id()
		if character.weapon_manager and character.weapon_manager.has_primary():
			_armed_character_ids[id] = true
		var previous = int(_tracked_characters.get(id, character.deaths))
		if character.deaths > previous:
			_total_deaths += character.deaths - previous
		_tracked_characters[id] = character.deaths
		var spawn_pos = _spawn_pos_for_character(character.name)
		if spawn_pos != Vector3.INF:
			_max_character_displacement = maxf(_max_character_displacement, character.global_position.distance_to(spawn_pos))

	var pickups = get_nodes_in_group("weapon_pickup")
	_max_active_pickups = max(_max_active_pickups, pickups.size())
	for character in _get_characters(arena):
		for pickup in pickups:
			if pickup is Node3D:
				_closest_pickup_distance = minf(_closest_pickup_distance, character.global_position.distance_to((pickup as Node3D).global_position))

func _print_summary() -> void:
	print("\n--- Smoke Summary ---")
	print("Simulation seconds: ", SIMULATION_SECONDS)
	print("Tracked AI count: ", _tracked_characters.size())
	print("AI armed at least once: ", _armed_character_ids.size())
	print("Total deaths observed: ", _total_deaths)
	print("Max simultaneous pickups observed: ", _max_active_pickups)
	print("Max character displacement: ", _max_character_displacement)
	print("Closest pickup distance observed: ", _closest_pickup_distance)

func _spawn_pos_for_character(name: String) -> Vector3:
	match name:
		"AI Bot 1":
			return Vector3(-27, 1.0, -4)
		"AI Bot 2":
			return Vector3(27, 1.0, -5)
		"AI Bot 3":
			return Vector3(-9, 1.0, 30)
		"AI Bot 4":
			return Vector3(15, 1.0, 30)
	return Vector3.INF

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
	print("FAIL ", message)

func _finish() -> void:
	if _host and is_instance_valid(_host):
		_host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("\n==================================================")
		print("[A1 Reference Basin AI Smoke] PASS")
		print("==================================================")
		quit(0)
	else:
		print("\n==================================================")
		print("[A1 Reference Basin AI Smoke] FAIL")
		for failure in _failures:
			print("- ", failure)
		print("==================================================")
		quit(1)
