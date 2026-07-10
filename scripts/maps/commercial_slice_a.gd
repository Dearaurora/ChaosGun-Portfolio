extends "res://scripts/maps/battle_arena.gd"

const MAP_SCALE := 1.25
const MAIN_ISLAND_CENTER := Vector3(0, -1, 0)
const MAIN_ISLAND_SIZE := Vector3(28.0 * MAP_SCALE, 2, 28.0 * MAP_SCALE)
const SIDE_ISLAND_SIZE := Vector3(14.0 * MAP_SCALE, 2, 14.0 * MAP_SCALE)
const SIDE_ISLAND_OFFSET := 28.0 * MAP_SCALE
const MAIN_BRIDGE_OFFSET := 17.5 * MAP_SCALE
const SIDE_LINK_OFFSET := 14.0 * MAP_SCALE

const MAIN_BRIDGE_SIZE_NS := Vector3(7.5 * MAP_SCALE, 1, 7.5 * MAP_SCALE)
const MAIN_BRIDGE_SIZE_EW := Vector3(7.5 * MAP_SCALE, 1, 7.5 * MAP_SCALE)
const SIDE_LINK_SIZE := Vector3(6.5 * MAP_SCALE, 1, 18.0 * MAP_SCALE)
const LOW_COVER_SIZE := Vector3(4.5 * MAP_SCALE, 1.8, 2.4 * MAP_SCALE)
const SPAWN_COVER_SIZE := Vector3(2.8 * MAP_SCALE, 1.8, 4.2 * MAP_SCALE)
const BACKDROP_SIZE := Vector3(104.0 * MAP_SCALE, 0.4, 104.0 * MAP_SCALE)
const DRESSING_ROOT_NAME := "CommercialSliceDressing"
const SHELL_ROOT_NAME := "CommercialSliceShells"
const EDGE_ROOT_NAME := "CommercialSliceIslandEdges"
const WALL_CAP_ROOT_NAME := "CommercialSliceWallCaps"
const BLENDER_VISUAL_ROOT_NAME := "CommercialSliceBlenderVisuals"
const DRESSING_ASSET_BASE := "res://assets/models/third_party/kenney/curated_food_dojo/"
const BLENDER_VISUAL_SCENE_PATH := "res://assets/models/generated/commercial_slice_a/commercial_slice_a_visuals.glb"

