extends SceneTree

## Fixed-seed AI integrity soak for the production Momentum Circuit map.
## Defaults are the release gate: eight seeds, thirty simulated seconds each.

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const LAYOUT_PATH := "res://resources/maps/momentum_circuit_layout_v2.json"
const AI_SCENE_PATH := "res://scenes/characters/ai_character.tscn"
const DEFAULT_REPORT_PATH := "res://reports/momentum_circuit_ai_batch.json"
const DEFAULT_SEEDS := [101, 211, 307, 401, 503, 601, 701, 809]
const DEFAULT_DURATION_SECONDS := 30.0
const PERMANENT_FALL_SECONDS := 4.0
const ABNORMAL_WIPE_SECONDS := 2.0

var _failures: Array[String] = []
var _layout: Dictionary = {}
var _report_path := DEFAULT_REPORT_PATH
var _pause_guard: Node = null


class AIPauseGuard extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		var scene_tree := get_tree()
		if scene_tree and scene_tree.paused:
			scene_tree.paused = false


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit AI Batch]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	paused = false
	Engine.time_scale = 1.0
	# Match results legitimately pause the shared tree. The runtime verifier owns
	# that behavior; this soak needs every seed to complete all 30 simulated
	# seconds even if a winner is declared early.
	_pause_guard = AIPauseGuard.new()
	_pause_guard.name = "MomentumCircuitAIPauseGuard"
	_pause_guard.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_pause_guard)

	_layout = _load_json_dictionary(LAYOUT_PATH)
	_report_path = _argument_value("--report=", DEFAULT_REPORT_PATH)
	if not _valid_report_path(_report_path):
		_fail("AI batch report must be a JSON file under res://reports/")
		_report_path = DEFAULT_REPORT_PATH
	if _layout.is_empty():
		_fail("Authoritative layout is missing or invalid: %s" % LAYOUT_PATH)
	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene is missing: %s" % SCENE_PATH)
	if not ResourceLoader.exists(AI_SCENE_PATH):
		_fail("Shared AI scene is missing: %s" % AI_SCENE_PATH)
	if not _failures.is_empty():
		await _finish([], {})
		return

	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load production scene")
		await _finish([], {})
		return
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		await _finish([], {})
		return

	var custom_seeds := _parse_seed_argument()
	var max_rounds := custom_seeds.size() if not custom_seeds.is_empty() else DEFAULT_SEEDS.size()
	var round_count := clampi(_argument_int("--rounds=", max_rounds), 1, max_rounds)
	var seeds: Array[int] = custom_seeds.duplicate()
	if seeds.is_empty():
		seeds.assign(DEFAULT_SEEDS)
	seeds.resize(round_count)
	var duration_seconds := clampf(_argument_float("--duration=", DEFAULT_DURATION_SECONDS), 1.0, 300.0)

	var danger_bias := await _verify_danger_bias(packed, match_config)
	var results: Array[Dictionary] = []
	for index in range(round_count):
		var result := await _run_round(packed, match_config, index, seeds[index], duration_seconds)
		results.append(result)
		_print_round(result)
	var aggregate := _summarize_and_verify(results, danger_bias)
	await _finish(results, aggregate)


func _verify_danger_bias(packed: PackedScene, match_config: Node) -> Dictionary:
	print("\n--- Light Bridge Warning Escape / Teleporter Availability Probe ---")
	match_config.set("slots", [
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	])
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	await physics_frame

	var teleporters := arena.get_tree().get_nodes_in_group(&"momentum_circuit_random_teleporter")
	var result := {
		"verified": false,
		"candidate": [],
		"direction": [],
		"weight": 0.0,
		"reason": "",
	}
	if teleporters.size() != 4:
		result["reason"] = "random teleporters missing"
		_fail("Momentum Circuit requires four random teleporters")
		await _release_arena(arena)
		return result
	var controllers := arena.get_tree().get_nodes_in_group(&"momentum_circuit_light_bridge_controller")
	var controller: Node = null
	for candidate: Node in controllers:
		if candidate == arena or arena.is_ancestor_of(candidate):
			controller = candidate
			break
	if controller == null or not controller.has_method("test_step") or not controller.has_method("get_ai_movement_bias"):
		result["reason"] = "light bridge controller missing"
		_fail("Momentum Circuit requires the rotating light-bridge controller")
		await _release_arena(arena)
		return result
	controller.set_physics_process(false)
	var debug := controller.call("get_debug_state") as Dictionary
	controller.call("test_step", maxf(0.0, float(debug.get("state_duration", 8.0)) - float(debug.get("state_elapsed", 0.0))))
	var specs := controller.call("get_bridge_specs") as Array
	var opening_spec: Dictionary = {}
	for value: Variant in specs:
		var spec := value as Dictionary
		if String(spec.get("id", "")) == "bridge_hole_02":
			opening_spec = spec
			break
	if opening_spec.is_empty():
		_fail("Opening hole-2 bridge spec is missing")
		await _release_arena(arena)
		return result
	var start_values := opening_spec.get("start_xz", []) as Array
	var end_values := opening_spec.get("end_xz", []) as Array
	var start := Vector3(float(start_values[0]), 1.86, float(start_values[1]))
	var finish := Vector3(float(end_values[0]), 1.86, float(end_values[1]))
	var probe := Node3D.new()
	probe.position = start.lerp(finish, 0.25)
	arena.add_child(probe)
	await process_frame
	var bias := controller.call("get_ai_movement_bias", probe) as Dictionary
	var bias_direction := bias.get("direction", Vector3.ZERO) as Vector3
	result["direction"] = [bias_direction.x, bias_direction.y, bias_direction.z]
	result["weight"] = float(bias.get("weight", 0.0))
	result["verified"] = absf(float(result["weight"]) - 0.85) <= 0.001
	result["reason"] = String(bias.get("reason", ""))
	if not bool(result["verified"]):
		_fail("Warning-bridge AI escape bias was not 0.85")
	print("OK  warning bridge yields 0.85 nearest-bank bias; four random teleporters remain available")
	probe.queue_free()
	await _release_arena(arena)
	return result


