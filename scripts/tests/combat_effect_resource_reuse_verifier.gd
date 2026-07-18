extends SceneTree

const CombatVisualResourceCache = preload("res://scripts/effects/combat_visual_resource_cache.gd")
const ShotTracerScript = preload("res://scripts/effects/shot_tracer.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Combat Effect Resource Reuse Verifier]")
	print("==================================================")
	CombatVisualResourceCache.clear_for_tests()

	var muzzle_pair := _make_muzzle_pair()
	var tracer_pair := _make_tracer_pair()
	var hit_pair := _make_hit_pair()
	var projectile_pair := _make_projectile_pair()
	await process_frame

	_verify_pair(muzzle_pair, "MuzzleCore", "muzzle core")
	_verify_pair(muzzle_pair, "MuzzlePetal_0", "muzzle petal")
	_verify_single_build_pair(muzzle_pair, "muzzle flash")

	_verify_pair(tracer_pair, "TracerGlow", "tracer glow")
	_verify_pair(tracer_pair, "TracerCore", "tracer core")
	_verify_single_build_pair(tracer_pair, "shot tracer")

	_verify_pair(hit_pair, "ImpactCore", "impact core")
	_verify_pair(hit_pair, "ImpactShard_0", "impact shard")
	_verify_single_build_pair(hit_pair, "hit effect")

	_verify_pair(projectile_pair, "BulletCore", "projectile core")
	_verify_pair(projectile_pair, "ShortTrail", "projectile trail")
	_verify_single_build_pair(projectile_pair, "projectile")

	var cache_debug := CombatVisualResourceCache.get_debug()
	var mesh_builds := int(cache_debug.get("mesh_builds", 0))
	var material_builds := int(cache_debug.get("material_builds", 0))
	if mesh_builds <= 0 or mesh_builds > 18:
		_fail("Shared combat mesh cache should stay finite, built %d resources" % mesh_builds)
	if material_builds <= 0 or material_builds > 20:
		_fail("Shared combat material cache should stay finite, built %d resources" % material_builds)
	print("OK  shared immutable resources: %d meshes / %d materials" % [mesh_builds, material_builds])

	await _finish(muzzle_pair + tracer_pair + hit_pair + projectile_pair)


func _make_muzzle_pair() -> Array[Node3D]:
	var scene := load("res://scenes/effects/muzzle_flash.tscn") as PackedScene
	var pair: Array[Node3D] = []
	for index in range(2):
		var effect := scene.instantiate() as Node3D
		effect.call("configure", Vector3.FORWARD, Color("#e96525"), &"ak_rifle")
		root.add_child(effect)
		pair.append(effect)
	return pair


func _make_tracer_pair() -> Array[Node3D]:
	var pair: Array[Node3D] = []
	var profile := {"length": 2.0, "width": 0.17, "lifetime": 0.055, "style": &"fork"}
	for index in range(2):
		var effect := ShotTracerScript.new() as Node3D
		effect.call("setup", Vector3.ZERO, Vector3.FORWARD, Color("#e96525"), profile)
		root.add_child(effect)
		pair.append(effect)
	return pair


func _make_hit_pair() -> Array[Node3D]:
	var scene := load("res://scenes/effects/hit_effect.tscn") as PackedScene
	var pair: Array[Node3D] = []
	for index in range(2):
		var effect := scene.instantiate() as Node3D
		effect.call("configure", Color("#e96525"), &"ak_rifle", Vector3.FORWARD)
		root.add_child(effect)
		pair.append(effect)
	return pair


func _make_projectile_pair() -> Array[Node3D]:
	var scene := load("res://scenes/weapons/pistol_projectile.tscn") as PackedScene
	var pair: Array[Node3D] = []
	for index in range(2):
		var projectile := scene.instantiate() as Projectile
		projectile.configure_visual_profile(&"ak_rifle", Color("#e96525"))
		root.add_child(projectile)
		pair.append(projectile)
	return pair


func _verify_pair(pair: Array[Node3D], mesh_name: String, label: String) -> void:
	var first := _find_mesh(pair[0], mesh_name)
	var second := _find_mesh(pair[1], mesh_name)
	if first == null or second == null:
		_fail("Missing %s while checking resource reuse" % label)
		return
	if first == second:
		_fail("%s should use separate MeshInstance3D nodes" % label)
	if first.mesh != second.mesh:
		_fail("%s instances should share one immutable Mesh resource" % label)
	if first.material_override != second.material_override:
		_fail("%s instances should share one immutable Material resource" % label)


func _verify_single_build_pair(pair: Array[Node3D], label: String) -> void:
	for node in pair:
		var debug := node.call("get_visual_debug") as Dictionary if node.has_method("get_visual_debug") else node.call("get_visual_profile_debug") as Dictionary
		if int(debug.get("build_count", 0)) != 1:
			_fail("Each %s should build its visual once, got %d" % [label, int(debug.get("build_count", 0))])


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


func _finish(nodes: Array[Node3D]) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[Combat Effect Resource Reuse Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Combat Effect Resource Reuse Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
