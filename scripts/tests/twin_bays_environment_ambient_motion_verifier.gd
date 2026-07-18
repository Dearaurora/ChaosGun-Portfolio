extends SceneTree

const BackdropScript = preload("res://scripts/maps/twin_bays_splash_backdrop.gd")
const EXPECTED_WATER_Y := -5.85
const EXPECTED_WATER_SIZE := Vector2(300.0, 300.0)
const MAX_FLOAT_BOB := 0.12
const MAX_FLOAT_TILT_DEGREES := 1.5
const MAX_PALM_SWAY_DEGREES := 2.0
const MAX_WATER_ENTRY_SCALE_DELTA := 0.04

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Environment Ambient Motion Verifier]")
	print("==================================================")

	var backdrop := BackdropScript.new() as Node3D
	backdrop.name = "TwinBaysAmbientMotionTestBackdrop"
	root.add_child(backdrop)
	backdrop.call("rebuild")
	backdrop.set_process(false)

	var at_zero := backdrop.call("get_ambient_motion_debug") as Dictionary
	_verify_registration(at_zero)
	_verify_water_contract(backdrop, at_zero)
	_verify_visual_only(backdrop)
	_verify_dry_floor_contract()

	backdrop.call("advance_ambient_motion", 1.0)
	var at_one_second := backdrop.call("get_ambient_motion_debug") as Dictionary
	_verify_sample("1 second", at_zero, at_one_second)

	backdrop.call("advance_ambient_motion", 2.0)
	var at_three_seconds := backdrop.call("get_ambient_motion_debug") as Dictionary
	_verify_sample("3 seconds", at_one_second, at_three_seconds)

	backdrop.queue_free()
	await process_frame
	_finish()


func _verify_registration(debug: Dictionary) -> void:
	if not bool(debug.get("ready", false)):
		_fail("Ambient motion controller did not register every required visual class")
	if int(debug.get("float_count", 0)) != 24:
		_fail("Expected 4 inflatable rings and 20 buoys, got %d floating visuals" % int(debug.get("float_count", 0)))
	if int(debug.get("palm_count", 0)) != 8:
		_fail("Expected 8 authored low-poly palms, got %d" % int(debug.get("palm_count", 0)))
	if int(debug.get("water_entry_count", 0)) != 4:
		_fail("Expected paired foam and ripple visuals at both pipe entries, got %d" % int(debug.get("water_entry_count", 0)))


func _verify_sample(label: String, previous: Dictionary, current: Dictionary) -> void:
	var elapsed := float(current.get("time", -1.0))
	var expected := 1.0 if label == "1 second" else 3.0
	if not is_equal_approx(elapsed, expected):
		_fail("%s controlled sample advanced to %.4f instead of %.1f" % [label, elapsed, expected])

	var float_samples := current.get("float_samples", []) as Array
	var palm_samples := current.get("palm_samples", []) as Array
	var entry_samples := current.get("water_entry_samples", []) as Array
	var previous_float := _sample_map(previous.get("float_samples", []) as Array, "bob_offset")
	var previous_palm := _sample_map(previous.get("palm_samples", []) as Array, "sway_degrees")
	var previous_entry := _sample_map(previous.get("water_entry_samples", []) as Array, "scale_ratio")

	var float_moved := false
	var float_min := INF
	var float_max := -INF
	for value: Variant in float_samples:
		var sample := value as Dictionary
		var path := String(sample.get("path", ""))
		var bob := float(sample.get("bob_offset", 0.0))
		var tilt := float(sample.get("tilt_degrees", 0.0))
		if absf(bob) > MAX_FLOAT_BOB + 0.0001:
			_fail("%s float bob exceeded %.2f at %s: %.5f" % [label, MAX_FLOAT_BOB, path, bob])
		if tilt > MAX_FLOAT_TILT_DEGREES + 0.0001:
			_fail("%s float tilt exceeded %.1f degrees at %s: %.5f" % [label, MAX_FLOAT_TILT_DEGREES, path, tilt])
		float_moved = float_moved or absf(bob - float(previous_float.get(path, bob))) > 0.002
		float_min = minf(float_min, bob)
		float_max = maxf(float_max, bob)
	if not float_moved:
		_fail("%s sample did not advance inflatable/buoy motion" % label)
	if float_max - float_min < 0.025:
		_fail("%s floating objects are not visibly out of phase" % label)

	var palm_moved := false
	var palm_min := INF
	var palm_max := -INF
	for value: Variant in palm_samples:
		var sample := value as Dictionary
		var path := String(sample.get("path", ""))
		var sway := float(sample.get("sway_degrees", 0.0))
		if sway > MAX_PALM_SWAY_DEGREES + 0.0001:
			_fail("%s palm sway exceeded %.1f degrees at %s: %.5f" % [label, MAX_PALM_SWAY_DEGREES, path, sway])
		palm_moved = palm_moved or absf(sway - float(previous_palm.get(path, sway))) > 0.002
		palm_min = minf(palm_min, sway)
		palm_max = maxf(palm_max, sway)
	if not palm_moved:
		_fail("%s sample did not advance palm motion" % label)
	if palm_max - palm_min < 0.15:
		_fail("%s palms are not visibly out of phase" % label)

	var entry_moved := false
	var entry_min := INF
	var entry_max := -INF
	for value: Variant in entry_samples:
		var sample := value as Dictionary
		var path := String(sample.get("path", ""))
		var ratio := float(sample.get("scale_ratio", 1.0))
		if absf(ratio - 1.0) > MAX_WATER_ENTRY_SCALE_DELTA + 0.0001:
			_fail("%s pipe-entry scale exceeded %.0f%% at %s: %.5f" % [label, MAX_WATER_ENTRY_SCALE_DELTA * 100.0, path, ratio])
		entry_moved = entry_moved or absf(ratio - float(previous_entry.get(path, ratio))) > 0.001
		entry_min = minf(entry_min, ratio)
		entry_max = maxf(entry_max, ratio)
	if not entry_moved:
		_fail("%s sample did not advance pipe-entry foam/ripple motion" % label)
	if entry_max - entry_min < 0.012:
		_fail("%s pipe-entry visuals are not visibly out of phase" % label)

	print(
		"OK  %s: float=[%.4f, %.4f] palm=[%.3f, %.3f] entry=[%.4f, %.4f]"
		% [label, float_min, float_max, palm_min, palm_max, entry_min, entry_max]
	)


