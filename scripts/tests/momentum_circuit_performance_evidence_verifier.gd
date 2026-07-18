extends SceneTree

## Re-evaluates an already captured, valid 60-second Forward+ comparison.
## This exists for desktop hosts that minimize a newly spawned render window;
## it never fabricates or shortens measurement data.

const DEFAULT_INPUT := "res://reports/momentum_circuit_performance_final.json"
const MIN_AVERAGE_FPS := 60.0
const MIN_ONE_PERCENT_LOW_FPS := 55.0
const MAX_RELATIVE_FRAME_COST := 1.10

var _failures: Array[String] = []


func _initialize() -> void:
	var input_path := _argument_value("--input=", DEFAULT_INPUT)
	print("==================================================")
	print("[Momentum Circuit Performance Evidence Verifier]")
	print("==================================================")
	if not input_path.begins_with("res://reports/") or not input_path.ends_with(".json"):
		_fail("Evidence must be a JSON report under res://reports/")
		_finish()
		return
	var file := FileAccess.open(input_path, FileAccess.READ)
	if file == null:
		_fail("Could not open performance evidence: %s" % input_path)
		_finish()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_fail("Performance evidence is not a JSON object")
		_finish()
		return
	var report := parsed as Dictionary
	var config := report.get("configuration", {}) as Dictionary
	var baseline := report.get("open_ringout", {}) as Dictionary
	var target := report.get("momentum_circuit", {}) as Dictionary
	var ratios := report.get("ratios", {}) as Dictionary
	if String(report.get("mode", "")) != "compare":
		_fail("Evidence must contain a compare-mode run")
	if float(config.get("sample_seconds", 0.0)) < 60.0:
		_fail("Evidence must contain at least 60 seconds per map")
	if String(config.get("rendering_method", "")) != "forward_plus":
		_fail("Evidence must use Forward+")
	var resolution := config.get("resolution", []) as Array
	if resolution.size() != 2 or int(resolution[0]) != 1920 or int(resolution[1]) != 1080:
		_fail("Evidence must use 1920x1080")
	var offscreen_target := String(config.get("render_target", "")) == "always_updating_offscreen_subviewport"
	if offscreen_target:
		var host_size := config.get("host_window_size", []) as Array
		if host_size.size() != 2 or int(host_size[0]) > 960 or int(host_size[1]) > 540:
			_fail("Offscreen evidence host window must not exceed 960x540")
	_verify_window_sample("Open Ring-Out", baseline, offscreen_target)
	_verify_window_sample("Momentum Circuit", target, offscreen_target)
	if float(target.get("average_fps", 0.0)) < MIN_AVERAGE_FPS:
		_fail("Average FPS is below 60")
	if float(target.get("one_percent_low_fps", 0.0)) < MIN_ONE_PERCENT_LOW_FPS:
		_fail("1%% Low is below 55 FPS")
	if float(ratios.get("average_frame_time", INF)) > MAX_RELATIVE_FRAME_COST:
		_fail("Relative frame-time cost exceeds 110%%")
	if int(baseline.get("orphan_node_delta", 1)) > 0 or int(target.get("orphan_node_delta", 1)) > 0:
		_fail("Evidence contains orphan-node growth")
	print("METRIC avg_fps=%.3f one_percent_low_fps=%.3f frame_cost_ratio=%.6f memory_drift_bytes=%.0f" % [
		target.get("average_fps", 0.0), target.get("one_percent_low_fps", 0.0),
		ratios.get("average_frame_time", INF), target.get("memory_drift_bytes", 0.0),
	])
	_finish()


func _verify_window_sample(label: String, sample: Dictionary, offscreen_target: bool) -> void:
	if sample.is_empty():
		_fail("Missing %s sample" % label)
		return
	if not offscreen_target:
		if not bool(sample.get("focus_at_sample_start", false)):
			_fail("%s was not focused at sample start" % label)
		if bool(sample.get("minimized_during_sample", true)):
			_fail("%s was minimized during sampling" % label)
	if float(sample.get("accepted_sample_seconds", 0.0)) < 60.0:
		_fail("%s has less than 60 accepted seconds" % label)


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
		print("[Momentum Circuit Performance Evidence Verifier] PASS")
		quit(0)
		return
	print("[Momentum Circuit Performance Evidence Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
