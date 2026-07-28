extends SceneTree

## Dedicated production-performance evidence for the Open Ring-Out scene.
## The PowerShell wrapper owns launch, foreground restoration, file hashes, and
## release completeness; this script owns the rendered sample and its validity.

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const MAP_SCRIPT_PATH := "res://scripts/maps/open_ringout_slice.gd"
const HERO_GLB_PATH := "res://assets/models/generated/characters/hero_character_rig_v3.glb"
const PROJECTILE_SCRIPT_PATH := "res://scripts/weapons/projectile.gd"
const HUD_SCRIPT_PATH := "res://scripts/ui/ringout_hud.gd"
const DEFAULT_REPORT_PATH := "res://reports/open_ringout_performance_raw.json"
const TARGET_RESOLUTION := Vector2i(1920, 1080)
const FORMAL_WARMUP_SECONDS := 10.0
const FORMAL_SAMPLE_SECONDS := 60.0
const QUICK_WARMUP_SECONDS := 2.0
const QUICK_SAMPLE_SECONDS := 5.0
const MIN_ONE_PERCENT_LOW_FPS := 60.0
const MAX_P99_FRAME_TIME_MS := 16.7
const MAX_AVERAGE_DRAW_CALLS := 1000.0
const MATERIAL_FOCUS_LOSS_SECONDS := 0.25
const SPIKE_FRAME_THRESHOLD_MS := 16.7
const MAX_RECORDED_SPIKE_FRAMES := 24

var _failures: Array[String] = []
var _report_path := DEFAULT_REPORT_PATH
var _target_resolution := TARGET_RESOLUTION
var _sampling_active := false
var _focus_loss_started_usec := 0
var _focus_lost_during_sample := false
var _minimized_during_sample := false
var _wrong_client_size_during_sample := false
var _render_activity_lost_during_sample := false


