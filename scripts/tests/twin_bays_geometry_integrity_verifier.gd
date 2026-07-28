extends SceneTree

## Read-only release gate for the deterministic Twin Bays geometry audit.
##
## The Blender builder owns the expensive topology and clearance measurements;
## this verifier proves that the shipped manifest contains a passing audit for
## the current canonical layout, then independently checks the mirrored pipe and
## portal contract that makes those measurements valid for both sides.

const LAYOUT_PATH := "res://resources/maps/twin_bays_layout_v1.json"
const MANIFEST_PATH := (
	"res://assets/models/generated/twin_bays_splash_arena_v4/"
	+ "twin_bays_splash_arena_v4_manifest.json"
)
const PORTAL_VFX_SCRIPT_PATH := "res://scripts/maps/twin_bays_portal_vfx.gd"

const MIRROR_EPSILON := 0.000001
const METRIC_EPSILON := 0.000001
const MIN_WALL_PIPE_CLEARANCE := 0.75
const MAX_SOUTH_WALL_BOUNDARY_GAP := 0.12
const MIN_PORTAL_APERTURE_CLEARANCE := 0.20
const MIN_PIPE_BEND_RADIUS := 8.85
const MAX_CAUSEWAY_OVERLAP_AREA := 0.0001
const MIN_TRIM_BLOCKER_CLEARANCE := 0.08
const MIN_PORTAL_MOUTH_PLATFORM_INSET := 0.25
const MAX_PORTAL_MOUTH_PLATFORM_INSET := 0.50
const MIN_PORTAL_NORMAL_DOT := 0.999

const EXPECTED_DYNAMIC_ENVELOPE := {
	"ring_scale_multiplier": 0.88,
	"ring_pulse_amplitude": 0.018,
	"foam_outer_radius_multiplier": 1.12,
	"foam_pulse_amplitude": 0.026,
	"inner_foam_outer_radius_multiplier": 1.04,
	"core_scale_multiplier": 0.92,
}

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Geometry Integrity Verifier]")
	print("==================================================")

	var layout := _load_json_dictionary(LAYOUT_PATH)
	var manifest := _load_json_dictionary(MANIFEST_PATH)
	if layout.is_empty():
		_fail("Canonical layout is missing or invalid: %s" % LAYOUT_PATH)
	if manifest.is_empty():
		_fail("Generated manifest is missing or invalid: %s" % MANIFEST_PATH)
	if not layout.is_empty() and not manifest.is_empty():
		_verify_manifest_matches_layout(layout, manifest)
		_verify_geometry_audit(manifest)
		_verify_mirrored_pipes_and_portals(layout)

	_finish()


func _verify_manifest_matches_layout(layout: Dictionary, manifest: Dictionary) -> void:
	if String(manifest.get("layout_schema", "")) != String(layout.get("schema", "")):
		_fail("Manifest layout schema does not match the canonical layout")
	if int(manifest.get("layout_version", -1)) != int(layout.get("version", -2)):
		_fail("Manifest layout version does not match the canonical layout")
	var expected_hash := FileAccess.get_sha256(LAYOUT_PATH)
	if String(manifest.get("layout_sha256", "")) != expected_hash:
		_fail("Manifest geometry audit is stale for the canonical layout SHA-256")
	else:
		print("OK  manifest audit belongs to the current canonical layout")


