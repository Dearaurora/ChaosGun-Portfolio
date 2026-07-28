extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const ShallowWaterScript = preload("res://scripts/maps/twin_bays_shallow_water.gd")

var _arena: Node3D
var _water: TwinBaysShallowWater
var _tide: TwinBaysTideController
var _failed := false


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN, match_config.SlotType.AI,
			match_config.SlotType.AI, match_config.SlotType.AI,
		]
	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	_assert(_arena != null, "production arena could not be instantiated")
	if _arena == null:
		quit(1)
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await physics_frame

	var characters: Array[BaseCharacter] = []
	for child in _arena.get_children():
		if child is BaseCharacter and not child is CloneCharacter:
			characters.append(child as BaseCharacter)
	_assert(characters.size() == 4, "expected four shared production characters")
	if characters.size() != 4:
		quit(1)
		return
	for character in characters:
		character.freeze = true
		character.set_process(false)
		character.set_physics_process(false)
		character.linear_velocity = Vector3.ZERO
		character.angular_velocity = Vector3.ZERO

	_water = _arena.get_node_or_null("TwinBaysShallowWater") as TwinBaysShallowWater
	_tide = _arena.get_node_or_null("TwinBaysTideController") as TwinBaysTideController
	_assert(_water != null, "production shallow-water controller is missing")
	_assert(_tide != null, "production tide controller is missing")
	if _water == null or _tide == null:
		quit(1)
		return
	await process_frame

	var initial_debug := _water.get_debug_state()
	_assert(bool(initial_debug.get("tide_mode", false)), "water feedback must use the tide profile")
	_assert(int(initial_debug.get("water_polygon_count", 0)) == 12, "production map must use twelve connected runoff networks")
	_assert(String(initial_debug.get("gameplay_effect", "")) == "none", "water must not modify gameplay")
	_assert(int(initial_debug.get("ripple_pool_size", 0)) == 32, "ripple pool size drifted")
	_assert(int(initial_debug.get("footprint_pool_size", 0)) == 24, "footprint pool size drifted")
	_assert(int(initial_debug.get("audio_pool_size", 0)) == 12, "audio pool size drifted")
	_assert(not _water.contains_world_point(Vector3(-40.0, 1.0, 0.0)), "initial dry phase was classified as water")
	_assert(not _has_forbidden_runtime_nodes(_water), "water feedback owns collision, Area, or navigation nodes")
	_assert(not _has_forbidden_runtime_nodes(_tide), "tide visuals own collision, Area, or navigation nodes")

	var character := characters[0]
	var visual := character.get_visual()
	_assert(visual != null, "shared character visual is missing")
	var physics_before := _physics_snapshot(character)
	_tide.set_debug_phase(&"high", 0.5)
	character.global_position = Vector3(-40.0, 1.25, 0.0)
	visual.call("_play_footstep_sfx")
	_tide.set_debug_phase(&"dry_hold", 0.5)
	var dry_steps := [
		Vector3(-14.0, 1.25, 0.0), Vector3(-12.8, 1.25, 0.0),
		Vector3(-11.6, 1.25, 0.0), Vector3(-10.4, 1.25, 0.0),
	]
	for dry_position in dry_steps:
		character.global_position = dry_position
		visual.call("_play_footstep_sfx")
	var motion_debug := visual.get_motion_debug()
	_assert(int(motion_debug.get("surface_footsteps_handled", 0)) == 4, "water + three wet steps were not handled")
	_assert(int(motion_debug.get("wood_footsteps_selected", 0)) == 1, "dry ground did not return to the ordinary footstep")
	var footprint_debug := _water.get_debug_state()
	_assert(int(footprint_debug.get("wet_footprints_spawned", 0)) == 3, "wet trail must be exactly three footprints")

	_tide.set_debug_phase(&"high", 0.5)
	_water.handle_character_landing(character, Vector3(-40.0, 1.0, 0.0), 8.0)
	_water.handle_character_landing(character, Vector3(0.0, 1.0, 18.0), 16.0)
	_assert(int(_water.get_debug_state().get("landing_events", 0)) == 1, "landing feedback escaped the water polygon")

	var projectile := Projectile.new()
	projectile.name = "ShallowWaterVerifierProjectile"
	_arena.add_child(projectile)
	await process_frame
	projectile.impact_resolved.emit(Vector3(0.0, 1.0, 18.0), Vector3.DOWN, &"pistol")
	var weapon_ids: Array[StringName] = [&"pistol", &"smg", &"ak_rifle", &"shotgun", &"gatling", &"sniper"]
	var impact_points := [
		Vector3(-40.0, 1.0, -5.0), Vector3(-35.0, 1.0, 0.0),
		Vector3(-40.0, 1.0, 8.0), Vector3(40.0, 1.0, -5.0),
		Vector3(35.0, 1.0, 0.0), Vector3(40.0, 1.0, 8.0),
	]
	for index in range(weapon_ids.size()):
		projectile.impact_resolved.emit(impact_points[index], Vector3.DOWN, weapon_ids[index])
	projectile.impact_resolved.emit(impact_points[0], Vector3.DOWN, &"gatling")
	var projectile_debug := _water.get_debug_state()
	_assert(int(projectile_debug.get("projectile_events", 0)) == 6, "six weapon families did not resolve on water")
	_assert(int(projectile_debug.get("projectile_events_throttled", 0)) >= 1, "same-cell high-rate projectile throttle did not engage")

	var pool_node_count := _descendant_count(_water)
	for index in range(80):
		projectile.impact_resolved.emit(impact_points[index % impact_points.size()], Vector3.DOWN, &"gatling")
	await process_frame
	_assert(_descendant_count(_water) == pool_node_count, "water feedback created runtime nodes under stress")
	_assert(int(_water.get_debug_state().get("projectile_events", 0)) <= 24, "global projectile feedback rate exceeded 24/s")
	_assert(_physics_snapshot(character) == physics_before, "water feedback changed character physics")

	_tide.set_debug_phase(&"dry_hold", 0.5)
	# Drive the pool by its authored lifetime so this verifier remains deterministic
	# under both uncapped headless runs and rendered release wrappers.
	_water.call("_update_footprints", 1.21)
	_assert(int(_water.get_debug_state().get("active_footprints", -1)) == 0, "wet footprints were not recycled after 1.2 seconds")
	projectile.queue_free()
	_arena.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if _failed:
		quit(1)
		return
	print("TWIN_BAYS_SHALLOW_WATER_VERIFY_PASS state=released")
	quit(0)


func _physics_snapshot(character: BaseCharacter) -> Dictionary:
	return {
		"mass": character.mass,
		"gravity_scale": character.gravity_scale,
		"linear_damp": character.linear_damp,
		"angular_damp": character.angular_damp,
		"outgoing_knockback_multiplier": character.get_outgoing_knockback_multiplier(),
		"linear_velocity": character.linear_velocity,
		"angular_velocity": character.angular_velocity,
	}


func _has_forbidden_runtime_nodes(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D or child is NavigationRegion3D or child is NavigationObstacle3D:
			return true
		if _has_forbidden_runtime_nodes(child):
			return true
	return false


func _descendant_count(node: Node) -> int:
	var result := 1
	for child in node.get_children():
		result += _descendant_count(child)
	return result


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("TWIN_BAYS_SHALLOW_WATER_VERIFY_FAIL %s" % message)