func _initialize() -> void:
	print("==================================================")
	print("[Open Ring-Out Performance]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	OS.low_processor_usage_mode = false
	root.focus_exited.connect(_on_window_focus_exited)

	_report_path = _argument_value("--report=", DEFAULT_REPORT_PATH)
	_target_resolution = _argument_resolution(TARGET_RESOLUTION)
	if not _valid_report_path(_report_path):
		_fail("Performance report must be a JSON file under res://reports/")
		_report_path = DEFAULT_REPORT_PATH
	if _target_resolution != TARGET_RESOLUTION:
		_fail("Open Ring-Out production gate is fixed at 1920x1080")

	var quick := _argument_bool("--quick=", false)
	var requested_warmup := _argument_float("--warmup=", QUICK_WARMUP_SECONDS if quick else FORMAL_WARMUP_SECONDS)
	var requested_sample := _argument_float("--sample=", QUICK_SAMPLE_SECONDS if quick else FORMAL_SAMPLE_SECONDS)
	var warmup_seconds := QUICK_WARMUP_SECONDS if quick else FORMAL_WARMUP_SECONDS
	var sample_seconds := QUICK_SAMPLE_SECONDS if quick else FORMAL_SAMPLE_SECONDS
	if not quick and (not is_equal_approx(requested_warmup, FORMAL_WARMUP_SECONDS) or not is_equal_approx(requested_sample, FORMAL_SAMPLE_SECONDS)):
		_fail("Formal performance gate requires exactly %.0f warmup seconds and %.0f accepted sample seconds" % [FORMAL_WARMUP_SECONDS, FORMAL_SAMPLE_SECONDS])
	if quick:
		warmup_seconds = clampf(requested_warmup, 1.0, QUICK_WARMUP_SECONDS)
		sample_seconds = clampf(requested_sample, 3.0, QUICK_SAMPLE_SECONDS)

	var report := _base_report(quick, warmup_seconds, sample_seconds)
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("Performance gate requires a render-capable display driver")
		await _finish(report)
		return
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		_fail("Performance gate requires Forward+; current method is %s" % RenderingServer.get_current_rendering_method())
		await _finish(report)
		return
	if OS.get_name() == "Windows" and RenderingServer.get_current_rendering_driver_name().to_lower() != "d3d12":
		_fail("Windows performance gate requires D3D12; current driver is %s" % RenderingServer.get_current_rendering_driver_name())
		await _finish(report)
		return
	if root.get_node_or_null("MatchConfig") == null:
		_fail("MatchConfig autoload is missing")
		await _finish(report)
		return

	_apply_target_window_state()
	await process_frame
	await process_frame
	report["sample"] = await _measure_open_ringout(warmup_seconds, sample_seconds)
	_verify_gate(report["sample"] as Dictionary, quick, sample_seconds)
	await _finish(report)


func _base_report(quick: bool, warmup_seconds: float, sample_seconds: float) -> Dictionary:
	return {
		"schema_version": 1,
		"gate": "open_ringout_dedicated_performance",
		"release_complete": false,
		"quick": quick,
		"started_at_utc": _utc_now(),
		"configuration": {
			"engine_version": Engine.get_version_info(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"video_adapter": RenderingServer.get_video_adapter_name(),
			"display_driver": DisplayServer.get_name(),
			"resolution": [_target_resolution.x, _target_resolution.y],
			"requested_window_mode": "windowed",
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
			"engine_max_fps": Engine.max_fps,
			"warmup_seconds": warmup_seconds,
			"accepted_sample_seconds_required": sample_seconds,
			"slots": "1 human + 3 AI",
		},
		"thresholds": {
			"minimum_one_percent_low_fps": MIN_ONE_PERCENT_LOW_FPS,
			"maximum_p99_frame_time_ms": MAX_P99_FRAME_TIME_MS,
			"maximum_average_draw_calls": MAX_AVERAGE_DRAW_CALLS,
		},
		"evidence": {
			"commit": _argument_value("--commit=", "unknown"),
			"files": _file_evidence(),
		},
	}


func _measure_open_ringout(warmup_seconds: float, sample_seconds: float) -> Dictionary:
	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Open Ring-Out scene is missing: %s" % SCENE_PATH)
		return {}
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load Open Ring-Out production scene")
		return {}
	var match_config := root.get_node_or_null("MatchConfig")
	match_config.set("slots", [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	])
	seed(20260719)
	Engine.time_scale = 1.0
	var arena := packed.instantiate()
	arena.name = "OpenRingoutPerformanceArena"
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame
	await physics_frame
	_apply_target_window_state()
	await process_frame
	await _wait_wall_seconds(warmup_seconds)
	_apply_target_window_state()
	await process_frame
	await process_frame
	RenderingServer.force_sync()

	var active_at_start := _active_character_count(arena)
	if active_at_start != 4:
		_fail("Open Ring-Out benchmark requires four active characters at sample start, got %d" % active_at_start)
	var focus_at_start := DisplayServer.window_is_focused()
	var mode_at_start := DisplayServer.window_get_mode()
	var client_at_start := DisplayServer.window_get_size()
	var viewport_at_start := root.size
	if not focus_at_start:
		_fail("Benchmark window is not foreground at sample start")
	if mode_at_start == DisplayServer.WINDOW_MODE_MINIMIZED:
		_fail("Benchmark window is minimized at sample start")
	if client_at_start != _target_resolution or viewport_at_start != _target_resolution:
		_fail("Benchmark client or viewport size is not 1920x1080 at sample start")
	if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		_fail("Benchmark VSync must be disabled")

	var frame_times: Array[float] = []
	var rendered_fps_samples: Array[float] = []
	var draw_call_samples: Array[float] = []
	var active_character_samples: Array[float] = []
	var spike_frames: Array[Dictionary] = []
	var rejected_samples := 0
	var rejected_unfocused_samples := 0
	var rejected_wrong_size_samples := 0
	var rejected_inactive_render_samples := 0
	var accepted_seconds := 0.0
	var started_usec := Time.get_ticks_usec()
	var previous_usec := started_usec
	var maximum_wall_seconds := sample_seconds * 3.0 + 30.0
	_focus_loss_started_usec = 0
	_focus_lost_during_sample = false
	_minimized_during_sample = false
	_wrong_client_size_during_sample = false
	_render_activity_lost_during_sample = false
	_sampling_active = true
	while accepted_seconds < sample_seconds:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		if float(now_usec - started_usec) / 1000000.0 > maximum_wall_seconds:
			_fail("Could not collect %.1f accepted seconds within %.1f wall seconds" % [sample_seconds, maximum_wall_seconds])
			break
		var window_mode := DisplayServer.window_get_mode()
		if window_mode == DisplayServer.WINDOW_MODE_MINIMIZED:
			_minimized_during_sample = true
		if not DisplayServer.window_is_focused():
			if _focus_loss_started_usec == 0:
				_focus_loss_started_usec = now_usec
			if float(now_usec - _focus_loss_started_usec) / 1000000.0 >= MATERIAL_FOCUS_LOSS_SECONDS:
				_focus_lost_during_sample = true
			rejected_unfocused_samples += 1
			rejected_samples += 1
			previous_usec = now_usec
			continue
		_focus_loss_started_usec = 0
		if DisplayServer.window_get_size() != _target_resolution or root.size != _target_resolution:
			_wrong_client_size_during_sample = true
			rejected_wrong_size_samples += 1
			rejected_samples += 1
			previous_usec = now_usec
			continue
		var draw_calls := float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if draw_calls <= 0.0:
			_render_activity_lost_during_sample = true
			rejected_inactive_render_samples += 1
			rejected_samples += 1
			previous_usec = now_usec
			continue
		var frame_seconds := float(now_usec - previous_usec) / 1000000.0
		previous_usec = now_usec
		if frame_seconds <= 0.0 or not is_finite(frame_seconds):
			rejected_samples += 1
			continue
		frame_times.append(frame_seconds)
		rendered_fps_samples.append(float(Performance.get_monitor(Performance.TIME_FPS)))
		draw_call_samples.append(draw_calls)
		active_character_samples.append(float(_active_character_count(arena)))
		if frame_seconds * 1000.0 >= SPIKE_FRAME_THRESHOLD_MS:
			_record_spike_frame(spike_frames, arena, frame_seconds, draw_calls, accepted_seconds)
		accepted_seconds += frame_seconds
	_sampling_active = false

	var focus_at_end := DisplayServer.window_is_focused()
	var mode_at_end := DisplayServer.window_get_mode()
	var client_at_end := DisplayServer.window_get_size()
	var viewport_at_end := root.size
	if _minimized_during_sample or mode_at_end == DisplayServer.WINDOW_MODE_MINIMIZED:
		_fail("Benchmark window was minimized during sampling")
	if _focus_lost_during_sample:
		_fail("Benchmark lost foreground focus for a material interval during sampling")
	if _wrong_client_size_during_sample or client_at_end != _target_resolution or viewport_at_end != _target_resolution:
		_fail("Benchmark client or viewport size changed during sampling")
	if _render_activity_lost_during_sample:
		_fail("Benchmark lost render activity during sampling")
	if not focus_at_end:
		_fail("Benchmark window is not foreground at sample end")
	if accepted_seconds < sample_seconds:
		_fail("Accepted sample duration %.3f seconds is shorter than required %.3f seconds" % [accepted_seconds, sample_seconds])
	if frame_times.size() < 30:
		_fail("Benchmark produced too few accepted frame samples: %d" % frame_times.size())
	if _minimum(active_character_samples) < 4.0:
		_fail("Open Ring-Out did not retain four active characters throughout sampling")

	var metrics := {
		"scene": SCENE_PATH,
		"frame_time_samples": frame_times.size(),
		"frame_time_average_ms": _average(frame_times) * 1000.0,
		"frame_time_p99_ms": _percentile(frame_times, 0.99) * 1000.0,
		"frame_time_max_ms": _maximum(frame_times) * 1000.0,
		"rendered_fps_average": _average(rendered_fps_samples),
		"rendered_fps_min": _minimum(rendered_fps_samples),
		"one_percent_low_fps": _one_percent_low_fps(frame_times),
		"average_draw_calls": _average(draw_call_samples),
		"maximum_draw_calls": _maximum(draw_call_samples),
		"average_active_characters": _average(active_character_samples),
		"maximum_active_characters": _maximum(active_character_samples),
		"minimum_active_characters": _minimum(active_character_samples),
		"worst_frame_samples": spike_frames,
		"accepted_sample_seconds": accepted_seconds,
		"wall_sample_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
		"rejected_samples": rejected_samples,
		"rejected_unfocused_samples": rejected_unfocused_samples,
		"rejected_wrong_size_samples": rejected_wrong_size_samples,
		"rejected_inactive_render_samples": rejected_inactive_render_samples,
		"focus_at_sample_start": focus_at_start,
		"focus_at_sample_end": focus_at_end,
		"focus_lost_for_material_interval": _focus_lost_during_sample,
		"material_focus_loss_seconds": MATERIAL_FOCUS_LOSS_SECONDS,
		"minimized_during_sample": _minimized_during_sample,
		"wrong_client_size_during_sample": _wrong_client_size_during_sample,
		"render_activity_lost_during_sample": _render_activity_lost_during_sample,
		"window_mode_at_sample_start": mode_at_start,
		"window_mode_at_sample_end": mode_at_end,
		"client_size_at_sample_start": [client_at_start.x, client_at_start.y],
		"client_size_at_sample_end": [client_at_end.x, client_at_end.y],
		"viewport_size_at_sample_start": [viewport_at_start.x, viewport_at_start.y],
		"viewport_size_at_sample_end": [viewport_at_end.x, viewport_at_end.y],
	}
	_cleanup_audio(arena)
	current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	print("METRIC open_ringout rendered_fps=%.2f one_percent_low_fps=%.2f p99_ms=%.3f avg_draw_calls=%.1f max_draw_calls=%.1f active=%.1f" % [metrics["rendered_fps_average"], metrics["one_percent_low_fps"], metrics["frame_time_p99_ms"], metrics["average_draw_calls"], metrics["maximum_draw_calls"], metrics["average_active_characters"]])
	return metrics


func _record_spike_frame(
	spike_frames: Array[Dictionary],
	arena: Node,
	frame_seconds: float,
	draw_calls: float,
	accepted_seconds: float
) -> void:
	var sample := {
		"sample_time_seconds": accepted_seconds,
		"frame_time_ms": frame_seconds * 1000.0,
		"draw_calls": draw_calls,
		"render_objects": float(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"node_count": float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"projectiles": get_nodes_in_group(&"projectile").size(),
		"active_characters": _active_character_count(arena),
		"runtime_players": get_nodes_in_group(&"player").size(),
		"runtime_ai": get_nodes_in_group(&"ai").size(),
		"temporary_clones": get_nodes_in_group(&"temporary_clone").size(),
		"clone_dissolve_effects": get_nodes_in_group(&"clone_dissolve_effect").size(),
		"weapon_pickups": get_nodes_in_group(&"weapon_pickup").size(),
		"powerup_pickups": get_nodes_in_group(&"powerup_pickup").size(),
	}
	spike_frames.append(sample)
	spike_frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["frame_time_ms"]) > float(b["frame_time_ms"])
	)
	if spike_frames.size() > MAX_RECORDED_SPIKE_FRAMES:
		spike_frames.resize(MAX_RECORDED_SPIKE_FRAMES)


func _verify_gate(sample: Dictionary, quick: bool, required_seconds: float) -> void:
	if sample.is_empty():
		_fail("Open Ring-Out performance metrics are incomplete")
		return
	if float(sample.get("accepted_sample_seconds", 0.0)) < required_seconds:
		_fail("Accepted duration is short")
	if not quick and float(sample.get("accepted_sample_seconds", 0.0)) < FORMAL_SAMPLE_SECONDS:
		_fail("Formal run requires 60 accepted seconds after warmup")
	if float(sample.get("one_percent_low_fps", 0.0)) < MIN_ONE_PERCENT_LOW_FPS:
		_fail("1%% low FPS %.2f is below %.2f" % [sample.get("one_percent_low_fps", 0.0), MIN_ONE_PERCENT_LOW_FPS])
	if float(sample.get("frame_time_p99_ms", INF)) > MAX_P99_FRAME_TIME_MS:
		_fail("p99 frame time %.3f ms exceeds %.3f ms" % [sample.get("frame_time_p99_ms", INF), MAX_P99_FRAME_TIME_MS])
	if float(sample.get("average_draw_calls", INF)) > MAX_AVERAGE_DRAW_CALLS:
		_fail("Average draw calls %.1f exceeds %.1f" % [sample.get("average_draw_calls", INF), MAX_AVERAGE_DRAW_CALLS])


func _apply_target_window_state() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	var safe_window_size := Vector2i(mini(_target_resolution.x, 960), mini(_target_resolution.y, 540))
	DisplayServer.window_set_size(safe_window_size)
	root.size = safe_window_size


func _active_character_count(arena: Node) -> int:
	var characters = arena.get("_characters")
	if characters is Array:
		var count := 0
		for character in characters:
			if is_instance_valid(character) and (character as Node).is_inside_tree():
				count += 1
		return count
	return 0


func _file_evidence() -> Dictionary:
	var paths := {
		"open_ringout_scene": SCENE_PATH,
		"open_ringout_script": MAP_SCRIPT_PATH,
		"hero_glb": HERO_GLB_PATH,
		"projectile_script": PROJECTILE_SCRIPT_PATH,
		"hud_script": HUD_SCRIPT_PATH,
	}
	var evidence := {}
	for label in paths:
		var path: String = paths[label]
		evidence[label] = {"path": path, "sha256": FileAccess.get_sha256(path)}
	return evidence


func _wait_wall_seconds(seconds: float) -> void:
	var started := Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started) / 1000000.0 < seconds:
		await process_frame