func _run_round(
	packed: PackedScene,
	match_config: Node,
	round_index: int,
	round_seed: int,
	duration_seconds: float
) -> Dictionary:
	# A prior round can legitimately finish a match and pause the shared tree.
	# Every seed must begin as an independent, live 30-second simulation.
	paused = false
	seed(round_seed)
	Engine.time_scale = 1.0
	match_config.set("slots", [
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	])
	var arena := packed.instantiate() as Node3D
	arena.name = "MomentumCircuitAIRound%d" % (round_index + 1)
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	await physics_frame

	var characters := _get_characters(arena)
	var physics_rate := maxi(1, Engine.physics_ticks_per_second)
	var physics_frames := int(round(duration_seconds * float(physics_rate)))
	var permanent_fall_frames := maxi(1, int(PERMANENT_FALL_SECONDS * float(physics_rate)))
	var game_config := root.get_node_or_null("GameConfig")
	var fall_threshold := float(game_config.get("fall_threshold")) if game_config != null else -16.0
	var result: Dictionary = {
		"round": round_index + 1,
		"seed": round_seed,
		"duration_seconds": duration_seconds,
		"character_count": characters.size(),
		"nan_or_inf_frames": 0,
		"permanent_fall_count": 0,
		"permanent_fall_characters": [],
		"abnormal_early_wipe": false,
		"first_all_unavailable_seconds": -1.0,
		"first_death_seconds": -1.0,
		"total_deaths": 0,
		"total_kills": 0,
		"maximum_continuous_fall_seconds": 0.0,
		"minimum_distance_travelled": 0.0,
		"controller_activation_serial": 0,
		"bridge_switch_serial": 0,
	}
	if characters.size() != 4:
		result["setup_failure"] = "Expected four AI characters, got %d" % characters.size()
		await _release_arena(arena)
		return result

	var tracked: Dictionary = {}
	for character in characters:
		tracked[character.get_instance_id()] = {
			"name": String(character.name),
			"last_position": character.global_position,
			"distance": 0.0,
			"below_frames": 0,
			"max_below_frames": 0,
			"permanent_recorded": false,
			"last_deaths": int(character.deaths),
		}

	for frame in range(physics_frames):
		await physics_frame
		characters = _get_characters(arena)
		var all_unavailable := not characters.is_empty()
		for character in characters:
			var id := character.get_instance_id()
			if not tracked.has(id):
				continue
			var state := tracked[id] as Dictionary
			var position := character.global_position
			if not _finite_vector(position) or not _finite_vector(character.linear_velocity):
				result["nan_or_inf_frames"] = int(result["nan_or_inf_frames"]) + 1
			var frame_distance := position.distance_to(state["last_position"] as Vector3)
			if is_finite(frame_distance):
				state["distance"] = float(state["distance"]) + frame_distance
			state["last_position"] = position

			if not character.is_game_over and position.y < fall_threshold:
				state["below_frames"] = int(state["below_frames"]) + 1
				state["max_below_frames"] = maxi(int(state["max_below_frames"]), int(state["below_frames"]))
				if int(state["below_frames"]) >= permanent_fall_frames and not bool(state["permanent_recorded"]):
					state["permanent_recorded"] = true
					result["permanent_fall_count"] = int(result["permanent_fall_count"]) + 1
					(result["permanent_fall_characters"] as Array).append(String(character.name))
			elif position.y >= fall_threshold + 2.0 or character.is_game_over:
				state["below_frames"] = 0

			var new_deaths := int(character.deaths) - int(state["last_deaths"])
			if new_deaths > 0:
				result["total_deaths"] = int(result["total_deaths"]) + new_deaths
				if float(result["first_death_seconds"]) < 0.0:
					result["first_death_seconds"] = float(frame) / float(physics_rate)
				state["last_deaths"] = int(character.deaths)
			tracked[id] = state
			if not character.is_dead and not character.is_game_over:
				all_unavailable = false

		if all_unavailable and float(result["first_all_unavailable_seconds"]) < 0.0:
			var wipe_time := float(frame) / float(physics_rate)
			result["first_all_unavailable_seconds"] = wipe_time
			if wipe_time < ABNORMAL_WIPE_SECONDS:
				result["abnormal_early_wipe"] = true

	var minimum_distance := INF
	var maximum_fall_frames := 0
	for state_value: Variant in tracked.values():
		var state := state_value as Dictionary
		minimum_distance = minf(minimum_distance, float(state["distance"]))
		maximum_fall_frames = maxi(maximum_fall_frames, int(state["max_below_frames"]))
	result["minimum_distance_travelled"] = minimum_distance if is_finite(minimum_distance) else 0.0
	result["maximum_continuous_fall_seconds"] = float(maximum_fall_frames) / float(physics_rate)
	for character in characters:
		result["total_kills"] = int(result["total_kills"]) + int(character.kills)
	var controller := _find_method_node(arena, [&"get_debug_state", &"get_ai_movement_bias", &"test_step"])
	if controller != null:
		var debug := controller.call("get_debug_state") as Dictionary
		result["bridge_switch_serial"] = int(debug.get("switch_serial", 0))
		result["controller_activation_serial"] = int(result["bridge_switch_serial"])

	await _release_arena(arena)
	return result


