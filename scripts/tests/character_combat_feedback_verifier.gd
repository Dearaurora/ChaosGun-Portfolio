extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Character Combat Feedback Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var host := Node3D.new()
	root.add_child(host)
	var feedback := CharacterCombatFeedback.new()
	feedback.name = "CombatFeedback"
	host.add_child(feedback)
	await process_frame

	feedback.set_shield_active(true)
	feedback.play_hit(Vector3(10.0, 0.0, 4.0), 1.0)
	await process_frame
	var feedback_debug := feedback.get_visual_debug()
	if not bool(feedback_debug.get("shield_active", false)):
		_fail("Respawn shield must expose an active visual state")
	if int(feedback_debug.get("shield_ring_count", 0)) != 2:
		_fail("Respawn shield should use exactly two controlled bands")
	if _count_prefixed(feedback, "DirectionalHitAccent_") != 1:
		_fail("Hit feedback must create one directional accent")
	if _count_prefixed(feedback, "ImpactSlash_") != 3:
		_fail("Directional hit accent should contain exactly three slashes")

	var ai_scene := load("res://scenes/characters/ai_character.tscn") as PackedScene
	var character := ai_scene.instantiate() as BaseCharacter if ai_scene else null
	if character == null:
		_fail("AI character scene must instantiate for feedback integration")
	else:
		root.add_child(character)
		await process_frame
		var integrated_feedback := character.get_node_or_null("CombatFeedback") as CharacterCombatFeedback
		if integrated_feedback == null:
			_fail("BaseCharacter must create its combat feedback node")
		else:
			character.apply_hit(Vector3.RIGHT * 4.0, 0.0, null)
			if int(integrated_feedback.get_visual_debug().get("hit_serial", 0)) != 1:
				_fail("BaseCharacter hits must trigger directional visual feedback")
			character.call("_respawn")
			if not bool(integrated_feedback.get_visual_debug().get("shield_active", false)):
				_fail("BaseCharacter respawn must activate the shield visual")

	var transition_scene := load("res://scenes/effects/character_transition_burst.tscn") as PackedScene
	if transition_scene == null:
		_fail("Character transition scene must load")
		await _finish([host])
		return
	var ringout := transition_scene.instantiate() as Node3D
	ringout.call("configure", &"ringout", Color("#ff6a3d"), 1.45)
	root.add_child(ringout)
	var respawn := transition_scene.instantiate() as Node3D
	respawn.call("configure", &"respawn", Color("#6ee7ff"), 1.15)
	root.add_child(respawn)
	await process_frame
	_verify_transition(ringout, "ringout", 6)
	_verify_transition(respawn, "respawn", 4)

	await create_timer(0.17).timeout
	if _count_prefixed(feedback, "DirectionalHitAccent_") != 0:
		_fail("Directional hit accent must clear within 0.17 seconds")
	await create_timer(0.18).timeout
	if is_instance_valid(ringout) and not ringout.is_queued_for_deletion():
		_fail("Ringout transition must self-remove")
	if is_instance_valid(respawn) and not respawn.is_queued_for_deletion():
		_fail("Respawn transition must self-remove")
	await _finish([host, character, ringout, respawn])

func _verify_transition(effect: Node3D, expected_mode: String, expected_rays: int) -> void:
	var debug := effect.call("get_visual_debug") as Dictionary
	if String(debug.get("mode", "")) != expected_mode:
		_fail("Transition mode mismatch for %s" % expected_mode)
	if int(debug.get("ring_count", 0)) != 1:
		_fail("%s transition should use one clean ring" % expected_mode)
	if int(debug.get("ray_count", 0)) != expected_rays:
		_fail("%s transition ray count should be %d" % [expected_mode, expected_rays])
	if float(debug.get("lifetime", 1.0)) > 0.30:
		_fail("%s transition must finish within 0.30 seconds" % expected_mode)

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
		print("[Character Combat Feedback Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Character Combat Feedback Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
