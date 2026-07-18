extends SceneTree

var _failures: Array[String] = []
var _stage: Node3D = null

func _initialize() -> void:
	print("==================================================")
	print("[Center Pickup Schedule Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	_stage = Node3D.new()
	_stage.name = "CenterPickupScheduleStage"
	root.add_child(_stage)
	current_scene = _stage

	var spawner := WeaponSpawner.new()
	spawner.name = "WeaponSpawner"
	spawner.initial_delay = 0.05
	spawner.stay_duration = 0.12
	spawner.fixed_spawn_interval = 0.30
	spawner.center_powerups_enabled = true
	spawner.max_active_pickups = 1
	spawner.fixed_spawn_points = [Vector3(0.0, 1.5, 0.0)]
	_stage.add_child(spawner)

	var first := await _wait_for_pickup(0.50)
	if first == null:
		_fail("Initial center pickup did not spawn")
		await _finish()
		return
	var first_spawn_time := Time.get_ticks_msec() * 0.001
	first.emit_signal("picked_up")
	first.queue_free()
	await process_frame

	await create_timer(0.16).timeout
	if _active_center_pickup() != null:
		_fail("Collecting early must not trigger an early center refill")

	var second := await _wait_for_pickup(0.30)
	if second == null:
		_fail("Center pickup did not return on the fixed interval tick")
		await _finish()
		return
	var second_spawn_time := Time.get_ticks_msec() * 0.001
	var first_gap := second_spawn_time - first_spawn_time
	if first_gap < 0.24 or first_gap > 0.42:
		_fail("Early collection changed the fixed interval: %.3f seconds" % first_gap)

	var second_expired := await _wait_for_no_pickup(0.28)
	if not second_expired:
		_fail("Uncollected center pickup did not expire after its stay duration")

	var third := await _wait_for_pickup(0.34)
	if third == null:
		_fail("Expiry incorrectly added stay duration onto the next fixed interval")
	else:
		var third_spawn_time := Time.get_ticks_msec() * 0.001
		var second_gap := third_spawn_time - second_spawn_time
		if second_gap < 0.24 or second_gap > 0.42:
			_fail("Center spawn cadence drifted after expiry: %.3f seconds" % second_gap)

	await _finish()

func _active_center_pickup() -> Node3D:
	for group_name in ["weapon_pickup", "powerup_pickup"]:
		for node in get_nodes_in_group(group_name):
			if node is Node3D and _stage.is_ancestor_of(node) and not node.is_queued_for_deletion():
				return node as Node3D
	return null

func _wait_for_pickup(timeout: float) -> Node3D:
	var deadline := Time.get_ticks_msec() * 0.001 + timeout
	while Time.get_ticks_msec() * 0.001 < deadline:
		var pickup := _active_center_pickup()
		if pickup:
			return pickup
		await process_frame
	return null

func _wait_for_no_pickup(timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() * 0.001 + timeout
	while Time.get_ticks_msec() * 0.001 < deadline:
		if _active_center_pickup() == null:
			return true
		await process_frame
	return false

func _finish() -> void:
	if _stage and is_instance_valid(_stage):
		_stage.queue_free()
		_stage = null
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("OK  early collection waits for the absolute interval tick")
		print("OK  expiry leaves a gap without stretching the 17-second cadence")
		print("[Center Pickup Schedule Verifier] PASS")
		quit(0)
		return
	print("[Center Pickup Schedule Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
