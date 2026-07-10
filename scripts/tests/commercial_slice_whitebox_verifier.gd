extends SceneTree

const SCENE_PATH := "res://scenes/maps/commercial_slice_a.tscn"
const REQUIRED_WHITEBOX_NODES := [
	"CommercialSliceWhitebox",
	"CommercialSliceWhitebox/CenterIsland",
	"CommercialSliceWhitebox/NorthIsland",
	"CommercialSliceWhitebox/SouthIsland",
	"CommercialSliceWhitebox/WestIsland",
	"CommercialSliceWhitebox/EastIsland",
	"CommercialSliceWhitebox/BridgeCN",
	"CommercialSliceWhitebox/BridgeCS",
	"CommercialSliceWhitebox/BridgeCW",
	"CommercialSliceWhitebox/BridgeCE",
	"CommercialSliceWhitebox/BridgeNW",
	"CommercialSliceWhitebox/BridgeNE",
	"CommercialSliceWhitebox/BridgeSW",
	"CommercialSliceWhitebox/BridgeSE",
]

var _failures: Array[String] = []
var _host: Node = null

func _initialize() -> void:
	print("==================================================")
	print("[Whitebox Verifier] Commercial Slice A")
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
	var authored_camera = arena.get_node_or_null("GlobalCamera") as Camera3D
	if authored_camera == null:
		_fail("GlobalCamera missing from authored scene")
		await _finish()
		return
	var authored_camera_position: Vector3 = authored_camera.position
	var authored_camera_basis: Basis = authored_camera.transform.basis
	var authored_camera_size: float = authored_camera.size
	_host.add_child(arena)

	await process_frame
	await process_frame

	_verify_required_nodes(arena)
	_verify_large_arena_scale(arena)
	_verify_no_legacy_dressing(arena)
	_verify_curated_dressing(arena)
	_verify_reference_style(arena)
	_verify_respawn_points(arena)
	_verify_weapon_spawns(arena)
	_verify_weapon_spawn_clusters(arena)
	_verify_visual_profile(arena)
	await _verify_fixed_camera(arena, authored_camera_position, authored_camera_basis, authored_camera_size)

	await _finish()

func _verify_required_nodes(arena: Node) -> void:
	print("\n--- Required Whitebox Nodes ---")
	for path in REQUIRED_WHITEBOX_NODES:
		if arena.get_node_or_null(path) == null:
			_fail("Missing node: %s" % path)
		else:
			print("OK  ", path)

func _verify_large_arena_scale(arena: Node) -> void:
	print("\n--- Large Arena Scale Validation ---")

	var center_size := _get_box_size(arena, "CommercialSliceWhitebox/CenterIsland")
	if center_size.x < 34.0 or center_size.z < 34.0:
		_fail("CenterIsland is still too small for the large-map target: %s" % str(center_size))
	else:
		print("OK  center island size: ", center_size)

	var north_island = arena.get_node_or_null("CommercialSliceWhitebox/NorthIsland") as Node3D
	if north_island == null or absf(north_island.position.z) < 34.0:
		_fail("Side islands are still too close to center for the large-map target")
	else:
		print("OK  side island offset: %.2f" % absf(north_island.position.z))

	var grass_size := _get_box_size(arena, "CommercialSliceBackdrop/GrassField")
	if grass_size.x < 124.0 or grass_size.z < 124.0:
		_fail("CommercialSliceBackdrop/GrassField is too small for the enlarged arena: %s" % str(grass_size))
	else:
		print("OK  backdrop size: ", grass_size)

	if not arena.has_method("_get_spawn_points"):
		_fail("Arena is missing _get_spawn_points during large-map validation")
		return

	var spawn_points = arena.call("_get_spawn_points") as Array
	var farthest_spawn := 0.0
	for point in spawn_points:
		var spawn = point as Vector3
		farthest_spawn = maxf(farthest_spawn, maxf(absf(spawn.x), absf(spawn.z)))

	if farthest_spawn < 38.0:
		_fail("Respawn points are still too close to center for the large-map target: %.2f" % farthest_spawn)
	else:
		print("OK  farthest respawn radius: %.2f" % farthest_spawn)

	var ai_script = load("res://scripts/player/ai_character.gd") as Script
	var ai_constants = ai_script.get_script_constant_map() if ai_script != null else {}
	var pickup_range = float(ai_constants.get("PICKUP_RANGE", 0.0))
	if pickup_range < 35.0:
		_fail("AI pickup range is too small for the enlarged arena: %.2f" % pickup_range)
	else:
		print("OK  AI pickup range: %.2f" % pickup_range)

