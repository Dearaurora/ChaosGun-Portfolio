extends SceneTree

const SHOT_TRACER_SCRIPT := "res://scripts/effects/shot_tracer.gd"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Shot Tracer Visual Verifier]")
	print("==================================================")

	var script := load(SHOT_TRACER_SCRIPT)
	if script == null:
		_fail("Shot tracer script missing at %s" % SHOT_TRACER_SCRIPT)
		await _finish([])
		return

	var tracer := script.new() as Node3D
	if tracer == null:
		_fail("Shot tracer script should instantiate a Node3D")
		await _finish([])
		return
	if not tracer.has_method("setup"):
		_fail("Shot tracer must expose setup(start, direction, color, profile)")
	if not tracer.has_method("get_visual_debug"):
		_fail("Shot tracer must expose get_visual_debug()")
	if not _failures.is_empty():
		await _finish([tracer])
		return

	tracer.call("setup", Vector3(2.0, 1.0, 3.0), Vector3.RIGHT, Color("#5ce3ff"), {
		"length": 7.5,
		"width": 0.22,
		"lifetime": 0.11,
	})
	root.add_child(tracer)
	await process_frame

	_verify_debug_profile(tracer)
	_verify_mesh_layers(tracer)

	await create_timer(0.16).timeout
	if is_instance_valid(tracer) and not tracer.is_queued_for_deletion():
		_fail("Shot tracer should self-remove after its configured lifetime")

	await _finish([tracer])

func _verify_debug_profile(tracer: Node3D) -> void:
	var debug := tracer.call("get_visual_debug") as Dictionary
	var length := float(debug.get("length", 0.0))
	var width := float(debug.get("width", 0.0))
	var lifetime := float(debug.get("lifetime", 0.0))
	if String(debug.get("shape", "")) != "yellow_white_teardrop":
		_fail("Tracer should use the approved yellow-white water-drop silhouette")
	var tracer_color := debug.get("color", Color.BLACK) as Color
	var tracer_core_color := debug.get("core_color", Color.BLACK) as Color
	if tracer_color.r < 0.90 or tracer_color.g < 0.60 or tracer_color.b > 0.38:
		_fail("Tracer debug contract should expose the shared warm-yellow shell")
	if minf(tracer_core_color.r, minf(tracer_core_color.g, tracer_core_color.b)) < 0.80:
		_fail("Tracer debug contract should expose the shared warm-white core")
	if length < 3.0 or length > 12.0:
		_fail("Tracer length should be readable without becoming a full-screen beam, got %.2f" % length)
	if width < 0.12 or width > 0.42:
		_fail("Tracer width should stay readable and light, got %.2f" % width)
	if lifetime < 0.06 or lifetime > 0.16:
		_fail("Tracer lifetime should be brief but visible, got %.2f" % lifetime)

func _verify_mesh_layers(tracer: Node3D) -> void:
	var glow := _find_mesh(tracer, "TracerGlow")
	var core := _find_mesh(tracer, "TracerCore")
	var lead := _find_mesh(tracer, "TracerLead")
	if glow == null:
		_fail("Shot tracer missing its connected yellow TracerGlow")
	if core == null:
		_fail("Shot tracer missing TracerCore")
	if lead != null:
		_fail("Shot tracer should not add a detached lead dot")

	if glow:
		if not (glow.mesh is ArrayMesh):
			_fail("TracerGlow should use authored water-drop geometry")
		var mat := glow.material_override as StandardMaterial3D
		if mat == null or mat.albedo_color.r < 0.90 or mat.albedo_color.g < 0.60 or mat.albedo_color.b > 0.38:
			_fail("TracerGlow should use the shared warm-yellow projectile palette")
	if core:
		if not (core.mesh is ArrayMesh):
			_fail("TracerCore should use authored water-drop geometry")
		var mat := core.material_override as StandardMaterial3D
		if mat == null or not mat.emission_enabled or minf(mat.albedo_color.r, minf(mat.albedo_color.g, mat.albedo_color.b)) < 0.80:
			_fail("TracerCore should be a luminous warm-white inset")

func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == mesh_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child, mesh_name)
		if found:
			return found
	return null

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(nodes: Array) -> void:
	for node in nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Shot Tracer Visual Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Shot Tracer Visual Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
