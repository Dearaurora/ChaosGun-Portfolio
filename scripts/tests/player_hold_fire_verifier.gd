extends SceneTree

var _failures: Array[String] = []
var _shots := 0

func _initialize() -> void:
	print("==================================================")
	print("[Player Hold Fire Verifier]")
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
	player.input_prefix = "p2_"
	stage.add_child(player)
	await process_frame
	player.set_process(false)
	player.freeze = true
	player.weapon_manager.weapon_fired.connect(func(_weapon_data: WeaponData): _shots += 1)

	Input.action_press("p2_fire")
	player.call("_handle_fire_input")
	if _shots != 1:
		_fail("P2 fire press should shoot the base pistol once")
	await process_frame
	player.weapon_manager.current_weapon.fire_cooldown = 0.0
	player.call("_handle_fire_input")
	if _shots != 2:
		_fail("P2 held fire must request another shot across frames without key release")
	Input.action_release("p2_fire")
	await process_frame
	player.weapon_manager.current_weapon.fire_cooldown = 0.0
	player.call("_handle_fire_input")
	if _shots != 2:
		_fail("P2 releasing fire must stop repeated shots")
	await _finish(player)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(player: Node) -> void:
	Input.action_release("p2_fire")
	if player and is_instance_valid(player):
		player.queue_free()
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[Player Hold Fire Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Player Hold Fire Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
