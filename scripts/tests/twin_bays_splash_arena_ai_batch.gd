extends SceneTree

## Deterministic gameplay soak for the production Twin Bays map.
##
## The default invocation is the release gate (8 seeds x 30 simulated seconds).
## Shorter runs are available for development. Pass --enforce-engagement=false to
## keep the integrity checks while skipping the intentionally long engagement
## quotas during a short smoke run.

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const DEFAULT_REPORT_PATH := "res://reports/twin_bays_splash_arena_ai_batch.json"
const DEFAULT_SEEDS := [101, 211, 307, 401, 503, 601, 701, 809]
const DEFAULT_ROUNDS := 8
const DEFAULT_DURATION_SECONDS := 30.0
const MIN_FIRST_DEATH_SECONDS := 2.0
const NON_COMBAT_STUCK_SECONDS := 5.0
const REQUIRED_ARMED_ROUNDS := 6
const REQUIRED_KILL_ROUNDS := 6
const REQUIRED_RINGOUT_ROUNDS := 4
const PORTAL_COOLDOWN_TOLERANCE_SECONDS := 0.015

var _failures: Array[String] = []
var _portal_last_event_seconds: Dictionary = {}
var _portal_event_count := 0
var _portal_ping_pong := false
var _portal_min_interval_seconds := INF
var _round_started_msec := 0
var _portal_cooldown_seconds := 0.55
var _report_path := DEFAULT_REPORT_PATH
var _enforce_engagement := true