func _summarize_and_verify(results: Array[Dictionary], danger_bias: Dictionary) -> Dictionary:
	var total_deaths := 0
	var total_kills := 0
	var activation_rounds := 0
	for result in results:
		var round_number := int(result.get("round", 0))
		if result.has("setup_failure"):
			_fail("Round %d setup failed: %s" % [round_number, result["setup_failure"]])
		if int(result.get("nan_or_inf_frames", 0)) > 0:
			_fail("Round %d observed NaN/INF character state" % round_number)
		if int(result.get("permanent_fall_count", 0)) > 0:
			_fail("Round %d left AI below the fall threshold for %.1f seconds" % [round_number, PERMANENT_FALL_SECONDS])
		if bool(result.get("abnormal_early_wipe", false)):
			_fail("Round %d had all AI unavailable inside %.1f seconds" % [round_number, ABNORMAL_WIPE_SECONDS])
		total_deaths += int(result.get("total_deaths", 0))
		total_kills += int(result.get("total_kills", 0))
		if int(result.get("bridge_switch_serial", 0)) > 0:
			activation_rounds += 1
	if not bool(danger_bias.get("verified", false)):
		_fail("Deterministic warning-bridge escape bias was not verified")
	print("BATCH rounds=%d deaths=%d kills=%d bridge_switch_rounds=%d warning_escape_bias=%s" % [
		results.size(), total_deaths, total_kills, activation_rounds, danger_bias.get("verified", false)
	])
	return {
		"rounds": results.size(),
		"total_deaths": total_deaths,
		"total_kills": total_kills,
		"gravity_activation_rounds": activation_rounds,
		"bridge_switch_rounds": activation_rounds,
		"danger_bias": danger_bias,
	}


func _find_unsafe_force_edge(arena: Node3D, direction: int) -> Vector3:
	var platform := _layout.get("platform", {}) as Dictionary
	var outline := _packed_vector2_array(platform.get("visual_top_outline_world_xz", platform.get("outline_world_xz", [])))
	var holes: Array[PackedVector2Array] = []
	for raw_hole: Variant in _layout.get("holes", []):
		var hole := raw_hole as Dictionary
		holes.append(_packed_vector2_array(hole.get("visual_top_outline_world_xz", hole.get("outline_world_xz", []))))
	if outline.size() < 3:
		return Vector3.ZERO
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var top_y := float(platform.get("top_y", 1.0))
	var x := 2.5
	while x <= bounds.end.x:
		var z := bounds.position.y
		while z <= bounds.end.y:
			var current := Vector2(x, z)
			var probe := current + Vector2(float(direction) * 7.0, 0.0)
			if _walkable_point(current, outline, holes) and not _walkable_point(probe, outline, holes):
				var candidate := Vector3(current.x, top_y + 0.4, current.y)
				if _has_ground_at(arena, candidate) and not _has_ground_at(arena, Vector3(probe.x, top_y + 0.4, probe.y)):
					return candidate
			z += 1.5
		x += 1.5
	return Vector3.ZERO


