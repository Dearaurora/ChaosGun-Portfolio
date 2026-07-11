extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Character Locomotion Visual Verifier]")
	print("==================================================")

	var visual = CharacterVisual.new()
	visual.name = "VisualUnderTest"
	root.add_child(visual)
	await process_frame
	await process_frame

	if not visual.has_method("animate_locomotion"):
		_fail("CharacterVisual must expose animate_locomotion(move_dir, facing_dir, speed_ratio, delta)")
		await _finish(visual)
		return
	if not visual.has_method("get_locomotion_forward_amount") or not visual.has_method("get_locomotion_right_amount"):
		_fail("CharacterVisual must expose locomotion blend getters for verification")
		await _finish(visual)
		return

	_verify_strafing_blends_smoothly(visual)
	_verify_backpedal_blends_against_facing(visual)
	_verify_idle_decays_smoothly(visual)
	await _verify_action_feedback(visual)
	await _finish(visual)

func _verify_strafing_blends_smoothly(visual: CharacterVisual) -> void:
	visual.animate_locomotion(Vector3.RIGHT, Vector3.FORWARD, 1.0, 1.0 / 60.0)
	var first_right := float(visual.call("get_locomotion_right_amount"))
	if first_right <= 0.02 or first_right >= 0.35:
		_fail("Strafe blend should start smoothly instead of snapping, got %.3f" % first_right)
	for _i in range(14):
		visual.animate_locomotion(Vector3.RIGHT, Vector3.FORWARD, 1.0, 1.0 / 60.0)
	var right_amount := float(visual.call("get_locomotion_right_amount"))
	var forward_amount := float(visual.call("get_locomotion_forward_amount"))
	if right_amount < 0.72:
		_fail("Strafe input should blend strongly to the local right side, got %.3f" % right_amount)
	if absf(forward_amount) > 0.22:
		_fail("Pure strafe should not read as forward/backpedal, forward amount %.3f" % forward_amount)
	if absf(visual.rotation.z) < 0.035:
		_fail("Strafe movement should visibly lean the bean model sideways")
	else:
		print("OK  smooth strafe locomotion")

func _verify_backpedal_blends_against_facing(visual: CharacterVisual) -> void:
	for _i in range(18):
		visual.animate_locomotion(Vector3.BACK, Vector3.FORWARD, 1.0, 1.0 / 60.0)
	var forward_amount := float(visual.call("get_locomotion_forward_amount"))
	var right_amount := float(visual.call("get_locomotion_right_amount"))
	if forward_amount > -0.65:
		_fail("Moving opposite the aim direction should read as backpedal, got %.3f" % forward_amount)
	if absf(right_amount) > 0.25:
		_fail("Backpedal should not keep a strong strafe blend, right amount %.3f" % right_amount)
	if visual.rotation.x < 0.025:
		_fail("Backpedal should pitch the model differently from forward movement")
	else:
		print("OK  backpedal locomotion relative to facing")

func _verify_idle_decays_smoothly(visual: CharacterVisual) -> void:
	var before := absf(float(visual.call("get_locomotion_forward_amount")))
	visual.animate_locomotion(Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0 / 60.0)
	var after_one := absf(float(visual.call("get_locomotion_forward_amount")))
	if after_one <= 0.01:
		_fail("Idle decay should be smooth, not snap to zero")
	for _i in range(40):
		visual.animate_locomotion(Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0 / 60.0)
	var after_decay := absf(float(visual.call("get_locomotion_forward_amount")))
	if after_decay >= before or after_decay > 0.08:
		_fail("Idle should decay locomotion blends toward zero, got %.3f" % after_decay)
	else:
		print("OK  idle locomotion decay")

func _verify_action_feedback(visual: CharacterVisual) -> void:
	if not visual.has_method("animate_fire") or not visual.has_method("animate_respawn") or not visual.has_method("get_motion_debug"):
		_fail("CharacterVisual must expose fire, respawn, and motion debug feedback")
		return

	visual.animate_fire(&"sniper")
	var fire_debug := visual.call("get_motion_debug") as Dictionary
	if float(fire_debug.get("weapon_kick", 0.0)) < 0.12 or float(fire_debug.get("recoil_pitch", 0.0)) < 0.09:
		_fail("Sniper fire should create a readable high-recoil impulse")
	await create_timer(0.25).timeout
	var decay_debug := visual.call("get_motion_debug") as Dictionary
	if float(decay_debug.get("weapon_kick", 1.0)) >= float(fire_debug.get("weapon_kick", 0.0)):
		_fail("Weapon kick should decay after firing")

	visual.animate_hit(Vector3.RIGHT, 1.0)
	var hit_debug := visual.call("get_motion_debug") as Dictionary
	if absf(float(hit_debug.get("impact_roll", 0.0))) < 0.10:
		_fail("Side impact should create directional body roll")

	visual.animate_respawn()
	var respawn_debug := visual.call("get_motion_debug") as Dictionary
	var respawn_scale := respawn_debug.get("action_scale", Vector3.ONE) as Vector3
	if respawn_scale.y < 1.30 or respawn_scale.x > 0.50:
		_fail("Respawn should begin with a narrow vertical stretch")

	visual.animate_squash(0.65, 1.22, 0.20)
	await process_frame
	if visual.scale.y >= visual.scale.x:
		_fail("Landing squash should deform the complete character assembly")
	else:
		print("OK  fire, impact, respawn, and whole-body deformation feedback")

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(visual: Node) -> void:
	if visual and is_instance_valid(visual):
		visual.queue_free()
		await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Character Locomotion Visual Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Character Locomotion Visual Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