func _build_map_layout() -> void:
	_clear_commercial_slice_nodes()

	var backdrop_root = Node3D.new()
	backdrop_root.name = "CommercialSliceBackdrop"
	add_child(backdrop_root)

	var map_root = Node3D.new()
	map_root.name = "CommercialSliceWhitebox"
	add_child(map_root)

	var shell_root = Node3D.new()
	shell_root.name = SHELL_ROOT_NAME
	add_child(shell_root)

	var edge_root = Node3D.new()
	edge_root.name = EDGE_ROOT_NAME
	add_child(edge_root)

	var wall_cap_root = Node3D.new()
	wall_cap_root.name = WALL_CAP_ROOT_NAME
	add_child(wall_cap_root)

	var backdrop_mat = _make_whitebox_material(Color("#b8d77f"))
	var island_mat = _make_whitebox_material(Color("#d8ef99"))
	var bridge_mat = _make_whitebox_material(Color("#ccb56f"))
	var cover_mat = _make_whitebox_material(Color("#a7acea"))
	var spawn_mat = _make_whitebox_material(Color("#b5baf0"))
	var patch_mat = _make_whitebox_material(Color("#f3eab8"))
	var moss_patch_mat = _make_whitebox_material(Color("#cfe691"))
	var island_shadow_mat = _make_overlay_material(Color("#8daf68"), 0.38)
	var path_wear_mat = _make_overlay_material(Color("#efd892"), 0.50)
	var path_wear_soft_mat = _make_overlay_material(Color("#d7e592"), 0.42)
	var island_edge_mat = _make_overlay_material(Color("#b8dd7d"), 0.68)
	var island_edge_highlight_mat = _make_overlay_material(Color("#e4f4a5"), 0.48)
	var wall_cap_mat = _make_overlay_material(Color("#b9bef4"), 0.92)
	var wall_cap_highlight_mat = _make_overlay_material(Color("#d2d6ff"), 0.78)

	_spawn_whitebox_block("GrassField", Vector3(0, -2.6, 0), BACKDROP_SIZE, backdrop_root, backdrop_mat, false)
	_spawn_whitebox_block("GrassFieldInset", Vector3(0, -2.3, 0), _map_size(92, 0.2, 92), backdrop_root, _make_whitebox_material(Color("#c9e48b")), false)
	_spawn_ground_patch("IslandShadowCenter", _map_pos(0, -2.15, 0), _map_vec2(36, 36), backdrop_root, island_shadow_mat, 0.0)
	_spawn_ground_patch("IslandShadowNorth", _map_pos(0, -2.15, -35), _map_vec2(19, 19), backdrop_root, island_shadow_mat, 0.0)
	_spawn_ground_patch("IslandShadowSouth", _map_pos(0, -2.15, 35), _map_vec2(19, 19), backdrop_root, island_shadow_mat, 0.0)
	_spawn_ground_patch("IslandShadowWest", _map_pos(-35, -2.15, 0), _map_vec2(19, 19), backdrop_root, island_shadow_mat, 0.0)
	_spawn_ground_patch("IslandShadowEast", _map_pos(35, -2.15, 0), _map_vec2(19, 19), backdrop_root, island_shadow_mat, 0.0)
	_spawn_ground_patch("PathWearNorth", _map_pos(0, -2.11, -21.5), _map_vec2(8.5, 6.0), backdrop_root, path_wear_mat, 0.0)
	_spawn_ground_patch("PathWearSouth", _map_pos(0, -2.11, 21.5), _map_vec2(8.5, 6.0), backdrop_root, path_wear_mat, 0.0)
	_spawn_ground_patch("PathWearWest", _map_pos(-21.5, -2.11, 0), _map_vec2(6.0, 8.5), backdrop_root, path_wear_mat, 0.0)
	_spawn_ground_patch("PathWearEast", _map_pos(21.5, -2.11, 0), _map_vec2(6.0, 8.5), backdrop_root, path_wear_mat, 0.0)
	_spawn_ground_patch("PathWearNorthWest", _map_pos(-17.5, -2.12, -17.5), _map_vec2(5.5, 12.0), backdrop_root, path_wear_soft_mat, -45.0)
	_spawn_ground_patch("PathWearNorthEast", _map_pos(17.5, -2.12, -17.5), _map_vec2(5.5, 12.0), backdrop_root, path_wear_soft_mat, 45.0)
	_spawn_ground_patch("PathWearSouthWest", _map_pos(-17.5, -2.12, 17.5), _map_vec2(5.5, 12.0), backdrop_root, path_wear_soft_mat, -135.0)
	_spawn_ground_patch("PathWearSouthEast", _map_pos(17.5, -2.12, 17.5), _map_vec2(5.5, 12.0), backdrop_root, path_wear_soft_mat, 135.0)
	_spawn_ground_patch("GroundPatchNorthWest", _map_pos(-24, -2.18, -22), _map_vec2(10, 7), backdrop_root, patch_mat, 18.0)
	_spawn_ground_patch("GroundPatchNorthEast", _map_pos(23, -2.18, -20), _map_vec2(9, 6), backdrop_root, moss_patch_mat, -12.0)
	_spawn_ground_patch("GroundPatchCenterWest", _map_pos(-14, -2.18, -2), _map_vec2(8, 5), backdrop_root, moss_patch_mat, 14.0)
	_spawn_ground_patch("GroundPatchCenterEast", _map_pos(18, -2.18, 8), _map_vec2(10, 6), backdrop_root, patch_mat, -8.0)
	_spawn_ground_patch("GroundPatchSouthWest", _map_pos(-20, -2.18, 24), _map_vec2(9, 6), backdrop_root, patch_mat, 10.0)
	_spawn_ground_patch("GroundPatchSouthEast", _map_pos(20, -2.18, 22), _map_vec2(11, 7), backdrop_root, moss_patch_mat, -16.0)

	_spawn_whitebox_block("CenterIsland", MAIN_ISLAND_CENTER, MAIN_ISLAND_SIZE, map_root, island_mat)
	_spawn_whitebox_block("NorthIsland", Vector3(0, -1, -SIDE_ISLAND_OFFSET), SIDE_ISLAND_SIZE, map_root, island_mat)
	_spawn_whitebox_block("SouthIsland", Vector3(0, -1, SIDE_ISLAND_OFFSET), SIDE_ISLAND_SIZE, map_root, island_mat)
	_spawn_whitebox_block("WestIsland", Vector3(-SIDE_ISLAND_OFFSET, -1, 0), SIDE_ISLAND_SIZE, map_root, island_mat)
	_spawn_whitebox_block("EastIsland", Vector3(SIDE_ISLAND_OFFSET, -1, 0), SIDE_ISLAND_SIZE, map_root, island_mat)

	_spawn_whitebox_block("BridgeCN", Vector3(0, 0, -MAIN_BRIDGE_OFFSET), MAIN_BRIDGE_SIZE_NS, map_root, bridge_mat)
	_spawn_whitebox_block("BridgeCS", Vector3(0, 0, MAIN_BRIDGE_OFFSET), MAIN_BRIDGE_SIZE_NS, map_root, bridge_mat)
	_spawn_whitebox_block("BridgeCW", Vector3(-MAIN_BRIDGE_OFFSET, 0, 0), MAIN_BRIDGE_SIZE_EW, map_root, bridge_mat)
	_spawn_whitebox_block("BridgeCE", Vector3(MAIN_BRIDGE_OFFSET, 0, 0), MAIN_BRIDGE_SIZE_EW, map_root, bridge_mat)

	_spawn_whitebox_block("BridgeNW", Vector3(-SIDE_LINK_OFFSET, 0, -SIDE_LINK_OFFSET), SIDE_LINK_SIZE, map_root, bridge_mat, true, -45.0)
	_spawn_whitebox_block("BridgeNE", Vector3(SIDE_LINK_OFFSET, 0, -SIDE_LINK_OFFSET), SIDE_LINK_SIZE, map_root, bridge_mat, true, 45.0)
	_spawn_whitebox_block("BridgeSW", Vector3(-SIDE_LINK_OFFSET, 0, SIDE_LINK_OFFSET), SIDE_LINK_SIZE, map_root, bridge_mat, true, -135.0)
	_spawn_whitebox_block("BridgeSE", Vector3(SIDE_LINK_OFFSET, 0, SIDE_LINK_OFFSET), SIDE_LINK_SIZE, map_root, bridge_mat, true, 135.0)

	# Light whitebox cover: short pauses only, no bunker rooms.
	_spawn_soft_wall_block("CoverNorth", _map_pos(0, -0.8, -6.5), LOW_COVER_SIZE, map_root, cover_mat)
	_spawn_soft_wall_block("CoverSouth", _map_pos(0, -0.8, 6.5), LOW_COVER_SIZE, map_root, cover_mat)
	_spawn_soft_wall_block("CoverWest", _map_pos(-6.5, -0.8, 0), _map_size(2.4, 1.8, 4.5), map_root, cover_mat)
	_spawn_soft_wall_block("CoverEast", _map_pos(6.5, -0.8, 0), _map_size(2.4, 1.8, 4.5), map_root, cover_mat)

	_spawn_soft_wall_block("SpawnCoverWest", _map_pos(-31.0, -0.8, 0), SPAWN_COVER_SIZE, map_root, spawn_mat)
	_spawn_soft_wall_block("SpawnCoverEast", _map_pos(31.0, -0.8, 0), SPAWN_COVER_SIZE, map_root, spawn_mat)
	_spawn_soft_wall_block("SpawnCoverNorth", _map_pos(0, -0.8, -31.0), _map_size(4.2, 1.8, 2.8), map_root, spawn_mat)
	_spawn_soft_wall_block("SpawnCoverSouth", _map_pos(0, -0.8, 31.0), _map_size(4.2, 1.8, 2.8), map_root, spawn_mat)

	_build_grouped_visual_shells(shell_root, cover_mat)
	_build_island_edge_treatment(edge_root, island_edge_mat, island_edge_highlight_mat)
	_build_wall_cap_treatment(wall_cap_root, wall_cap_mat, wall_cap_highlight_mat)
	_build_blender_visual_layer()

