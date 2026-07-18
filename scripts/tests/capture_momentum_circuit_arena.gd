extends SceneTree

## Render-capable production capture for Momentum Circuit.
##
## Example:
##   godot --path . --script res://scripts/tests/capture_momentum_circuit_arena.gd -- \
##     --mode=empty --mechanism=active_plus --width=1536 --height=1024 \
##     --output=res://reports/momentum_circuit_active_plus.png --settle=4.0

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const CAPTURE_MODES := ["empty", "battle"]
const MECHANISM_STATES := [
	"idle",
	"warning",
	"active_plus",
	"reversing",
	"active_minus",
	"recovery",
]

var _arena: Node3D = null
var _controller: Node = null
var _capture_viewport: SubViewport = null


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Momentum Circuit production capture requires a render-capable display driver")
		return
	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene is missing: %s" % SCENE_PATH)
		return

	var mode := _argument_value("--mode=", "empty").to_lower()
	var mechanism := _argument_value("--mechanism=", "idle").to_lower()
	if mode not in CAPTURE_MODES:
		_fail("Unknown mode '%s'; expected empty or battle" % mode)
		return
	if mechanism not in MECHANISM_STATES:
		_fail("Unknown mechanism state '%s'; expected %s" % [mechanism, MECHANISM_STATES])
		return

	var default_size := Vector2i(1536, 1024) if mode == "empty" else Vector2i(1920, 1080)
	var viewport_size := Vector2i(
		maxi(320, int(_argument_value("--width=", str(default_size.x)))),
		maxi(180, int(_argument_value("--height=", str(default_size.y))))
	)
	var settle_seconds := maxf(0.2, float(_argument_value("--settle=", "4.0")))
	var output_path := _argument_value(
		"--output=",
		_default_output_path(mode, mechanism, viewport_size)
	)
	if not output_path.to_lower().ends_with(".png"):
		_fail("Capture output must end in .png: %s" % output_path)
		return

	seed(20260718)
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_position(Vector2i.ZERO)
	DisplayServer.window_set_size(viewport_size)
	var test_window_policy := root.get_node_or_null("TestWindowPolicy")
	if test_window_policy != null and test_window_policy.has_method("enforce_now"):
		test_window_policy.call("enforce_now")
	if not _configure_slots(mode):
		return
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "MomentumCircuitCaptureViewport"
	_capture_viewport.size = viewport_size
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_capture_viewport.own_world_3d = true
	root.add_child(_capture_viewport)

	var packed := load(SCENE_PATH) as PackedScene
	_arena = packed.instantiate() as Node3D if packed else null
	if _arena == null:
		_fail("Could not instantiate %s" % SCENE_PATH)
		return
	_capture_viewport.add_child(_arena)

	# Let the arena build its authoritative gameplay tree, imported foreground,
	# cloud vortex, dynamic VFX, camera, characters, and HUD before isolation.
	await process_frame
	await process_frame
	await physics_frame
	if mode == "empty":
		_isolate_empty_capture()
	else:
		_prepare_battle_capture()
	await process_frame
	await physics_frame
	_advance_cloud_review(maxf(0.0, float(_argument_value("--cloud-advance=", "0.0"))))

	if not _drive_mechanism(mechanism):
		return
	await process_frame
	await process_frame

	# Forward+ may need several frames to compile the imported foreground and
	# cloud materials. A time-based settle is more stable than a fixed frame count.
	await create_timer(settle_seconds).timeout
	await process_frame
	await process_frame
	if not _verify_capture_contract(mode, mechanism, viewport_size):
		return

	var image := _capture_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Viewport screenshot image is empty")
		return
	if image.get_width() != viewport_size.x or image.get_height() != viewport_size.y:
		_fail("Capture size mismatch: image=%dx%d requested=%dx%d" % [
			image.get_width(), image.get_height(), viewport_size.x, viewport_size.y,
		])
		return

	var absolute_output := _absolute_path(output_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	if directory_error != OK:
		_fail("Could not create output directory for %s (error %d)" % [
			absolute_output, directory_error,
		])
		return
	var save_error := image.save_png(absolute_output)
	if save_error != OK:
		_fail("Could not save screenshot %s (error %d)" % [absolute_output, save_error])
		return

	print("MOMENTUM_CIRCUIT_ARENA_CAPTURE_OK|mode=%s|mechanism=%s|width=%d|height=%d|path=%s" % [
		mode,
		mechanism,
		image.get_width(),
		image.get_height(),
		absolute_output,
	])
	quit(0)


func _configure_slots(mode: String) -> bool:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		return false
	if mode == "battle":
		match_config.slots = [
			match_config.SlotType.HUMAN,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
		]
	else:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]
	return true