func _verify_geometry_audit(manifest: Dictionary) -> void:
	print("\n--- Generated Geometry Audit ---")
	var audit_value: Variant = manifest.get("geometry_audit")
	if not audit_value is Dictionary:
		_fail("Manifest is missing geometry_audit")
		return
	var audit := audit_value as Dictionary
	if audit.has("passed") and audit.get("passed") != true:
		_fail("Manifest geometry_audit reports passed=false")

	_require_audit_flag(audit, "outline_simple")
	_require_audit_flag(audit, "production_outline_simple")
	_require_audit_flag(audit, "portal_mouths_mounted_on_platform")
	_require_min_metric(audit, "portal_mouth_platform_min_inset", MIN_PORTAL_MOUTH_PLATFORM_INSET)
	_require_max_metric(audit, "portal_mouth_platform_max_inset", MAX_PORTAL_MOUTH_PLATFORM_INSET)
	_require_min_metric(audit, "wall_pipe_min_clearance", MIN_WALL_PIPE_CLEARANCE)
	_require_max_metric(audit, "south_wall_boundary_max_gap", MAX_SOUTH_WALL_BOUNDARY_GAP)
	_require_min_metric(audit, "portal_aperture_min_clearance", MIN_PORTAL_APERTURE_CLEARANCE)
	_require_min_metric(audit, "pipe_min_bend_radius", MIN_PIPE_BEND_RADIUS)
	_require_max_metric(audit, "causeway_overlap_area", MAX_CAUSEWAY_OVERLAP_AREA)
	_require_min_metric(audit, "trim_blocker_min_clearance", MIN_TRIM_BLOCKER_CLEARANCE)
	_verify_dynamic_envelope(audit)


func _require_audit_flag(audit: Dictionary, key: String) -> void:
	if not audit.has(key):
		_fail("geometry_audit is missing required flag: %s" % key)
		return
	var raw: Variant = audit[key]
	if raw is bool:
		if raw != true:
			_fail("geometry_audit.%s must be true" % key)
		else:
			print("OK  geometry_audit.%s" % key)
		return
	if raw is Dictionary:
		var result := raw as Dictionary
		if result.get("passed") != true:
			_fail("geometry_audit.%s must report passed=true" % key)
			return
		if result.has("value") and result.get("value") != true:
			_fail("geometry_audit.%s value must be true" % key)
			return
		print("OK  geometry_audit.%s" % key)
		return
	_fail("geometry_audit.%s must be a bool or result dictionary" % key)


func _require_min_metric(audit: Dictionary, key: String, minimum: float) -> void:
	var value: Variant = _audit_metric_value(audit, key)
	if value == null:
		return
	var number := float(value)
	if number + METRIC_EPSILON < minimum:
		_fail("geometry_audit.%s %.6f is below %.6f" % [key, number, minimum])
	else:
		print("OK  geometry_audit.%s = %.6f (minimum %.6f)" % [key, number, minimum])


func _require_max_metric(audit: Dictionary, key: String, maximum: float) -> void:
	var value: Variant = _audit_metric_value(audit, key)
	if value == null:
		return
	var number := float(value)
	if number - METRIC_EPSILON > maximum:
		_fail("geometry_audit.%s %.6f exceeds %.6f" % [key, number, maximum])
	else:
		print("OK  geometry_audit.%s = %.6f (maximum %.6f)" % [key, number, maximum])


func _audit_metric_value(audit: Dictionary, key: String) -> Variant:
	if not audit.has(key):
		_fail("geometry_audit is missing required metric: %s" % key)
		return null
	var raw: Variant = audit[key]
	if raw is Dictionary:
		var result := raw as Dictionary
		if result.has("passed") and result.get("passed") != true:
			_fail("geometry_audit.%s reports passed=false" % key)
			return null
		if not result.has("value"):
			_fail("geometry_audit.%s result has no numeric value" % key)
			return null
		raw = result["value"]
	if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
		_fail("geometry_audit.%s must be numeric" % key)
		return null
	var value := float(raw)
	if is_nan(value) or is_inf(value):
		_fail("geometry_audit.%s must be finite" % key)
		return null
	return value


