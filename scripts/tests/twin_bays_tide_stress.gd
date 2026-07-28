extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const REQUIRED_PHASES := [
	"initial_dry", "warning", "rising", "high", "falling", "draining", "dry_hold",
]

var _failed := false
var _arena: Node3D = null


func _initialize() -> void:
	seed(20260722)
	root.set_meta("disable_runtime_audio", true)
	var duration := _argument_float("--duration=", 55.0)
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN, match_config.SlotType.AI,
			match_config.SlotType.AI, match_config.SlotType.AI,
		]
	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	_expect(_arena != null, "production arena loads")
	if _arena == null:
		_finish(duration)
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await physics_frame
	var tide := _arena.get_node_or_null("TwinBaysTideController") as TwinBaysTideController
	var water := _arena.get_node_or_null("TwinBaysShallowWater") as TwinBaysShallowWater
	_expect(tide != null and water != null, "tide and water feedback controllers exist")
	if tide == null or water == null:
		_finish(duration)
		return

	var intro_wait := 0.0
	while not bool(tide.get_debug_state().get("running", false)) and intro_wait < 4.0:
		await create_timer(0.05).timeout
		intro_wait += 0.05
	_expect(bool(tide.get_debug_state().get("running", false)), "GO completion starts the tide cycle")

	var seen: Dictionary = {}
	var high_modifier_verified := false
	var off_high_restore_verified := false
	var elapsed := 0.0
	while elapsed < duration and is_instance_valid(_arena):
		var state := tide.get_debug_state()
		var phase := String(state.get("phase", ""))
		seen[phase] = true
		var characters := _characters()
		if phase == "high" and characters.size() == 4:
			var eligible_count := 0
			for character in characters:
				if not character.is_dead and not character.is_game_over \
				and not character.is_scripted_traversal_active():
					eligible_count += 1
			# The gameplay contract deliberately excludes dead, falling-hidden,
			# and scripted portal-traversal actors. Requiring all four live slots
			# simultaneously made the long-run test depend on combat timing.
			high_modifier_verified = high_modifier_verified or (
				eligible_count > 0
				and int(state.get("motion_modifier_count", 0)) == eligible_count
			)
		elif phase in ["falling", "draining", "dry_hold"]:
			off_high_restore_verified = off_high_restore_verified or int(state.get("motion_modifier_count", -1)) == 0
		for character in characters:
			_expect(_finite_vector(character.global_position), "character position remains finite")
			_expect(_finite_vector(character.linear_velocity), "character velocity remains finite")
		await create_timer(0.10).timeout
		elapsed += 0.10

	if duration >= 54.0:
		for phase in REQUIRED_PHASES:
			_expect(seen.has(phase), "55-second run reaches phase %s" % phase)
		_expect(high_modifier_verified, "all eligible characters receive high-tide resistance")
		_expect(off_high_restore_verified, "environment resistance clears after high tide")
		_expect(int(tide.get_debug_state().get("collision_nodes", -1)) == 0, "tide visuals remain collision-free")
		var water_debug := water.get_debug_state()
		_expect(int(water_debug.get("ripple_pool_size", 0)) == 32, "ripple pool remains bounded")
		_expect(int(water_debug.get("footprint_pool_size", 0)) == 24, "footprint pool remains bounded")
	_finish(duration)


func _characters() -> Array[BaseCharacter]:
	var result: Array[BaseCharacter] = []
	if _arena == null:
		return result
	for child in _arena.get_children():
		if child is BaseCharacter and not child is CloneCharacter:
			result.append(child as BaseCharacter)
	return result


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _argument_float(prefix: String, fallback: float) -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return maxf(float(argument.trim_prefix(prefix)), 0.5)
	return fallback


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("TWIN_BAYS_TIDE_STRESS_FAIL %s" % message)


func _finish(duration: float) -> void:
	if _arena:
		for node in _walk(_arena):
			if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
				node.stop()
	current_scene = null
	if _arena:
		_arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	await process_frame
	Engine.time_scale = 1.0
	if _failed:
		quit(1)
	else:
		print("TWIN_BAYS_TIDE_STRESS_PASS duration=%.1f tier=%s" % [duration, "full" if duration >= 54.0 else "smoke"])
		quit(0)


func _walk(search_root: Node) -> Array[Node]:
	var nodes: Array[Node] = [search_root]
	for child in search_root.get_children():
		nodes.append_array(_walk(child))
	return nodes
