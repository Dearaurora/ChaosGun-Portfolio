extends SceneTree

const AI_SCENE := preload("res://scenes/characters/ai_character.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[AI Point-Blank Fire Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	await _verify_clear_case("same-origin", Vector3.ZERO)
	await _verify_clear_case("epsilon", Vector3(0.05, 0.0, 0.0))
	await _verify_clear_case("physical-contact", Vector3(0.0, 0.0, -2.8))
	await _verify_clear_case("normal-range", Vector3(0.0, 0.0, -8.0))
	await _verify_cover_blocks_fire()
	await _finish()

func _verify_clear_case(label: String, target_offset: Vector3) -> void:
	var stage := Node3D.new()
	stage.name = "Case_%s" % label
	root.add_child(stage)
	current_scene = stage
	var pair := await _spawn_pair(stage, target_offset)
	var shooter := pair[0] as AICharacter
	var target := pair[1] as AICharacter
	if shooter == null or target == null:
		_fail("%s characters must instantiate" % label)
		await _free_stage(stage)
		return

	if not bool(shooter.call("_has_line_of_sight_to_target")):
		_fail("%s must preserve line of sight at point-blank or normal range" % label)
	var shots := [0]
	shooter.weapon_manager.weapon_fired.connect(
		func(_weapon_data: WeaponData) -> void: shots[0] += 1
	)
	shooter.set("_reaction_timer", 0.0)
	shooter.call("_do_shoot", 1.0 / 60.0)
	if shots[0] < 1:
		_fail("%s must fire when the target is visible" % label)
	await _free_stage(stage)

func _verify_cover_blocks_fire() -> void:
	var stage := Node3D.new()
	stage.name = "Case_cover"
	root.add_child(stage)
	current_scene = stage
	var pair := await _spawn_pair(stage, Vector3(0.0, 0.0, -8.0))
	var shooter := pair[0] as AICharacter
	var target := pair[1] as AICharacter
	var cover := StaticBody3D.new()
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 4.0, 0.8)
	shape_node.shape = shape
	cover.add_child(shape_node)
	stage.add_child(cover)
	cover.global_position = Vector3(0.0, 1.5, -5.2)
	await physics_frame

	if bool(shooter.call("_has_line_of_sight_to_target")):
		_fail("cover must still block AI line of sight")
	var shots := [0]
	shooter.weapon_manager.weapon_fired.connect(
		func(_weapon_data: WeaponData) -> void: shots[0] += 1
	)
	shooter.set("_reaction_timer", 0.0)
	shooter.call("_do_shoot", 1.0 / 60.0)
	if shots[0] != 0:
		_fail("AI must not fire through cover")
	await _free_stage(stage)

func _spawn_pair(stage: Node3D, target_offset: Vector3) -> Array[AICharacter]:
	var shooter := AI_SCENE.instantiate() as AICharacter
	var target := AI_SCENE.instantiate() as AICharacter
	if shooter == null or target == null:
		return [shooter, target]
	shooter.name = "Shooter"
	target.name = "Target"
	stage.add_child(shooter)
	stage.add_child(target)
	await process_frame
	shooter.freeze = true
	target.freeze = true
	shooter.set_process(false)
	shooter.set_physics_process(false)
	target.set_process(false)
	target.set_physics_process(false)
	shooter.global_position = Vector3.ZERO
	target.global_position = target_offset
	shooter.set("_target", target)
	shooter.set("_state", AICharacter.State.SHOOT)
	await physics_frame
	return [shooter, target]

func _free_stage(stage: Node) -> void:
	if is_instance_valid(stage):
		stage.queue_free()
	await process_frame
	await physics_frame

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print("[AI Point-Blank Fire Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[AI Point-Blank Fire Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
