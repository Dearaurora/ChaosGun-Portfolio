extends "res://scripts/maps/battle_arena.gd"

const ROOT_WHITEBOX := "A1ReferenceWhitebox"
const ROOT_BACKDROP := "A1ReferenceBackdrop"
const ROOT_DRESSING := "A1ReferenceDressing"

func _build_map_layout() -> void:
	_clear_a1_nodes()

	var backdrop = Node3D.new()
	backdrop.name = ROOT_BACKDROP
	add_child(backdrop)

	var map_root = Node3D.new()
	map_root.name = ROOT_WHITEBOX
	add_child(map_root)

	var grass_mat = _make_mat(Color("#ceeb88"))
	var bridge_mat = _make_mat(Color("#cdb56d"))
	var cliff_mat = _make_mat(Color("#7d90c7"))
	var cover_mat = _make_mat(Color("#98a5de"))
	var sand_mat = _make_overlay_mat(Color("#efd89b"), 0.62)
	var void_mat = _make_mat(Color("#132232"))

	_spawn_visual_box("VoidBackdrop", Vector3(0, -3.0, 6), Vector3(102, 0.3, 82), backdrop, void_mat)

	# West garden island.
	_spawn_box("WestIslandCore", Vector3(-25, -1, -3), Vector3(30, 2, 30), map_root, grass_mat)
	_spawn_box("WestIslandNorthLobe", Vector3(-18, -1, -19), Vector3(26, 2, 12), map_root, grass_mat)
	_spawn_box("WestIslandSouthLobe", Vector3(-24, -1, 13), Vector3(25, 2, 13), map_root, grass_mat)
	_spawn_box("WestIslandOuterLobe", Vector3(-40, -1, -3), Vector3(12, 2, 22), map_root, grass_mat)

	# East landmark island.
	_spawn_box("EastIslandCore", Vector3(25, -1, -4), Vector3(32, 2, 30), map_root, grass_mat)
	_spawn_box("EastIslandNorthLobe", Vector3(31, -1, -19), Vector3(24, 2, 12), map_root, grass_mat)
	_spawn_box("EastIslandSouthLobe", Vector3(25, -1, 13), Vector3(30, 2, 12), map_root, grass_mat)
	_spawn_box("EastIslandOuterLobe", Vector3(42, -1, -1), Vector3(12, 2, 22), map_root, grass_mat)

	# South recovery / flank island.
	_spawn_box("SouthIslandCore", Vector3(3, -1, 30), Vector3(44, 2, 18), map_root, grass_mat)
	_spawn_box("SouthIslandWestLobe", Vector3(-14, -1, 23), Vector3(20, 2, 14), map_root, grass_mat)
	_spawn_box("SouthIslandEastLobe", Vector3(21, -1, 23), Vector3(20, 2, 14), map_root, grass_mat)

	# Bridges are intentionally wide combat spaces and overlap the islands at both ends.
	_spawn_box("BridgeWestEastMain", Vector3(-1, -0.65, -3), Vector3(24, 1.3, 8.5), map_root, bridge_mat)
	_spawn_box("BridgeWestSouth", Vector3(-13, -0.65, 18), Vector3(25, 1.3, 8.0), map_root, bridge_mat, true, -35.0)
	_spawn_box("BridgeEastSouth", Vector3(14, -0.65, 18), Vector3(24, 1.3, 8.0), map_root, bridge_mat, true, -132.0)

	# Non-collision path overlays communicate the safe routes without changing gameplay geometry.
	_spawn_visual_box("PathWestMain", Vector3(-26, 0.06, -3), Vector3(25, 0.08, 8), map_root, sand_mat)
	_spawn_visual_box("PathEastMain", Vector3(25, 0.06, -4), Vector3(27, 0.08, 8), map_root, sand_mat)
	_spawn_visual_box("PathSouthLoop", Vector3(3, 0.06, 30), Vector3(34, 0.08, 7), map_root, sand_mat)
	_spawn_visual_box("PathWestSouthHint", Vector3(-14, 0.07, 18), Vector3(18, 0.08, 4), map_root, sand_mat, -35.0)
	_spawn_visual_box("PathEastSouthHint", Vector3(14, 0.07, 18), Vector3(18, 0.08, 4), map_root, sand_mat, -132.0)

	# Visual cliff lips sit below the walking surface and do not block ring-outs.
	_spawn_visual_box("CliffLipWestGap", Vector3(-9.5, -0.12, 3), Vector3(2, 0.25, 18), map_root, cliff_mat)
	_spawn_visual_box("CliffLipEastGap", Vector3(9.5, -0.12, 3), Vector3(2, 0.25, 18), map_root, cliff_mat)
	_spawn_visual_box("CliffLipSouthGap", Vector3(0, -0.12, 19), Vector3(30, 0.25, 2), map_root, cliff_mat)
	_spawn_visual_box("CliffLipWestOuter", Vector3(-41, -0.12, -3), Vector3(2, 0.25, 22), map_root, cliff_mat)
	_spawn_visual_box("CliffLipEastOuter", Vector3(43, -0.12, -1), Vector3(2, 0.25, 22), map_root, cliff_mat)

	# Cover and landmark. These are collidable by design.
	_spawn_cover("CoverWestLow", Vector3(-28, 0, -9), Vector3(8, 1.8, 2.3), map_root, cover_mat, -12.0)
	_spawn_cover("CoverWestSouth", Vector3(-19, 0, 11), Vector3(7, 1.8, 2.4), map_root, cover_mat, 14.0)
	_spawn_cover("CoverEastNorth", Vector3(28, 0, -13), Vector3(8, 1.9, 2.4), map_root, cover_mat, 16.0)
	_spawn_cover("CoverEastSouth", Vector3(33, 0, 9), Vector3(8, 1.9, 2.4), map_root, cover_mat, -18.0)
	_spawn_cover("CoverSouthWest", Vector3(-7, 0, 30), Vector3(8, 1.7, 2.2), map_root, cover_mat, 12.0)
	_spawn_cover("CoverSouthEast", Vector3(18, 0, 27), Vector3(9, 1.7, 2.2), map_root, cover_mat, -14.0)

	_spawn_crescent_landmark(map_root)

