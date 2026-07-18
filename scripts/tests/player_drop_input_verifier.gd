extends SceneTree

const PLAYER_PREFIXES: Array[String] = ["p1_", "p2_", "p3_", "p4_"]

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Player Drop Input Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var player_scene := load("res://scenes/characters/player.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerCharacter if player_scene else null
	if player == null:
		_fail("Player scene must instantiate")
		await _finish(null)
		return
	stage.add_child(player)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.freeze = true

	for prefix in PLAYER_PREFIXES:
		player.input_prefix = prefix
		player.weapon_manager.equip_weapon(WeaponData.create_smg())
		if player.weapon_manager.current_weapon == player.weapon_manager.sidearm:
			_fail("%s must hold a primary before input testing" % prefix)

		var action: String = prefix + "drop_weapon"
		Input.action_press(action)
		player.call("_handle_weapon_input")
		Input.action_release(action)

		if player.weapon_manager.primary != null:
			_fail("%s drop input did not clear the primary slot" % prefix)
		if player.weapon_manager.current_weapon != player.weapon_manager.sidearm:
			_fail("%s drop input did not return to the pistol" % prefix)
		elif player.weapon_manager.current_weapon.weapon_data.weapon_id != &"pistol":
			_fail("%s drop input selected a non-pistol fallback" % prefix)
		await process_frame

	await _finish(player)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(player: Node) -> void:
	for prefix in PLAYER_PREFIXES:
		Input.action_release(prefix + "drop_weapon")
	if player and is_instance_valid(player):
		player.queue_free()
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("OK  Player 1-4 drop actions reach PlayerCharacter")
		print("OK  every primary is cleared and replaced by the pistol")
		print("[Player Drop Input Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Player Drop Input Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
