extends SceneTree

const SCENE_PATH := "res://scenes/maps/commercial_slice_a.tscn"
const VISUAL_ROOT_PATH := "CommercialSliceBlenderVisuals"
const VISUAL_SCENE_PATH := "res://assets/models/generated/commercial_slice_a/commercial_slice_a_visuals.glb"
const MIN_MESH_COUNT := 80
const MIN_MATERIAL_COUNT := 8

var _failures: Array[String] = []
var _host: Node = null

func _initialize() -> void:
	print("==================================================")
	print("[Blender Visual Verifier] Commercial Slice A")
	print("==================================================")

	if not ResourceLoader.exists(VISUAL_SCENE_PATH):
		_fail("Blender visual GLB is not imported or loadable: %s" % VISUAL_SCENE_PATH)

	var scene = load(SCENE_PATH)
	if not scene:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
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

	var mesh_count := _count_mesh_instances(visual_root)
	var material_names: Dictionary = {}
	_collect_material_names(visual_root, material_names)

	print("Mesh instances: ", mesh_count)
	print("Unique materials: ", material_names.size())

	if mesh_count < MIN_MESH_COUNT:
		_fail("Expected at least %d Blender visual mesh instances, got %d" % [MIN_MESH_COUNT, mesh_count])

	if material_names.size() < MIN_MATERIAL_COUNT:
		_fail("Expected at least %d Blender visual materials, got %d" % [MIN_MATERIAL_COUNT, material_names.size()])

	await _finish()

func _count_mesh_instances(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count

func _collect_material_names(node: Node, material_names: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_node = node as MeshInstance3D
		var mesh = mesh_node.mesh
		if mesh:
			for surface in range(mesh.get_surface_count()):
				var material = mesh_node.get_surface_override_material(surface)
				if material == null:
					material = mesh.surface_get_material(surface)
				if material:
					material_names[String(material.resource_name)] = true

	for child in node.get_children():
		_collect_material_names(child, material_names)

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
