extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Arena Base Contract Verifier]")
	print("==================================================")

	var base_script := load("res://scripts/maps/twin_bays_arena_base.gd") as Script
	if base_script == null:
		_fail("Could not load Twin Bays arena base script")
		quit(1)
		return
	var arena := base_script.new() as Node3D
	arena.call("_build_map_layout")
	_verify_layers(arena)
	_verify_gameplay_collision(arena)
	_verify_foreground_is_visual_only(arena)
	_verify_portals(arena)
	_verify_layout_access(arena)
	arena.free()

	if _failures.is_empty():
		print("[Twin Bays Arena Base Contract Verifier] PASS")
		quit(0)
		return
	print("[Twin Bays Arena Base Contract Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)

func _verify_layers(arena: Node3D) -> void:
	print("\n--- Four Responsibility Layers ---")
	for layer_name in ["Gameplay", "ForegroundVisuals", "Backdrop", "Portals"]:
		if arena.get_node_or_null(layer_name) == null:
			_fail("Missing default production layer: %s" % layer_name)
		else:
			print("OK  ", layer_name)
	if arena.call("get_twin_bays_layer", &"gameplay") == arena.call("get_twin_bays_layer", &"foreground"):
		_fail("Production Gameplay and ForegroundVisuals layers must be distinct")

func _verify_gameplay_collision(arena: Node3D) -> void:
	print("\n--- Godot-Owned Gameplay Collision ---")
	var gameplay := arena.get_node_or_null("Gameplay")
	if gameplay == null:
		return
	var surface := gameplay.get_node_or_null("ArenaSurface") as CSGPolygon3D
	if surface == null or not surface.use_collision or surface.visible:
		_fail("Gameplay ArenaSurface must be invisible collision-enabled CSG")
	else:
		print("OK  authoritative platform collision")
	if gameplay.get_node_or_null("CausewaySafetyCollision") == null:
		_fail("Gameplay causeway safety collision missing")
	var layout := arena.call("get_twin_bays_layout") as Dictionary
	for cover_value: Variant in layout["covers"] as Array:
		var node_name := String((cover_value as Dictionary)["node_name"])
		var cover := gameplay.get_node_or_null(node_name)
		if cover == null or not _contains_collision_shape(cover):
			_fail("Gameplay cover collision missing: %s" % node_name)
	if gameplay.find_child("BeveledMesh", true, false) != null:
		_fail("Gameplay collision layer must not contain foreground cover meshes")
	else:
		print("OK  covers contain collision without visual meshes")

func _verify_foreground_is_visual_only(arena: Node3D) -> void:
	print("\n--- Collision-Free Foreground ---")
	var foreground := arena.get_node_or_null("ForegroundVisuals")
	if foreground == null:
		return
	var pending: Array[Node] = [foreground]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node != foreground and (node is CollisionObject3D or node is CollisionShape3D):
			_fail("Foreground contains collision node: %s" % foreground.get_path_to(node))
		for child: Node in node.get_children():
			pending.append(child)
	print("OK  ForegroundVisuals is collision-free")

func _verify_portals(arena: Node3D) -> void:
	print("\n--- Shared Portal Mechanics ---")
	var left := arena.get_node_or_null("Portals/LeftPortal") as TwinBaysPortal
	var right := arena.get_node_or_null("Portals/RightPortal") as TwinBaysPortal
	if left == null or right == null:
		_fail("Shared portal pair missing")
		return
	if left.paired_portal != right or right.paired_portal != left:
		_fail("Shared portals are not configured bidirectionally")
	if not is_equal_approx(left.cooldown_seconds, 0.55) or not is_equal_approx(right.cooldown_seconds, 0.55):
		_fail("Shared portal cooldown differs from layout")
	else:
		print("OK  configure_pair and cooldown")

func _verify_layout_access(arena: Node3D) -> void:
	print("\n--- Shared Layout Access ---")
	var layout := arena.call("get_twin_bays_layout") as Dictionary
	if layout.is_empty() or (layout["platform"] as Dictionary)["outline"].size() != 116:
		_fail("Base layout accessor did not return the authoritative layout")
	if (arena.call("_get_spawn_points") as Array).size() != 4:
		_fail("Base spawn accessor did not return four spawns")
	else:
		print("OK  layout and spawn access")

func _contains_collision_shape(root_node: Node) -> bool:
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CollisionShape3D:
			return true
		for child: Node in node.get_children():
			pending.append(child)
	return false

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