func _build_map_dressing() -> void:
	var root = get_node_or_null(DRESSING_ROOT_NAME)
	if root:
		root.queue_free()

	root = Node3D.new()
	root.name = DRESSING_ROOT_NAME
	add_child(root)

	for tree in [
		[_map_pos(-42, 0.0, -26), "nature_tree_small.glb", 1.9],
		[_map_pos(-42, 0.0, 26), "nature_tree_small.glb", 1.9],
		[_map_pos(42, 0.0, -26), "nature_tree_small.glb", 1.9],
		[_map_pos(42, 0.0, 26), "nature_tree_small.glb", 1.9],
		[_map_pos(-24, 0.0, -42), "nature_tree_simple.glb", 1.8],
		[_map_pos(24, 0.0, -42), "nature_tree_simple.glb", 1.8],
		[_map_pos(-24, 0.0, 42), "nature_tree_simple.glb", 1.8],
		[_map_pos(24, 0.0, 42), "nature_tree_simple.glb", 1.8],
	]:
		_spawn_prop(DRESSING_ASSET_BASE + tree[1], tree[0], Vector3(tree[2], tree[2], tree[2]), root)

	for rock in [
		[_map_pos(-37, 0.0, -11), "nature_rock_smallTopA.glb", 1.85, 15.0],
		[_map_pos(-37, 0.0, 11), "nature_rock_smallA.glb", 1.7, -18.0],
		[_map_pos(37, 0.0, -11), "nature_rock_smallA.glb", 1.7, 22.0],
		[_map_pos(37, 0.0, 11), "nature_rock_smallTopA.glb", 1.85, -12.0],
		[_map_pos(-11, 0.0, -37), "nature_rock_smallTopA.glb", 1.8, 34.0],
		[_map_pos(11, 0.0, -37), "nature_rock_smallA.glb", 1.65, -28.0],
		[_map_pos(-11, 0.0, 37), "nature_rock_smallA.glb", 1.65, 26.0],
		[_map_pos(11, 0.0, 37), "nature_rock_smallTopA.glb", 1.8, -20.0],
	]:
		_spawn_prop(DRESSING_ASSET_BASE + rock[1], rock[0], Vector3(rock[2], rock[2], rock[2]), root, rock[3])

	for foliage in [
		[_map_pos(-33, 0.0, -18), "nature_plant_bushDetailed.glb", 1.35, 0.0],
		[_map_pos(-33, 0.0, 18), "nature_plant_bushDetailed.glb", 1.35, 0.0],
		[_map_pos(33, 0.0, -18), "nature_plant_bushDetailed.glb", 1.35, 0.0],
		[_map_pos(33, 0.0, 18), "nature_plant_bushDetailed.glb", 1.35, 0.0],
		[_map_pos(-18, 0.0, -33), "nature_grass_large.glb", 1.3, 12.0],
		[_map_pos(18, 0.0, -33), "nature_grass_large.glb", 1.3, -12.0],
		[_map_pos(-18, 0.0, 33), "nature_grass_large.glb", 1.3, -10.0],
		[_map_pos(18, 0.0, 33), "nature_grass_large.glb", 1.3, 10.0],
	]:
		_spawn_prop(DRESSING_ASSET_BASE + foliage[1], foliage[0], Vector3(foliage[2], foliage[2], foliage[2]), root, foliage[3])

	for foliage in [
		[_map_pos(-24, 0.0, -20), "nature_plant_bushDetailed.glb", 1.15, 0.0],
		[_map_pos(24, 0.0, -20), "nature_plant_bushDetailed.glb", 1.15, 0.0],
		[_map_pos(-24, 0.0, 20), "nature_plant_bushDetailed.glb", 1.15, 0.0],
		[_map_pos(24, 0.0, 20), "nature_plant_bushDetailed.glb", 1.15, 0.0],
	]:
		_spawn_prop(DRESSING_ASSET_BASE + foliage[1], foliage[0], Vector3(foliage[2], foliage[2], foliage[2]), root, foliage[3])