func _verify_no_legacy_dressing(arena: Node) -> void:
	print("\n--- Legacy Scene Cleanup ---")
	for path in ["Floor", "Obstacles", "CommercialDressing", "ExternalArt"]:
		if arena.get_node_or_null(path) != null:
			_fail("Legacy node still present in whitebox scene: %s" % path)
		else:
			print("OK  ", path, " not present")

func _verify_curated_dressing(arena: Node) -> void:
	print("\n--- Curated Dressing Validation ---")
	var dressing_root = arena.get_node_or_null("CommercialSliceDressing") as Node3D
	if dressing_root == null:
		_fail("CommercialSliceDressing missing")
		return

	var prop_count := dressing_root.get_child_count()
	if prop_count < 12:
		_fail("CommercialSliceDressing is too sparse: expected at least 12 props, got %d" % prop_count)
	else:
		print("OK  dressing props: ", prop_count)

func _verify_reference_style(arena: Node) -> void:
	print("\n--- Reference Style Validation ---")
	_verify_reference_ground_palette(arena)
	_verify_reference_dressing_language(arena)
	_verify_reference_soft_geometry(arena)

func _verify_reference_ground_palette(arena: Node) -> void:
	var backdrop = arena.get_node_or_null("CommercialSliceBackdrop") as Node3D
	if backdrop == null or backdrop.get_node_or_null("GrassField") == null:
		_fail("CommercialSliceBackdrop/GrassField missing")
	else:
		print("OK  backdrop grass field present")

	var island_color = _get_block_albedo(arena, "CommercialSliceWhitebox/CenterIsland")
	if island_color == null:
		_fail("CenterIsland material missing")
	else:
		var island = island_color as Color
		if island.r < 0.78 or island.g < 0.88 or island.b > 0.62:
			_fail("CenterIsland is not using the lighter grass palette: %s" % str(island))
		else:
			print("OK  center island grass palette: ", island)

	var bridge_color = _get_block_albedo(arena, "CommercialSliceWhitebox/BridgeCN")
	if bridge_color == null:
		_fail("BridgeCN material missing")
	else:
		var bridge = bridge_color as Color
		if bridge.r < 0.72 or bridge.g < 0.62 or bridge.b > 0.45:
			_fail("BridgeCN is not using the warm bridge palette: %s" % str(bridge))
		else:
			print("OK  bridge palette: ", bridge)

	var wall_color = _get_block_albedo(arena, "CommercialSliceWhitebox/CoverNorth")
	if wall_color == null:
		_fail("CoverNorth material missing")
	else:
		var wall = wall_color as Color
		if wall.r < 0.64 or wall.g < 0.64 or wall.g > 0.80 or wall.b < 0.78:
			_fail("CoverNorth is not using the pastel lavender wall palette: %s" % str(wall))
		else:
			print("OK  wall palette: ", wall)

