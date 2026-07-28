extends SceneTree

## Render-capable production capture for Momentum Circuit.
##
## Example:
##   godot --path . --script res://scripts/tests/capture_momentum_circuit_arena.gd -- \
##     --mode=empty --mechanism=warning --width=1536 --height=1024 \
##     --output=res://reports/momentum_circuit_bridge_warning.png --settle=4.0

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const CAPTURE_MODES := ["empty", "battle"]
const MECHANISM_STATES := [
	"stable",
	"warning",
	"switching",
	"new_bridge",
	"teleport_empty",
	"teleport_half",
	"teleport_ready",
	"teleport_trail",
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
	var mechanism := _argument_value("--mechanism=", "stable").to_lower()
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
	var capture_id := _argument_value("--capture-id=", "")
	var run_id := _argument_value("--run-id=", "")
	if not capture_id.is_empty() and not run_id.is_empty() and _argument_value("--output=", "").is_empty():
		output_path = "res://reports/momentum_circuit_release_validation/%s/captures/%s.png" % [run_id, capture_id]
	if not output_path.to_lower().ends_with(".png"):
		_fail("Capture output must end in .png: %s" % output_path)
		return

	seed(20260718)
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	var safe_window_size := Vector2i(mini(viewport_size.x, 960), mini(viewport_size.y, 540))
	DisplayServer.window_set_size(safe_window_size)
	root.size = safe_window_size
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
	_advance_cloud_review(maxf(0.0, float(_argument_value("--cloud-time=", _argument_value("--cloud-advance=", "0.0")))))

	if not _drive_mechanism(mechanism):
		return
	await process_frame
	await process_frame

	# Forward+ may need several frames to compile the imported foreground and
	# cloud materials. A time-based settle is more stable than a fixed frame count.
	await create_timer(settle_seconds).timeout
	await process_frame
	await process_frame
	if mechanism == "teleport_trail":
		_stage_teleport_trail()
		await process_frame
		await process_frame
	var weapon_id := _argument_value("--weapon=", "")
	if not weapon_id.is_empty():
		if not _stage_weapon_review(weapon_id):
			return
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
	var manifest_entry := _argument_value("--manifest-entry=", "")
	if not manifest_entry.is_empty():
		var entry := {
			"id": capture_id,
			"run_id": run_id,
			"mode": mode,
			"mechanism": mechanism,
			"phase_progress": float(_argument_value("--phase-progress=", "0.0")),
			"cloud_time_seconds": float(_argument_value("--cloud-time=", _argument_value("--cloud-advance=", "0.0"))),
			"framing": _argument_value("--framing=", "overview"),
			"weapon_id": _argument_value("--weapon=", ""),
			"output_path": output_path,
			"sha256": FileAccess.get_sha256(output_path),
			"width": image.get_width(),
			"height": image.get_height(),
		}
		var entry_absolute := _absolute_path(manifest_entry)
		DirAccess.make_dir_recursive_absolute(entry_absolute.get_base_dir())
		var entry_file := FileAccess.open(manifest_entry, FileAccess.WRITE)
		if entry_file == null:
			_fail("Could not write capture manifest entry: %s" % manifest_entry)
			return
		entry_file.store_string(JSON.stringify(entry, "\t"))

	print("MOMENTUM_CIRCUIT_ARENA_CAPTURE_OK|mode=%s|mechanism=%s|width=%d|height=%d|path=%s" % [
		mode,
		mechanism,
		image.get_width(),
		image.get_height(),
		absolute_output,
	])
	if is_instance_valid(_capture_viewport):
		_capture_viewport.queue_free()
	_capture_viewport = null
	_arena = null
	await process_frame
	await process_frame
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
		_arena.call("get_light_bridge_controller")
		if _arena.has_method("get_light_bridge_controller")
		else null
	)
	if _controller == null or not is_instance_valid(_controller):
		_fail("Production light-bridge controller is missing")
		return false
	if not _controller.has_method("test_step") \
		or not _controller.has_method("get_debug_state"):
		_fail("Light-bridge controller does not expose the production capture API")
		return false
	_controller.set_physics_process(false)
	var debug := _controller.call("get_debug_state") as Dictionary
	var phase := clampf(float(_argument_value("--phase-progress=", "0.0")), 0.0, 1.0)
	var active_remaining := maxf(0.0, float(debug.get("state_duration", 8.0)) - float(debug.get("state_elapsed", 0.0)))
	if target in ["teleport_empty", "teleport_half", "teleport_ready", "teleport_trail"]:
		_controller.call("test_step", active_remaining * 0.40)
		_stage_teleporter_cooldown(target)
		return _expect_mechanism_state("ACTIVE", "bridge_hole_02")
	match target:
		"stable":
			_controller.call("test_step", active_remaining * phase)
			return _expect_mechanism_state("ACTIVE", "bridge_hole_02")
		"warning":
			_controller.call("test_step", active_remaining)
			debug = _controller.call("get_debug_state") as Dictionary
			_controller.call("test_step", float(debug.get("state_duration", 2.0)) * phase)
			return _expect_mechanism_state("WARNING", "bridge_hole_02")
		"switching":
			_controller.call("test_step", active_remaining)
			debug = _controller.call("get_debug_state") as Dictionary
			_controller.call("test_step", float(debug.get("state_duration", 2.0)))
			debug = _controller.call("get_debug_state") as Dictionary
			_controller.call("test_step", float(debug.get("state_duration", 0.45)) * phase)
			return _expect_mechanism_state("SWITCHING", "bridge_hole_02")
		"new_bridge":
			_controller.call("test_step", active_remaining)
			debug = _controller.call("get_debug_state") as Dictionary
			_controller.call("test_step", float(debug.get("state_duration", 2.0)))
			debug = _controller.call("get_debug_state") as Dictionary
			_controller.call("test_step", float(debug.get("state_duration", 0.45)))
			return _expect_mechanism_state("ACTIVE", "bridge_hole_01")
	return false