func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Splash Arena AI Batch]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var match_config := root.get_node_or_null("MatchConfig")
	var game_config := root.get_node_or_null("GameConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
	if game_config == null:
		_fail("GameConfig autoload is missing")
	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene is missing: %s" % SCENE_PATH)
	if not _failures.is_empty():
		await _finish([], {})
		return

	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load production scene: %s" % SCENE_PATH)
		await _finish([], {})
		return

	var round_count := clampi(_argument_int("--rounds=", DEFAULT_ROUNDS), 1, DEFAULT_ROUNDS)
	var duration_seconds := clampf(
		_argument_float("--duration=", DEFAULT_DURATION_SECONDS),
		1.0,
		DEFAULT_DURATION_SECONDS
	)
	_enforce_engagement = _argument_bool("--enforce-engagement=", true)
	_report_path = _argument_value("--report=", DEFAULT_REPORT_PATH)
	if not _is_valid_report_path(_report_path):
		_fail("AI batch report must be a JSON file under res://reports/")
		_report_path = DEFAULT_REPORT_PATH

	var results: Array[Dictionary] = []
	for round_index in range(round_count):
		var result := await _run_round(packed, match_config, round_index, duration_seconds)
		results.append(result)
		_print_round(result)

	var aggregate := _verify_and_summarize(results, round_count)
	await _finish(results, aggregate)


func _run_round(
	packed: PackedScene,
	match_config: Node,
	round_index: int,
	duration_seconds: float
) -> Dictionary:
	var round_seed := int(DEFAULT_SEEDS[round_index])
	seed(round_seed)
	await _settle_game_feel()
	Engine.time_scale = 1.0
	match_config.set("slots", [
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	])

	var arena := packed.instantiate()
	arena.name = "TwinBaysAIBatchRound%d" % (round_index + 1)
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	await physics_frame

	var characters := _get_characters(arena)
	var result: Dictionary = {
		"round": round_index + 1,
		"seed": round_seed,
		"duration_seconds": duration_seconds,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"character_count": characters.size(),
		"armed_count": 0,
		"kills": 0,
		"deaths": 0,
		"ringouts": 0,
		"first_death_seconds": -1.0,
		"minimum_spawn_lifetime_seconds": -1.0,
		"portal_events": 0,
		"portal_min_interval_seconds": -1.0,
		"portal_ping_pong": false,
		"spawn_checks": 0,
		"illegal_spawn_count": 0,
		"nan_or_inf_frames": 0,
		"stuck_count": 0,
		"stuck_characters": [],
		"max_noncombat_idle_seconds": 0.0,
		"character_activity": [],
	}
	if characters.size() != 4:
		result["setup_failure"] = "Expected four AI characters, got %d" % characters.size()
		await _release_round(arena)
		return result

	var game_config := root.get_node_or_null("GameConfig")
	var fall_threshold := float(game_config.get("fall_threshold")) if game_config else -16.0
	var tracked: Dictionary = {}
	var armed_ids: Dictionary = {}
	var stuck_ids: Dictionary = {}
	var excluded_rids: Array[RID] = []
	for character in characters:
		excluded_rids.append(character.get_rid())

	for character in characters:
		var id := character.get_instance_id()
		tracked[id] = {
			"name": String(character.name),
			"deaths": int(character.deaths),
			"below_threshold": false,
			"was_dead": bool(character.is_dead),
			"spawn_frame": 0,
			"last_position": character.global_position,
			"inactive_frames": 0,
			"max_inactive_frames": 0,
			"shots": 0,
			"last_shots": 0,
			"distance_travelled": 0.0,
		}
		result["spawn_checks"] = int(result["spawn_checks"]) + 1
		if not _has_safe_ground_at(character.global_position, excluded_rids):
			result["illegal_spawn_count"] = int(result["illegal_spawn_count"]) + 1
		if character.weapon_manager:
			character.weapon_manager.weapon_fired.connect(_on_ai_weapon_fired.bind(id, tracked))

	_prepare_portal_observation(arena)
	_round_started_msec = Time.get_ticks_msec()
	var physics_rate := maxi(1, Engine.physics_ticks_per_second)
	var physics_frames := int(round(duration_seconds * float(physics_rate)))
	var stuck_frame_limit := maxi(1, int(NON_COMBAT_STUCK_SECONDS * float(physics_rate)))

	for frame in range(physics_frames):
		await physics_frame
		characters = _get_characters(arena)
		for character in characters:
			var id := character.get_instance_id()
			if not tracked.has(id):
				continue
			var state: Dictionary = tracked[id]
			var position := character.global_position
			if not _is_finite_vector(position) or not _is_finite_vector(character.linear_velocity):
				result["nan_or_inf_frames"] = int(result["nan_or_inf_frames"]) + 1

			if bool(state["was_dead"]) and not character.is_dead:
				state["spawn_frame"] = frame
				state["inactive_frames"] = 0
				state["last_position"] = position
				result["spawn_checks"] = int(result["spawn_checks"]) + 1
				if not _has_safe_ground_at(position, excluded_rids):
					result["illegal_spawn_count"] = int(result["illegal_spawn_count"]) + 1

			if position.y < fall_threshold:
				state["below_threshold"] = true
			if character.weapon_manager and character.weapon_manager.has_primary():
				armed_ids[id] = true

			var new_deaths := int(character.deaths) - int(state["deaths"])
			if new_deaths > 0:
				result["deaths"] = int(result["deaths"]) + new_deaths
				var death_time := float(frame) / float(physics_rate)
				if float(result["first_death_seconds"]) < 0.0:
					result["first_death_seconds"] = death_time
				var spawn_lifetime := float(frame - int(state["spawn_frame"])) / float(physics_rate)
				if float(result["minimum_spawn_lifetime_seconds"]) < 0.0:
					result["minimum_spawn_lifetime_seconds"] = spawn_lifetime
				else:
					result["minimum_spawn_lifetime_seconds"] = minf(
						float(result["minimum_spawn_lifetime_seconds"]),
						spawn_lifetime
					)
				if bool(state["below_threshold"]):
					result["ringouts"] = int(result["ringouts"]) + new_deaths
				state["deaths"] = int(character.deaths)
				state["below_threshold"] = false
				state["inactive_frames"] = 0
			elif not character.is_dead and position.y > fall_threshold + 5.0:
				state["below_threshold"] = false

			var frame_distance := position.distance_to(state["last_position"] as Vector3)
			state["distance_travelled"] = float(state["distance_travelled"]) + frame_distance
			var combat_engaged := character is AICharacter and (
				int(character.get("_state")) == AICharacter.State.SHOOT
			)
			if character.is_dead or character.is_game_over or combat_engaged:
				state["inactive_frames"] = 0
			else:
				var moved := frame_distance > 0.04
				var fired := int(state["shots"]) > int(state["last_shots"])
				if moved or fired:
					state["inactive_frames"] = 0
				else:
					state["inactive_frames"] = int(state["inactive_frames"]) + 1
				state["max_inactive_frames"] = maxi(
					int(state["max_inactive_frames"]),
					int(state["inactive_frames"])
				)
				if int(state["inactive_frames"]) >= stuck_frame_limit:
					stuck_ids[id] = true

			state["last_position"] = position
			state["last_shots"] = int(state["shots"])
			state["was_dead"] = bool(character.is_dead)
			tracked[id] = state

	result["armed_count"] = armed_ids.size()
	var total_kills := 0
	for character in characters:
		total_kills += int(character.kills)
	result["kills"] = total_kills
	result["portal_events"] = _portal_event_count
	result["portal_ping_pong"] = _portal_ping_pong
	if is_finite(_portal_min_interval_seconds):
		result["portal_min_interval_seconds"] = _portal_min_interval_seconds
	result["stuck_count"] = stuck_ids.size()
	var stuck_names: Array[String] = []
	for id in stuck_ids:
		if tracked.has(id):
			stuck_names.append(String(tracked[id]["name"]))
	result["stuck_characters"] = stuck_names
	var activity: Array[Dictionary] = []
	for id in tracked:
		var state: Dictionary = tracked[id]
		result["max_noncombat_idle_seconds"] = maxf(
			float(result["max_noncombat_idle_seconds"]),
			float(state["max_inactive_frames"]) / float(physics_rate)
		)
		activity.append({
			"name": String(state["name"]),
			"armed": armed_ids.has(id),
			"shots": int(state["shots"]),
			"distance_travelled": float(state["distance_travelled"]),
			"max_noncombat_idle_seconds": float(state["max_inactive_frames"]) / float(physics_rate),
		})
	result["character_activity"] = activity

	await _release_round(arena)
	return result


func _prepare_portal_observation(arena: Node) -> void:
	_portal_last_event_seconds.clear()
	_portal_event_count = 0
	_portal_ping_pong = false
	_portal_min_interval_seconds = INF
	_portal_cooldown_seconds = 0.55
	for node in _walk(arena):
		var portal := node as TwinBaysPortal
		if portal == null:
			continue
		_portal_cooldown_seconds = maxf(_portal_cooldown_seconds, portal.cooldown_seconds)
		if not portal.character_teleported.is_connected(_on_portal_event):
			portal.character_teleported.connect(_on_portal_event)


func _verify_and_summarize(results: Array[Dictionary], round_count: int) -> Dictionary:
	var armed_rounds := 0
	var kill_rounds := 0
	var ringout_rounds := 0
	var total_portal_events := 0
	for result in results:
		if result.has("setup_failure"):
			_fail("Round %d setup failed: %s" % [result["round"], result["setup_failure"]])
		if int(result["armed_count"]) >= 3:
			armed_rounds += 1
		if int(result["kills"]) > 0:
			kill_rounds += 1
		if int(result["ringouts"]) > 0:
			ringout_rounds += 1
		total_portal_events += int(result["portal_events"])
		if int(result["illegal_spawn_count"]) > 0:
			_fail("Round %d had %d illegal initial/respawn locations" % [
				result["round"], result["illegal_spawn_count"]
			])
		if int(result["nan_or_inf_frames"]) > 0:
			_fail("Round %d observed NaN/INF character state" % result["round"])
		if bool(result["portal_ping_pong"]):
			_fail("Round %d observed portal ping-pong inside the 0.55 s cooldown" % result["round"])
		if int(result["stuck_count"]) > 0:
			_fail("Round %d had %d AI stuck without movement or fire for %.1f s" % [
				result["round"], result["stuck_count"], NON_COMBAT_STUCK_SECONDS
			])
		var first_death := float(result["first_death_seconds"])
		if first_death >= 0.0 and first_death < MIN_FIRST_DEATH_SECONDS:
			_fail("Round %d first death occurred at %.2f s" % [result["round"], first_death])

	var armed_required := int(ceil(float(REQUIRED_ARMED_ROUNDS) * float(round_count) / float(DEFAULT_ROUNDS)))
	var kills_required := int(ceil(float(REQUIRED_KILL_ROUNDS) * float(round_count) / float(DEFAULT_ROUNDS)))
	var ringouts_required := int(ceil(float(REQUIRED_RINGOUT_ROUNDS) * float(round_count) / float(DEFAULT_ROUNDS)))
	if _enforce_engagement:
		if armed_rounds < armed_required:
			_fail("Only %d/%d rounds armed at least three AI; required %d" % [armed_rounds, round_count, armed_required])
		if kill_rounds < kills_required:
			_fail("Only %d/%d rounds contained a kill; required %d" % [kill_rounds, round_count, kills_required])
		if ringout_rounds < ringouts_required:
			_fail("Only %d/%d rounds contained a ring-out; required %d" % [ringout_rounds, round_count, ringouts_required])

	print("BATCH  armed_rounds=%d kill_rounds=%d ringout_rounds=%d portal_events=%d" % [
		armed_rounds, kill_rounds, ringout_rounds, total_portal_events
	])
	return {
		"armed_rounds": armed_rounds,
		"kill_rounds": kill_rounds,
		"ringout_rounds": ringout_rounds,
		"portal_events": total_portal_events,
		"required": {
			"armed_rounds": armed_required,
			"kill_rounds": kills_required,
			"ringout_rounds": ringouts_required,
		},
		"engagement_gate_enforced": _enforce_engagement,
	}


func _on_ai_weapon_fired(_weapon_data: WeaponData, id: int, tracked: Dictionary) -> void:
	if tracked.has(id):
		var state: Dictionary = tracked[id]
		state["shots"] = int(state["shots"]) + 1
		tracked[id] = state


func _on_portal_event(
	character: BaseCharacter,
	_from_portal: TwinBaysPortal,
	_to_portal: TwinBaysPortal
) -> void:
	var elapsed_seconds := float(Time.get_ticks_msec() - _round_started_msec) / 1000.0
	var id := character.get_instance_id()
	if _portal_last_event_seconds.has(id):
		var interval := elapsed_seconds - float(_portal_last_event_seconds[id])
		_portal_min_interval_seconds = minf(_portal_min_interval_seconds, interval)
		if interval < _portal_cooldown_seconds - PORTAL_COOLDOWN_TOLERANCE_SECONDS:
			_portal_ping_pong = true
	_portal_last_event_seconds[id] = elapsed_seconds
	_portal_event_count += 1


func _get_characters(arena: Node) -> Array[BaseCharacter]:
	var characters: Array[BaseCharacter] = []
	for node in _walk(arena):
		if node is BaseCharacter and not node is CloneCharacter:
			characters.append(node as BaseCharacter)
	return characters


func _has_safe_ground_at(position: Vector3, excluded_rids: Array[RID]) -> bool:
	var world := root.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 3.0,
		position + Vector3.DOWN * 6.0
	)
	query.exclude = excluded_rids
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider := hit.get("collider") as Node
	if collider is BaseCharacter:
		return false
	var normal := hit.get("normal", Vector3.ZERO) as Vector3
	return normal.dot(Vector3.UP) >= 0.55


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _walk(search_root: Node) -> Array[Node]:
	var nodes: Array[Node] = [search_root]
	for child in search_root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _cleanup_audio_players(search_root: Node) -> void:
	for node in _walk(search_root):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.stop()