func _verify_reference_dressing_language(arena: Node) -> void:
	var dressing_root = arena.get_node_or_null("CommercialSliceDressing") as Node3D
	if dressing_root == null:
		_fail("CommercialSliceDressing missing during reference-style validation")
		return

	var tree_count := 0
	var rock_count := 0
	var foliage_count := 0

	for child in dressing_root.get_children():
		if not (child is Node):
			continue
		var path := String((child as Node).scene_file_path).to_lower()
		if path.is_empty():
			continue

		if _path_contains_any(path, [
			"gate",
			"banner",
			"grave_",
			"altar",
			"lightpost",
			"lantern",
			"pillar",
			"fence",
			"cart",
		]):
			_fail("CommercialSliceDressing still contains off-style prop: %s" % path)

		if path.contains("nature_tree"):
			tree_count += 1
		elif path.contains("rock"):
			rock_count += 1
		elif path.contains("plant") or path.contains("grass"):
			foliage_count += 1

	if tree_count < 6:
		_fail("Reference-style dressing needs at least 6 trees, got %d" % tree_count)
	else:
		print("OK  tree count: ", tree_count)

	if rock_count < 6:
		_fail("Reference-style dressing needs at least 6 rocks, got %d" % rock_count)
	else:
		print("OK  rock count: ", rock_count)

	if foliage_count < 6:
		_fail("Reference-style dressing needs at least 6 foliage props, got %d" % foliage_count)
	else:
		print("OK  foliage count: ", foliage_count)

func _verify_reference_soft_geometry(arena: Node) -> void:
	var backdrop = arena.get_node_or_null("CommercialSliceBackdrop") as Node3D
	if backdrop == null:
		_fail("CommercialSliceBackdrop missing during soft-geometry validation")
	else:
		var patch_count := 0
		var art_ground_layer_count := 0
		for child in backdrop.get_children():
			var child_name := String(child.name)
			if child_name.begins_with("GroundPatch"):
				patch_count += 1
			if (
				child_name.begins_with("GroundPatch")
				or child_name.begins_with("IslandShadow")
				or child_name.begins_with("PathWear")
			):
				art_ground_layer_count += 1
		if patch_count < 4:
			_fail("Reference-style ground needs at least 4 soft ground patches, got %d" % patch_count)
		else:
			print("OK  soft ground patches: ", patch_count)
		if art_ground_layer_count < 18:
			_fail("Art-quality ground treatment needs at least 18 soft ground layers, got %d" % art_ground_layer_count)
		else:
			print("OK  art-quality ground layers: ", art_ground_layer_count)

		for required_path in [
			"CommercialSliceBackdrop/IslandShadowCenter",
			"CommercialSliceBackdrop/IslandShadowNorth",
			"CommercialSliceBackdrop/IslandShadowSouth",
			"CommercialSliceBackdrop/IslandShadowWest",
			"CommercialSliceBackdrop/IslandShadowEast",
			"CommercialSliceBackdrop/PathWearNorth",
			"CommercialSliceBackdrop/PathWearSouth",
			"CommercialSliceBackdrop/PathWearWest",
			"CommercialSliceBackdrop/PathWearEast",
		]:
			if arena.get_node_or_null(required_path) == null:
				_fail("Missing art-quality ground layer: %s" % required_path)
			else:
				print("OK  art ground layer: ", required_path)

	for path in [
		"CommercialSliceWhitebox/CoverNorth",
		"CommercialSliceWhitebox/CoverSouth",
		"CommercialSliceWhitebox/CoverWest",
		"CommercialSliceWhitebox/CoverEast",
		"CommercialSliceWhitebox/SpawnCoverWest",
		"CommercialSliceWhitebox/SpawnCoverEast",
	]:
		var mesh = _get_block_mesh(arena, path)
		if not (mesh is CapsuleMesh):
			_fail("%s is not using a softened CapsuleMesh wall shell" % path)
		else:
			print("OK  softened wall shell: ", path)

	var shell_root = arena.get_node_or_null("CommercialSliceShells") as Node3D
	if shell_root == null:
		_fail("CommercialSliceShells missing")
		return

	var grouped_shell_count := 0
	for child in shell_root.get_children():
		if not String(child.name).begins_with("Shell"):
			continue
		grouped_shell_count += 1

		var shell_path = "CommercialSliceShells/%s" % child.name
		var shell_mesh = _get_block_mesh(arena, shell_path)
		if not (shell_mesh is CapsuleMesh):
			_fail("%s is not using a CapsuleMesh grouped shell" % shell_path)

		if (child as Node).get_node_or_null("StaticBody3D") != null:
			_fail("%s should stay decorative and collision-free" % shell_path)

	if grouped_shell_count < 32:
		_fail("Reference-style grouped shells need at least 32 decorative segments, got %d" % grouped_shell_count)
	else:
		print("OK  grouped shell segments: ", grouped_shell_count)

	for required_path in [
		"CommercialSliceShells/ShellBridgeNorthLeft",
		"CommercialSliceShells/ShellBridgeNorthRight",
		"CommercialSliceShells/ShellBridgeSouthLeft",
		"CommercialSliceShells/ShellBridgeSouthRight",
		"CommercialSliceShells/ShellBridgeWestTop",
		"CommercialSliceShells/ShellBridgeWestBottom",
		"CommercialSliceShells/ShellBridgeEastTop",
		"CommercialSliceShells/ShellBridgeEastBottom",
		"CommercialSliceShells/ShellSideLinkNWNorth",
		"CommercialSliceShells/ShellSideLinkNWWest",
		"CommercialSliceShells/ShellSideLinkNENorth",
		"CommercialSliceShells/ShellSideLinkNEEast",
		"CommercialSliceShells/ShellSideLinkSWSouth",
		"CommercialSliceShells/ShellSideLinkSWWest",
		"CommercialSliceShells/ShellSideLinkSESouth",
		"CommercialSliceShells/ShellSideLinkSEEast",
	]:
		if arena.get_node_or_null(required_path) == null:
			_fail("Missing grouped shell segment: %s" % required_path)
		else:
			print("OK  grouped shell anchor: ", required_path)

	_verify_island_edge_treatment(arena)
	_verify_wall_cap_treatment(arena)