func _sample_map(samples: Array, value_key: String) -> Dictionary:
	var result := {}
	for value: Variant in samples:
		var sample := value as Dictionary
		result[String(sample.get("path", ""))] = float(sample.get(value_key, 0.0))
	return result


func _verify_water_contract(backdrop: Node3D, debug: Dictionary) -> void:
	if absf(float(debug.get("water_y", 0.0)) - EXPECTED_WATER_Y) > 0.0001:
		_fail("Water-height debug contract changed")
	if (debug.get("water_plane_size", Vector2.ZERO) as Vector2).distance_to(EXPECTED_WATER_SIZE) > 0.0001:
		_fail("Water-size debug contract changed")

	var water := backdrop.find_child("DynamicBackgroundWater", true, false) as MeshInstance3D
	if water == null:
		_fail("DynamicBackgroundWater is missing")
		return
	if absf(water.position.y - EXPECTED_WATER_Y) > 0.0001:
		_fail("Water moved above or below its frozen backdrop height: %.4f" % water.position.y)
	var plane := water.mesh as PlaneMesh
	if plane == null or plane.size.distance_to(EXPECTED_WATER_SIZE) > 0.0001:
		_fail("Water plane must remain an authored 300x300 opaque backdrop")
	var material := water.material_override as ShaderMaterial
	if material == null or material.shader == null:
		_fail("Water must retain its deterministic two-layer caustic shader")
		return
	var code := material.shader.code
	if not code.contains("depth_draw_opaque") or code.contains("blend_"):
		_fail("Water shader must remain opaque and depth-writing")
	if not code.contains("layer_a") or not code.contains("layer_b"):
		_fail("Water shader must preserve both authored caustic layers")


func _verify_visual_only(backdrop: Node3D) -> void:
	var animated_count := 0
	var stack: Array[Node] = [backdrop]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject3D or node is CollisionShape3D:
			_fail("Backdrop ambient layer must remain collision-free: %s" % node.get_path())
		if node.has_meta("ambient_motion"):
			animated_count += 1
			if not bool(node.get_meta("visual_only", false)):
				_fail("Animated backdrop node is not tagged visual-only: %s" % node.get_path())
		for child in node.get_children():
			stack.append(child)
	if animated_count != 36:
		_fail("Expected 36 explicitly tagged ambient-motion visuals, got %d" % animated_count)

	for slide_name in ["NorthWestSlideEnd", "NorthEastSlideEnd"]:
		var slide := backdrop.find_child(slide_name, true, false)
		if slide == null:
			_fail("Static slide-end composition is missing: %s" % slide_name)
		elif slide.has_meta("ambient_motion"):
			_fail("Slide ends must remain static and compositionally clear: %s" % slide_name)


func _verify_dry_floor_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/maps/twin_bays_splash_backdrop.gd").to_lower()
	var forbidden_terms := [
		"floor" + "wetmarks",
		"floor" + "puddles",
		"wet" + "ness",
		"moisture",
		"de" + "cal",
	]
	for term in forbidden_terms:
		if source.contains(term):
			_fail("Backdrop source introduced forbidden dry-floor content: %s" % term)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("\n==================================================")
	if _failures.is_empty():
		print("[Twin Bays Environment Ambient Motion Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Twin Bays Environment Ambient Motion Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
