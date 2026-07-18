extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const V2_ROOT_PATH := "OpenRingoutBlenderVisuals/SunsetV2GameplayVisuals"
const MAX_V2_MESHES := 240
const MAX_V2_SURFACES := 245

var _failures: Array[String] = []
var _arena: Node = null


func _initialize() -> void:
	print("==================================================")
	print("[Open Ring-Out Render Cost Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	_configure_empty_roster()

	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() if packed else null
	if _arena == null:
		_fail("Could not instantiate %s" % SCENE_PATH)
		await _finish()
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame

	var roots := {
		"legacy": _arena.get_node_or_null("OpenRingoutBlenderVisuals/BlenderAuthoredOpenRingoutVisuals"),
		"sunset_v2": _arena.get_node_or_null(V2_ROOT_PATH),
		"p14": _arena.get_node_or_null("OpenRingoutBlenderVisuals/P14SunsetEnvironment"),
		"procedural_art": _arena.get_node_or_null("OpenRingoutArt"),
	}
	for label in roots:
		var stats := _collect_stats(roots[label])
		print("%s: %s" % [label, stats])
		if OS.get_cmdline_user_args().has("--list-visible"):
			print("%s visible meshes: %s" % [label, _visible_mesh_names(roots[label])])

	var v2_stats := _collect_stats(roots["sunset_v2"])
	if int(v2_stats.get("meshes", 0)) > MAX_V2_MESHES:
		_fail(
			"Sunset V2 exceeds the P26 mesh budget: %d > %d"
			% [int(v2_stats.get("meshes", 0)), MAX_V2_MESHES]
		)
	if int(v2_stats.get("surfaces", 0)) > MAX_V2_SURFACES:
		_fail(
			"Sunset V2 exceeds the P26 surface budget: %d > %d"
			% [int(v2_stats.get("surfaces", 0)), MAX_V2_SURFACES]
		)
	if _arena.has_method("get_environment_motion_debug"):
		var motion := _arena.call("get_environment_motion_debug") as Dictionary
		if int(motion.get("rotor_count", 0)) != 2 or int(motion.get("edge_gem_count", 0)) != 22:
			_fail("P26 batching must preserve P25 dynamic landmarks")

	await _finish()


func _collect_stats(node: Node) -> Dictionary:
	var stats := {
		"meshes": 0,
		"surfaces": 0,
		"visible_meshes": 0,
		"visible_surfaces": 0,
	}
	_collect_stats_recursive(node, stats)
	return stats


func _collect_stats_recursive(node: Node, stats: Dictionary) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0
		stats["meshes"] = int(stats["meshes"]) + 1
		stats["surfaces"] = int(stats["surfaces"]) + surface_count
		if mesh_instance.is_visible_in_tree():
			stats["visible_meshes"] = int(stats["visible_meshes"]) + 1
			stats["visible_surfaces"] = int(stats["visible_surfaces"]) + surface_count
	for child in node.get_children():
		_collect_stats_recursive(child, stats)


func _visible_mesh_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	_collect_visible_mesh_names(node, names)
	return names


func _collect_visible_mesh_names(node: Node, names: Array[String]) -> void:
	if node == null:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
		names.append(String(node.name))
	for child in node.get_children():
		_collect_visible_mesh_names(child, names)


func _configure_empty_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _arena and is_instance_valid(_arena):
		current_scene = null
		_arena.queue_free()
		_arena = null
	await process_frame
	await physics_frame
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[Open Ring-Out Render Cost Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Open Ring-Out Render Cost Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
