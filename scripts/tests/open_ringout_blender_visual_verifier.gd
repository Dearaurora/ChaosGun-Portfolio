extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const VISUAL_ROOT_PATH := "OpenRingoutBlenderVisuals"
const VISUAL_SCENE_PATH := "res://assets/models/generated/open_ringout_slice/open_ringout_visuals.glb"
const MIN_MESH_COUNT := 170
const MIN_MATERIAL_COUNT := 14

const REQUIRED_MESHES := [
	"main_deck_irregular_top_slab",
	"north_deck_irregular_top_slab",
	"east_deck_irregular_top_slab",
	"south_deck_irregular_top_slab",
	"west_deck_irregular_top_slab",
	"north_bridge_irregular_top_slab",
	"east_bridge_irregular_top_slab",
	"south_bridge_irregular_top_slab",
	"west_bridge_irregular_top_slab",
	"A1MainDeckOuterSkirtNorth",
	"A1MainDeckOuterSkirtSouth",
	"A1MainDeckOuterSkirtWest",
	"A1MainDeckOuterSkirtEast",
	"A1NorthDeckHeroCrown",
	"A1EastDeckHeroCrown",
	"A1SouthDeckHeroCrown",
	"A1WestDeckHeroCrown",
	"A1NorthBridgeRouteRailL",
	"A1NorthBridgeRouteRailR",
	"A1EastBridgeRouteRailL",
	"A1EastBridgeRouteRailR",
	"A1SouthBridgeRouteRailL",
	"A1SouthBridgeRouteRailR",
	"A1WestBridgeRouteRailL",
	"A1WestBridgeRouteRailR",
	"A1CenterPickupRuneOuter",
	"A1CenterPickupRuneInner",
	"A1SkyIslandToyWindmillNE_pole",
	"A1SkyIslandToyWindmillNE_blade_a",
	"A1SkyIslandFlagSW_pole",
	"A1SkyIslandFlagSW_banner",
	"A1DepthCloudRibbonNorth",
	"A1DepthCloudRibbonSouth",
	"A1DepthIslandClusterNW_cliff",
	"A1DepthIslandClusterSE_cliff"
]

const REQUIRED_PREFIX_COUNTS := {
	"A1EdgeBeacon": 18,
	"A1SurfacePanel": 22,
	"A1BridgeMouthMarker": 8,
	"A1DepthGlowMote": 14
}

const FORBIDDEN_NAME_PARTS := [
	"_front_lip",
	"_back_lip",
	"bumper_east",
	"bumper_se",
	"round_drum_",
	"round_drum_cap_",
	"tiny_cone_",
	"blue_panel_",
	"metal_plate_"
]

var _failures: Array[String] = []
var _host: Node = null

func _initialize() -> void:
	print("==================================================")
	print("[Blender Visual Verifier] Open Ring-Out A1")
	print("==================================================")

	if not ResourceLoader.exists(VISUAL_SCENE_PATH):
		_fail("Blender visual GLB is not imported or loadable: %s" % VISUAL_SCENE_PATH)

	var visual_scene_resource = load(VISUAL_SCENE_PATH) as PackedScene
	if visual_scene_resource == null:
		_fail("Blender visual GLB is not loadable as a PackedScene: %s" % VISUAL_SCENE_PATH)

	var scene = load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("Missing MatchConfig autoload; cannot force empty player slots")
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

	var visual_root = arena.get_node_or_null(VISUAL_ROOT_PATH)
	if visual_root == null:
		_fail("Missing %s" % VISUAL_ROOT_PATH)
		await _finish()
		return

	_verify_counts(visual_root)
	_verify_required_meshes(visual_root)
	_verify_prefix_counts(visual_root)
	_verify_forbidden_names(visual_root)
	_verify_no_collision(visual_root)
	_verify_bridge_deck_readability(visual_root)

	await _finish()

func _verify_counts(visual_root: Node) -> void:
	var mesh_count := _count_mesh_instances(visual_root)
	var material_names: Dictionary = {}
	_collect_material_names(visual_root, material_names)
	print("Mesh instances: ", mesh_count)
	print("Unique materials: ", material_names.size())
	if mesh_count < MIN_MESH_COUNT:
		_fail("Expected at least %d Blender visual mesh instances, got %d" % [MIN_MESH_COUNT, mesh_count])
	if material_names.size() < MIN_MATERIAL_COUNT:
		_fail("Expected at least %d Blender visual materials, got %d" % [MIN_MATERIAL_COUNT, material_names.size()])

func _verify_required_meshes(visual_root: Node) -> void:
	for mesh_name in REQUIRED_MESHES:
		if not _has_named_descendant(visual_root, String(mesh_name)):
			_fail("Open Ring-Out A1 GLB is missing required mesh: %s" % mesh_name)

func _verify_prefix_counts(visual_root: Node) -> void:
	for prefix in REQUIRED_PREFIX_COUNTS.keys():
		var count := _count_descendants_with_prefix(visual_root, String(prefix))
		var expected := int(REQUIRED_PREFIX_COUNTS[prefix])
		if count < expected:
			_fail("Expected at least %d nodes with prefix %s, got %d" % [expected, prefix, count])

