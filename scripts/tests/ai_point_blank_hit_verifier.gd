extends SceneTree

const AI_SCENE := preload("res://scenes/characters/ai_character.tscn")

const PASS_MARKER := "AI_POINT_BLANK_HIT_VERIFIER_PASS"
var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[AI Point-Blank Hit Verifier]")
	print("==================================================")
	seed(123456)
	root.set_meta("disable_runtime_audio", true)

	var arena := await _boot_runtime_stage()
	if arena == null:
		_fail("runtime physics stage must instantiate")
	else:
		await _verify_physical_contact_hit(arena)
		await _verify_cover_blocks_fire_and_hit(arena)
		await _free_node(arena)

	_finish()

func _boot_runtime_stage() -> Node3D:
	# Keep the regression independent from arena presentation scripts while using
	# the production AI scenes, weapon manager, projectile, bodies and physics.
	var arena := Node3D.new()
	arena.name = "PointBlankRuntimeStage"
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await physics_frame
	return arena

func _verify_physical_contact_hit(arena: Node3D) -> void:
	var pair := await _spawn_pair(arena, Vector3(0.0, 1.0, -2.75))
	var shooter := pair[0] as AICharacter
	var target := pair[1] as AICharacter
	if shooter == null or target == null:
		_fail("real AI scene instances must spawn")
		return

	var contact_distance := shooter.global_position.distance_to(target.global_position)
	if contact_distance > 2.85:
		_fail("AI pair must be at physical face-to-face contact, distance=%.3f" % contact_distance)
	if not bool(shooter.call("_has_line_of_sight_to_target")):
		_fail("point-blank target must be visible through the real collision world")

	var shots := [0]
	shooter.weapon_manager.weapon_fired.connect(
		func(_weapon_data: WeaponData) -> void: shots[0] += 1
	)
	var hp_before := target.current_hp
	shooter.set("_reaction_timer", 0.0)
	shooter.call("_do_shoot", 1.0 / 60.0)
	if shots[0] != 1:
		_fail("point-blank AI must fire exactly one real pistol shot, shots=%d" % shots[0])

	for _frame in range(12):
		await physics_frame
	if target.current_hp >= hp_before:
		_fail("real projectile must damage the contact target, hp=%.1f -> %.1f" % [hp_before, target.current_hp])

	await _free_children(arena)

func _verify_cover_blocks_fire_and_hit(arena: Node3D) -> void:
	var pair := await _spawn_pair(arena, Vector3(0.0, 1.0, -8.0))
	var shooter := pair[0] as AICharacter
	var target := pair[1] as AICharacter
	if shooter == null or target == null:
		_fail("cover case AI scene instances must spawn")
		return

	var cover := StaticBody3D.new()
	cover.name = "VerifierCover"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 4.0, 0.8)
	shape_node.shape = shape
	cover.add_child(shape_node)
	arena.add_child(cover)
	cover.global_position = Vector3(0.0, 1.5, -4.2)
	await physics_frame

	if bool(shooter.call("_has_line_of_sight_to_target")):
		_fail("cover must block the real AI line of sight")
	var shots := [0]
	shooter.weapon_manager.weapon_fired.connect(
		func(_weapon_data: WeaponData) -> void: shots[0] += 1
	)
	var hp_before := target.current_hp
	shooter.set("_reaction_timer", 0.0)
	shooter.call("_do_shoot", 1.0 / 60.0)
	for _frame in range(12):
		await physics_frame
	if shots[0] != 0:
		_fail("AI must not fire through cover, shots=%d" % shots[0])
	if target.current_hp != hp_before:
		_fail("cover must prevent projectile damage, hp=%.1f -> %.1f" % [hp_before, target.current_hp])

	await _free_children(arena)

func _spawn_pair(arena: Node3D, target_position: Vector3) -> Array[AICharacter]:
	var shooter := AI_SCENE.instantiate() as AICharacter
	var target := AI_SCENE.instantiate() as AICharacter
	if shooter == null or target == null:
		return [shooter, target]
	shooter.name = "VerifierShooter"
	target.name = "VerifierTarget"
	arena.add_child(shooter)
	arena.add_child(target)
	shooter.add_to_group("player")
	target.add_to_group("player")
	await process_frame
	shooter.freeze = true
	target.freeze = true
	shooter.set_process(false)
	shooter.set_physics_process(false)
	target.set_process(false)
	target.set_physics_process(false)
	shooter.global_position = Vector3(0.0, 1.0, 0.0)
	target.global_position = target_position
	shooter.set("_target", target)
	shooter.set("_state", AICharacter.State.SHOOT)
	await physics_frame
	return [shooter, target]

func _free_children(parent: Node) -> void:
	for child in parent.get_children():
		if child.name.begins_with("Verifier"):
			child.queue_free()
	await process_frame
	await physics_frame

func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print(PASS_MARKER)
		print("[AI Point-Blank Hit Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[AI Point-Blank Hit Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