func _verify_island_edge_treatment(arena: Node) -> void:
	var edge_root = arena.get_node_or_null("CommercialSliceIslandEdges") as Node3D
	if edge_root == null:
		_fail("CommercialSliceIslandEdges missing")
		return

	var edge_count := 0
	for child in edge_root.get_children():
		if not String(child.name).begins_with("IslandEdge"):
			continue
		edge_count += 1

		var edge_path = "CommercialSliceIslandEdges/%s" % child.name
		var edge_mesh = _get_block_mesh(arena, edge_path)
		if not (edge_mesh is CylinderMesh):
			_fail("%s is not using a soft CylinderMesh island-edge layer" % edge_path)

		if (child as Node).get_node_or_null("StaticBody3D") != null:
			_fail("%s should stay decorative and collision-free" % edge_path)

	if edge_count < 24:
		_fail("Art-quality island edge treatment needs at least 24 decorative segments, got %d" % edge_count)
	else:
		print("OK  island edge segments: ", edge_count)

	for required_path in [
		"CommercialSliceIslandEdges/IslandEdgeCenterNorth",
		"CommercialSliceIslandEdges/IslandEdgeCenterSouth",
		"CommercialSliceIslandEdges/IslandEdgeCenterWest",
		"CommercialSliceIslandEdges/IslandEdgeCenterEast",
		"CommercialSliceIslandEdges/IslandEdgeNorthOuter",
		"CommercialSliceIslandEdges/IslandEdgeSouthOuter",
		"CommercialSliceIslandEdges/IslandEdgeWestOuter",
		"CommercialSliceIslandEdges/IslandEdgeEastOuter",
	]:
		if arena.get_node_or_null(required_path) == null:
			_fail("Missing island edge segment: %s" % required_path)
		else:
			print("OK  island edge anchor: ", required_path)

