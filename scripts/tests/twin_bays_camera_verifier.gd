extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const PartyShooterCameraDirectorScript = preload("res://scripts/maps/party_shooter_camera_director.gd")
const TEST_VIEWPORT_SIZE := Vector2i(1280, 720)
const CAMERA_OCCLUDER_GROUP := &"party_shooter_camera_occluder"
const CLUSTER_POSITIONS := [
	Vector3(-4.0, 1.1, -3.0),
	Vector3(4.0, 1.1, -3.0),
	Vector3(-4.0, 1.1, 4.0),
	Vector3(4.0, 1.1, 4.0),
]
const LEFT_PORTAL_FIGHT := [
	Vector3(-47.0, 1.1, -8.0),
	Vector3(-43.0, 1.1, -7.0),
	Vector3(-46.0, 1.1, -2.5),
	Vector3(-42.0, 1.1, -1.5),
]
const RIGHT_PORTAL_FIGHT := [
	Vector3(47.0, 1.1, -8.0),
	Vector3(43.0, 1.1, -7.0),
	Vector3(46.0, 1.1, -2.5),
	Vector3(42.0, 1.1, -1.5),
]
const FOUR_WAY_SPREAD := [
	Vector3(-43.0, 1.1, -20.0),
	Vector3(43.0, 1.1, -20.0),
	Vector3(-43.0, 1.1, 20.0),
	Vector3(43.0, 1.1, 20.0),
]

var _failures: Array[String] = []
var _arena: Node = null


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	root.size = TEST_VIEWPORT_SIZE
	_configure_roster()

	var packed := load(SCENE_PATH) as PackedScene
	var arena := packed.instantiate() if packed else null
	_arena = arena
	if arena == null:
		_fail("Could not instantiate Twin Bays production scene")
		await _finish()
		return
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var director := arena.get_node_or_null("TwinBaysCameraDirector")
	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	var characters := arena.get("_characters") as Array
	if director == null or camera == null or characters.size() != 4:
		_fail("Twin Bays camera verifier requires a director, camera, and four characters")
		await _finish()
		return
	var left_portal := arena.find_child("LeftPortal", true, false) as TwinBaysPortal
	var right_portal := arena.find_child("RightPortal", true, false) as TwinBaysPortal
	var portal_camera_callback := Callable(arena, "_on_twin_bays_character_teleported")
	if left_portal == null or right_portal == null \
		or not left_portal.character_teleported.is_connected(portal_camera_callback) \
		or not right_portal.character_teleported.is_connected(portal_camera_callback):
		_fail("Twin Bays portal signal is not connected to the shared camera director")
	else:
		print("OK  portal transfer signal drives the shared camera discontinuity guard")

	for item in characters:
		var character := item as BaseCharacter
		character.freeze = true
		character.linear_velocity = Vector3.ZERO
		character.process_mode = Node.PROCESS_MODE_DISABLED

	var initial_state := arena.call("get_runtime_camera_debug") as Dictionary
	_verify_profile_and_tilt(initial_state, camera)
	var authored_basis := camera.transform.basis

	_stage(characters, CLUSTER_POSITIONS)
	_step_camera(arena, 180)
	var cluster_state := arena.call("get_runtime_camera_debug") as Dictionary
	var cluster_size := float(cluster_state.get("current_size", 0.0))
	if int(cluster_state.get("tracked_count", 0)) != 4:
		_fail("Twin Bays director must track four live combatants")
	if cluster_size < 43.5 or cluster_size > 46.0:
		_fail("Clustered Twin Bays combat should retain a close follow view, got %.2f" % cluster_size)
	else:
		print("OK  Twin Bays clustered combat zoom: %.2f" % cluster_size)
	_verify_live_hud_regions(cluster_state, "1280x720")

	_stage(characters, LEFT_PORTAL_FIGHT)
	_step_camera(arena, 180)
	_verify_portal_transition(
		arena, director, camera, characters,
		left_portal, right_portal,
		LEFT_PORTAL_FIGHT, RIGHT_PORTAL_FIGHT,
		"left-to-right"
	)
	_verify_portal_transition(
		arena, director, camera, characters,
		right_portal, left_portal,
		RIGHT_PORTAL_FIGHT, LEFT_PORTAL_FIGHT,
		"right-to-left"
	)

	_stage(characters, FOUR_WAY_SPREAD)
	_step_camera(arena, 240)
	var spread_state := arena.call("get_runtime_camera_debug") as Dictionary
	var spread_size := float(spread_state.get("current_size", 0.0))
	if spread_size < cluster_size + 18.0:
		_fail("Four-way Twin Bays spread should pull back: cluster %.2f spread %.2f" % [cluster_size, spread_size])
	elif spread_size > float(spread_state.get("max_size", 0.0)) + 0.1:
		_fail("Twin Bays spread exceeded configured maximum: %.2f" % spread_size)
	else:
		print("OK  Twin Bays four-way overview zoom: %.2f" % spread_size)
	_verify_points_hud_safe(director, characters, "four-way spread")
	_verify_portal_mouth_readability(arena, camera, TEST_VIEWPORT_SIZE)

	var ignored := characters[0] as BaseCharacter
	ignored.is_dead = true
	ignored.global_position = Vector3(-200.0, -20.0, 200.0)
	_step_camera(arena, 1)
	var ignored_state := arena.call("get_runtime_camera_debug") as Dictionary
	if int(ignored_state.get("tracked_count", 0)) != 3:
		_fail("Dead/falling Twin Bays characters must be excluded from camera framing")
	else:
		print("OK  dead/falling Twin Bays character ignored")
	ignored.is_dead = false

	root.size = Vector2i(1920, 1080)
	_stage(characters, FOUR_WAY_SPREAD)
	_step_camera(arena, 120)
	var wide_state := arena.call("get_runtime_camera_debug") as Dictionary
	var viewport_size := wide_state.get("viewport_size", Vector2.ZERO) as Vector2
	if viewport_size.distance_to(Vector2(1920.0, 1080.0)) > 1.0:
		_fail("Director did not adopt the 1920x1080 viewport: %s" % viewport_size)
	_verify_live_hud_regions(wide_state, "1920x1080")
	_verify_points_hud_safe(director, characters, "1920x1080 spread")

	if not camera.transform.basis.is_equal_approx(authored_basis):
		_fail("Camera follow changed the authored Twin Bays viewing angle")
	else:
		print("OK  follow preserves the authored tilted basis")

	await _finish()