func _average(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _maximum(values: Array[float]) -> float:
	var largest := 0.0
	for value in values:
		largest = maxf(largest, value)
	return largest


func _minimum(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var smallest := values[0]
	for value in values:
		smallest = minf(smallest, value)
	return smallest


func _percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(quantile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _one_percent_low_fps(frame_times: Array[float]) -> float:
	if frame_times.is_empty():
		return 0.0
	var sorted := frame_times.duplicate()
	sorted.sort()
	sorted.reverse()
	var count := maxi(1, int(ceil(float(sorted.size()) * 0.01)))
	var total := 0.0
	for index in range(count):
		total += sorted[index]
	return 1.0 / (total / float(count)) if total > 0.0 else 0.0


func _cleanup_audio(search_root: Node) -> void:
	if search_root is AudioStreamPlayer or search_root is AudioStreamPlayer3D:
		search_root.stop()
	for child in search_root.get_children():
		_cleanup_audio(child)


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _argument_float(prefix: String, fallback: float) -> float:
	var value := _argument_value(prefix, str(fallback))
	return float(value) if value.is_valid_float() else fallback


func _argument_bool(prefix: String, fallback: bool) -> bool:
	var value := _argument_value(prefix, str(fallback)).to_lower()
	return value in ["1", "true", "yes"]


func _argument_resolution(fallback: Vector2i) -> Vector2i:
	var value := _argument_value("--resolution=", "%dx%d" % [fallback.x, fallback.y])
	var parts := value.split("x", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return fallback
	return Vector2i(int(parts[0]), int(parts[1]))


func _valid_report_path(path: String) -> bool:
	return path.begins_with("res://reports/") and path.ends_with(".json")


func _utc_now() -> String:
	return Time.get_datetime_string_from_system(true, false) + "Z"


func _on_window_focus_exited() -> void:
	if _sampling_active and _focus_loss_started_usec == 0:
		_focus_loss_started_usec = Time.get_ticks_usec()


func _write_report(report: Dictionary) -> void:
	report["ended_at_utc"] = _utc_now()
	report["failures"] = _failures
	report["passed"] = _failures.is_empty()
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write performance report: %s" % _report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _fail(message: String) -> void:
	_failures.append(message)
	# Threshold and environment invalidations are expected gate outcomes, not
	# engine faults. Actual engine/script errors still reach the wrapper logs.
	print("FAIL ", message)


func _finish(report: Dictionary) -> void:
	_sampling_active = false
	_write_report(report)
	Engine.time_scale = 1.0
	root.set_meta("disable_runtime_audio", false)
	await process_frame
	if _failures.is_empty():
		print("RESULT open_ringout_performance passed=true")
		quit(0)
		return
	print("RESULT open_ringout_performance passed=false failures=%d" % _failures.size())
	for failure in _failures:
		print("- ", failure)
	quit(1)