func _build_map_dressing() -> void:
	var root = get_node_or_null(ROOT_DRESSING)
	if root:
		root.queue_free()
	root = Node3D.new()
	root.name = ROOT_DRESSING
	add_child(root)

	var plant_mat = _make_mat(Color("#67b86f"))
	for item in [
		["PlantWestNorth", Vector3(-39, 0, -12), Vector3(2.6, 2.8, 2.6)],
		["PlantWestSouth", Vector3(-31, 0, 19), Vector3(3.0, 3.0, 3.0)],
		["PlantEastNorth", Vector3(42, 0, -12), Vector3(2.6, 2.8, 2.6)],
		["PlantEastSouth", Vector3(38, 0, 15), Vector3(2.8, 2.8, 2.8)],
		["PlantSouthWest", Vector3(-17, 0, 33), Vector3(3.0, 3.0, 3.0)],
		["PlantSouthEast", Vector3(27, 0, 32), Vector3(2.8, 2.8, 2.8)],
	]:
		_spawn_visual_cylinder(item[0], item[1], item[2], root, plant_mat)

func _get_spawn_points() -> Array:
	return [
		Vector3(-27, 1.0, -4),
		Vector3(27, 1.0, -5),
		Vector3(-9, 1.0, 30),
		Vector3(15, 1.0, 30),
	]