func _verify_wall_cap_treatment(arena: Node) -> void:
	var cap_root = arena.get_node_or_null("CommercialSliceWallCaps") as Node3D
	if cap_root == null:
		_fail("CommercialSliceWallCaps missing")
		return

	var cap_count := 0
	for child in cap_root.get_children():
		if not String(child.name).begins_with("WallCap"):
			continue
		cap_count += 1

		var cap_path = "CommercialSliceWallCaps/%s" % child.name
		var cap_mesh = _get_block_mesh(arena, cap_path)
		if not (cap_mesh is SphereMesh):
			_fail("%s is not using a rounded SphereMesh wall cap" % cap_path)

		if (child as Node).get_node_or_null("StaticBody3D") != null:
			_fail("%s should stay decorative and collision-free" % cap_path)

	if cap_count < 24:
		_fail("Art-quality wall cap treatment needs at least 24 decorative caps, got %d" % cap_count)
	else:
		print("OK  wall cap segments: ", cap_count)

	for required_path in [
		"CommercialSliceWallCaps/WallCapBridgeNorthLeft",
		"CommercialSliceWallCaps/WallCapBridgeNorthRight",
		"CommercialSliceWallCaps/WallCapBridgeSouthLeft",
		"CommercialSliceWallCaps/WallCapBridgeSouthRight",
		"CommercialSliceWallCaps/WallCapCenterNorthWest",
		"CommercialSliceWallCaps/WallCapCenterNorthEast",
		"CommercialSliceWallCaps/WallCapCenterSouthWest",
		"CommercialSliceWallCaps/WallCapCenterSouthEast",
	]:
		if arena.get_node_or_null(required_path) == null:
			_fail("Missing wall cap segment: %s" % required_path)
		else:
			print("OK  wall cap anchor: ", required_path)

func _verify_visual_profile(arena: Node) -> void:
	print("\n--- Visual Profile Validation ---")

	var light = arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light == null:
		_fail("DirectionalLight3D missing")
	else:
		if light.light_energy > 0.72:
			_fail("DirectionalLight3D energy is still too high for Commercial Slice A: %.2f" % light.light_energy)
		else:
			print("OK  light energy: %.2f" % light.light_energy)

	var env_node = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		_fail("WorldEnvironment missing")
		return

	var env = env_node.environment
	if env.tonemap_exposure > 0.56:
		_fail("Tonemap exposure is still too bright for Commercial Slice A: %.2f" % env.tonemap_exposure)
	else:
		print("OK  tonemap exposure: %.2f" % env.tonemap_exposure)

	if env.ambient_light_energy > 0.22:
		_fail("Ambient light energy is still too high for Commercial Slice A: %.2f" % env.ambient_light_energy)
	else:
		print("OK  ambient light energy: %.2f" % env.ambient_light_energy)

	if env.fog_density > 0.0020:
		_fail("Fog density is still too high for Commercial Slice A: %.4f" % env.fog_density)
	else:
		print("OK  fog density: %.4f" % env.fog_density)

func _verify_weapon_spawns(arena: Node) -> void:
	print("\n--- Weapon Spawn Validation ---")
	var weapon_spawner = arena.get_node_or_null("WeaponSpawner")
	if weapon_spawner == null:
		_fail("WeaponSpawner node missing")
		return

	var spawn_points = weapon_spawner.get("custom_spawn_points")
	if spawn_points == null or spawn_points.is_empty():
		_fail("WeaponSpawner.custom_spawn_points is empty")
		return

	var whitebox_root = arena.get_node_or_null("CommercialSliceWhitebox") as Node3D
	if whitebox_root == null:
		_fail("CommercialSliceWhitebox root missing")
		return

	for point in spawn_points:
		if not _point_on_any_whitebox_surface(point as Vector3, whitebox_root):
			_fail("Weapon spawn is not on a playable whitebox surface: %s" % str(point))
		else:
			print("OK  ", point)