func _release_round(arena: Node) -> void:
	_cleanup_audio_players(arena)
	current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	await _settle_game_feel()


func _settle_game_feel() -> void:
	for _frame in range(120):
		if is_equal_approx(Engine.time_scale, 1.0):
			break
		await process_frame
	Engine.time_scale = 1.0


func _print_round(result: Dictionary) -> void:
	print("ROUND %d seed=%d armed=%d kills=%d ringouts=%d first_death=%.2f portals=%d stuck=%d" % [
		result["round"], result["seed"], result["armed_count"], result["kills"],
		result["ringouts"], result["first_death_seconds"], result["portal_events"], result["stuck_count"],
	])


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _argument_int(prefix: String, fallback: int) -> int:
	var value := _argument_value(prefix, str(fallback))
	return int(value) if value.is_valid_int() else fallback


func _argument_float(prefix: String, fallback: float) -> float:
	var value := _argument_value(prefix, str(fallback))
	return float(value) if value.is_valid_float() else fallback


func _argument_bool(prefix: String, fallback: bool) -> bool:
	var value := _argument_value(prefix, "true" if fallback else "false").to_lower()
	if value in ["true", "1", "yes"]:
		return true
	if value in ["false", "0", "no"]:
		return false
	return fallback


func _is_valid_report_path(path: String) -> bool:
	return path.begins_with("res://reports/") and path.ends_with(".json")