func _advance_cloud_review(seconds: float) -> void:
	if seconds <= 0.0:
		return
	for node: Node in get_nodes_in_group(&"momentum_circuit_cloud_vortex"):
		if node.has_method("advance_motion"):
			node.call("advance_motion", seconds)


func _isolate_empty_capture() -> void:
	for node: Node in _walk(_arena):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
		if node is WeaponSpawner:
			var spawner := node as WeaponSpawner
			spawner.max_active_pickups = 0
			spawner.set_process(false)
			spawner.set_physics_process(false)
		if node is WeaponPickup or node is WeaponSpawnPedestal or node.is_in_group(&"weapon_pickup"):
			node.queue_free()
		if node is BaseCharacter and not node is CloneCharacter:
			node.queue_free()


func _prepare_battle_capture() -> void:
	_hide_review_overlays()
	var characters := _review_characters()
	if characters.size() != 4:
		_fail("Battle capture requires four characters, got %d" % characters.size())
		return
	var spawn_points: Array = (
		_arena.call("_get_spawn_points")
		if _arena.has_method("_get_spawn_points")
		else []
	)
	var weapon_factories: Array[Callable] = [
		WeaponData.create_pistol,
		WeaponData.create_smg,
		WeaponData.create_shotgun,
		WeaponData.create_gatling,
	]
	for index in range(characters.size()):
		var character := characters[index]
		var spawn := (
			spawn_points[index] as Vector3
			if index < spawn_points.size()
			else character.global_position
		)
		# Pull actors slightly toward the center so their silhouettes read clearly
		# while preserving the authored four-quadrant spawn composition.
		spawn.x *= 0.88
		spawn.z *= 0.88
		character.set_process(false)
		character.set_physics_process(false)
		character.set_process_input(false)
		character.set_process_unhandled_input(false)
		character.freeze = true
		character.is_dead = false
		character.is_game_over = false
		character.visible = true
		character.linear_velocity = Vector3.ZERO
		character.angular_velocity = Vector3.ZERO
		character.global_position = spawn
		character.look_at(Vector3(8.0, spawn.y, -2.0), Vector3.UP)
		character.reset_physics_interpolation()
		if character.weapon_manager:
			var weapon := weapon_factories[index].call() as WeaponData
			if weapon:
				character.weapon_manager.equip_weapon(weapon)


func _drive_mechanism(target: String) -> bool:
	_controller = (
		_arena.call("get_gravity_controller")
		if _arena.has_method("get_gravity_controller")
		else null
	)
	if _controller == null or not is_instance_valid(_controller):
		_fail("Production gravity controller is missing")
		return false
	if not _controller.has_method("request_toggle") \
		or not _controller.has_method("test_step") \
		or not _controller.has_method("get_debug_state"):
		_fail("Gravity controller does not expose the production capture API")
		return false
	_controller.set_physics_process(false)

	if target == "idle":
		return _expect_mechanism_state("idle", 0)
	var activator := _first_activator()
	if activator == null:
		_fail("No shootable gravity activator is available")
		return false
	if not bool(_controller.call("request_toggle", activator, null)):
		_fail("Controller rejected the first capture activation")
		return false
	if target == "warning":
		return _expect_mechanism_state("warning", 0)

	var debug := _controller.call("get_debug_state") as Dictionary
	_controller.call("test_step", float(debug.get("warning_seconds", 1.25)) + 0.001)
	if target == "active_plus":
		return _expect_mechanism_state("active", 1)
	if target == "recovery":
		debug = _controller.call("get_debug_state") as Dictionary
		_controller.call("test_step", float(debug.get("active_seconds", 4.0)) + 0.001)
		return _expect_mechanism_state("recovery", 1)

	# The first warning is longer than the global guard, so a second successful
	# public request now enters the real reversing branch and requests -X.
	var reversal_activator := _activator_by_number(2)
	if reversal_activator == null:
		_fail("Second gravity activator is unavailable for the reversal capture")
		return false
	if not bool(_controller.call("request_toggle", reversal_activator, null)):
		_fail("Controller rejected the reversal capture activation")
		return false
	if target == "reversing":
		return _expect_mechanism_state("reversing", 1)
	debug = _controller.call("get_debug_state") as Dictionary
	_controller.call("test_step", float(debug.get("reversing_seconds", 0.65)) + 0.001)
	return _expect_mechanism_state("active", -1)


