extends SceneTree

const CONFIG_PATH := "res://resources/maps/momentum_circuit_production_v8.json"
const MODEL_PATH := "res://assets/models/generated/momentum_circuit_v8/momentum_circuit_environment_v8.glb"
const EnvironmentScript = preload(
	"res://scripts/maps/momentum_circuit_environment_dressing_v8.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit v8 Environment Verifier]")
	print("==================================================")
	var config := _load_json(CONFIG_PATH)
	var dressing_config := config.get("environment_dressing", {}) as Dictionary
	_verify_source_asset()

	var host := Node3D.new()
	host.name = "EnvironmentVerifierHost"
	root.add_child(host)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 49.068444, 62.0)
	host.add_child(camera)
	var dressing := EnvironmentScript.new() as Node3D
	host.add_child(dressing)
	await process_frame
	dressing.configure(dressing_config, camera)
	await process_frame
	await process_frame

	var initial := dressing.get_debug_state() as Dictionary
	_expect_int(initial, "background_layer_count", 3)
	_expect_int(initial, "model_family_count", 10)
	_expect_int(initial, "ring_instance_count", 2)
	_expect_int(initial, "traffic_route_count", 3)
	_expect_int(initial, "sensor_scan_count", 2)
	_expect_int(initial, "active_motion_system_count", 3)
	if int(initial.get("estimated_visible_draw_calls", 999)) > 55:
		_fail("Runtime environment exceeds 55 added draw calls: %s" % initial.get("estimated_visible_draw_calls"))
	print(
		"RUNTIME instances=%d visible_meshes=%d estimated_draw_calls=%d"
		% [
			int(initial.get("instance_count", 0)),
			int(initial.get("visible_mesh_instance_count", 0)),
			int(initial.get("estimated_visible_draw_calls", 0)),
		]
	)
	for key in ["collision_node_count", "shadow_caster_count", "camera_node_count", "light_node_count"]:
		if int(initial.get(key, -1)) != 0:
			_fail("Environment debug %s must equal zero" % key)

	var traffic := _find_prefixed(dressing, "CargoSkiff_")
	var ring := _find_prefixed(dressing, "RingSegment_")
	var traffic_before := traffic.position if traffic != null else Vector3.ZERO
	var ring_before := ring.rotation.y if ring != null else 0.0
	dressing.advance_motion(1.25)
	var traffic_after := traffic.position if traffic != null else Vector3.ZERO
	var ring_after := ring.rotation.y if ring != null else 0.0
	if traffic == null or traffic_before.distance_to(traffic_after) < 0.05:
		_fail("Ambient traffic route did not advance")
	if ring == null or absf(angle_difference(ring_before, ring_after)) < 0.005:
		_fail("Energy ring did not rotate")
	dressing.set_capture_time(3.5)
	var captured := dressing.get_debug_state() as Dictionary
	if absf(float(captured.get("elapsed", -1.0)) - 3.5) > 0.001:
		_fail("Capture-time interface did not freeze the requested phase")

	host.queue_free()
	await process_frame
	_finish()


func _verify_source_asset() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		_fail("Environment GLB could not be loaded")
		return
	var source := packed.instantiate()
	var family_count := 0
	var material_names := {}
	var triangle_count := 0
	for node: Node in _walk(source):
		if String(node.name).begins_with("EnvFamily") and String(node.name).count("_") == 1:
			family_count += 1
		if node is CollisionObject3D or node is CollisionShape3D:
			_fail("Environment GLB contains collision: %s" % node.name)
		if node is Camera3D or node is Light3D:
			_fail("Environment GLB contains forbidden node: %s" % node.get_class())
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh == null:
				continue
			for surface_index in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface_index)
				var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
				var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				triangle_count += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
				var material := mesh.surface_get_material(surface_index)
				if material != null:
					material_names[material.resource_name] = true
	if family_count != 10:
		_fail("Environment GLB must contain exactly ten family roots, got %d" % family_count)
	if material_names.size() > 5:
		_fail("Environment GLB exceeds five shared materials: %d" % material_names.size())
	if triangle_count <= 0 or triangle_count > 35000:
		_fail("Environment GLB triangle count %d is outside 1..35000" % triangle_count)
	print(
		"ASSET families=%d materials=%d triangles=%d"
		% [family_count, material_names.size(), triangle_count]
	)
	source.free()


func _find_prefixed(search_root: Node, prefix: String) -> Node3D:
	for node: Node in _walk(search_root):
		if node is Node3D and String(node.name).begins_with(prefix):
			return node as Node3D
	return null


func _walk(search_root: Node) -> Array[Node]:
	var result: Array[Node] = [search_root]
	for child: Node in search_root.get_children():
		result.append_array(_walk(child))
	return result


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect_int(dictionary: Dictionary, key: String, expected: int) -> void:
	if int(dictionary.get(key, -1)) != expected:
		_fail("%s must equal %d, got %s" % [key, expected, dictionary.get(key, "<missing>")])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT momentum_circuit_environment_v8 passed=true")
		print("[Momentum Circuit v8 Environment Verifier] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_environment_v8 passed=false failures=%d" % _failures.size())
	print("[Momentum Circuit v8 Environment Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
