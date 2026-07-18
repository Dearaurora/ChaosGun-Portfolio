extends SceneTree

const OPEN_RINGOUT_SCENE := "res://scenes/maps/open_ringout_slice.tscn"
const TWIN_BAYS_SCENE := "res://scenes/maps/twin_bays_splash_arena.tscn"
const PartyShooterCameraDirectorScript = preload("res://scripts/maps/party_shooter_camera_director.gd")

const FORWARD_DOT_MIN := 0.999999
const PITCH_EPSILON_DEGREES := 0.0001

var _failures: Array[String] = []


func _initialize() -> void:
	root.set_meta("disable_runtime_audio", true)
	root.size = Vector2i(1280, 720)
	_configure_empty_roster()

	var open_snapshot: Dictionary = await _capture_map_camera(
		OPEN_RINGOUT_SCENE, "OpenRingoutCameraDirector", "Open Ring-Out"
	)
	var twin_snapshot: Dictionary = await _capture_map_camera(
		TWIN_BAYS_SCENE, "TwinBaysCameraDirector", "Twin Bays"
	)
	if not open_snapshot.is_empty() and not twin_snapshot.is_empty():
		_verify_shared_contract(open_snapshot, twin_snapshot)
	_finish()


func _capture_map_camera(scene_path: String, director_name: String, label: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("Could not load %s scene: %s" % [label, scene_path])
		return {}
	var arena := packed.instantiate() as Node3D
	if arena == null:
		_fail("Could not instantiate %s" % label)
		return {}
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	# Both production maps author the shared READY/GO intro. Observe the actual
	# controller state instead of relying on wall-clock padding before teardown.
	await _await_match_presentation_settled(arena)

	var camera := arena.get_node_or_null("GlobalCamera") as Camera3D
	var director := arena.get_node_or_null(director_name)
	if camera == null or director == null:
		_fail("%s is missing its production camera/director" % label)
		current_scene = null
		arena.queue_free()
		await process_frame
		return {}
	if not director is PartyShooterCameraDirector:
		_fail("%s director does not inherit PartyShooterCameraDirector" % label)
	var debug := arena.call("get_runtime_camera_debug") as Dictionary
	var behavior := director.call("get_behavior_contract") as Dictionary
	var snapshot := {
		"label": label,
		"projection": camera.projection,
		"basis": camera.global_transform.basis,
		"forward": -camera.global_transform.basis.z.normalized(),
		"view_offset": debug.get("view_offset", Vector3.ZERO) as Vector3,
		"behavior": behavior,
		"size": camera.size,
	}

	current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	return snapshot


func _await_match_presentation_settled(arena: Node) -> void:
	var presentation := arena.find_child("OpenRingoutMatchPresentation", true, false)
	if presentation == null:
		presentation = arena.find_child("PartyShooterMatchPresentation", true, false)
	if presentation == null or not presentation.has_method("get_debug_state"):
		return
	var deadline_msec := Time.get_ticks_msec() + 2000
	while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
		var state := presentation.call("get_debug_state") as Dictionary
		if String(state.get("cue_state", "idle")) in ["idle", "complete", "result_ready"]:
			break
		await create_timer(0.05, true, false, true).timeout
	await process_frame


func _verify_shared_contract(open_snapshot: Dictionary, twin_snapshot: Dictionary) -> void:
	var open_expected := PartyShooterCameraDirectorScript.STANDARD_GAMEPLAY_VIEW_OFFSET as Vector3
	var twin_expected := PartyShooterCameraDirectorScript.view_offset_with_standard_pitch(0.0, 64.0) as Vector3
	for snapshot in [open_snapshot, twin_snapshot]:
		var label := String((snapshot as Dictionary).get("label", "map"))
		if int((snapshot as Dictionary).get("projection", -1)) != Camera3D.PROJECTION_ORTHOGONAL:
			_fail("%s production camera must be orthographic" % label)
	var open_offset := open_snapshot.get("view_offset", Vector3.ZERO) as Vector3
	var twin_offset := twin_snapshot.get("view_offset", Vector3.ZERO) as Vector3
	if not open_offset.is_equal_approx(open_expected):
		_fail("Open Ring-Out view offset drifted from its authored contract: %s" % open_offset)
	if not twin_offset.is_equal_approx(twin_expected):
		_fail("Twin Bays view offset drifted from its centered horizontal contract: %s" % twin_offset)

	var open_forward := open_snapshot.get("forward", Vector3.ZERO) as Vector3
	var twin_forward := twin_snapshot.get("forward", Vector3.ZERO) as Vector3
	if open_forward.dot(-open_expected.normalized()) < FORWARD_DOT_MIN:
		_fail("Open Ring-Out camera basis does not match its authored view offset")
	if twin_forward.dot(-twin_expected.normalized()) < FORWARD_DOT_MIN:
		_fail("Twin Bays camera basis does not match its authored view offset")

	var open_pitch := PartyShooterCameraDirectorScript.downward_pitch_degrees(open_offset)
	var twin_pitch := PartyShooterCameraDirectorScript.downward_pitch_degrees(twin_offset)
	var standard_pitch := float(PartyShooterCameraDirectorScript.STANDARD_GAMEPLAY_DOWNWARD_PITCH_DEGREES)
	if absf(open_pitch - standard_pitch) > PITCH_EPSILON_DEGREES:
		_fail("Open Ring-Out downward pitch drifted: %.8f" % open_pitch)
	if absf(twin_pitch - standard_pitch) > PITCH_EPSILON_DEGREES:
		_fail("Twin Bays downward pitch drifted: %.8f" % twin_pitch)
	if absf(open_pitch - twin_pitch) > PITCH_EPSILON_DEGREES:
		_fail("Player-map downward pitches differ: Open %.8f / Twin %.8f" % [open_pitch, twin_pitch])
	if open_snapshot.get("behavior", {}) != twin_snapshot.get("behavior", {}):
		_fail("Player maps do not expose the same follow behavior contract")

	if _failures.is_empty():
		var open_yaw := rad_to_deg(atan2(open_offset.x, open_offset.z))
		var twin_yaw := rad_to_deg(atan2(twin_offset.x, twin_offset.z))
		print("OK  both player maps share downward pitch %.6f degrees" % twin_pitch)
		print("OK  map-readable horizontal yaw: Open %.3f / Twin %.3f" % [open_yaw, twin_yaw])
		print("OK  framing size remains map-specific: Open %.2f / Twin %.2f" % [
			float(open_snapshot.get("size", 0.0)),
			float(twin_snapshot.get("size", 0.0)),
		])


func _configure_empty_roster() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Party Shooter Camera Consistency Verifier] PASS")
		quit(0)
		return
	print("[Party Shooter Camera Consistency Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
