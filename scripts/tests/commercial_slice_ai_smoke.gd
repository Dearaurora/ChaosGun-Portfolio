extends SceneTree

const SCENE_PATH := "res://scenes/maps/commercial_slice_a.tscn"
const SIMULATION_SECONDS := 18.0
const PHYSICS_FRAMES := int(SIMULATION_SECONDS * 60.0)
const REQUIRED_MIN_SIMULTANEOUS_PICKUPS := 2
const REQUIRED_MIN_SIMULTANEOUS_PICKUP_CLUSTERS := 2

var _failures: Array[String] = []
var _host: Node = null
var _tracked_characters: Dictionary = {}
var _armed_character_ids: Dictionary = {}
var _total_deaths := 0
var _suspected_ring_outs := 0
var _first_death_frame := -1
var _max_active_pickups := 0
var _max_active_pickup_clusters := 0

func _initialize() -> void:
	print("==================================================")
	print("[AI Smoke] Commercial Slice A")
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

	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload missing")
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
	if characters.size() < 2:
		_fail("Expected at least two AI characters, found %d" % characters.size())
		await _finish()
		return

	_prime_character_state(characters)

	var fall_threshold = float(game_config.get("fall_threshold"))
	for frame in range(PHYSICS_FRAMES):
		await physics_frame
		characters = _get_characters(arena)
		_track_frame(characters, fall_threshold, frame)

	if _max_active_pickups < REQUIRED_MIN_SIMULTANEOUS_PICKUPS:
		_fail(
			"Expected at least %d simultaneous pickups, observed %d" % [
				REQUIRED_MIN_SIMULTANEOUS_PICKUPS,
				_max_active_pickups,
			]
		)
	if _max_active_pickup_clusters < REQUIRED_MIN_SIMULTANEOUS_PICKUP_CLUSTERS:
		_fail(
			"Expected at least %d simultaneous pickup clusters, observed %d" % [
				REQUIRED_MIN_SIMULTANEOUS_PICKUP_CLUSTERS,
				_max_active_pickup_clusters,
			]
		)

	_print_summary()
	await _finish()

func _get_characters(arena: Node) -> Array[BaseCharacter]:
	var characters: Array[BaseCharacter] = []
	for child in arena.get_children():
		if child is BaseCharacter:
			characters.append(child as BaseCharacter)
	return characters

func _prime_character_state(characters: Array[BaseCharacter]) -> void:
	for character in characters:
		_tracked_characters[character.get_instance_id()] = {
			"name": character.name,
			"deaths": character.deaths,
			"below_threshold": false,
		}

func _track_frame(characters: Array[BaseCharacter], fall_threshold: float, frame: int) -> void:
	for character in characters:
		var id = character.get_instance_id()
		if not _tracked_characters.has(id):
			_tracked_characters[id] = {
				"name": character.name,
				"deaths": character.deaths,
				"below_threshold": false,
			}

		var entry = _tracked_characters[id]
		if character.global_position.y < fall_threshold:
			entry["below_threshold"] = true

		if character.weapon_manager and character.weapon_manager.has_primary():
			_armed_character_ids[id] = true

		var previous_deaths = entry["deaths"] if entry["deaths"] is int else 0
		var current_deaths = character.deaths if character.deaths is int else 0
		if current_deaths > previous_deaths:
			var new_deaths = current_deaths - previous_deaths
			_total_deaths += new_deaths
			if _first_death_frame == -1:
				_first_death_frame = frame
			if bool(entry["below_threshold"]):
				_suspected_ring_outs += new_deaths
			entry["deaths"] = current_deaths
			entry["below_threshold"] = false
		elif not character.is_dead and character.global_position.y > fall_threshold + 5.0:
			entry["below_threshold"] = false

		_tracked_characters[id] = entry

	var active_pickups = get_nodes_in_group("weapon_pickup")
	_max_active_pickups = max(_max_active_pickups, active_pickups.size())
	var active_cluster_ids: Dictionary = {}
	for pickup in active_pickups:
		if pickup is Node and pickup.has_meta("spawn_cluster_id"):
			active_cluster_ids[int(pickup.get_meta("spawn_cluster_id"))] = true
	_max_active_pickup_clusters = max(_max_active_pickup_clusters, active_cluster_ids.size())

func _print_summary() -> void:
	print("\n--- Smoke Summary ---")
	print("Simulation seconds: ", SIMULATION_SECONDS)
	print("Tracked AI count: ", _tracked_characters.size())
	print("AI armed at least once: ", _armed_character_ids.size())
	print("Total deaths observed: ", _total_deaths)
	print("Suspected ring-out deaths: ", _suspected_ring_outs)
	print("Max simultaneous pickups observed: ", _max_active_pickups)
	print("Required simultaneous pickups: ", REQUIRED_MIN_SIMULTANEOUS_PICKUPS)
	print("Max simultaneous pickup clusters observed: ", _max_active_pickup_clusters)
	print("Required simultaneous pickup clusters: ", REQUIRED_MIN_SIMULTANEOUS_PICKUP_CLUSTERS)
	if _first_death_frame >= 0:
		print("First death at: %.2fs" % (float(_first_death_frame) / 60.0))
	else:
		print("First death at: none in smoke window")

	if _total_deaths == 0:
		print("WARNING: No deaths observed in smoke window.")
	if _suspected_ring_outs == 0:
		print("WARNING: No suspected ring-out deaths observed in smoke window.")
	if _armed_character_ids.is_empty():
		print("WARNING: No AI character picked up a primary weapon.")

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _cleanup_audio_players(node: Node) -> void:
	for child in node.get_children():
		_cleanup_audio_players(child)
	if node is AudioStreamPlayer3D:
		var audio_player = node as AudioStreamPlayer3D
		audio_player.stop()
		audio_player.queue_free()

func _finish() -> void:
	Engine.time_scale = 1.0
	_cleanup_audio_players(root)
	await process_frame
	if _host and is_instance_valid(_host):
		_host.queue_free()
		await process_frame
		await process_frame
	root.set_meta("disable_runtime_audio", false)

	print("\n==================================================")
	if _failures.is_empty():
		print("[AI Smoke] PASS")
		print("==================================================")
		quit(0)
		return

	print("[AI Smoke] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
