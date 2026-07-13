extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Dodgeable Projectile Speed Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var scene := load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish(null)
		return

	var arena := scene.instantiate()
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var game_config := root.get_node_or_null("GameConfig")
	if game_config == null:
		_fail("GameConfig autoload missing")
		await _finish(arena)
		return

	var multiplier := float(game_config.get("bullet_speed_multiplier"))
	if multiplier < 0.85 or multiplier > 1.25:
		_fail("Open ring-out should use dodgeable projectile speed multiplier around 1.0, got %.2f" % multiplier)

	_verify_weapon_speed("pistol", WeaponData.create_pistol(), multiplier, 50.0, 85.0)
	_verify_weapon_speed("smg", WeaponData.create_smg(), multiplier, 45.0, 80.0)
	_verify_weapon_speed("ak_rifle", WeaponData.create_ak_rifle(), multiplier, 60.0, 100.0)
	_verify_weapon_speed("sniper", WeaponData.create_sniper(), multiplier, 100.0, 155.0)
	_verify_weapon_speed("gatling", WeaponData.create_gatling(), multiplier, 48.0, 82.0)
	_verify_weapon_speed("shotgun", WeaponData.create_shotgun(), multiplier, 52.0, 90.0)

	await _finish(arena)

func _verify_weapon_speed(label: String, data: WeaponData, multiplier: float, min_speed: float, max_speed: float) -> void:
	var actual := data.bullet_speed * multiplier
	if actual < min_speed or actual > max_speed:
		_fail("%s projectile speed should be dodge-readable, got %.2f; expected %.2f..%.2f" % [label, actual, min_speed, max_speed])
	else:
		print("OK  %s speed %.2f" % [label, actual])

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(arena: Node) -> void:
	if arena and is_instance_valid(arena):
		arena.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)

	print("\n==================================================")
	if _failures.is_empty():
		print("[Dodgeable Projectile Speed Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Dodgeable Projectile Speed Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
