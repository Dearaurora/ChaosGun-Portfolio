extends SceneTree

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"

var failures: Array[String] = []

func _initialize() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Momentum Circuit scene could not be loaded")
		_finish(); return
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await physics_frame
	var wind := _find_group(arena, &"momentum_circuit_wind_controller")
	if wind != null: _fail("Formal scene must not contain a wind controller")
	var teleporters := get_nodes_in_group(&"momentum_circuit_random_teleporter")
	if teleporters.size() != 4: _fail("Expected four random teleporters, got %d" % teleporters.size())
	for teleporter in teleporters:
		if not teleporter.has_method("set_destinations") or not teleporter.has_method("get_debug_state"):
			_fail("Teleporter contract missing on %s" % teleporter.name)
	var gravity_nodes := []
	for node in _walk(arena):
		var path := String(node.get_script().resource_path) if node.get_script() != null else ""
		if path.contains("momentum_circuit_gravity") or node.is_in_group(&"momentum_circuit_gravity_activator"):
			gravity_nodes.append(node)
	if not gravity_nodes.is_empty(): _fail("Formal scene still contains legacy gravity/button nodes")
	if failures.is_empty():
		print("RESULT momentum_circuit_wind_teleport_mechanics passed=true wind=disabled teleporter_targets=4")
	else:
		for failure in failures: push_error(failure)
		print("RESULT momentum_circuit_wind_teleport_mechanics passed=false failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _find_group(arena: Node, group_name: StringName) -> Node:
	for node in get_nodes_in_group(group_name):
		if node == arena or arena.is_ancestor_of(node): return node
	return null

func _walk(node: Node) -> Array[Node]:
	var result: Array[Node] = [node]
	for child in node.get_children(): result.append_array(_walk(child))
	return result

func _fail(message: String) -> void:
	failures.append(message)

func _finish() -> void:
	quit(1)
