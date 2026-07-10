extends SceneTree

const SCENE_PATH := "res://scenes/maps/a1_reference_basin.tscn"
const REQUIRED_NODES := [
	"A1ReferenceWhitebox",
	"A1ReferenceWhitebox/WestIslandCore",
	"A1ReferenceWhitebox/EastIslandCore",
	"A1ReferenceWhitebox/SouthIslandCore",
	"A1ReferenceWhitebox/BridgeWestEastMain",
	"A1ReferenceWhitebox/BridgeWestSouth",
	"A1ReferenceWhitebox/BridgeEastSouth",
	"A1ReferenceWhitebox/CrescentLandmarkBack",
]

var _failures: Array[String] = []
var _host: Node = null

func _initialize() -> void:
	print("==================================================")
	print("[A1 Reference Basin Verifier]")
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
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]

	_host = Node.new()
	root.add_child(_host)

	var arena = scene.instantiate()
	_host.add_child(arena)

	await process_frame
	await process_frame
	await physics_frame

	_verify_required_nodes(arena)
	_verify_bridge_widths(arena)
	_verify_spawn_ground(arena)
	_verify_void_samples(arena)
	_verify_weapon_clusters(arena)

	await _finish()

func _verify_required_nodes(arena: Node) -> void:
	print("\n--- Required Nodes ---")
	for path in REQUIRED_NODES:
		if arena.get_node_or_null(path) == null:
			_fail("Missing node: %s" % path)
		else:
			print("OK  ", path)

func _verify_bridge_widths(arena: Node) -> void:
	print("\n--- Bridge Widths ---")
	var main_size = _get_box_size(arena, "A1ReferenceWhitebox/BridgeWestEastMain")
	if main_size.x < 22.0 or main_size.z < 8.0:
		_fail("Main bridge is too small: %s" % str(main_size))
	else:
		print("OK  main bridge: ", main_size)

	for path in [
		"A1ReferenceWhitebox/BridgeWestSouth",
		"A1ReferenceWhitebox/BridgeEastSouth",
	]:
		var size = _get_box_size(arena, path)
		if size.x < 22.0 or size.z < 7.5:
			_fail("%s is too small: %s" % [path, str(size)])
		else:
			print("OK  ", path, ": ", size)

func _verify_spawn_ground(arena: Node) -> void:
	print("\n--- Spawn Ground ---")
	if not arena.has_method("_get_spawn_points"):
		_fail("Arena missing _get_spawn_points")
		return
	var points = arena.call("_get_spawn_points") as Array
	if points.size() != 4:
		_fail("Expected 4 spawn points, got %d" % points.size())
	for point in points:
		var pos = point as Vector3
		if not _has_ground_at(pos):
			_fail("Spawn has no ground beneath it: %s" % str(pos))
		else:
			print("OK  spawn grounded: ", pos)

func _verify_void_samples(_arena: Node) -> void:
	print("\n--- Void Samples ---")
	for point in [
		Vector3(0, 5, 10),
		Vector3(-2, 5, 12),
		Vector3(4, 5, 14),
	]:
		if _has_ground_at(point):
			_fail("Expected void sample to have no ground: %s" % str(point))
		else:
			print("OK  void sample clear: ", point)

func _verify_weapon_clusters(arena: Node) -> void:
	print("\n--- Weapon Clusters ---")
	var spawner = arena.get_node_or_null("WeaponSpawner")
	if spawner == null:
		_fail("WeaponSpawner missing")
		return
	var clusters = spawner.get("custom_spawn_clusters")
	if not (clusters is Array) or clusters.size() < 2:
		_fail("Expected at least 2 weapon spawn clusters")
	else:
		print("OK  weapon clusters: ", clusters.size())
	var max_active = int(spawner.get("max_active_pickups"))
	if max_active < 2:
		_fail("Expected max_active_pickups >= 2")
	else:
		print("OK  max active pickups: ", max_active)

func _has_ground_at(pos: Vector3) -> bool:
	var world = root.get_world_3d()
	if world == null:
		return false
	var origin = Vector3(pos.x, 8.0, pos.z)
	var target = Vector3(pos.x, -6.0, pos.z)
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	var result = world.direct_space_state.intersect_ray(query)
	return not result.is_empty()

func _get_box_size(arena: Node, path: String) -> Vector3:
	var node = arena.get_node_or_null(path)
	if node == null:
		return Vector3.ZERO
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh = (child as MeshInstance3D).mesh
			if mesh is BoxMesh:
				return (mesh as BoxMesh).size
	return Vector3.ZERO

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
		print("[A1 Reference Basin Verifier] PASS")
		print("==================================================")
		quit(0)
	else:
		print("\n==================================================")
		print("[A1 Reference Basin Verifier] FAIL")
		for failure in _failures:
			print("- ", failure)
		print("==================================================")
		quit(1)
