extends SceneTree

const PLAYER_SCENE := "res://scenes/characters/player.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Screen Relative Movement Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	var host := Node3D.new()
	host.name = "ScreenRelativeMovementHost"
	root.add_child(host)
	current_scene = host

	var camera := Camera3D.new()
	camera.name = "GlobalCamera"
	host.add_child(camera)
	camera.look_at_from_position(Vector3(40, 50, 55), Vector3(2, 0, 2), Vector3.UP)
	camera.current = true

	var player_scene := load(PLAYER_SCENE) as PackedScene
	if player_scene == null:
		_fail("Could not load %s" % PLAYER_SCENE)
		await _finish(host)
		return
	var player := player_scene.instantiate() as PlayerCharacter
	host.add_child(player)
	await process_frame

	if not player.has_method("_movement_direction_from_input"):
		_fail("PlayerCharacter should expose _movement_direction_from_input(input_dir) for screen-relative movement")
		await _finish(host)
		return

	var screen_up := _ground_project(camera.global_transform.basis.y)
	var screen_right := _ground_project(camera.global_transform.basis.x)

	_expect_direction(player, Vector2(0, -1), screen_up, "W should move toward screen up")
	_expect_direction(player, Vector2(0, 1), -screen_up, "S should move toward screen down")
	_expect_direction(player, Vector2(1, 0), screen_right, "D should move toward screen right")
	_expect_direction(player, Vector2(-1, 0), -screen_right, "A should move toward screen left")
	_expect_direction(player, Vector2(1, -1), (screen_right + screen_up).normalized(), "W+D should move diagonally up-right")

	await _finish(host)

func _expect_direction(player: PlayerCharacter, input_dir: Vector2, expected: Vector3, label: String) -> void:
	var actual := player.call("_movement_direction_from_input", input_dir) as Vector3
	if actual.length_squared() <= 0.0001:
		_fail("%s: got zero direction" % label)
		return
	var dot := actual.normalized().dot(expected.normalized())
	if dot < 0.985:
		_fail("%s: expected %s, got %s, dot %.3f" % [label, str(expected), str(actual), dot])
	else:
		print("OK  ", label)

func _ground_project(dir: Vector3) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return flat.normalized()

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(host: Node) -> void:
	if host and is_instance_valid(host):
		host.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)

	print("\n==================================================")
	if _failures.is_empty():
		print("[Screen Relative Movement Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Screen Relative Movement Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