func _get_spawn_points() -> Array:
	return [
		_map_pos(-31, 1, -3),
		_map_pos(31, 1, 3),
		_map_pos(-3, 1, -31),
		_map_pos(3, 1, 31),
	]

func _configure_map_runtime() -> void:
	if weapon_spawner:
		var center_route_pickups = [
			_map_pos(-12, 1.5, 0),
			_map_pos(12, 1.5, 0),
			_map_pos(0, 1.5, -12),
			_map_pos(0, 1.5, 12),
		]
		var side_route_pickups = [
			_map_pos(-28, 1.5, -4),
			_map_pos(-28, 1.5, 4),
			_map_pos(28, 1.5, -4),
			_map_pos(28, 1.5, 4),
			_map_pos(-4, 1.5, -28),
			_map_pos(4, 1.5, -28),
			_map_pos(-4, 1.5, 28),
			_map_pos(4, 1.5, 28),
		]
		weapon_spawner.initial_delay = 3.5
		weapon_spawner.stay_duration = 10.0
		weapon_spawner.respawn_cooldown = 4.0
		weapon_spawner.max_active_pickups = 2
		weapon_spawner.custom_spawn_clusters = [
			center_route_pickups,
			side_route_pickups,
		]
		weapon_spawner.custom_spawn_points = center_route_pickups + side_route_pickups