func _verify_profile_and_tilt(state: Dictionary, camera: Camera3D) -> void:
	if String(state.get("profile_id", "")) != "twin_bays_splash_arena":
		_fail("Twin Bays did not install its shared camera profile")
	var offset := state.get("view_offset", Vector3.ZERO) as Vector3
	var expected := PartyShooterCameraDirectorScript.view_offset_with_standard_pitch(0.0, 64.0) as Vector3
	if not offset.is_equal_approx(expected):
		_fail("Twin Bays must preserve its centered horizontal view %s, got %s" % [expected, offset])
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_fail("Twin Bays party camera must remain orthographic")
	var expected_forward := -expected.normalized()
	var actual_forward := -camera.global_transform.basis.z.normalized()
	if actual_forward.dot(expected_forward) < 0.999999:
		_fail("Twin Bays camera direction drifted from its authored yaw: %.8f" % actual_forward.dot(expected_forward))
	else:
		var pitch := PartyShooterCameraDirectorScript.downward_pitch_degrees(offset)
		var standard_pitch := float(PartyShooterCameraDirectorScript.STANDARD_GAMEPLAY_DOWNWARD_PITCH_DEGREES)
		if absf(pitch - standard_pitch) > 0.0001:
			_fail("Twin Bays downward pitch must match Open Ring-Out: %.8f vs %.8f" % [pitch, standard_pitch])
		else:
			print("OK  centered Twin Bays yaw with shared %.6f-degree downward pitch: %s" % [pitch, offset])