func _verify_dynamic_envelope(audit: Dictionary) -> void:
	var envelope_value: Variant = audit.get("dynamic_envelope")
	if not envelope_value is Dictionary:
		_fail("geometry_audit is missing dynamic_envelope")
		return
	var envelope := envelope_value as Dictionary
	var script := load(PORTAL_VFX_SCRIPT_PATH) as Script
	var runtime_envelope: Dictionary = {}
	if script == null:
		_fail("Portal VFX script is missing: %s" % PORTAL_VFX_SCRIPT_PATH)
	else:
		var instance: Object = script.new()
		if instance == null or not instance.has_method("get_dynamic_envelope_contract"):
			_fail("Portal VFX does not expose its dynamic geometry contract")
		else:
			runtime_envelope = instance.call("get_dynamic_envelope_contract") as Dictionary
		if instance:
			instance.free()
	for key: String in EXPECTED_DYNAMIC_ENVELOPE:
		if not envelope.has(key):
			_fail("geometry_audit.dynamic_envelope is missing %s" % key)
			continue
		var raw: Variant = envelope[key]
		if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
			_fail("geometry_audit.dynamic_envelope.%s must be numeric" % key)
			continue
		var actual := float(raw)
		var expected := float(EXPECTED_DYNAMIC_ENVELOPE[key])
		if absf(actual - expected) > METRIC_EPSILON:
			_fail("geometry_audit.dynamic_envelope.%s %.6f does not match %.6f" % [
				key, actual, expected,
			])
		else:
			print("OK  dynamic envelope %s = %.6f" % [key, actual])
		if not runtime_envelope.is_empty():
			if not runtime_envelope.has(key) or absf(float(runtime_envelope.get(key, -INF)) - expected) > METRIC_EPSILON:
				_fail("Runtime PortalVFX.%s does not match the generated geometry audit" % key)


func _verify_mirrored_pipes_and_portals(layout: Dictionary) -> void:
	print("\n--- Canonical Bilateral Geometry Contract ---")
	var pipes := _entries_by_id(layout.get("portal_pipes", []), "portal_pipes")
	var portals := _entries_by_id(layout.get("portals", []), "portals")
	if pipes.size() != 2:
		_fail("Canonical layout must contain exactly two portal pipes")
	if portals.size() != 2:
		_fail("Canonical layout must contain exactly two portals")
	var left_pipe: Dictionary = pipes.get("left_portal_pipe", {})
	var right_pipe: Dictionary = pipes.get("right_portal_pipe", {})
	var left_portal: Dictionary = portals.get("left_portal", {})
	var right_portal: Dictionary = portals.get("right_portal", {})
	if left_pipe.is_empty() or right_pipe.is_empty() or left_portal.is_empty() or right_portal.is_empty():
		_fail("Canonical left/right pipe or portal ids are incomplete")
		return

	var failure_count_before := _failures.size()
	_verify_pipe_mirror(left_pipe, right_pipe)
	_verify_portal_mirror(left_portal, right_portal)
	_verify_pipe_portal_links(left_pipe, right_pipe, left_portal, right_portal)
	_verify_portal_normal_alignment(left_pipe, left_portal)
	_verify_portal_normal_alignment(right_pipe, right_portal)
	if _failures.size() == failure_count_before:
		print("OK  left/right pipe and portal definitions are strict X mirrors")


func _verify_pipe_mirror(left: Dictionary, right: Dictionary) -> void:
	var left_path: Array = left.get("path", [])
	var right_path: Array = right.get("path", [])
	if left_path.size() != right_path.size() or left_path.size() < 2:
		_fail("Left/right pipe paths must have the same count and at least two points")
	else:
		for index in range(left_path.size()):
			_assert_mirrored_vector3(
				left_path[index], right_path[index], "portal pipe path[%d]" % index
			)
	_assert_mirrored_vector3(
		left.get("water_entry_position"), right.get("water_entry_position"),
		"portal pipe water_entry_position"
	)
	for key in ["outer_radius", "inner_radius", "collar_outer_radius"]:
		_assert_numeric_arrays_equal(left.get(key), right.get(key), "portal pipe %s" % key)
	for key in ["collar_depth", "radial_segments", "water_entry_foam_radius"]:
		_assert_numbers_equal(left.get(key), right.get(key), "portal pipe %s" % key)


