extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"

func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	seed(_argument_int("--seed=", 307))
	var match_config := root.get_node_or_null("MatchConfig")
	match_config.slots = [
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	]
	var packed := load(SCENE_PATH) as PackedScene
	var arena := packed.instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	await physics_frame
	var duration := _argument_float("--duration=", 15.0)
	var elapsed := 0.0
	while elapsed < duration:
		await create_timer(1.0).timeout
		elapsed += 1.0
		print("T=%.0f" % elapsed)
		for child in arena.get_children():
			if not child is AICharacter:
				continue
			var ai := child as AICharacter
			var target = ai.get("_target")
			var target_name := String(target.name) if is_instance_valid(target) else "none"
			var target_distance := ai.global_position.distance_to(target.global_position) if is_instance_valid(target) and target is Node3D else -1.0
			print("  %s pos=(%.1f,%.1f,%.1f) hp=%.0f lives=%d state=%s target=%s dist=%.1f vel=%.1f primary=%s" % [
				ai.name,
				ai.global_position.x, ai.global_position.y, ai.global_position.z,
				ai.current_hp, ai.lives, str(ai.get("_state")), target_name, target_distance,
				Vector3(ai.linear_velocity.x, 0.0, ai.linear_velocity.z).length(),
				str(ai.weapon_manager.has_primary() if ai.weapon_manager else false),
			])
	quit(0)

func _argument_int(prefix: String, fallback: int) -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return int(argument.trim_prefix(prefix))
	return fallback

func _argument_float(prefix: String, fallback: float) -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return float(argument.trim_prefix(prefix))
	return fallback