func _verify_portal_mouth_readability(arena: Node, camera: Camera3D, viewport_size: Vector2i) -> void:
	var layout := arena.call("get_twin_bays_layout") as Dictionary
	var safe_rect := Rect2(Vector2(8.0, 8.0), Vector2(viewport_size) - Vector2(16.0, 16.0))
	for portal_value: Variant in layout.get("portals", []):
		var portal_data := portal_value as Dictionary
		var node_name := String(portal_data.get("node_name", ""))
		var portal := arena.find_child(node_name, true, false) as Node3D
		var foam := portal.find_child("PortalFoamRim", true, false) as MeshInstance3D if portal else null
		if portal == null or foam == null:
			_fail("Portal readability probe is missing production foam geometry: %s" % node_name)
			continue

		var normal_values := portal_data.get("normal", []) as Array
		var normal := Vector3(
			float(normal_values[0]),
			float(normal_values[1]),
			float(normal_values[2])
		).normalized()
		var to_camera := camera.global_position - portal.global_position
		to_camera.y = 0.0
		to_camera = to_camera.normalized()
		var facing := normal.dot(to_camera)
		if facing < 0.55:
			_fail("Portal mouth is too oblique to communicate the pair: %s facing=%.3f" % [node_name, facing])

		var screen_rect := _mesh_screen_rect(camera, foam, Vector2(viewport_size))
		var min_width := maxf(14.0, float(viewport_size.x) * 0.01)
		var min_height := float(viewport_size.y) * 0.05
		var aspect := screen_rect.size.x / maxf(screen_rect.size.y, 0.001)
		if screen_rect.size.x < min_width or screen_rect.size.y < min_height or aspect < 0.25:
			_fail("Portal mouth is not readable on screen: %s rect=%s aspect=%.3f" % [
				node_name, screen_rect, aspect,
			])
		elif not safe_rect.encloses(screen_rect):
			_fail("Portal mouth is clipped by the four-way gameplay frame: %s rect=%s" % [node_name, screen_rect])
		else:
			print("OK  readable portal mouth: %s rect=%s facing=%.3f" % [node_name, screen_rect, facing])


func _mesh_screen_rect(camera: Camera3D, mesh_instance: MeshInstance3D, target_viewport: Vector2) -> Rect2:
	var aabb := mesh_instance.get_aabb()
	var end := aabb.position + aabb.size
	var screen_min := Vector2(INF, INF)
	var screen_max := Vector2(-INF, -INF)
	var aspect := target_viewport.x / maxf(target_viewport.y, 1.0)
	var screen_right := camera.global_transform.basis.x.normalized()
	var screen_up := camera.global_transform.basis.y.normalized()
	for x in [aabb.position.x, end.x]:
		for y in [aabb.position.y, end.y]:
			for z in [aabb.position.z, end.z]:
				var world_point := mesh_instance.global_transform * Vector3(x, y, z)
				if camera.is_position_behind(world_point):
					return Rect2()
				var camera_offset := world_point - camera.global_position
				var screen_point := Vector2(
					(0.5 + camera_offset.dot(screen_right) / (camera.size * aspect)) * target_viewport.x,
					(0.5 - camera_offset.dot(screen_up) / camera.size) * target_viewport.y
				)
				screen_min.x = minf(screen_min.x, screen_point.x)
				screen_min.y = minf(screen_min.y, screen_point.y)
				screen_max.x = maxf(screen_max.x, screen_point.x)
				screen_max.y = maxf(screen_max.y, screen_point.y)
	return Rect2(screen_min, screen_max - screen_min)


