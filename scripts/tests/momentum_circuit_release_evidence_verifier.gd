extends SceneTree

## Guards release-evidence tier semantics. It validates assertions supplied by
## the wrapper; it never creates a human-playtest result or performance result.

var _failures: Array[String] = []


func _initialize() -> void:
	var input_path := _argument_value("--input=", "")
	if input_path.is_empty() or not input_path.ends_with(".json"):
		_fail("Use --input=<release-evidence.json>")
		_finish()
		return
	if not input_path.begins_with("res://reports/momentum_circuit_release_validation/"):
		_fail("Release evidence must be stored in a run-specific release-validation directory")
		_finish()
		return
	var evidence := _read_dictionary(input_path)
	if evidence.is_empty():
		_fail("Could not read release evidence: %s" % input_path)
		_finish()
		return
	_verify(evidence)
	_finish()


func _verify(evidence: Dictionary) -> void:
	if int(evidence.get("schema_version", 0)) != 2:
		_fail("Release evidence schema_version must be 2")
	var run_id := String(evidence.get("run_id", ""))
	if run_id.is_empty():
		_fail("Release evidence is missing run_id")
	var quick := bool(evidence.get("quick", false))
	var dev_only := bool(evidence.get("dev_only", false))
	var skip_performance := bool(evidence.get("skip_performance", false))
	var formal := not quick and not dev_only and not skip_performance
	var tier := String(evidence.get("evidence_tier", ""))
	var release_complete := bool(evidence.get("release_complete", false))
	var alias_kind := String(evidence.get("latest_alias_kind", ""))
	if formal and tier != "release":
		_fail("A complete-gate run must be recorded in the release tier")
	if not formal and tier != "development":
		_fail("Quick, dev-only, or skipped-performance output must use the development tier")
	if not formal and release_complete:
		_fail("Development-tier output may never claim release_complete")
	if not formal and alias_kind == "release":
		_fail("Development-tier output may never update the release alias")
	if release_complete:
		if not formal:
			_fail("release_complete requires a non-quick, non-dev, non-skipped run")
		if alias_kind != "release":
			_fail("A release pass must designate only the release alias")
		_verify_passed_human_gate(evidence.get("human_evidence", {}) as Dictionary, run_id)
		_verify_passed_snapshot("visual_evidence", evidence.get("visual_evidence", {}) as Dictionary, run_id)
		_verify_passed_snapshot("performance_report", evidence.get("performance_report", {}) as Dictionary, run_id)
	else:
		if alias_kind == "release":
			_fail("A non-pass must not designate the release alias")


func _verify_passed_human_gate(gate: Dictionary, run_id: String) -> void:
	# This is an attestation contract, not an automated substitute for a human.
	if String(gate.get("status", "")) != "passed":
		_fail("Release pass requires an externally supplied human-playtest PASS")
	if String(gate.get("attested_by", "")).strip_edges().is_empty():
		_fail("Human-playtest PASS is missing attested_by")
	if String(gate.get("attested_at_utc", "")).strip_edges().is_empty():
		_fail("Human-playtest PASS is missing attested_at_utc")
	_verify_passed_snapshot("human_evidence", gate, run_id)


func _verify_passed_snapshot(label: String, snapshot: Dictionary, run_id: String) -> void:
	if not bool(snapshot.get("passed", false)):
		_fail("Release pass requires passed %s" % label)
	var path := String(snapshot.get("path", ""))
	if not path.begins_with("res://reports/momentum_circuit_release_validation/%s/" % run_id):
		_fail("%s is not an immutable run snapshot" % label)
	if String(snapshot.get("sha256", "")).length() != 64:
		_fail("%s is missing its SHA-256" % label)


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
		print("RESULT momentum_circuit_release_evidence passed=true failures=0")
		quit(0)
		return
	print("RESULT momentum_circuit_release_evidence passed=false failures=%d" % _failures.size())
	for failure in _failures:
		print("- ", failure)
	quit(1)