func _apply_map_visual_overrides() -> void:
	var light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.light_color = Color("#f4edc6")
		light.light_energy = 0.70
		light.shadow_blur = 1.8

	var env_node = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null or env_node.environment == null:
		return

	var env = env_node.environment
	env.tonemap_exposure = 0.55
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.08
	env.ambient_light_color = Color("#c2d69d")
	env.ambient_light_energy = 0.17
	env.fog_light_color = Color("#d3e2b4")
	env.fog_density = 0.0008
	env.fog_sun_scatter = 0.05
	env.fog_aerial_perspective = 0.01

	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
		sky_mat.sky_top_color = Color("#8bc0d5")
		sky_mat.sky_horizon_color = Color("#bfe3cb")
		sky_mat.ground_bottom_color = Color("#96b56c")
		sky_mat.ground_horizon_color = Color("#cfe08f")

func _uses_fixed_runtime_camera() -> bool:
	return true

func _clear_commercial_slice_nodes() -> void:
	for child in get_children():
		if child.name in [
			"Floor",
			"Obstacles",
			"CommercialDressing",
			"ExternalArt",
			"CommercialSliceBackdrop",
			SHELL_ROOT_NAME,
			EDGE_ROOT_NAME,
			WALL_CAP_ROOT_NAME,
			BLENDER_VISUAL_ROOT_NAME,
			DRESSING_ROOT_NAME,
			"CommercialSliceWhitebox",
			"KaykitMap",
			"VisualLanguage",
		]:
			child.queue_free()

func _make_whitebox_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	return mat