func _verify_portal_transition(
	arena: Node,
	director: Node,
	camera: Camera3D,
	characters: Array,
	from_portal: TwinBaysPortal,
	to_portal: TwinBaysPortal,
	from_positions: Array,
	to_positions: Array,
	label: String
) -> void:
	var positions := from_positions.duplicate()
	_stage(characters, positions)
	_step_camera(arena, 180)
	var before := arena.call("get_runtime_camera_debug") as Dictionary
	var previous_focus := before.get("current_focus", Vector3.ZERO) as Vector3
	var previous_size := float(before.get("current_size", 0.0))
	var previous_screen_speed := 0.0
	var event_serial_before := int(before.get("discontinuity_event_serial", 0))
	var first_frame_focus_delta := -1.0
	var max_world_step := 0.0
	var max_screen_step := 0.0
	var max_screen_speed := 0.0
	var max_screen_acceleration := 0.0
	var hold_frames := 0
	var shrank_while_active := false
	var transition_target := Vector3.ZERO
	var target_captured := false
	var error_at_half_second := -1.0
	var error_at_one_quarter_seconds := -1.0
	var last_event_frame := (characters.size() - 1) * 3

	for frame in range(150):
		var event_index := int(frame / 3) if frame % 3 == 0 else -1
		if event_index >= 0 and event_index < characters.size():
			positions[event_index] = to_positions[event_index]
			_stage(characters, positions)
			from_portal.character_teleported.emit(
				characters[event_index] as BaseCharacter,
				from_portal,
				to_portal
			)

		_step_camera(arena, 1)
		var state := arena.call("get_runtime_camera_debug") as Dictionary
		var focus := state.get("current_focus", Vector3.ZERO) as Vector3
		var size := float(state.get("current_size", 0.0))
		var phase := String(state.get("discontinuity_phase", "idle"))
		var world_step := focus - previous_focus
		var screen_step_world := Vector2(
			world_step.dot(camera.global_transform.basis.x.normalized()),
			world_step.dot(camera.global_transform.basis.y.normalized())
		)
		var screen_step := screen_step_world.length() * float(TEST_VIEWPORT_SIZE.y) / maxf(size, 0.001)
		var screen_speed := screen_step * 60.0
		max_world_step = maxf(max_world_step, world_step.length())
		max_screen_step = maxf(max_screen_step, screen_step)
		max_screen_speed = maxf(max_screen_speed, screen_speed)
		max_screen_acceleration = maxf(
			max_screen_acceleration,
			absf(screen_speed - previous_screen_speed) * 60.0
		)
		if frame == 0:
			first_frame_focus_delta = world_step.length()
		if phase == "hold":
			hold_frames += 1
		if phase != "idle" and size < previous_size - 0.05:
			shrank_while_active = true
		if frame in [0, last_event_frame]:
			_verify_points_hud_safe(director, characters, "%s portal event frame %d" % [label, frame])
		if frame == last_event_frame:
			_verify_portal_mouth_readability(arena, camera, TEST_VIEWPORT_SIZE)
		if frame > last_event_frame and phase == "recover" and not target_captured:
			transition_target = state.get("target_focus", Vector3.ZERO) as Vector3
			target_captured = true
		if target_captured and frame == last_event_frame + 30:
			error_at_half_second = focus.distance_to(transition_target)
		if target_captured and frame == last_event_frame + 75:
			error_at_one_quarter_seconds = focus.distance_to(transition_target)

		previous_focus = focus
		previous_size = size
		previous_screen_speed = screen_speed

	var final_state := arena.call("get_runtime_camera_debug") as Dictionary
	var final_focus := final_state.get("current_focus", Vector3.ZERO) as Vector3
	var final_target := final_state.get("target_focus", Vector3.ZERO) as Vector3
	var final_phase := String(final_state.get("discontinuity_phase", "idle"))
	var expected_serial := event_serial_before + characters.size()
	var max_allowed_screen_speed := float(TEST_VIEWPORT_SIZE.y) \
		* float(PartyShooterCameraDirectorScript.DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND) + 6.0
	var max_allowed_screen_acceleration := float(TEST_VIEWPORT_SIZE.y) \
		* float(PartyShooterCameraDirectorScript.DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND_SQUARED) + 50.0

	if int(final_state.get("discontinuity_event_serial", 0)) != expected_serial:
		_fail("%s portal events were not consumed exactly once" % label)
	if first_frame_focus_delta < 0.0 or first_frame_focus_delta > 0.05:
		_fail("%s portal transition moved focus on its safety frame: %.4f" % [label, first_frame_focus_delta])
	if hold_frames < 6 or hold_frames > 15:
		_fail("%s portal hold duration is outside 0.10-0.25s: %d frames" % [label, hold_frames])
	if max_screen_speed > max_allowed_screen_speed:
		_fail("%s portal pan exceeded screen-speed cap: %.2f > %.2f px/s" % [
			label, max_screen_speed, max_allowed_screen_speed,
		])
	if max_screen_acceleration > max_allowed_screen_acceleration:
		_fail("%s portal pan exceeded acceleration cap: %.2f > %.2f px/s^2" % [
			label, max_screen_acceleration, max_allowed_screen_acceleration,
		])
	if shrank_while_active:
		_fail("%s portal safety view shrank before focus recovery finished" % label)
	if not target_captured:
		_fail("%s portal transition never entered recovery" % label)
	if final_phase != "idle":
		_fail("%s portal transition did not return to normal follow: %s" % [label, final_phase])
	if final_focus.distance_to(final_target) > 0.5:
		_fail("%s portal transition did not settle: %.3f" % [label, final_focus.distance_to(final_target)])
	if error_at_half_second < 0.0 or error_at_one_quarter_seconds < 0.0:
		_fail("%s portal recovery checkpoints were not sampled" % label)
	elif error_at_one_quarter_seconds >= error_at_half_second:
		_fail("%s portal recovery did not make monotonic progress: %.2f -> %.2f" % [
			label, error_at_half_second, error_at_one_quarter_seconds,
		])
	else:
		print(
			"OK  %s portal camera: first=%.3fu hold=%df max=%.2fu/%.2fpx %.1fpx/s accel=%.1fpx/s^2 errors=%.2f->%.2f" % [
				label,
				first_frame_focus_delta,
				hold_frames,
				max_world_step,
				max_screen_step,
				max_screen_speed,
				max_screen_acceleration,
				error_at_half_second,
				error_at_one_quarter_seconds,
			]
		)


