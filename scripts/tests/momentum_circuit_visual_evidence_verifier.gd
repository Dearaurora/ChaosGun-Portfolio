extends SceneTree

## Validates the release-review capture manifest. This checks provenance and
## coverage only; it intentionally does not make a subjective visual approval.

const REQUIRED_IDS := [
	"empty_arena",
	"battle_overview",
	"battle_hud",
	"mechanism_stable",
	"mechanism_warning",
	"mechanism_switching",
	"mechanism_new_bridge",
	"teleport_cooldown_0",
	"teleport_cooldown_50",
	"teleport_cooldown_100",
	"teleport_trail",
	"trajectory_pistol",
	"trajectory_smg",
	"trajectory_ak_rifle",
	"trajectory_shotgun",
	"trajectory_gatling",
	"trajectory_sniper",
	"cloud_frame_00",
	"cloud_frame_01",
]
const REQUIRED_PHASES := {
	"mechanism_warning": ["warning", 0.50],
	"mechanism_switching": ["switching", 0.50],
	"mechanism_new_bridge": ["new_bridge", 0.40],
}
const EPSILON := 0.001

var _failures: Array[String] = []


func _initialize() -> void:
	var input_path := _argument_value("--input=", "")
	if input_path.is_empty() or not input_path.ends_with(".json"):
		_fail("Use --input=<capture-manifest.json>")
		_finish()
		return
	if not input_path.begins_with("res://reports/momentum_circuit_release_validation/"):
		_fail("Capture manifest must be stored in a run-specific release-validation directory")
		_finish()
		return
	var manifest := _read_dictionary(input_path)
	if manifest.is_empty():
		_fail("Could not read capture manifest: %s" % input_path)
		_finish()
		return
	if int(manifest.get("schema_version", 0)) != 1:
		_fail("Capture manifest schema_version must be 1")
	var run_id := String(manifest.get("run_id", ""))
	if run_id.is_empty():
		_fail("Capture manifest is missing run_id")
	var captures := manifest.get("captures", []) as Array
	var by_id := {}
	for raw: Variant in captures:
		if not raw is Dictionary:
			_fail("Capture entry is not an object")
			continue
		var entry := raw as Dictionary
		var id := String(entry.get("id", ""))
		if id.is_empty() or by_id.has(id):
			_fail("Capture manifest has a missing or duplicate id: %s" % id)
			continue
		by_id[id] = entry
	for id in REQUIRED_IDS:
		if not by_id.has(id):
			_fail("Missing required capture: %s" % id)
			continue
		_verify_entry(id, by_id[id] as Dictionary, run_id)
	_verify_phase_entries(by_id)
	_verify_cloud_frames(by_id)
	_finish()


func _verify_entry(id: String, entry: Dictionary, run_id: String) -> void:
	if String(entry.get("run_id", "")) != run_id:
		_fail("%s does not declare the manifest run_id" % id)
	var output_path := String(entry.get("output_path", ""))
	if not output_path.begins_with("res://reports/momentum_circuit_release_validation/%s/" % run_id):
		_fail("%s output is not immutable run evidence: %s" % [id, output_path])
		return
	if not output_path.ends_with(".png"):
		_fail("%s output must be a PNG" % id)
		return
	var file := FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		_fail("%s output is missing: %s" % [id, output_path])
		return
	file.close()
	var actual_hash := FileAccess.get_sha256(output_path)
	if String(entry.get("sha256", "")).to_lower() != actual_hash.to_lower():
		_fail("%s SHA-256 does not match its output" % id)
	if int(entry.get("width", 0)) < 320 or int(entry.get("height", 0)) < 180:
		_fail("%s dimensions are not reviewable" % id)
	if id == "empty_arena" and String(entry.get("mode", "")) != "empty":
		_fail("empty_arena must use empty mode")
	if id in ["battle_overview", "battle_hud"] and String(entry.get("mode", "")) != "battle":
		_fail("%s must use battle mode" % id)
	if id == "mechanism_stable" and String(entry.get("mechanism", "")) != "stable":
		_fail("mechanism_stable must use stable")
	if id.begins_with("trajectory_") and String(entry.get("weapon_id", "")).is_empty():
		_fail("%s must declare its reviewed weapon" % id)


func _verify_phase_entries(by_id: Dictionary) -> void:
	for id: String in REQUIRED_PHASES:
		if not by_id.has(id):
			continue
		var entry := by_id[id] as Dictionary
		var requirement := REQUIRED_PHASES[id] as Array
		if String(entry.get("mechanism", "")) != String(requirement[0]):
			_fail("%s has the wrong mechanism phase" % id)
		if absf(float(entry.get("phase_progress", -1.0)) - float(requirement[1])) > EPSILON:
			_fail("%s does not use its locked phase progress" % id)


func _verify_cloud_frames(by_id: Dictionary) -> void:
	if not by_id.has("cloud_frame_00") or not by_id.has("cloud_frame_01"):
		return
	var first := by_id["cloud_frame_00"] as Dictionary
	var second := by_id["cloud_frame_01"] as Dictionary
	var first_time := float(first.get("cloud_time_seconds", -1.0))
	var second_time := float(second.get("cloud_time_seconds", -1.0))
	if first_time < 0.0 or second_time <= first_time:
		_fail("Cloud frames must use two ordered, frozen cloud times")


func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT momentum_circuit_visual_evidence passed=true failures=0")
		quit(0)
		return
	print("RESULT momentum_circuit_visual_evidence passed=false failures=%d" % _failures.size())
	for failure in _failures:
		print("- ", failure)
	quit(1)
