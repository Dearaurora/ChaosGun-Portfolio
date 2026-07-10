extends SceneTree

const SCENE_PATH := "res://scenes/maps/commercial_slice_a.tscn"
const DEFAULT_SECONDS := 18.0

var _failures: Array[String] = []
var _host: Node = null
var _tracked_characters: Dictionary = {}
var _armed_character_ids: Dictionary = {}
var _total_deaths := 0
var _suspected_ring_outs := 0
var _first_death_frame := -1
var _max_active_pickups := 0
var _max_active_pickup_clusters := 0
var _profile_path := "res://resources/feel_profiles/default.json"
var _out_path := ""
var _seconds := DEFAULT_SECONDS
var _seed_value := 0
var _profile: Dictionary = {}

func _initialize() -> void:
	_parse_args()
	if _seed_value != 0:
		seed(_seed_value)
	_profile = _load_profile(_profile_path)
	_apply_profile(_profile)

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
	if characters.size() < 2:
		_fail("Expected at least two AI characters, found %d" % characters.size())
		await _finish()
		return
	_prime_character_state(characters)

	var game_config = root.get_node_or_null("GameConfig")
	var fall_threshold = float(game_config.get("fall_threshold")) if game_config else -120.0
	for frame in range(int(_seconds * 60.0)):
		await physics_frame
		characters = _get_characters(arena)
		_track_frame(characters, fall_threshold, frame)

	await _finish()

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			_profile_path = arg.trim_prefix("--profile=")
		elif arg.begins_with("--out="):
			_out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--seconds="):
			_seconds = maxf(1.0, float(arg.trim_prefix("--seconds=")))
		elif arg.begins_with("--seed="):
			_seed_value = int(arg.trim_prefix("--seed="))

func _load_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("Profile not found: %s" % path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fail("Profile is not a JSON object: %s" % path)
		return {}
	return parsed

func _apply_profile(profile: Dictionary) -> void:
	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		return
	var config_values = profile.get("game_config", {})
	if config_values is Dictionary:
		for key in config_values.keys():
			if String(key) in game_config:
				game_config.set(String(key), config_values[key])
	var weapon_overrides = profile.get("weapon_feel_overrides", {})
	if weapon_overrides is Dictionary:
		game_config.set("weapon_feel_overrides", weapon_overrides)

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
		var previous_deaths = int(entry["deaths"])
		var current_deaths = character.deaths
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

func _build_result() -> Dictionary:
	return {
		"profile": _profile.get("id", _profile_path),
		"profile_path": _profile_path,
		"seed": _seed_value,
		"seconds": _seconds,
		"tracked_ai": _tracked_characters.size(),
		"armed_ai": _armed_character_ids.size(),
		"deaths": _total_deaths,
		"ring_outs": _suspected_ring_outs,
		"max_pickups": _max_active_pickups,
		"max_pickup_clusters": _max_active_pickup_clusters,
		"first_death_seconds": null if _first_death_frame < 0 else float(_first_death_frame) / 60.0,
		"failures": _failures,
	}

func _write_result(result: Dictionary) -> void:
	print("FEEL_PROBE_RESULT=%s" % JSON.stringify(result))
	if _out_path.is_empty():
		return
	var file = FileAccess.open(_out_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write output: %s" % _out_path)
		return
	file.store_string(JSON.stringify(result, "\t"))

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	Engine.time_scale = 1.0
	var result = _build_result()
	_write_result(result)
	if _host and is_instance_valid(_host):
		_host.queue_free()
		await process_frame
	root.set_meta("disable_runtime_audio", false)
	quit(0 if _failures.is_empty() else 1)