func _configure_roster() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.HUMAN,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
			match_config.SlotType.AI,
		]


func _stage(characters: Array, positions: Array) -> void:
	for index in range(mini(characters.size(), positions.size())):
		var character := characters[index] as BaseCharacter
		character.is_dead = false
		character.is_game_over = false
		character.global_position = positions[index] as Vector3
		character.linear_velocity = Vector3.ZERO


func _step_camera(arena: Node, frame_count: int) -> void:
	for _frame in range(frame_count):
		arena.call("_update_map_runtime_camera", 1.0 / 60.0)


func _verify_points_hud_safe(director: Node, characters: Array, label: String) -> void:
	for index in range(characters.size()):
		var character := characters[index] as BaseCharacter
		if bool(director.call("is_world_point_hud_occluded", character.global_position)):
			_fail("%s leaves character %d outside the HUD-safe frame" % [label, index + 1])
			return
	print("OK  %s keeps all characters HUD-safe" % label)


func _verify_live_hud_regions(state: Dictionary, label: String) -> void:
	var controls: Array[Control] = []
	for node in get_nodes_in_group(CAMERA_OCCLUDER_GROUP):
		var control := node as Control
		if control and control.is_visible_in_tree():
			controls.append(control)
	var regions := state.get("hud_occlusion_regions", []) as Array
	if controls.is_empty() or regions.size() != controls.size():
		_fail("%s live HUD controls do not match director regions: %d controls / %d regions" % [
			label, controls.size(), regions.size(),
		])
		return
	for control in controls:
		var enclosed := false
		for region_variant: Variant in regions:
			if (region_variant as Rect2).encloses(control.get_global_rect()):
				enclosed = true
				break
		if not enclosed:
			_fail("%s director region does not enclose live HUD control %s" % [label, control.name])
			return
	if label == "1920x1080":
		var ai_panel := root.find_child("AIStatusPanel", true, false) as Control
		if ai_panel == null or ai_panel.position.x < 1500.0:
			_fail("Legacy HUD did not relayout after the 1920x1080 resize")
			return
	print("OK  %s camera regions match the live responsive HUD" % label)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	await _await_match_presentation_settled()
	if _arena and is_instance_valid(_arena):
		if current_scene == _arena:
			current_scene = null
		_arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	if _failures.is_empty():
		print("[Twin Bays Camera Verifier] PASS")
		quit(0)
		return
	print("[Twin Bays Camera Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)


func _await_match_presentation_settled() -> void:
	if _arena == null or not is_instance_valid(_arena):
		return
	var presentation := _arena.find_child("PartyShooterMatchPresentation", true, false)
	if presentation == null or not presentation.has_method("get_debug_state"):
		return
	var deadline_msec := Time.get_ticks_msec() + 1800
	while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
		var state := presentation.call("get_debug_state") as Dictionary
		if String(state.get("cue_state", "idle")) in ["idle", "complete", "result_ready"]:
			break
		await create_timer(0.05, true, false, true).timeout
	await process_frame