func _verify_weapon_spawn_clusters(arena: Node) -> void:
	print("\n--- Weapon Spawn Cluster Validation ---")
	var weapon_spawner = arena.get_node_or_null("WeaponSpawner")
	if weapon_spawner == null:
		_fail("WeaponSpawner node missing")
		return

	var spawn_clusters = weapon_spawner.get("custom_spawn_clusters") as Array
	if spawn_clusters == null or spawn_clusters.size() < 2:
		_fail("WeaponSpawner.custom_spawn_clusters must define at least two route groups")
		return

	var center_cluster = spawn_clusters[0] as Array
	if center_cluster == null or center_cluster.is_empty():
		_fail("Center-route pickup cluster is empty")
	else:
		for point in center_cluster:
			if not _is_bridge_mouth_pickup_point(point as Vector3):
				_fail("Center-route pickup is not bridge-adjacent enough: %s" % str(point))
			else:
				print("OK  bridge-mouth ", point)

	var side_cluster = spawn_clusters[1] as Array
	if side_cluster == null or side_cluster.is_empty():
		_fail("Side-route pickup cluster is empty")
	else:
		for point in side_cluster:
			if not _is_side_route_pickup_point(point as Vector3):
				_fail("Side-route pickup is too centered on its island: %s" % str(point))
			else:
				print("OK  side-route ", point)

func _verify_fixed_camera(
	arena: Node,
	authored_camera_position: Vector3,
	authored_camera_basis: Basis,
	authored_camera_size: float
) -> void:
	print("\n--- Fixed Camera Validation ---")

	var camera = arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		_fail("GlobalCamera missing after scene setup")
		return

	_assert_camera_matches_authored(camera, authored_camera_position, authored_camera_basis, authored_camera_size, "scene setup")

	var ta_runtime = arena.get_node_or_null("TAPipelineRuntime")
	if ta_runtime == null:
		_fail("TAPipelineRuntime missing")
		return

	var dummy_character = Node3D.new()
	dummy_character.position = Vector3(240, -80, 240)
	_host.add_child(dummy_character)

	ta_runtime.call("update_runtime_camera", arena, [dummy_character], 1.0)
	await process_frame

	camera = arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		_fail("GlobalCamera missing after runtime follow update")
	else:
		_assert_camera_matches_authored(camera, authored_camera_position, authored_camera_basis, authored_camera_size, "runtime follow update")

	dummy_character.queue_free()

func _assert_camera_matches_authored(
	camera: Camera3D,
	authored_camera_position: Vector3,
	authored_camera_basis: Basis,
	authored_camera_size: float,
	context: String
) -> void:
	if not camera.position.is_equal_approx(authored_camera_position):
		_fail("GlobalCamera moved during %s: expected position %s, got %s" % [
			context,
			str(authored_camera_position),
			str(camera.position),
		])
	else:
		print("OK  camera position locked during ", context)

	if not _basis_is_equal_approx(camera.transform.basis, authored_camera_basis):
		_fail("GlobalCamera rotated during %s" % context)
	else:
		print("OK  camera rotation locked during ", context)

	if not is_equal_approx(camera.size, authored_camera_size):
		_fail("GlobalCamera size changed during %s: expected %.2f, got %.2f" % [
			context,
			authored_camera_size,
			camera.size,
		])
	else:
		print("OK  camera size locked during ", context)