func _write_report(results: Array[Dictionary], aggregate: Dictionary) -> void:
	var report := {
		"schema_version": 1,
		"scene": SCENE_PATH,
		"configuration": {
			"seeds": DEFAULT_SEEDS.slice(0, results.size()),
			"rounds": results.size(),
			"duration_seconds": float(results[0]["duration_seconds"]) if not results.is_empty() else 0.0,
			"release_gate": results.size() == DEFAULT_ROUNDS and (
				results.is_empty() or is_equal_approx(float(results[0]["duration_seconds"]), DEFAULT_DURATION_SECONDS)
			),
			"engine_output_validation": "PowerShell wrapper scans stdout/stderr for script, engine, crash, and leak errors",
		},
		"aggregate": aggregate,
		"results": results,
		"failures": _failures,
		"passed": _failures.is_empty(),
		"generated_at_unix": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write AI batch report: %s" % _report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(results: Array[Dictionary], aggregate: Dictionary) -> void:
	_write_report(results, aggregate)
	Engine.time_scale = 1.0
	current_scene = null
	root.set_meta("disable_runtime_audio", false)
	await process_frame
	print("==================================================")
	if _failures.is_empty():
		print("[Twin Bays Splash Arena AI Batch] PASS")
		quit(0)
		return
	print("[Twin Bays Splash Arena AI Batch] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