func _verify_forbidden_names(visual_root: Node) -> void:
	for name_part in FORBIDDEN_NAME_PARTS:
		if _has_descendant_name_containing(visual_root, String(name_part)):
			_fail("Open Ring-Out A1 GLB still has forbidden stale visual name: %s" % name_part)

func _verify_no_collision(visual_root: Node) -> void:
	if _has_collision_descendant(visual_root):
		_fail("Blender visual GLB must remain non-colliding; collision belongs to OpenRingoutPlayable/OpenRingoutCovers")

func _verify_bridge_deck_readability(visual_root: Node) -> void:
	var checks := [
		["north_bridge_irregular_top_slab", Vector2(8.0, 4.0), "north bridge deck"],
		["east_bridge_irregular_top_slab", Vector2(5.5, 6.0), "east bridge deck"],
		["south_bridge_irregular_top_slab", Vector2(8.0, 3.8), "south bridge deck"],
		["west_bridge_irregular_top_slab", Vector2(5.0, 7.0), "west bridge deck"],
	]
	for check in checks:
		var mesh_name := check[0] as String
		var min_size := check[1] as Vector2
		var role := check[2] as String
		var mesh := _find_mesh_instance_by_name(visual_root, mesh_name)
		if mesh == null:
			_fail("Missing obvious bridge connector mesh: %s" % mesh_name)
			continue
		var size := _mesh_visual_size(mesh)
		if size.x < min_size.x or size.z < min_size.y:
			_fail("%s is too small to read as %s, size %s" % [mesh_name, role, str(size)])

func _count_mesh_instances(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count

func _collect_material_names(node: Node, material_names: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh:
			for surface in range(mesh.get_surface_count()):
				var material := mesh_node.get_surface_override_material(surface)
				if material == null:
					material = mesh.surface_get_material(surface)
				if material:
					var material_key := _material_identity_key(material, surface)
					material_names[material_key] = true
	for child in node.get_children():
		_collect_material_names(child, material_names)

func _has_named_descendant(node: Node, target_name: String) -> bool:
	if node.name == target_name:
		return true
	for child in node.get_children():
		if _has_named_descendant(child, target_name):
			return true
	return false

func _has_descendant_name_containing(node: Node, name_part: String) -> bool:
	if String(node.name).contains(name_part):
		return true
	for child in node.get_children():
		if _has_descendant_name_containing(child, name_part):
			return true
	return false

func _count_descendants_with_prefix(node: Node, prefix: String) -> int:
	var count := 1 if String(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_descendants_with_prefix(child, prefix)
	return count

func _has_collision_descendant(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		return true
	for child in node.get_children():
		if _has_collision_descendant(child):
			return true
	return false

func _find_mesh_instance_by_name(node: Node, target_name: String) -> MeshInstance3D:
	if node.name == target_name and node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance_by_name(child, target_name)
		if found:
			return found
	return null

func _mesh_visual_size(mesh: MeshInstance3D) -> Vector3:
	if mesh.mesh == null:
		return Vector3.ZERO
	var local_aabb := mesh.mesh.get_aabb()
	var min_point := Vector3(INF, INF, INF)
	var max_point := Vector3(-INF, -INF, -INF)
	var origin := local_aabb.position
	var size := local_aabb.size
	var corners := [
		origin,
		origin + Vector3(size.x, 0.0, 0.0),
		origin + Vector3(0.0, size.y, 0.0),
		origin + Vector3(0.0, 0.0, size.z),
		origin + Vector3(size.x, size.y, 0.0),
		origin + Vector3(size.x, 0.0, size.z),
		origin + Vector3(0.0, size.y, size.z),
		origin + size,
	]
	for corner in corners:
		var world_corner: Vector3 = mesh.global_transform * corner
		min_point = Vector3(
			minf(min_point.x, world_corner.x),
			minf(min_point.y, world_corner.y),
			minf(min_point.z, world_corner.z)
		)
		max_point = Vector3(
			maxf(max_point.x, world_corner.x),
			maxf(max_point.y, world_corner.y),
			maxf(max_point.z, world_corner.z)
		)
	return max_point - min_point

func _material_identity_key(material: Material, surface_index: int) -> String:
	if material.resource_path != "":
		return material.resource_path
	if material.resource_name != "":
		return material.resource_name
	if material is BaseMaterial3D:
		var base_material := material as BaseMaterial3D
		return "%s|%s|%s|%s|%s|%s" % [
			base_material.get_class(),
			str(base_material.albedo_color),
			str(base_material.emission),
			str(base_material.emission_enabled),
			str(base_material.metallic),
			str(base_material.roughness),
		]
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var shader := shader_material.shader
		if shader:
			if shader.resource_path != "":
				return "%s|%s" % [shader_material.get_class(), shader.resource_path]
			if shader.resource_name != "":
				return "%s|%s" % [shader_material.get_class(), shader.resource_name]
		return shader_material.get_class()
	return "surface_%d" % surface_index

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	await process_frame
	if _host and is_instance_valid(_host):
		_host.queue_free()
		await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Blender Visual Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Blender Visual Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