func _verify_respawn_points(arena: Node) -> void:
	print("\n--- Respawn Point Validation ---")

	if not arena.has_method("_get_spawn_points"):
		_fail("Arena is missing _get_spawn_points")
		return

	var expected_spawn_points = arena.call("_get_spawn_points") as Array
	if expected_spawn_points == null or expected_spawn_points.is_empty():
		_fail("Arena returned no spawn points")
		return

	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload missing")
		return

	var actual_respawn_points = game_config.get("respawn_points") as Array
	if actual_respawn_points == null:
		_fail("GameConfig.respawn_points missing")
		return

	if actual_respawn_points.size() != expected_spawn_points.size():
		_fail("GameConfig.respawn_points does not match arena spawn point count")
	else:
		for i in range(expected_spawn_points.size()):
			var expected = expected_spawn_points[i] as Vector3
			var actual = actual_respawn_points[i] as Vector3
			if not actual.is_equal_approx(expected):
				_fail("Respawn point mismatch at index %d: expected %s, got %s" % [i, str(expected), str(actual)])
			else:
				print("OK  ", actual)

	var whitebox_root = arena.get_node_or_null("CommercialSliceWhitebox") as Node3D
	if whitebox_root == null:
		_fail("CommercialSliceWhitebox root missing")
		return

	for point in actual_respawn_points:
		if not _point_on_any_whitebox_surface(point as Vector3, whitebox_root):
			_fail("Respawn point is not on a playable whitebox surface: %s" % str(point))

func _point_on_any_whitebox_surface(point: Vector3, whitebox_root: Node3D) -> bool:
	for child in whitebox_root.get_children():
		if not (child is Node3D):
			continue
		if _point_on_block_surface(point, child as Node3D):
			return true
	return false

func _point_on_block_surface(point: Vector3, block_root: Node3D) -> bool:
	var mesh_instance: MeshInstance3D = null
	for child in block_root.get_children():
		if child is MeshInstance3D:
			mesh_instance = child as MeshInstance3D
			break
	if mesh_instance == null:
		return false
	if mesh_instance.mesh == null or not (mesh_instance.mesh is BoxMesh):
		return false

	var box_mesh = mesh_instance.mesh as BoxMesh
	var local_point = block_root.to_local(point)
	var half_size = box_mesh.size * 0.5

	var inside_x = absf(local_point.x) <= half_size.x + 0.05
	var inside_z = absf(local_point.z) <= half_size.z + 0.05
	var near_top = absf(local_point.y - box_mesh.size.y) <= 0.55

	return inside_x and inside_z and near_top

func _is_bridge_mouth_pickup_point(point: Vector3) -> bool:
	var on_cardinal_lane = absf(point.x) <= 2.5 or absf(point.z) <= 2.5
	var bridge_band = max(absf(point.x), absf(point.z)) >= 14.0
	return on_cardinal_lane and bridge_band

func _is_side_route_pickup_point(point: Vector3) -> bool:
	var primary_axis = max(absf(point.x), absf(point.z))
	var secondary_axis = min(absf(point.x), absf(point.z))
	return primary_axis >= 34.0 and secondary_axis >= 4.0 and secondary_axis <= 8.5

func _basis_is_equal_approx(a: Basis, b: Basis) -> bool:
	return a.x.is_equal_approx(b.x) and a.y.is_equal_approx(b.y) and a.z.is_equal_approx(b.z)

func _get_block_albedo(arena: Node, path: String) -> Variant:
	var block_root = arena.get_node_or_null(path) as Node3D
	if block_root == null:
		return null

	for child in block_root.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh_instance = child as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			return (mesh_instance.material_override as StandardMaterial3D).albedo_color
	return null

func _get_block_mesh(arena: Node, path: String) -> Mesh:
	var block_root = arena.get_node_or_null(path) as Node3D
	if block_root == null:
		return null

	for child in block_root.get_children():
		if child is MeshInstance3D:
			return (child as MeshInstance3D).mesh
	return null

func _get_box_size(arena: Node, path: String) -> Vector3:
	var mesh = _get_block_mesh(arena, path)
	if mesh is BoxMesh:
		return (mesh as BoxMesh).size
	return Vector3.ZERO

func _path_contains_any(path: String, tokens: Array) -> bool:
	for token in tokens:
		if path.contains(String(token)):
			return true
	return false

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	if _host and is_instance_valid(_host):
		_host.queue_free()
		await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Whitebox Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Whitebox Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
