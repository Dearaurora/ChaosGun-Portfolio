extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const P14_ASSET_PATH := "res://assets/models/generated/sunset_toy_sky_islands/p14_sunset_environment.glb"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[P14 Environment Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	if not ResourceLoader.exists(P14_ASSET_PATH):
		_fail("P14 authored environment GLB is missing")
		await _finish(null)
		return
	var packed = load(SCENE_PATH) as PackedScene
	var arena = packed.instantiate() if packed else null
	if arena == null:
		_fail("Could not instantiate Open Ring-Out")
		await _finish(null)
		return
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var p14_root = arena.get_node_or_null("OpenRingoutBlenderVisuals/P14SunsetEnvironment") as Node3D
	if p14_root == null:
		_fail("P14SunsetEnvironment is not integrated into the playable map")
		await _finish(arena)
		return

	var cloud_count := _count_descendants_with_prefix(p14_root, "P14CloudBank")
	var island_count := _count_descendants_with_suffix(p14_root, "Cliff", "P14DistantIsland")
	if cloud_count != 10:
		_fail("P14 needs ten authored cloud-bank meshes, got %d" % cloud_count)
	else:
		print("OK  authored cloud banks: ", cloud_count)
	if island_count != 7:
		_fail("P14 needs seven landmark-varied distant islands, got %d" % island_count)
	else:
		print("OK  distant islands: ", island_count)
	if _has_collision_descendant(p14_root):
		_fail("P14 background assets must remain visual-only")
	_verify_cloud_materials(p14_root)
	_verify_balloon_structure(p14_root)
	_verify_predecessors_hidden(arena)
	_verify_background_depth(arena)
	_verify_grade(arena)
	_print_island_projection(arena, p14_root)
	await _finish(arena)

func _verify_cloud_materials(p14_root: Node) -> void:
	var inspected := 0
	for node in _descendants_with_prefix(p14_root, "P14CloudBank"):
		if not (node is MeshInstance3D):
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() != 1:
			_fail("%s must keep exactly one cloud surface without an underside layer" % node.name)
			continue
		for surface_index in range(1):
			var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if material == null:
				_fail("%s surface %d is missing an imported PBR material" % [node.name, surface_index])
				continue
			if material.roughness < 0.94:
				_fail("%s cloud roughness should stay soft and matte" % node.name)
		if mesh_instance.global_position.y <= -25.0:
			_fail("%s is hidden below the abyss plane" % node.name)
		inspected += 1
	if inspected != 10:
		_fail("Could not inspect all authored P14 cloud materials")
	else:
		print("OK  single-material matte cloud banks without underside layers: ", inspected)

func _verify_balloon_structure(p14_root: Node) -> void:
	for required_name in [
		"P14HotAirBalloonEnvelope",
		"P14HotAirBalloonEnvelopeSeams",
		"P14HotAirBalloonBasket",
		"P14HotAirBalloonBasketRim",
	]:
		if p14_root.find_child(required_name, true, false) == null:
			_fail("P14 hot-air balloon is missing %s" % required_name)
	var rope_count := _count_descendants_with_prefix(p14_root, "P14HotAirBalloonRope")
	if rope_count != 4:
		_fail("P14 hot-air balloon needs four readable suspension ropes, got %d" % rope_count)
	var envelope = p14_root.find_child("P14HotAirBalloonEnvelope", true, false) as MeshInstance3D
	if envelope == null or envelope.mesh == null or envelope.mesh.get_surface_count() != 2:
		_fail("P14 balloon envelope must expose two integrated panel surfaces")
	else:
		print("OK  segmented balloon, curved seams, four ropes, and basket")

func _verify_predecessors_hidden(arena: Node) -> void:
	var backdrop = arena.get_node_or_null("OpenRingoutBackdrop") as Node3D
	if backdrop == null or backdrop.visible:
		_fail("Procedural backdrop islands should be hidden after P14 loads")
	var abyss = arena.get_node_or_null("OpenRingoutAbyss") as Node3D
	if abyss == null:
		_fail("OpenRingoutAbyss is missing")
		return
	for child in abyss.get_children():
		if child is Node3D and (child as Node3D).visible:
			_fail("Legacy abyss decoration remains visible: %s" % child.name)
	var sky_backplate := arena.get_node_or_null("SunsetSkyBackplate") as CanvasLayer
	if sky_backplate == null or sky_backplate.get_node_or_null("BackdropTexture") == null:
		_fail("Sunset sky backplate is missing")
	var blender_root = arena.get_node_or_null("OpenRingoutBlenderVisuals")
	for prefix in ["WarmCloudBank", "CoolCloudBank", "FarAbyssCloudPuff_", "FarAbyssGlowMote_", "V3Cloud", "V3DistantIsland", "V3HotAirBalloon"]:
		for node in _descendants_with_prefix(blender_root, prefix):
			if node is Node3D and _is_effectively_visible(node as Node3D, arena):
				_fail("Replaced background node remains visible: %s" % node.name)
	print("OK  flat clouds, glow motes, duplicate islands, and old balloon are hidden")

func _verify_background_depth(arena: Node) -> void:
	var abyss_plane = arena.get_node_or_null("OpenRingoutAbyss/AbyssPlane") as Node3D
	if abyss_plane == null:
		_fail("AbyssPlane is missing")
		return
	if abyss_plane.visible:
		_fail("AbyssPlane should be hidden behind the authored sky backplate")
	if abyss_plane.global_position.y > -25.0:
		_fail("AbyssPlane must stay behind the complete distant-island silhouettes")
	else:
		print("OK  hidden abyss fallback stays behind the authored sky backplate")

func _verify_grade(arena: Node) -> void:
	var light = arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	var env_node = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if light == null or absf(light.light_energy - 1.08) > 0.01:
		_fail("Full-frame key light energy should be 1.08")
	if env_node == null or env_node.environment == null:
		_fail("P14 WorldEnvironment is missing")
		return
	var env: Environment = env_node.environment
	if env.tonemap_exposure < 0.76 or env.tonemap_exposure > 0.78:
		_fail("Full-frame exposure should preserve warm highlights without clipping")
	if env.adjustment_saturation < 1.09 or env.adjustment_saturation > 1.11:
		_fail("Full-frame saturation is outside the approved restrained range")
	if env.ambient_light_energy < 0.17 or env.ambient_light_energy > 0.19:
		_fail("Full-frame ambient energy should preserve cool shadow readability")
	if env.fog_density > 0.0015:
		_fail("P14 fog should not wash out distant silhouettes")
	print("OK  P14 warm-key/cool-shadow final grade")

func _print_island_projection(arena: Node, p14_root: Node) -> void:
	var camera = arena.get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		return
	for node in _descendants_with_prefix(p14_root, "P14DistantIsland"):
		if not String(node.name).ends_with("Cliff") or not (node is Node3D):
			continue
		var point := camera.unproject_position((node as Node3D).global_position)
		print("PROJECTION  %s -> %s behind=%s" % [node.name, point, camera.is_position_behind((node as Node3D).global_position)])

func _count_descendants_with_prefix(node: Node, prefix: String) -> int:
	return _descendants_with_prefix(node, prefix).size()

func _count_descendants_with_suffix(node: Node, suffix: String, prefix: String) -> int:
	var count := 0
	for child in _descendants_with_prefix(node, prefix):
		if String(child.name).ends_with(suffix):
			count += 1
	return count

func _descendants_with_prefix(node: Node, prefix: String) -> Array[Node]:
	var matches: Array[Node] = []
	if node == null:
		return matches
	if String(node.name).begins_with(prefix):
		matches.append(node)
	for child in node.get_children():
		matches.append_array(_descendants_with_prefix(child, prefix))
	return matches

func _has_collision_descendant(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _has_collision_descendant(child):
			return true
	return false

func _is_effectively_visible(node: Node3D, stop: Node) -> bool:
	var cursor: Node = node
	while cursor != null and cursor != stop:
		if cursor is Node3D and not (cursor as Node3D).visible:
			return false
		cursor = cursor.get_parent()
	return true

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(arena: Node) -> void:
	if arena and is_instance_valid(arena):
		arena.queue_free()
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[P14 Environment Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[P14 Environment Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
