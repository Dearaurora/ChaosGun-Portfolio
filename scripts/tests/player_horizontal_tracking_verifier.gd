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
	player.set("_face_dir", Vector3.RIGHT)

	var off_plane := BaseCharacter.new()
	off_plane.name = "CloserButOffPlane"
	off_plane.freeze = true
	stage.add_child(off_plane)
	off_plane.position = Vector3(8.0, 2.0, 11.0)
	var same_plane := BaseCharacter.new()
	same_plane.name = "FartherSamePlane"
	same_plane.freeze = true
	stage.add_child(same_plane)
	same_plane.position = Vector3(20.0, 7.0, 2.0)
	await process_frame

	var target := player.call("_get_lock_target") as BaseCharacter
	if target != same_plane:
		_fail("Lock-on should ignore a closer target outside the same Z lane")
	var fire_dir := player.call("_get_lock_on_fire_dir", Vector3.RIGHT) as Vector3
	if fire_dir.distance_to(Vector3.RIGHT) > 0.001:
		_fail("Lock-on fire must travel on one horizontal lane, got %s" % fire_dir)
	if absf(fire_dir.y) > 0.001 or absf(fire_dir.z) > 0.001:
		_fail("Lock-on direction must not track vertical or Z displacement")

	same_plane.global_position.z = 7.0
	var invalidated := player.call("_get_lock_target") as BaseCharacter
	if invalidated != null:
		_fail("Cached lock target should be released after leaving the Z tolerance")

	same_plane.global_position = Vector3(-18.0, 6.0, 1.0)
	player.set("_lock_target", null)
	player.set("_face_dir", Vector3.LEFT)
	var assisted_dir := player.call("_get_aim_assisted_dir", Vector3.LEFT) as Vector3
	if assisted_dir.distance_to(Vector3.LEFT) > 0.001:
		_fail("Aim assist should return a pure horizontal direction for same-lane targets")

	stage.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)
	print("OK  same-lane target filtering, cache invalidation, and flat fire direction")
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