func _verify_portal_mirror(left: Dictionary, right: Dictionary) -> void:
	_assert_mirrored_vector3(left.get("position"), right.get("position"), "portal position")
	_assert_mirrored_vector3(left.get("normal"), right.get("normal"), "portal normal")
	_assert_numbers_equal(left.get("cooldown_seconds"), right.get("cooldown_seconds"), "portal cooldown")

	var left_trigger := _dictionary(left.get("trigger"), "left portal trigger")
	var right_trigger := _dictionary(right.get("trigger"), "right portal trigger")
	_assert_mirrored_vector3(left_trigger.get("local_position"), right_trigger.get("local_position"), "portal trigger position")
	_assert_numeric_arrays_equal(left_trigger.get("size"), right_trigger.get("size"), "portal trigger size")

	var left_exit := _dictionary(left.get("exit"), "left portal exit")
	var right_exit := _dictionary(right.get("exit"), "right portal exit")
	_assert_mirrored_vector3(left_exit.get("local_position"), right_exit.get("local_position"), "portal exit position")
	if String(left_exit.get("node_name", "")) != String(right_exit.get("node_name", "")):
		_fail("Portal exit node names differ across sides")

	var left_ring := _dictionary(left.get("ring"), "left portal ring")
	var right_ring := _dictionary(right.get("ring"), "right portal ring")
	_assert_mirrored_vector3(left_ring.get("local_position"), right_ring.get("local_position"), "portal ring position")
	_assert_numeric_arrays_equal(left_ring.get("scale"), right_ring.get("scale"), "portal ring scale")
	for key in ["inner_radius", "outer_radius", "segments"]:
		_assert_numbers_equal(left_ring.get(key), right_ring.get(key), "portal ring %s" % key)

	var left_core := _dictionary(left.get("core"), "left portal core")
	var right_core := _dictionary(right.get("core"), "right portal core")
	_assert_mirrored_vector3(left_core.get("local_position"), right_core.get("local_position"), "portal core position")
	_assert_numeric_arrays_equal(left_core.get("scale"), right_core.get("scale"), "portal core scale")
	for key in ["radius", "segments"]:
		_assert_numbers_equal(left_core.get(key), right_core.get(key), "portal core %s" % key)

	var left_light := _dictionary(left.get("light"), "left portal light")
	var right_light := _dictionary(right.get("light"), "right portal light")
	_assert_mirrored_vector3(left_light.get("local_position"), right_light.get("local_position"), "portal light position")
	for key in ["range", "energy"]:
		_assert_numbers_equal(left_light.get(key), right_light.get(key), "portal light %s" % key)


func _verify_pipe_portal_links(
	left_pipe: Dictionary,
	right_pipe: Dictionary,
	left_portal: Dictionary,
	right_portal: Dictionary
) -> void:
	if String(left_pipe.get("portal_id", "")) != "left_portal":
		_fail("Left pipe must reference left_portal")
	if String(right_pipe.get("portal_id", "")) != "right_portal":
		_fail("Right pipe must reference right_portal")
	if String(left_portal.get("pipe_id", "")) != "left_portal_pipe":
		_fail("Left portal must reference left_portal_pipe")
	if String(right_portal.get("pipe_id", "")) != "right_portal_pipe":
		_fail("Right portal must reference right_portal_pipe")
	if String(left_portal.get("paired_portal_id", "")) != "right_portal":
		_fail("Left portal must pair with right_portal")
	if String(right_portal.get("paired_portal_id", "")) != "left_portal":
		_fail("Right portal must pair with left_portal")
	_verify_portal_mouth_sync(left_pipe, left_portal)
	_verify_portal_mouth_sync(right_pipe, right_portal)


func _verify_portal_mouth_sync(pipe: Dictionary, portal: Dictionary) -> void:
	var path: Array = pipe.get("path", [])
	if path.is_empty():
		_fail("Portal pipe has no mouth point: %s" % pipe.get("id", "?"))
		return
	var mouth := _vector3(path[0], "%s path[0]" % pipe.get("id", "pipe"))
	var root := _vector3(portal.get("position"), "%s position" % portal.get("id", "portal"))
	var xz_error := Vector2(mouth.x, mouth.z).distance_to(Vector2(root.x, root.z))
	if xz_error > 0.001:
		_fail("Portal root drifted from pipe mouth by %.6f XZ units: %s" % [
			xz_error, portal.get("id", "?"),
		])
	else:
		print("OK  %s root is aligned to its pipe mouth" % portal.get("id", "portal"))


