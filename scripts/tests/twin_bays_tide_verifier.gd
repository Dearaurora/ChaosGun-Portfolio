extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const PROFILE_PATH := "res://resources/maps/twin_bays_tide_v1.json"
const MOTION_SOURCE := &"twin_bays_high_tide"

var _failed := false
var _arena: Node3D = null
var _tide: TwinBaysTideController = null


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN, match_config.SlotType.AI,
			match_config.SlotType.AI, match_config.SlotType.AI,
		]
	var profile := _load_json(PROFILE_PATH)
	_expect(String(profile.get("schema", "")) == "chaos_gun.twin_bays_tide", "tide profile schema")
	var timing := profile.get("timing", {}) as Dictionary
	var repeat_duration := 0.0
	for key in ["warning", "rising", "high", "falling", "draining", "dry_hold"]:
		repeat_duration += float(timing.get(key, 0.0))
	_expect(is_equal_approx(repeat_duration, 45.0), "repeat cycle must be exactly 45 seconds")

	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	_expect(_arena != null, "production arena loads")
	if _arena == null:
		_finish()
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await physics_frame
	_tide = _arena.get_node_or_null("TwinBaysTideController") as TwinBaysTideController
	var water := _arena.get_node_or_null("TwinBaysShallowWater") as TwinBaysShallowWater
	_expect(_tide != null, "production tide controller exists")
	_expect(water != null, "production water feedback exists")
	if _tide == null or water == null:
		_finish()
		return

	var characters: Array[BaseCharacter] = []
	for child in _arena.get_children():
		if child is BaseCharacter and not child is CloneCharacter:
			characters.append(child as BaseCharacter)
	_expect(characters.size() == 4, "four production characters participate")

	_tide.stop_cycle()
	_tide.start_cycle()
	_expect(String(_tide.get_debug_state().get("phase", "")) == "initial_dry", "cycle starts dry")
	var paused_elapsed := float(_tide.get_debug_state().get("phase_elapsed", -1.0))
	paused = true
	await create_timer(0.12, true).timeout
	paused = false
	_expect(is_equal_approx(float(_tide.get_debug_state().get("phase_elapsed", -2.0)), paused_elapsed), "pause freezes tide time")
	_tide.call("_process", 12.01)
	_expect(String(_tide.get_debug_state().get("phase", "")) == "warning", "dry advances to warning")
	_tide.call("_process", 3.01)
	_expect(String(_tide.get_debug_state().get("phase", "")) == "rising", "warning advances to rising")
	_tide.call("_process", 3.01)
	_expect(String(_tide.get_debug_state().get("phase", "")) == "high", "rising advances to high")

	for character in characters:
		var motion := character.get_environment_motion_debug()
		_expect((motion.get("sources", {}) as Dictionary).has(MOTION_SOURCE), "high tide applies composable motion source")
		_expect(is_equal_approx(float(motion.get("speed_multiplier", 0.0)), 0.90), "high tide speed multiplier")
		_expect(is_equal_approx(float(motion.get("damp_multiplier", 0.0)), 1.25), "high tide damp multiplier")
	var sample := characters[0]
	var clone_scene := load("res://scenes/characters/clone_character.tscn") as PackedScene
	var clone := clone_scene.instantiate() as CloneCharacter if clone_scene else null
	_expect(clone != null, "temporary clone scene loads")
	if clone:
		clone.configure_clone(sample, 5.0, Color.CYAN, Vector3(-40.0, 1.2, 0.0))
		# Exercise the concrete clone type without entering the scene tree; entrance
		# animation is unrelated and would add a teardown tween to this unit fixture.
		var tide_characters := _tide.get("_characters") as Array
		tide_characters.append(clone)
		_tide.set("_characters", tide_characters)
		_tide.call("_update_motion_modifiers")
		var clone_motion := clone.get_environment_motion_debug()
		_expect((clone_motion.get("sources", {}) as Dictionary).has(MOTION_SOURCE), "temporary clone receives high-tide resistance")
	sample.movement_speed_multiplier = 1.4
	var expected_ground_speed := 620.0 * 1.4 * 0.90
	_expect(absf(sample.get_movement_speed() - expected_ground_speed) < 0.5, "speed powerup composes with tide")
	_expect(water.contains_world_point(Vector3(-40.0, 1.0, 0.0)), "high tide water covers playable platform")
	_expect(not water.contains_world_point(Vector3(0.0, 1.0, 18.0)), "lethal inner bay is not classified as playable shallow water")

	_tide.call("_process", 10.01)
	_expect(String(_tide.get_debug_state().get("phase", "")) == "falling", "high advances to falling")
	for character in characters:
		_expect(not (character.get_environment_motion_debug().get("sources", {}) as Dictionary).has(MOTION_SOURCE), "falling clears tide resistance")

	_tide.set_debug_phase(&"draining", 0.0)
	var start_coverage := float(_tide.get_debug_state().get("residue_coverage", 0.0))
	_expect(start_coverage >= 0.14 and start_coverage <= 0.16, "drain start coverage is 14-16 percent")
	_expect(int(_tide.get_debug_state().get("residue_vertex_count", 0)) > 300, "drain network has renderable curved geometry")
	_expect(water.contains_world_point(Vector3(-48.0, 1.0, -4.5)), "runoff network remains interactive after tide")
	_tide.set_debug_phase(&"draining", 0.5)
	var mid_coverage := float(_tide.get_debug_state().get("residue_coverage", 0.0))
	_expect(mid_coverage >= 0.07 and mid_coverage <= 0.09, "nine-second coverage is 7-9 percent")
	_tide.set_debug_phase(&"draining", 1.0)
	_expect(float(_tide.get_debug_state().get("residue_coverage", 1.0)) <= 0.001, "residue is dry after 18 seconds")
	_expect(not water.contains_world_point(Vector3(-48.0, 1.0, -4.5)), "dry runoff no longer triggers water feedback")

	_tide.set_debug_phase(&"high", 0.5)
	_expect(int(_tide.get_debug_state().get("collision_nodes", -1)) == 0, "tide visuals own no collision or navigation")
	var backdrop := _arena.find_child("SplashBackdropVisuals", true, false) as TwinBaysSplashBackdrop
	_expect(backdrop != null, "splash backdrop remains present")
	if backdrop:
		var backdrop_debug := backdrop.get_ambient_motion_debug()
		_expect(absf(float(backdrop_debug.get("water_y", 0.0)) - 1.06) < 0.01, "background reaches authored high-water level")

	_tide.stop_cycle()
	for character in characters:
		_expect(not (character.get_environment_motion_debug().get("sources", {}) as Dictionary).has(MOTION_SOURCE), "stop clears all tide modifiers")
	if clone and is_instance_valid(clone):
		clone.free()
	# Let the shared READY/GO presentation finish its awaited tween chain before
	# tearing down this otherwise time-compressed state-machine fixture.
	await create_timer(1.40).timeout
	_tide.stop_cycle()
	_finish()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("TWIN_BAYS_TIDE_VERIFY_FAIL %s" % message)


func _finish() -> void:
	if _arena:
		_arena.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if _failed:
		quit(1)
	else:
		print("TWIN_BAYS_TIDE_VERIFY_PASS")
		quit(0)