func _stage_teleporter_cooldown(target: String) -> void:
	if not _arena.has_method("get_random_teleporters"):
		return
	var teleporters := _arena.call("get_random_teleporters") as Array
	for value: Variant in teleporters:
		var teleporter := value as Node
		if teleporter:
			teleporter.set_physics_process(false)
	if teleporters.is_empty() or target in ["teleport_ready", "teleport_trail"]:
		return
	var review_pad := teleporters[0] as Node
	review_pad.call("_begin_landing_cooldown")
	if target == "teleport_half":
		review_pad.call("test_step", 1.5)


func _stage_teleport_trail() -> void:
	var vfx := _arena.get_node_or_null("MechanismVFX/RotatingLightBridgeAndTeleportVFX")
	if vfx == null or not vfx.has_method("stage_review_teleport_trail"):
		_fail("v7 teleport trail review interface is missing")
		return
	if not bool(vfx.call("stage_review_teleport_trail", 0.40)):
		_fail("v7 teleport trail could not be staged")


func _stage_weapon_review(weapon_id: String) -> bool:
	var characters := _review_characters()
	if characters.is_empty():
		_fail("Weapon trajectory review requires a battle capture")
		return false
	var factories := {
		"pistol": WeaponData.create_pistol,
		"smg": WeaponData.create_smg,
		"ak_rifle": WeaponData.create_ak_rifle,
		"shotgun": WeaponData.create_shotgun,
		"gatling": WeaponData.create_gatling,
		"sniper": WeaponData.create_sniper,
	}
	if not factories.has(weapon_id):
		_fail("Unknown trajectory review weapon: %s" % weapon_id)
		return false
	var character := characters[0]
	if character.weapon_manager == null or character.weapon_point == null:
		_fail("Trajectory review character has no weapon manager/fire point")
		return false
	character.weapon_manager.equip_weapon((factories[weapon_id] as Callable).call())
	character.weapon_manager.is_switching = false
	var target := Vector3(12.0, character.weapon_point.global_position.y, -4.0)
	var direction := (
		target - character.weapon_point.global_position
	).normalized()
	if not character.weapon_manager.try_fire(character.weapon_point, direction, character):
		_fail("Trajectory review weapon did not fire: %s" % weapon_id)
		return false
	return true


func _expect_mechanism_state(expected_state: String, expected_bridge_id: String) -> bool:
	var debug := _controller.call("get_debug_state") as Dictionary
	var actual_state := String(debug.get("state", ""))
	var actual_bridge_id := String(debug.get("active_bridge_id", ""))
	if actual_state != expected_state or actual_bridge_id != expected_bridge_id:
		_fail("Mechanism staging mismatch: expected=%s/%s actual=%s/%s" % [
			expected_state, expected_bridge_id, actual_state, actual_bridge_id,
		])
		return false
	return true


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
	var expected_state := "ACTIVE"
	var expected_bridge := "bridge_hole_02"
	if mechanism == "warning":
		expected_state = "WARNING"
	elif mechanism == "switching":
		expected_state = "SWITCHING"
	elif mechanism == "new_bridge":
		expected_bridge = "bridge_hole_01"
	return _expect_mechanism_state(expected_state, expected_bridge)


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
