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
	hit.call("configure", Color("#ffb13b"), &"ak_rifle", Vector3.RIGHT)
	root.add_child(hit)
	var sniper_hit := hit_scene.instantiate() as Node3D
	sniper_hit.call("configure", Color("#5ce3ff"), &"sniper", Vector3.FORWARD)
	root.add_child(sniper_hit)
	var shotgun_hit := hit_scene.instantiate() as Node3D
	shotgun_hit.call("configure", Color("#d884ff"), &"shotgun", Vector3.FORWARD)
	root.add_child(shotgun_hit)
	await process_frame

	_verify_muzzle(muzzle)
	_verify_hit(hit)
	_verify_hit_profile_contrast(sniper_hit, shotgun_hit)
	await create_timer(0.22).timeout
	if is_instance_valid(muzzle) and not muzzle.is_queued_for_deletion():
		_fail("Muzzle flash must self-remove without lingering particles")
	if is_instance_valid(hit) and not hit.is_queued_for_deletion():
		_fail("Hit effect must self-remove without decals or motes")
	await _finish([muzzle, hit, sniper_hit, shotgun_hit])

func _verify_muzzle(muzzle: Node3D) -> void:
	var debug := muzzle.call("get_visual_debug") as Dictionary
	if int(debug.get("petal_count", 0)) != 2:
		_fail("Sniper muzzle flash should use two controlled lance petals")
	if String(debug.get("shape", "")) != "lance":
		_fail("Sniper muzzle flash should report the lance silhouette")
	if int(debug.get("ring_count", 0)) != 1 or _count_named(muzzle, "MuzzleShockRing") != 1:
		_fail("Sniper muzzle flash should include one connected shock ring")
	if String(debug.get("petal_axis", "")) != "horizontal_y":
		_fail("Muzzle petals must fan across the gameplay plane")
	var light_energy := float(debug.get("light_energy", 0.0))
	if light_energy < 0.45 or light_energy > 1.40:
		_fail("Muzzle light must remain brief and restrained")
	if float(debug.get("lifetime", 1.0)) > 0.085:
		_fail("Muzzle flash lifetime should remain below 0.085 seconds")
	if _count_named(muzzle, "MuzzleCore") != 1 or _count_named(muzzle, "MuzzleUnderlay") != 0:
		_fail("Muzzle flash should use one colored core without a ring-like dark underlay")
	if _count_named(muzzle, "MuzzleLight") != 1:
		_fail("Muzzle flash should use exactly one non-shadowing transient light")

func _verify_hit(hit: Node3D) -> void:
	var debug := hit.call("get_visual_debug") as Dictionary
	if int(debug.get("shard_count", 0)) != 4:
		_fail("AK hit effect should use exactly four directional shards")
	if float(debug.get("lifetime", 1.0)) > 0.18:
		_fail("Hit effect must finish within 0.18 seconds")
	if _count_named(hit, "ImpactCore") != 1 or _count_prefixed(hit, "ImpactShard_") != 4:
		_fail("Hit effect node count should remain deterministic and clean")
	if String(debug.get("shape", "")) != "directional_slash":
		_fail("AK hit effect should report its directional slash shape")
	var impact_direction := debug.get("impact_direction", Vector3.ZERO) as Vector3
	for child in hit.get_children():
		if String(child.name).begins_with("ImpactShard_") and child is Node3D:
			var shard := child as Node3D
			var shard_position := shard.position
			if shard_position.dot(impact_direction) <= 0.0:
				_fail("Every impact shard should travel into the forward impact hemisphere")
			if shard.scale.z <= shard.scale.x * 3.0:
				_fail("Directional impact shards must preserve a clear streak aspect ratio")

func _verify_hit_profile_contrast(sniper_hit: Node3D, shotgun_hit: Node3D) -> void:
	var sniper_debug := sniper_hit.call("get_visual_debug") as Dictionary
	var shotgun_debug := shotgun_hit.call("get_visual_debug") as Dictionary
	if float(sniper_debug.get("fan_degrees", 90.0)) >= 24.0:
		_fail("Sniper impact should remain a narrow directional fan")
	if float(shotgun_debug.get("fan_degrees", 0.0)) <= 60.0:
		_fail("Shotgun impact should use a visibly wider fan")
	if float(sniper_debug.get("elongation", 0.0)) <= float(shotgun_debug.get("elongation", 0.0)):
		_fail("Sniper impact streaks should be longer than shotgun streaks")
	if int(sniper_debug.get("ring_count", 0)) != 1 or int(shotgun_debug.get("ring_count", 0)) != 0:
		_fail("Only the sniper impact should add the precision shock ring")
	if int(shotgun_debug.get("shard_count", 0)) <= int(sniper_debug.get("shard_count", 0)):
		_fail("Shotgun impact should use more shards than the sniper impact")

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
