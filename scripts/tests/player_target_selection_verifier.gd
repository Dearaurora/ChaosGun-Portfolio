extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Player Target Selection Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var stage := Node3D.new()
	stage.name = "TargetSelectionStage"
	root.add_child(stage)
	current_scene = stage

	var player := PlayerCharacter.new()
	player.name = "SelectionPlayer"
	player.freeze = true
	player.set_process(false)
	player.set_physics_process(false)
	player.slot_index = 2
	stage.add_child(player)
	player.position = Vector3(0.0, 2.0, 0.0)
	player.set("_face_dir", Vector3(0.0, 0.0, 1.0))

	var front := _make_target(stage, "FrontTarget", Vector3(0.0, 2.0, 18.0))
	var right := _make_target(stage, "RightTarget", Vector3(14.0, 2.0, 0.0))
	var left := _make_target(stage, "LeftTarget", Vector3(-16.0, 2.0, -2.0))
	await process_frame

	_verify_intent_first_acquisition(player, front)
	_verify_player_colored_indicator(player)
	_verify_held_fire_stability(player, front)
	_verify_manual_cycle_and_protection(player, front, right, left)
	_verify_release_turn_reacquisition(player, right)
	_verify_soft_lock_timeout(player)
	_verify_indicator_does_not_select(player)
	_verify_cycle_action_path(player)
	await _verify_occlusion_release(stage, player, front)

	Input.action_release("p1_fire")
	Input.action_release("p1_target_cycle")
	stage.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)
	_finish()


func _make_target(parent: Node3D, target_name: String, target_position: Vector3) -> BaseCharacter:
	var target := BaseCharacter.new()
	target.name = target_name
	target.freeze = true
	parent.add_child(target)
	target.position = target_position
	return target


func _verify_intent_first_acquisition(player: PlayerCharacter, expected: BaseCharacter) -> void:
	player.call("_clear_lock_target")
	var selected := player.call("_acquire_lock_target", Vector3(0.0, 0.0, 1.0)) as BaseCharacter
	if selected != expected:
		_fail("Initial acquisition should prioritize player intent over the nearest target")
	else:
		print("OK  intent-weighted initial acquisition")


func _verify_player_colored_indicator(player: PlayerCharacter) -> void:
	player.call("_update_lock_indicator")
	var indicator := player.get("_lock_indicator") as MeshInstance3D
	var material := indicator.material_override as StandardMaterial3D if indicator else null
	if material == null or not material.emission.is_equal_approx(Color("#d66bdc")):
		_fail("The lock indicator should use the selecting player's slot color")
	else:
		print("OK  player-colored target feedback")


func _verify_held_fire_stability(player: PlayerCharacter, expected: BaseCharacter) -> void:
	player.call("_begin_lock_session", Vector3(0.0, 0.0, 1.0))
	player.call("_tick_lock_state", 0.12, Vector3.RIGHT, true)
	var debug := player.call("get_lock_on_debug") as Dictionary
	if debug.get("target") != expected or debug.get("state") != "hard":
		_fail("Held fire should keep a stable hard lock instead of following movement input")
	else:
		print("OK  held-fire hard-lock stability")


func _verify_manual_cycle_and_protection(
	player: PlayerCharacter,
	front: BaseCharacter,
	right: BaseCharacter,
	left: BaseCharacter
) -> void:
	var visited: Array[BaseCharacter] = [front]
	for index in range(2):
		var selected := player.call("_cycle_lock_target", true, Vector3.RIGHT) as BaseCharacter
		if selected == null or selected in visited:
			_fail("Manual target cycle should visit each available opponent before wrapping")
			return
		visited.append(selected)
	if right not in visited or left not in visited:
		_fail("Manual target cycle did not expose every living opponent")
		return

	var protected_target := player.call("_get_lock_target") as BaseCharacter
	player.call("_begin_lock_session", -_direction_to(player, protected_target))
	if player.call("_get_lock_target") != protected_target:
		_fail("A manually selected target should be protected from immediate automatic override")
	else:
		print("OK  deterministic manual cycling with short protection")


func _verify_release_turn_reacquisition(player: PlayerCharacter, expected: BaseCharacter) -> void:
	player.set("_manual_lock_remaining", 0.0)
	player.call("_end_lock_session")
	var soft_debug := player.call("get_lock_on_debug") as Dictionary
	if soft_debug.get("state") != "soft":
		_fail("Releasing fire should move the target from hard lock to soft lock")
		return
	player.call("_tick_lock_state", 0.08, Vector3.RIGHT, false)
	if player.call("_get_lock_target") != null:
		_fail("A deliberate turn during soft lock should release the previous target")
		return
	player.call("_begin_lock_session", Vector3.RIGHT)
	if player.call("_get_lock_target") != expected:
		_fail("The next firing session should acquire the opponent in the new intent direction")
	else:
		print("OK  release-turn-reacquire player control")


func _verify_soft_lock_timeout(player: PlayerCharacter) -> void:
	player.call("_end_lock_session")
	player.call("_tick_lock_state", 0.31, Vector3.ZERO, false)
	if player.call("_get_lock_target") != null:
		_fail("Soft lock should expire after its grace window")
	else:
		print("OK  finite soft-lock grace window")


func _verify_indicator_does_not_select(player: PlayerCharacter) -> void:
	player.call("_clear_lock_target")
	player.call("_update_lock_indicator")
	if player.call("_get_lock_target") != null:
		_fail("The target indicator must not acquire a target as a side effect")
	else:
		print("OK  read-only lock indicator")


func _verify_cycle_action_path(player: PlayerCharacter) -> void:
	player.call("_clear_lock_target")
	Input.action_press("p1_target_cycle")
	player.call("_update_lock_on_input", 0.016, Vector3(0.0, 0.0, 1.0), "lock_on")
	Input.action_release("p1_target_cycle")
	var debug := player.call("get_lock_on_debug") as Dictionary
	if debug.get("target") == null or debug.get("state") != "soft":
		_fail("The configured target-cycle action should create a protected soft selection")
	elif float(debug.get("manual_lock_remaining", 0.0)) <= 0.0:
		_fail("Manual target cycling should protect the player's selection")
	else:
		print("OK  configured target-cycle input path")


func _verify_occlusion_release(
	stage: Node3D,
	player: PlayerCharacter,
	target: BaseCharacter
) -> void:
	var blocker := StaticBody3D.new()
	blocker.name = "LockOcclusionBlocker"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 4.0, 2.0)
	shape_node.shape = shape
	blocker.add_child(shape_node)
	stage.add_child(blocker)
	blocker.position = Vector3(0.0, 2.0, 9.0)
	await physics_frame

	player.call("_clear_lock_target")
	player.call("_set_lock_target", target)
	player.call("_tick_lock_state", 0.29, Vector3.ZERO, false)
	if player.call("_get_lock_target") != target:
		_fail("A brief occlusion should not immediately discard the target")
		return
	player.call("_tick_lock_state", 0.02, Vector3.ZERO, false)
	if player.call("_get_lock_target") != null:
		_fail("A target occluded beyond the grace window should be released")
	else:
		print("OK  occlusion grace and release")


func _direction_to(player: PlayerCharacter, target: BaseCharacter) -> Vector3:
	var direction := target.global_position - player.global_position
	direction.y = 0.0
	return direction.normalized()


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print("[Player Target Selection Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Player Target Selection Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