func _walkable_point(point: Vector2, outline: PackedVector2Array, holes: Array[PackedVector2Array]) -> bool:
	if not Geometry2D.is_point_in_polygon(point, outline):
		return false
	for hole in holes:
		if Geometry2D.is_point_in_polygon(point, hole):
			return false
	return true


func _has_ground_at(arena: Node3D, position: Vector3) -> bool:
	var world := arena.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 3.0, position + Vector3.DOWN * 8.0)
	query.collision_mask = 1
	query.collide_with_areas = false
	return not world.direct_space_state.intersect_ray(query).is_empty()


func _find_method_node(search_root: Node, methods: Array[StringName]) -> Node:
	for node in _walk(search_root):
		var matches := true
		for method_name in methods:
			if not node.has_method(method_name):
				matches = false
				break
		if matches:
			return node
	return null


func _get_characters(search_root: Node) -> Array[BaseCharacter]:
	var result: Array[BaseCharacter] = []
	for node in _walk(search_root):
		if node is BaseCharacter and not node is CloneCharacter:
			result.append(node as BaseCharacter)
	return result


func _walk(search_root: Node) -> Array[Node]:
	var result: Array[Node] = [search_root]
	for child in search_root.get_children():
		result.append_array(_walk(child))
	return result


func _release_arena(arena: Node) -> void:
	paused = false
	if arena != null and is_instance_valid(arena):
		_cleanup_audio(arena)
		current_scene = null
		arena.queue_free()
		await process_frame
		await process_frame
	Engine.time_scale = 1.0


func _cleanup_audio(search_root: Node) -> void:
	for node in _walk(search_root):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.stop()


func _packed_vector2_array(value: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	if value is PackedVector2Array:
		return value as PackedVector2Array
	if not value is Array:
		return result
	for raw_point: Variant in value as Array:
		if raw_point is Array and (raw_point as Array).size() >= 2:
			result.append(Vector2(float(raw_point[0]), float(raw_point[1])))
	return result


func _parse_seed_argument() -> Array[int]:
	var list_value := _argument_value("--seeds=", "")
	if not list_value.is_empty():
		var result: Array[int] = []
		for token in list_value.split(",", false):
			var value := token.strip_edges()
			if value.is_valid_int():
				result.append(int(value))
		return result
	var single_value := _argument_value("--seed=", "")
	if single_value.is_valid_int():
		return [int(single_value)]
	return []


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


func _valid_report_path(path: String) -> bool:
	return path.begins_with("res://reports/") and path.ends_with(".json")


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _print_round(result: Dictionary) -> void:
	print("ROUND %d seed=%d deaths=%d kills=%d nan=%d permanent_falls=%d early_wipe=%s bridge_switches=%d" % [
		result.get("round", 0), result.get("seed", 0), result.get("total_deaths", 0),
		result.get("total_kills", 0), result.get("nan_or_inf_frames", 0),
		result.get("permanent_fall_count", 0), result.get("abnormal_early_wipe", false),
		result.get("bridge_switch_serial", 0),
	])


func _write_report(results: Array[Dictionary], aggregate: Dictionary) -> void:
	var release_gate := results.size() == DEFAULT_SEEDS.size()
	if release_gate:
		for index in range(results.size()):
			release_gate = release_gate and int(results[index].get("seed", 0)) == DEFAULT_SEEDS[index]
			release_gate = release_gate and absf(float(results[index].get("duration_seconds", 0.0)) - DEFAULT_DURATION_SECONDS) < 0.001
	var report := {
		"schema_version": 1,
		"scene": SCENE_PATH,
		"configuration": {
			"seeds": results.map(func(value: Dictionary) -> int: return int(value.get("seed", 0))),
			"duration_seconds": float(results[0].get("duration_seconds", 0.0)) if not results.is_empty() else 0.0,
			"release_gate": release_gate,
			"permanent_fall_seconds": PERMANENT_FALL_SECONDS,
			"abnormal_wipe_seconds": ABNORMAL_WIPE_SECONDS,
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
		print("RESULT momentum_circuit_ai_batch passed=true rounds=%d" % results.size())
		print("[Momentum Circuit AI Batch] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_ai_batch passed=false rounds=%d failures=%d" % [results.size(), _failures.size()])
	print("[Momentum Circuit AI Batch] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
