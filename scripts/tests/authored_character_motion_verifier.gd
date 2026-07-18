extends SceneTree

const WEAPON_CASES := {
	&"pistol": &"pistol",
	&"smg": &"smg",
	&"ak_rifle": &"ak",
	&"sniper": &"sniper",
	&"shotgun": &"shotgun",
	&"gatling": &"gatling",
}

var _failures: Array[String] = []

func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	print("==================================================")
	print("[Authored Character Motion Verifier]")
	print("==================================================")

	var visual := CharacterVisual.new()
	root.add_child(visual)
	await process_frame
	await process_frame
	var skeleton := _find_skeleton(visual)
	if skeleton == null:
		_fail("Hero character must expose its imported Skeleton3D")
		await _finish(visual)
		return

	var initial_debug := visual.get_motion_debug()
	if not bool(initial_debug.get("authored_motion_enabled", false)):
		_fail("CharacterVisual did not enable the exported authored motion set")
		await _finish(visual)
		return

	for weapon_id in WEAPON_CASES:
		await _verify_weapon_motion(visual, skeleton, weapon_id, WEAPON_CASES[weapon_id])

	await _finish(visual)

func _verify_weapon_motion(
	visual: CharacterVisual,
	skeleton: Skeleton3D,
	weapon_id: StringName,
	clip_suffix: StringName
) -> void:
	visual.set_weapon_visual(weapon_id)
	await process_frame
	var hand_index := skeleton.find_bone(&"Hand.L")
	var thigh_index := skeleton.find_bone(&"Thigh.L")
	var hold_hand := skeleton.get_bone_pose_rotation(hand_index)

	visual.animate_locomotion(Vector3.FORWARD, Vector3.FORWARD, 1.0, 1.0 / 60.0)
	var start_debug := visual.get_motion_debug()
	if StringName(start_debug.get("authored_motion_clip", &"")) != StringName("start_%s" % clip_suffix):
		_fail("%s did not enter its authored start clip" % weapon_id)
	await create_timer(0.36).timeout

	var run_debug := visual.get_motion_debug()
	if StringName(run_debug.get("authored_motion_clip", &"")) != StringName("run_%s" % clip_suffix):
		_fail("%s did not transition from start to its authored run loop" % weapon_id)
	var run_hand := skeleton.get_bone_pose_rotation(hand_index)
	if hold_hand.angle_to(run_hand) > 0.025:
		_fail("%s run loop changed the authored support-hand grip" % weapon_id)
	if weapon_id == &"smg":
		var spine_index := skeleton.find_bone(&"Spine")
		var spine_before_fire := skeleton.get_bone_pose_rotation(spine_index)
		visual.animate_fire(weapon_id)
		await process_frame
		await process_frame
		var spine_after_fire := skeleton.get_bone_pose_rotation(spine_index)
		var holder := visual.get_node_or_null("WeaponHolder") as Node3D
		if spine_before_fire.angle_to(spine_after_fire) < 0.015:
			_fail("Authored run playback overwrote the rigged upper-body recoil")
		if holder == null or absf(holder.rotation.x) < 0.012:
			_fail("Held weapon did not follow recoil while an authored run loop was playing")
	var first_thigh := skeleton.get_bone_pose_rotation(thigh_index)
	await create_timer(0.12).timeout
	var second_thigh := skeleton.get_bone_pose_rotation(thigh_index)
	if first_thigh.angle_to(second_thigh) < 0.025:
		_fail("%s run loop does not visibly advance the planted-leg pose" % weapon_id)
	if weapon_id == &"smg":
		var footstep_before := int((visual.get_motion_debug() as Dictionary).get("footstep_serial", 0))
		await create_timer(0.24).timeout
		var footstep_after := int((visual.get_motion_debug() as Dictionary).get("footstep_serial", 0))
		if footstep_after <= footstep_before:
			_fail("Authored run contacts did not emit synchronized deck footsteps")

	visual.animate_locomotion(Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0 / 60.0)
	var stop_debug := visual.get_motion_debug()
	if StringName(stop_debug.get("authored_motion_clip", &"")) != StringName("stop_%s" % clip_suffix):
		_fail("%s did not enter its authored stop clip" % weapon_id)
	await create_timer(0.36).timeout
	var hold_debug := visual.get_motion_debug()
	if StringName(hold_debug.get("authored_motion_clip", &"")) != visual.call("_weapon_pose_animation_for", weapon_id):
		_fail("%s did not settle back to its weapon hold pose" % weapon_id)

	visual.animate_hit(Vector3.RIGHT, 1.0)
	var hit_debug := visual.get_motion_debug()
	if StringName(hit_debug.get("authored_motion_clip", &"")) != StringName("hit_%s" % clip_suffix):
		_fail("%s did not enter its authored impact brace" % weapon_id)
	await create_timer(0.24).timeout
	var recovered_debug := visual.get_motion_debug()
	if StringName(recovered_debug.get("authored_motion_clip", &"")) != visual.call("_weapon_pose_animation_for", weapon_id):
		_fail("%s impact brace did not recover to its hold pose" % weapon_id)
	else:
		print("OK  %s start/run/stop/hit choreography" % weapon_id)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var skeleton := _find_skeleton(child)
		if skeleton != null:
			return skeleton
	return null

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(visual: Node) -> void:
	if is_instance_valid(visual):
		visual.queue_free()
		await process_frame
	if _failures.is_empty():
		print("[Authored Character Motion Verifier] PASS")
		quit(0)
		return
	print("[Authored Character Motion Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