func _configure_map_runtime() -> void:
	if weapon_spawner:
		var west_pickups = [
			Vector3(-20, 1.5, -4),
			Vector3(-24, 1.5, 4),
		]
		var east_pickups = [
			Vector3(20, 1.5, -5),
			Vector3(24, 1.5, 4),
		]
		var south_west_pickups = [
			Vector3(-4, 1.5, 30),
			Vector3(-13, 1.5, 18),
		]
		var south_east_pickups = [
			Vector3(10, 1.5, 30),
			Vector3(14, 1.5, 18),
		]
		weapon_spawner.initial_delay = 3.0
		weapon_spawner.stay_duration = 10.0
		weapon_spawner.respawn_cooldown = 4.0
		weapon_spawner.max_active_pickups = 4
		weapon_spawner.custom_spawn_clusters = [
			west_pickups,
			east_pickups,
			south_west_pickups,
			south_east_pickups,
		]
		weapon_spawner.custom_spawn_points = west_pickups + east_pickups + south_west_pickups + south_east_pickups

func _apply_map_visual_overrides() -> void:
	var camera = get_node_or_null("GlobalCamera") as Camera3D
	if camera:
		camera.position = Vector3(0, 58, 58)
		camera.rotation_degrees = Vector3(-45, 0, 0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 88.0

	var light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.light_color = Color("#f3eec8")
		light.light_energy = 0.72
		light.shadow_enabled = true
		light.shadow_blur = 1.8

func _uses_fixed_runtime_camera() -> bool:
	return true

func _clear_a1_nodes() -> void:
	for child in get_children():
		if child.name in [
			"Floor",
			"Obstacles",
			"KaykitMap",
			"ExternalArt",
			ROOT_WHITEBOX,
			ROOT_BACKDROP,
			ROOT_DRESSING,
		]:
			child.queue_free()

func _spawn_box(
	name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	mat: Material,
	collision_enabled: bool = true,
	yaw_deg: float = 0.0
) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, size.y * 0.5, 0)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	if collision_enabled:
		var static_body = StaticBody3D.new()
		var collision_shape = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision_shape.shape = shape
		collision_shape.position = Vector3(0, size.y * 0.5, 0)
		static_body.add_child(collision_shape)
		root.add_child(static_body)

	return root

func _spawn_visual_box(
	name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	mat: Material,
	yaw_deg: float = 0.0
) -> Node3D:
	return _spawn_box(name, pos, size, parent, mat, false, yaw_deg)

func _spawn_cover(name: String, pos: Vector3, size: Vector3, parent: Node3D, mat: Material, yaw_deg: float) -> Node3D:
	var root = _spawn_box(name, pos, size, parent, mat, true, yaw_deg)
	root.position.y = 0.0
	return root

func _spawn_crescent_landmark(parent: Node3D) -> void:
	var mat = _make_mat(Color("#c99050"))
	var dark_mat = _make_mat(Color("#9e6e37"))
	_spawn_cover("CrescentLandmarkBack", Vector3(25, 0, 0), Vector3(16, 1.6, 3.0), parent, mat, 10.0)
	_spawn_cover("CrescentLandmarkTop", Vector3(22, 0, -4), Vector3(10, 1.6, 3.0), parent, mat, -28.0)
	_spawn_cover("CrescentLandmarkBottom", Vector3(22, 0, 4), Vector3(10, 1.6, 3.0), parent, mat, 28.0)
	_spawn_visual_box("CrescentLandmarkShadow", Vector3(28, 0.1, 0), Vector3(7.5, 0.12, 4.5), parent, dark_mat, 0.0)

func _spawn_visual_cylinder(name: String, pos: Vector3, scale_value: Vector3, parent: Node3D, mat: Material) -> Node3D:
	var root = Node3D.new()
	root.name = name
	root.position = pos
	parent.add_child(root)

	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.75
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh_instance.mesh = mesh
	mesh_instance.scale = scale_value
	mesh_instance.position = Vector3(0, scale_value.y * 0.5, 0)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)
	return root

func _make_mat(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	return mat

func _make_overlay_mat(color: Color, alpha: float) -> StandardMaterial3D:
	var mat = _make_mat(color)
	mat.albedo_color.a = alpha
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