func _build_blender_visual_layer() -> void:
	var existing = get_node_or_null(BLENDER_VISUAL_ROOT_NAME)
	if existing:
		existing.queue_free()

	var visual_root = Node3D.new()
	visual_root.name = BLENDER_VISUAL_ROOT_NAME
	add_child(visual_root)

	var packed_scene = load(BLENDER_VISUAL_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_warning("Commercial Slice Blender visual scene is not available: %s" % BLENDER_VISUAL_SCENE_PATH)
		return

	var visual_scene = packed_scene.instantiate() as Node3D
	if visual_scene == null:
		push_warning("Commercial Slice Blender visual scene could not be instantiated.")
		return

	visual_scene.name = "BlenderAuthoredArenaVisuals"
	visual_root.add_child(visual_scene)

func _make_overlay_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat = _make_whitebox_material(color)
	mat.albedo_color.a = alpha
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _map_pos(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * MAP_SCALE, y, z * MAP_SCALE)

func _map_size(x: float, y: float, z: float) -> Vector3:
	return Vector3(x * MAP_SCALE, y, z * MAP_SCALE)

func _map_vec2(x: float, y: float) -> Vector2:
	return Vector2(x * MAP_SCALE, y * MAP_SCALE)

func _spawn_ground_patch(
	name: String,
	pos: Vector3,
	size: Vector2,
	parent: Node3D,
	mat: Material,
	yaw_deg: float = 0.0
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.08
	mesh.radial_segments = 14
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(size.x, 1.0, size.y)
	mesh_instance.position = Vector3(0, 0.04, 0)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	return root

func _spawn_soft_wall_block(
	name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	mat: Material,
	collision_enabled: bool = true
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = size.y * 0.5

	if size.x >= size.z:
		capsule.height = size.x
		mesh_instance.rotation_degrees = Vector3(0, 0, 90)
		mesh_instance.scale = Vector3(1.0, 1.0, size.z / size.y)
	else:
		capsule.height = size.z
		mesh_instance.rotation_degrees = Vector3(90, 0, 0)
		mesh_instance.scale = Vector3(size.x / size.y, 1.0, 1.0)

	mesh_instance.mesh = capsule
	mesh_instance.position = Vector3(0, size.y * 0.5, 0)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	if collision_enabled:
		var static_body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		collision_shape.shape = box
		collision_shape.position = Vector3(0, size.y * 0.5, 0)
		static_body.add_child(collision_shape)
		root.add_child(static_body)

	return root

func _build_grouped_visual_shells(parent: Node3D, mat: Material) -> void:
	for shell in [
		["ShellBridgeNorthLeft", _map_pos(-5.0, -0.92, -12.2), _map_size(3.6, 1.35, 1.7)],
		["ShellBridgeNorthRight", _map_pos(5.0, -0.92, -12.2), _map_size(3.6, 1.35, 1.7)],
		["ShellBridgeSouthLeft", _map_pos(-5.0, -0.92, 12.2), _map_size(3.6, 1.35, 1.7)],
		["ShellBridgeSouthRight", _map_pos(5.0, -0.92, 12.2), _map_size(3.6, 1.35, 1.7)],
		["ShellBridgeWestTop", _map_pos(-12.2, -0.92, -5.0), _map_size(1.7, 1.35, 3.6)],
		["ShellBridgeWestBottom", _map_pos(-12.2, -0.92, 5.0), _map_size(1.7, 1.35, 3.6)],
		["ShellBridgeEastTop", _map_pos(12.2, -0.92, -5.0), _map_size(1.7, 1.35, 3.6)],
		["ShellBridgeEastBottom", _map_pos(12.2, -0.92, 5.0), _map_size(1.7, 1.35, 3.6)],
		["ShellSideLinkNWNorth", _map_pos(-7.5, -0.94, -24.0), _map_size(3.0, 1.25, 1.5)],
		["ShellSideLinkNWWest", _map_pos(-24.0, -0.94, -7.5), _map_size(1.5, 1.25, 3.0)],
		["ShellSideLinkNENorth", _map_pos(7.5, -0.94, -24.0), _map_size(3.0, 1.25, 1.5)],
		["ShellSideLinkNEEast", _map_pos(24.0, -0.94, -7.5), _map_size(1.5, 1.25, 3.0)],
		["ShellSideLinkSWSouth", _map_pos(-7.5, -0.94, 24.0), _map_size(3.0, 1.25, 1.5)],
		["ShellSideLinkSWWest", _map_pos(-24.0, -0.94, 7.5), _map_size(1.5, 1.25, 3.0)],
		["ShellSideLinkSESouth", _map_pos(7.5, -0.94, 24.0), _map_size(3.0, 1.25, 1.5)],
		["ShellSideLinkSEEast", _map_pos(24.0, -0.94, 7.5), _map_size(1.5, 1.25, 3.0)],
		["ShellNorthOuterLeft", _map_pos(-4.6, -0.95, -34.0), _map_size(3.8, 1.3, 1.6)],
		["ShellNorthOuterRight", _map_pos(4.6, -0.95, -34.0), _map_size(3.8, 1.3, 1.6)],
		["ShellSouthOuterLeft", _map_pos(-4.6, -0.95, 34.0), _map_size(3.8, 1.3, 1.6)],
		["ShellSouthOuterRight", _map_pos(4.6, -0.95, 34.0), _map_size(3.8, 1.3, 1.6)],
		["ShellWestOuterTop", _map_pos(-34.0, -0.95, -4.6), _map_size(1.6, 1.3, 3.8)],
		["ShellWestOuterBottom", _map_pos(-34.0, -0.95, 4.6), _map_size(1.6, 1.3, 3.8)],
		["ShellEastOuterTop", _map_pos(34.0, -0.95, -4.6), _map_size(1.6, 1.3, 3.8)],
		["ShellEastOuterBottom", _map_pos(34.0, -0.95, 4.6), _map_size(1.6, 1.3, 3.8)],
		["ShellCenterNorthWest", _map_pos(-8.7, -0.94, -8.7), _map_size(2.4, 1.3, 1.6)],
		["ShellCenterNorthEast", _map_pos(8.7, -0.94, -8.7), _map_size(2.4, 1.3, 1.6)],
		["ShellCenterSouthWest", _map_pos(-8.7, -0.94, 8.7), _map_size(2.4, 1.3, 1.6)],
		["ShellCenterSouthEast", _map_pos(8.7, -0.94, 8.7), _map_size(2.4, 1.3, 1.6)],
		["ShellTurnNWNorth", _map_pos(-12.0, -0.95, -15.6), _map_size(3.0, 1.25, 1.5)],
		["ShellTurnNWWest", _map_pos(-15.6, -0.95, -12.0), _map_size(1.5, 1.25, 3.0)],
		["ShellTurnNENorth", _map_pos(12.0, -0.95, -15.6), _map_size(3.0, 1.25, 1.5)],
		["ShellTurnNEEast", _map_pos(15.6, -0.95, -12.0), _map_size(1.5, 1.25, 3.0)],
		["ShellTurnSWSouth", _map_pos(-12.0, -0.95, 15.6), _map_size(3.0, 1.25, 1.5)],
		["ShellTurnSWWest", _map_pos(-15.6, -0.95, 12.0), _map_size(1.5, 1.25, 3.0)],
		["ShellTurnSESouth", _map_pos(12.0, -0.95, 15.6), _map_size(3.0, 1.25, 1.5)],
		["ShellTurnSEEast", _map_pos(15.6, -0.95, 12.0), _map_size(1.5, 1.25, 3.0)],
	]:
		_spawn_soft_wall_block(shell[0], shell[1], shell[2], parent, mat, false)

func _build_island_edge_treatment(parent: Node3D, edge_mat: Material, highlight_mat: Material) -> void:
	for edge in [
		["IslandEdgeCenterNorth", _map_pos(0, 1.02, -13.2), _map_vec2(22.0, 2.3), edge_mat, 0.0],
		["IslandEdgeCenterSouth", _map_pos(0, 1.02, 13.2), _map_vec2(22.0, 2.3), edge_mat, 0.0],
		["IslandEdgeCenterWest", _map_pos(-13.2, 1.02, 0), _map_vec2(2.3, 22.0), edge_mat, 0.0],
		["IslandEdgeCenterEast", _map_pos(13.2, 1.02, 0), _map_vec2(2.3, 22.0), edge_mat, 0.0],
		["IslandEdgeCenterNorthWest", _map_pos(-11.8, 1.03, -11.8), _map_vec2(4.4, 4.4), highlight_mat, 22.0],
		["IslandEdgeCenterNorthEast", _map_pos(11.8, 1.03, -11.8), _map_vec2(4.4, 4.4), highlight_mat, -18.0],
		["IslandEdgeCenterSouthWest", _map_pos(-11.8, 1.03, 11.8), _map_vec2(4.4, 4.4), highlight_mat, -12.0],
		["IslandEdgeCenterSouthEast", _map_pos(11.8, 1.03, 11.8), _map_vec2(4.4, 4.4), highlight_mat, 16.0],
		["IslandEdgeNorthOuter", _map_pos(0, 1.02, -34.2), _map_vec2(11.5, 2.1), edge_mat, 0.0],
		["IslandEdgeNorthInner", _map_pos(0, 1.02, -21.8), _map_vec2(11.5, 1.8), highlight_mat, 0.0],
		["IslandEdgeNorthWest", _map_pos(-6.2, 1.02, -28.0), _map_vec2(1.8, 10.5), edge_mat, 0.0],
		["IslandEdgeNorthEast", _map_pos(6.2, 1.02, -28.0), _map_vec2(1.8, 10.5), edge_mat, 0.0],
		["IslandEdgeSouthOuter", _map_pos(0, 1.02, 34.2), _map_vec2(11.5, 2.1), edge_mat, 0.0],
		["IslandEdgeSouthInner", _map_pos(0, 1.02, 21.8), _map_vec2(11.5, 1.8), highlight_mat, 0.0],
		["IslandEdgeSouthWest", _map_pos(-6.2, 1.02, 28.0), _map_vec2(1.8, 10.5), edge_mat, 0.0],
		["IslandEdgeSouthEast", _map_pos(6.2, 1.02, 28.0), _map_vec2(1.8, 10.5), edge_mat, 0.0],
		["IslandEdgeWestOuter", _map_pos(-34.2, 1.02, 0), _map_vec2(2.1, 11.5), edge_mat, 0.0],
		["IslandEdgeWestInner", _map_pos(-21.8, 1.02, 0), _map_vec2(1.8, 11.5), highlight_mat, 0.0],
		["IslandEdgeWestNorth", _map_pos(-28.0, 1.02, -6.2), _map_vec2(10.5, 1.8), edge_mat, 0.0],
		["IslandEdgeWestSouth", _map_pos(-28.0, 1.02, 6.2), _map_vec2(10.5, 1.8), edge_mat, 0.0],
		["IslandEdgeEastOuter", _map_pos(34.2, 1.02, 0), _map_vec2(2.1, 11.5), edge_mat, 0.0],
		["IslandEdgeEastInner", _map_pos(21.8, 1.02, 0), _map_vec2(1.8, 11.5), highlight_mat, 0.0],
		["IslandEdgeEastNorth", _map_pos(28.0, 1.02, -6.2), _map_vec2(10.5, 1.8), edge_mat, 0.0],
		["IslandEdgeEastSouth", _map_pos(28.0, 1.02, 6.2), _map_vec2(10.5, 1.8), edge_mat, 0.0],
	]:
		_spawn_ground_patch(edge[0], edge[1], edge[2], parent, edge[3], edge[4])

func _build_wall_cap_treatment(parent: Node3D, cap_mat: Material, highlight_mat: Material) -> void:
	for cap in [
		["WallCapBridgeNorthLeft", _map_pos(-5.0, 0.18, -12.2), _map_size(2.0, 0.72, 1.55), cap_mat],
		["WallCapBridgeNorthRight", _map_pos(5.0, 0.18, -12.2), _map_size(2.0, 0.72, 1.55), cap_mat],
		["WallCapBridgeSouthLeft", _map_pos(-5.0, 0.18, 12.2), _map_size(2.0, 0.72, 1.55), cap_mat],
		["WallCapBridgeSouthRight", _map_pos(5.0, 0.18, 12.2), _map_size(2.0, 0.72, 1.55), cap_mat],
		["WallCapBridgeWestTop", _map_pos(-12.2, 0.18, -5.0), _map_size(1.55, 0.72, 2.0), cap_mat],
		["WallCapBridgeWestBottom", _map_pos(-12.2, 0.18, 5.0), _map_size(1.55, 0.72, 2.0), cap_mat],
		["WallCapBridgeEastTop", _map_pos(12.2, 0.18, -5.0), _map_size(1.55, 0.72, 2.0), cap_mat],
		["WallCapBridgeEastBottom", _map_pos(12.2, 0.18, 5.0), _map_size(1.55, 0.72, 2.0), cap_mat],
		["WallCapCenterNorthWest", _map_pos(-8.7, 0.20, -8.7), _map_size(1.9, 0.78, 1.9), highlight_mat],
		["WallCapCenterNorthEast", _map_pos(8.7, 0.20, -8.7), _map_size(1.9, 0.78, 1.9), highlight_mat],
		["WallCapCenterSouthWest", _map_pos(-8.7, 0.20, 8.7), _map_size(1.9, 0.78, 1.9), highlight_mat],
		["WallCapCenterSouthEast", _map_pos(8.7, 0.20, 8.7), _map_size(1.9, 0.78, 1.9), highlight_mat],
		["WallCapSideLinkNWNorth", _map_pos(-7.5, 0.18, -24.0), _map_size(1.8, 0.68, 1.5), cap_mat],
		["WallCapSideLinkNWWest", _map_pos(-24.0, 0.18, -7.5), _map_size(1.5, 0.68, 1.8), cap_mat],
		["WallCapSideLinkNENorth", _map_pos(7.5, 0.18, -24.0), _map_size(1.8, 0.68, 1.5), cap_mat],
		["WallCapSideLinkNEEast", _map_pos(24.0, 0.18, -7.5), _map_size(1.5, 0.68, 1.8), cap_mat],
		["WallCapSideLinkSWSouth", _map_pos(-7.5, 0.18, 24.0), _map_size(1.8, 0.68, 1.5), cap_mat],
		["WallCapSideLinkSWWest", _map_pos(-24.0, 0.18, 7.5), _map_size(1.5, 0.68, 1.8), cap_mat],
		["WallCapSideLinkSESouth", _map_pos(7.5, 0.18, 24.0), _map_size(1.8, 0.68, 1.5), cap_mat],
		["WallCapSideLinkSEEast", _map_pos(24.0, 0.18, 7.5), _map_size(1.5, 0.68, 1.8), cap_mat],
		["WallCapNorthOuterLeft", _map_pos(-4.6, 0.18, -34.0), _map_size(1.9, 0.68, 1.55), cap_mat],
		["WallCapNorthOuterRight", _map_pos(4.6, 0.18, -34.0), _map_size(1.9, 0.68, 1.55), cap_mat],
		["WallCapSouthOuterLeft", _map_pos(-4.6, 0.18, 34.0), _map_size(1.9, 0.68, 1.55), cap_mat],
		["WallCapSouthOuterRight", _map_pos(4.6, 0.18, 34.0), _map_size(1.9, 0.68, 1.55), cap_mat],
		["WallCapWestOuterTop", _map_pos(-34.0, 0.18, -4.6), _map_size(1.55, 0.68, 1.9), cap_mat],
		["WallCapWestOuterBottom", _map_pos(-34.0, 0.18, 4.6), _map_size(1.55, 0.68, 1.9), cap_mat],
		["WallCapEastOuterTop", _map_pos(34.0, 0.18, -4.6), _map_size(1.55, 0.68, 1.9), cap_mat],
		["WallCapEastOuterBottom", _map_pos(34.0, 0.18, 4.6), _map_size(1.55, 0.68, 1.9), cap_mat],
	]:
		_spawn_wall_cap(cap[0], cap[1], cap[2], parent, cap[3])

func _spawn_wall_cap(name: String, pos: Vector3, size: Vector3, parent: Node3D, mat: Material) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh_instance.mesh = sphere
	mesh_instance.scale = size
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	return root
