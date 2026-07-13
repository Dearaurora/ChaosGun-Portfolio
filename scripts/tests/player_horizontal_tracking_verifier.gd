extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Player Horizontal Tracking Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var player := PlayerCharacter.new()
	player.name = "TrackingPlayer"
	player.freeze = true
	player.set_process(false)
	player.set_physics_process(false)
	stage.add_child(player)
	player.position = Vector3(0.0, 2.0, 0.0)
	player.set("_face_dir", Vector3(0.6, 0.0, 0.8))

	var arena_target := BaseCharacter.new()
	arena_target.name = "ArenaTarget"
	arena_target.freeze = true
	stage.add_child(arena_target)
	arena_target.position = Vector3(12.0, 18.0, 16.0)
	await process_frame

	var target := player.call("_get_lock_target") as BaseCharacter
	if target != arena_target:
		_fail("Lock-on should acquire targets across the full arena XZ plane")
	var expected_direction := Vector3(12.0, 0.0, 16.0).normalized()
	var fire_dir := player.call("_get_lock_on_fire_dir", expected_direction) as Vector3
	if fire_dir.distance_to(expected_direction) > 0.001:
		_fail("Lock-on should follow horizontal XZ displacement, got %s" % fire_dir)
	if absf(fire_dir.y) > 0.001:
		_fail("Lock-on direction must ignore terrain and character height differences")

	arena_target.global_position = Vector3(20.0, 42.0, 60.0)
	var retained := player.call("_get_lock_target") as BaseCharacter
	if retained != arena_target:
		_fail("Cached lock target should survive large Z and height changes while horizontally in range")
	arena_target.global_position = Vector3(80.0, 2.0, 60.0)
	var invalidated := player.call("_get_lock_target") as BaseCharacter
	if invalidated != null:
		_fail("Cached lock target should release only after leaving horizontal range")

	arena_target.global_position = Vector3(-18.0, 30.0, -12.0)
	player.set("_lock_target", null)
	var assisted_expected := Vector3(-18.0, 0.0, -12.0).normalized()
	player.set("_face_dir", assisted_expected)
	var assisted_dir := player.call("_get_aim_assisted_dir", assisted_expected) as Vector3
	if assisted_dir.distance_to(assisted_expected) > 0.001 or absf(assisted_dir.y) > 0.001:
		_fail("Aim assist should retain full-arena horizontal tracking without vertical aim")

	stage.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)
	print("OK  full-arena XZ tracking, range cache, and flattened vertical aim")
	_finish()

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print("[Player Horizontal Tracking Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Player Horizontal Tracking Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
