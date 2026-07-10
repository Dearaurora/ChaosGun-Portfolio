extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Live Play HUD Verifier]")
	print("==================================================")

	var game_config = root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload missing")
		await _finish()
		return
	game_config.set_meta("feel_profile_id", "ringout_push")

	var hud_script = load("res://scripts/ui/game_hud.gd")
	if hud_script == null:
		_fail("Could not load GameHUD script")
		await _finish()
		return

	var host = Node3D.new()
	host.name = "HudVerifierHost"
	root.add_child(host)

	var hud = CanvasLayer.new()
	hud.set_script(hud_script)
	host.add_child(hud)
	await process_frame
	await process_frame

	if not hud.has_method("_get_active_profile_id"):
		_fail("GameHUD is missing _get_active_profile_id")
	elif String(hud.call("_get_active_profile_id")) != "ringout_push":
		_fail("GameHUD did not read active profile id")

	if hud.get("_profile_badge_label") == null:
		_fail("GameHUD did not create the profile badge label")
	else:
		var label = hud.get("_profile_badge_label") as Label
		if label == null or label.text != "FEEL: RINGOUT_PUSH":
			_fail("Unexpected profile badge text: %s" % (label.text if label else "<missing>"))

	host.queue_free()
	await process_frame
	await _finish()

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print("[Live Play HUD Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Live Play HUD Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
