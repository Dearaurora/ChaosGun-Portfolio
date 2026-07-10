extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Weapon Shot Tracer Integration Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var scene_root := Node3D.new()
	scene_root.name = "TracerIntegrationScene"
	root.add_child(scene_root)
	current_scene = scene_root

	var shooter := StaticBody3D.new()
	shooter.name = "Shooter"
	scene_root.add_child(shooter)

	var fire_point := Marker3D.new()
	fire_point.name = "FirePoint"
	scene_root.add_child(fire_point)
	fire_point.position = Vector3(0.0, 1.0, 0.0)

	var weapon := Weapon.new()
	weapon.name = "Weapon"
	scene_root.add_child(weapon)
	weapon.init_weapon(WeaponData.create_ak_rifle())
	await process_frame

	var fired := weapon.try_fire(fire_point, Vector3.RIGHT, shooter)
	await process_frame

	if not fired:
		_fail("Weapon should fire in integration verifier")

	var projectile := _find_by_class(scene_root, "Projectile")
	var tracer := _find_by_class(scene_root, "ShotTracer")
	if projectile == null:
		_fail("Weapon fire should still spawn a gameplay Projectile")
	if tracer == null:
		_fail("Weapon fire should spawn a non-gameplay ShotTracer")
	else:
		var debug := tracer.call("get_visual_debug") as Dictionary
		var length := float(debug.get("length", 0.0))
		var width := float(debug.get("width", 0.0))
		var lifetime := float(debug.get("lifetime", 0.0))
		if length < 2.0 or length > 3.6:
			_fail("AK shot tracer should be a short muzzle direction cue, got length %.2f" % length)
		if width < 0.18 or width > 0.32:
			_fail("AK shot tracer width should stay readable but not replace the projectile, got %.2f" % width)
		if lifetime > 0.085:
			_fail("AK shot tracer should fade quickly so dodgeable bullets remain the main read, got %.3f" % lifetime)

	await _finish([scene_root])

func _find_by_class(node: Node, class_name_text: String) -> Node:
	if node.get_class() == class_name_text or node.is_class(class_name_text):
		return node
	if class_name_text == "Projectile" and node is Projectile:
		return node
	if class_name_text == "ShotTracer" and node.has_method("get_visual_debug"):
		return node
	for child in node.get_children():
		var found := _find_by_class(child, class_name_text)
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
	root.set_meta("disable_runtime_audio", false)

	print("\n==================================================")
	if _failures.is_empty():
		print("[Weapon Shot Tracer Integration Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Weapon Shot Tracer Integration Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
