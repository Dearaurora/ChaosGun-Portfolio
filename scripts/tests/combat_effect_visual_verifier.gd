extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Combat Effect Visual Verifier]")
	print("==================================================")

	var muzzle_scene := load("res://scenes/effects/muzzle_flash.tscn") as PackedScene
	var hit_scene := load("res://scenes/effects/hit_effect.tscn") as PackedScene
	if muzzle_scene == null or hit_scene == null:
		_fail("Combat effect scenes must load")
		await _finish([])
		return

	var muzzle := muzzle_scene.instantiate() as Node3D
	muzzle.call("configure", Vector3.FORWARD, Color("#5ce3ff"), &"sniper")
	root.add_child(muzzle)
	var hit := hit_scene.instantiate() as Node3D
	hit.call("configure", Color("#ffb13b"), &"ak_rifle")
	root.add_child(hit)
	await process_frame

	_verify_muzzle(muzzle)
	_verify_hit(hit)
	await create_timer(0.22).timeout
	if is_instance_valid(muzzle) and not muzzle.is_queued_for_deletion():
		_fail("Muzzle flash must self-remove without lingering particles")
	if is_instance_valid(hit) and not hit.is_queued_for_deletion():
		_fail("Hit effect must self-remove without decals or motes")
	await _finish([muzzle, hit])

func _verify_muzzle(muzzle: Node3D) -> void:
	var debug := muzzle.call("get_visual_debug") as Dictionary
	if int(debug.get("petal_count", 0)) != 2:
		_fail("Muzzle flash should use exactly two controlled petals")
	if float(debug.get("lifetime", 1.0)) > 0.085:
		_fail("Muzzle flash lifetime should remain below 0.085 seconds")
	if _count_named(muzzle, "MuzzleCore") != 1 or _count_named(muzzle, "MuzzleUnderlay") != 0:
		_fail("Muzzle flash should use one colored core without a ring-like dark underlay")

func _verify_hit(hit: Node3D) -> void:
	var debug := hit.call("get_visual_debug") as Dictionary
	if int(debug.get("shard_count", 0)) != 4:
		_fail("Hit effect should use exactly four directional shards")
	if float(debug.get("lifetime", 1.0)) > 0.18:
		_fail("Hit effect must finish within 0.18 seconds")
	if _count_named(hit, "ImpactCore") != 1 or _count_prefixed(hit, "ImpactShard_") != 4:
		_fail("Hit effect node count should remain deterministic and clean")

func _count_named(node: Node, target_name: String) -> int:
	var count := 1 if node.name == target_name else 0
	for child in node.get_children():
		count += _count_named(child, target_name)
	return count

func _count_prefixed(node: Node, prefix: String) -> int:
	var count := 1 if String(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_prefixed(child, prefix)
	return count

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
		print("[Combat Effect Visual Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Combat Effect Visual Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
