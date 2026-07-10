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
	if length < 3.0 or length > 12.0:
		_fail("Tracer length should be readable without becoming a full-screen beam, got %.2f" % length)
	if width < 0.12 or width > 0.42:
		_fail("Tracer width should stay readable and light, got %.2f" % width)
	if lifetime < 0.06 or lifetime > 0.16:
		_fail("Tracer lifetime should be brief but visible, got %.2f" % lifetime)

func _verify_mesh_layers(tracer: Node3D) -> void:
	var underlay := _find_mesh(tracer, "TracerUnderlay")
	var core := _find_mesh(tracer, "TracerCore")
	var lead := _find_mesh(tracer, "TracerLead")
	if underlay == null:
		_fail("Shot tracer missing TracerUnderlay")
	if core == null:
		_fail("Shot tracer missing TracerCore")
	if lead == null:
		_fail("Shot tracer missing TracerLead")

	if underlay:
		var mat := underlay.material_override as StandardMaterial3D
		if mat == null or mat.albedo_color.a < 0.52:
			_fail("TracerUnderlay should provide a strong dark outline")
	if core:
		var mat := core.material_override as StandardMaterial3D
		if mat == null or not mat.emission_enabled or mat.albedo_color.a > 0.74:
			_fail("TracerCore should be bright and translucent")
	if lead:
		var mat := lead.material_override as StandardMaterial3D
		if mat == null or not mat.emission_enabled or mat.emission_energy_multiplier < 5.0:
			_fail("TracerLead should be the brightest point")

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
