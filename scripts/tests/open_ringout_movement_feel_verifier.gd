extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"

var _failures: Array[String] = []
var _host: Node = null

func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	print("==================================================")
	print("[Open Ringout Movement Feel Verifier]")
	print("==================================================")

	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	_configure_minimal_roster()
	_host = Node.new()
	root.add_child(_host)

	var arena := scene.instantiate()
	_host.add_child(arena)

	await process_frame
	await process_frame

	_verify_ground_damping()
	_verify_air_damping_unchanged()

	await _finish()

func _configure_minimal_roster() -> void:
	var match_config = root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload missing")
		return
	match_config.slots = [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.EMPTY,
		match_config.SlotType.EMPTY,
	]

func _verify_ground_damping() -> void:
	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload missing")
		return
	var ground_damp := float(game_config.get("character_horizontal_damp"))
	if ground_damp >= 2.7:
		_fail("Open ring-out ground damping should be slightly lower than the previous 2.7, got %.2f" % ground_damp)
	elif ground_damp < 2.25 or ground_damp > 2.5:
		_fail("Open ring-out ground damping should stay in the controlled slight-reduction range 2.25-2.50, got %.2f" % ground_damp)
	else:
		print("OK  ground damping slight reduction: %.2f" % ground_damp)

func _verify_air_damping_unchanged() -> void:
	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		return
	var air_damp := float(game_config.get("character_air_horizontal_damp"))
	if absf(air_damp - 0.25) > 0.001:
		_fail("Air damping should remain 0.25 for the current aerial feel, got %.2f" % air_damp)
	else:
		print("OK  air damping unchanged: %.2f" % air_damp)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	if _host and is_instance_valid(_host):
		_host.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)

	print("\n==================================================")
	if _failures.is_empty():
		print("[Open Ringout Movement Feel Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Open Ringout Movement Feel Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