func _expect_mechanism_state(expected_state: String, expected_direction: int) -> bool:
	var debug := _controller.call("get_debug_state") as Dictionary
	var actual_state := String(debug.get("state", ""))
	var actual_direction := int(debug.get("direction", 0))
	if actual_state != expected_state or actual_direction != expected_direction:
		_fail("Mechanism staging mismatch: expected=%s/%d actual=%s/%d" % [
			expected_state, expected_direction, actual_state, actual_direction,
		])
		return false
	return true


func _first_activator() -> Node3D:
	return _activator_by_number(1)


func _activator_by_number(number: int) -> Node3D:
	var expected_name := "GravityActivator%02d" % number
	var named := _arena.find_child(expected_name, true, false) if _arena else null
	if named is Node3D and is_instance_valid(named):
		return named as Node3D
	var candidates := get_nodes_in_group(&"momentum_circuit_gravity_activator")
	for index in range(candidates.size()):
		if index != number - 1:
			continue
		var candidate := candidates[index] as Node
		if candidate is Node3D and is_instance_valid(candidate):
			return candidate as Node3D
	return null


func _verify_capture_contract(mode: String, mechanism: String, viewport_size: Vector2i) -> bool:
	if _capture_viewport == null or _capture_viewport.size != viewport_size:
		_fail("Capture viewport size drifted")
		return false
	var camera := _capture_viewport.get_camera_3d()
	if camera == null or not camera.current:
		_fail("Production capture has no active camera")
		return false
	var character_count := _review_characters().size()
	if mode == "empty" and character_count != 0:
		_fail("Empty capture still contains %d characters" % character_count)
		return false
	if mode == "battle" and character_count != 4:
		_fail("Battle capture lost characters during settle: %d" % character_count)
		return false
	var expected_state := mechanism
	if mechanism in ["active_plus", "active_minus"]:
		expected_state = "active"
	var expected_direction := 0
	if mechanism in ["active_plus", "reversing", "recovery"]:
		expected_direction = 1
	elif mechanism == "active_minus":
		expected_direction = -1
	return _expect_mechanism_state(expected_state, expected_direction)


func _review_characters() -> Array[BaseCharacter]:
	var result: Array[BaseCharacter] = []
	if _arena == null:
		return result
	for node: Node in _walk(_arena):
		if node is BaseCharacter and not node is CloneCharacter and not node.is_queued_for_deletion():
			result.append(node as BaseCharacter)
	return result


func _hide_review_overlays() -> void:
	for node_name in ["ControlModeReviewPanel", "VictoryScreen", "DebugOverlay"]:
		var item := _arena.find_child(node_name, true, false) as CanvasItem
		if item:
			item.visible = false


func _walk(search_root: Node) -> Array[Node]:
	var nodes: Array[Node] = [search_root]
	for child: Node in search_root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _default_output_path(mode: String, mechanism: String, viewport_size: Vector2i) -> String:
	return "res://reports/momentum_circuit_%s_%s_%dx%d.png" % [
		mode, mechanism, viewport_size.x, viewport_size.y,
	]


func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path.simplify_path()


func _fail(message: String) -> void:
	push_error("MOMENTUM_CIRCUIT_ARENA_CAPTURE_FAIL %s" % message)
	print("MOMENTUM_CIRCUIT_ARENA_CAPTURE_ERROR|message=%s" % message.replace("|", "/"))
	quit(1)