func _verify_portal_normal_alignment(pipe: Dictionary, portal: Dictionary) -> void:
	var path: Array = pipe.get("path", [])
	if path.size() < 2:
		return
	var mouth := _vector3(path[0], "%s path[0]" % pipe.get("id", "pipe"))
	var next := _vector3(path[1], "%s path[1]" % pipe.get("id", "pipe"))
	var normal := _vector3(portal.get("normal"), "%s normal" % portal.get("id", "portal"))
	var reverse_tangent := mouth - next
	if reverse_tangent.length() <= MIRROR_EPSILON or normal.length() <= MIRROR_EPSILON:
		_fail("Portal normal or first pipe segment is degenerate: %s" % portal.get("id", "?"))
		return
	var alignment := normal.normalized().dot(reverse_tangent.normalized())
	if alignment + METRIC_EPSILON < MIN_PORTAL_NORMAL_DOT:
		_fail("Portal normal / reverse first-segment tangent dot %.6f is below %.3f: %s" % [
			alignment, MIN_PORTAL_NORMAL_DOT, portal.get("id", "?"),
		])
	else:
		print("OK  %s mouth alignment dot = %.6f" % [portal.get("id", "portal"), alignment])


func _entries_by_id(value: Variant, label: String) -> Dictionary:
	var result := {}
	if not value is Array:
		_fail("Canonical %s must be an array" % label)
		return result
	for raw_entry: Variant in value as Array:
		if not raw_entry is Dictionary:
			_fail("Canonical %s contains a non-dictionary entry" % label)
			continue
		var entry := raw_entry as Dictionary
		var id := String(entry.get("id", ""))
		if id.is_empty():
			_fail("Canonical %s entry has no id" % label)
		elif result.has(id):
			_fail("Canonical %s contains duplicate id %s" % [label, id])
		else:
			result[id] = entry
	return result


func _assert_mirrored_vector3(left_value: Variant, right_value: Variant, label: String) -> void:
	var left := _vector3(left_value, "left %s" % label)
	var right := _vector3(right_value, "right %s" % label)
	var expected := Vector3(-left.x, left.y, left.z)
	if right.distance_to(expected) > MIRROR_EPSILON:
		_fail("%s is not a strict X mirror: left=%s right=%s expected=%s" % [
			label, left, right, expected,
		])


func _assert_numeric_arrays_equal(left_value: Variant, right_value: Variant, label: String) -> void:
	if not left_value is Array or not right_value is Array:
		_fail("%s must be numeric arrays on both sides" % label)
		return
	var left := left_value as Array
	var right := right_value as Array
	if left.size() != right.size():
		_fail("%s array lengths differ" % label)
		return
	for index in range(left.size()):
		_assert_numbers_equal(left[index], right[index], "%s[%d]" % [label, index])


func _assert_numbers_equal(left: Variant, right: Variant, label: String) -> void:
	if typeof(left) not in [TYPE_INT, TYPE_FLOAT] or typeof(right) not in [TYPE_INT, TYPE_FLOAT]:
		_fail("%s must be numeric on both sides" % label)
		return
	if absf(float(left) - float(right)) > MIRROR_EPSILON:
		_fail("%s differs across sides: %s vs %s" % [label, left, right])


func _vector3(value: Variant, label: String) -> Vector3:
	if not value is Array or (value as Array).size() != 3:
		_fail("%s must be a three-number array" % label)
		return Vector3.ZERO
	var values := value as Array
	for component in values:
		if typeof(component) not in [TYPE_INT, TYPE_FLOAT]:
			_fail("%s contains a non-numeric component" % label)
			return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _dictionary(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		_fail("%s must be a dictionary" % label)
		return {}
	return value as Dictionary


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print("==================================================")
	if _failures.is_empty():
		print("[Twin Bays Geometry Integrity Verifier] PASS")
		quit(0)
		return
	print("[Twin Bays Geometry Integrity Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
