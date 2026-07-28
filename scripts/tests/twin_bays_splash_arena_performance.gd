extends SceneTree

## Render-capable Forward+ benchmark for Open Ring-Out and Twin Bays.
##
## The PowerShell wrapper runs --map=open and --map=twin in separate Godot
## processes so resource caches from the first map cannot bias the second map's
## memory result. Direct invocation defaults to --map=compare as a convenient,
## shared-process diagnostic; only the wrapper output is the release gate.

const OPEN_RINGOUT_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const TWIN_BAYS_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const TWIN_BAYS_ART_V5_PERFORMANCE_PATH := \
	"res://scenes/maps/review/twin_bays_art_v5_performance.tscn"
const TWIN_BAYS_ART_V6_PERFORMANCE_PATH := \
	"res://scenes/maps/review/twin_bays_art_v6_performance.tscn"
const DEFAULT_WARMUP_SECONDS := 10.0
const DEFAULT_SAMPLE_SECONDS := 60.0
const MAX_RELATIVE_COST := 1.10
const MAX_MEMORY_DRIFT_BYTES := 5 * 1024 * 1024
const MIN_AVERAGE_FPS := 60.0
const MIN_ONE_PERCENT_LOW_FPS := 55.0
const MAX_P99_FRAME_TIME_MS := 18.2
const DEFAULT_REPORT_PATH := "res://reports/twin_bays_splash_arena_performance.json"
const DEFAULT_TARGET_RESOLUTION := Vector2i(960, 540)
const REQUIRED_WINDOWS_RENDERING_DRIVER := "d3d12"

var _failures: Array[String] = []
var _report_path := DEFAULT_REPORT_PATH
var _sampling_active := false
var _focus_lost_during_sample := false
var _minimized_during_sample := false
var _focus_abort_requested := false
var _target_resolution := DEFAULT_TARGET_RESOLUTION
var _phase_breakdown_enabled := false
var _art_v5_review_enabled := false
var _art_v6_review_enabled := false
var _benchmark_viewport: SubViewport = null


func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Splash Arena Performance]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	var headless_host := DisplayServer.get_name().to_lower() == "headless"
	if not headless_host:
		root.focus_exited.connect(_on_window_focus_exited)
	var test_window_policy := root.get_node_or_null("TestWindowPolicy")
	# Keep the benchmark representative if Windows changes foreground focus;
	# minimization is still treated as an invalid measurement environment.
	OS.low_processor_usage_mode = false

	_report_path = _argument_value("--report=", DEFAULT_REPORT_PATH)
	_target_resolution = _argument_resolution(DEFAULT_TARGET_RESOLUTION)
	_phase_breakdown_enabled = "--phase-breakdown" in OS.get_cmdline_user_args()
	_art_v5_review_enabled = "--art-v5-review" in OS.get_cmdline_user_args()
	_art_v6_review_enabled = "--art-v6-review" in OS.get_cmdline_user_args()
	if _art_v5_review_enabled and _art_v6_review_enabled:
		_fail("Only one isolated art review route can be enabled")
		await _finish({})
		return
	if not _is_valid_report_path(_report_path):
		_fail("Performance report must be a JSON file under res://reports/")
		_report_path = DEFAULT_REPORT_PATH

	var rendering_method := RenderingServer.get_current_rendering_method()
	if rendering_method != "forward_plus":
		_fail("Performance gate requires Forward+; current method is %s" % rendering_method)
		await _finish({})
		return
	var rendering_driver := RenderingServer.get_current_rendering_driver_name().to_lower()
	if OS.get_name() == "Windows" and rendering_driver != REQUIRED_WINDOWS_RENDERING_DRIVER:
		_fail(
			"Windows performance gate requires the production D3D12 driver; current driver is %s"
			% rendering_driver
		)
		await _finish({})
		return
	if root.get_node_or_null("MatchConfig") == null:
		_fail("MatchConfig autoload is missing")
		await _finish({})
		return

	_apply_target_window_state()
	_setup_benchmark_viewport()
	await process_frame
	await process_frame
	if _benchmark_viewport == null or _benchmark_viewport.size != _target_resolution:
		_fail("Benchmark render target is not %s" % str(_target_resolution))

	var warmup_seconds := clampf(
		_argument_float("--warmup=", DEFAULT_WARMUP_SECONDS),
		1.0,
		DEFAULT_WARMUP_SECONDS
	)
	var sample_seconds := clampf(
		_argument_float("--sample=", DEFAULT_SAMPLE_SECONDS),
		3.0,
		DEFAULT_SAMPLE_SECONDS
	)
	var map_mode := _argument_value("--map=", "compare").to_lower()
	if map_mode not in ["open", "twin", "compare"]:
		_fail("--map must be open, twin, or compare")
		await _finish({})
		return

	var report := _base_report(map_mode, warmup_seconds, sample_seconds)
	var twin_bays_scene_path := TWIN_BAYS_PATH
	if _art_v6_review_enabled:
		twin_bays_scene_path = TWIN_BAYS_ART_V6_PERFORMANCE_PATH
	elif _art_v5_review_enabled:
		twin_bays_scene_path = TWIN_BAYS_ART_V5_PERFORMANCE_PATH
	match map_mode:
		"open":
			var open_sample := await _measure_scene(
				OPEN_RINGOUT_PATH, "open_ringout", warmup_seconds, sample_seconds
			)
			report["sample"] = open_sample
		"twin":
			var twin_sample := await _measure_scene(
				twin_bays_scene_path, "twin_bays", warmup_seconds, sample_seconds
			)
			report["sample"] = twin_sample
			_verify_absolute_twin_gate(twin_sample)
		"compare":
			var baseline := await _measure_scene(
				OPEN_RINGOUT_PATH, "open_ringout", warmup_seconds, sample_seconds
			)
			var twin_bays := await _measure_scene(
				twin_bays_scene_path, "twin_bays", warmup_seconds, sample_seconds
			)
			report["open_ringout"] = baseline
			report["twin_bays"] = twin_bays
			report["isolation"] = "shared_process_diagnostic"
			report["ratios"] = _verify_comparison_gate(baseline, twin_bays)

	await _finish(report)


func _base_report(map_mode: String, warmup_seconds: float, sample_seconds: float) -> Dictionary:
	return {
		"schema_version": 1,
		"mode": "single_process_sample" if map_mode != "compare" else "shared_process_comparison",
		"map": map_mode,
		"configuration": {
			"engine_version": Engine.get_version_info(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"video_adapter": RenderingServer.get_video_adapter_name(),
			"display_driver": DisplayServer.get_name(),
			"resolution": [_target_resolution.x, _target_resolution.y],
			"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
			"viewport_size": [_benchmark_viewport.size.x, _benchmark_viewport.size.y],
			"host_window_size": [root.size.x, root.size.y],
			"render_target": "always_updating_offscreen_subviewport",
			"window_mode": DisplayServer.window_get_mode(),
			"borderless": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
			"no_focus": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),
			"always_on_top": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP),
			"slots": "1 human + 3 AI",
			"warmup_seconds": warmup_seconds,
			"sample_seconds": sample_seconds,
			"vsync_mode": (
				DisplayServer.VSYNC_DISABLED
				if DisplayServer.get_name().to_lower() == "headless"
				else DisplayServer.window_get_vsync_mode()
			),
			"engine_max_fps": Engine.max_fps,
			"low_processor_usage_mode": OS.low_processor_usage_mode,
			"art_v5_review": _art_v5_review_enabled,
			"art_v6_review": _art_v6_review_enabled,
			"focus_policy": (
				"headless host; %dx%d UPDATE_ALWAYS SubViewport is authoritative"
				% [_target_resolution.x, _target_resolution.y]
				if DisplayServer.get_name().to_lower() == "headless"
				else "formal sample requires one focused, non-minimized host window"
			),
		},
	}


func _apply_target_window_state() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		var headless_window_size := Vector2i(mini(_target_resolution.x, 960), mini(_target_resolution.y, 540))
		root.size = headless_window_size
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, false)
	var safe_window_size := Vector2i(mini(_target_resolution.x, 960), mini(_target_resolution.y, 540))
	DisplayServer.window_set_size(safe_window_size)
	root.size = safe_window_size


func _setup_benchmark_viewport() -> void:
	if _benchmark_viewport and is_instance_valid(_benchmark_viewport):
		return
	_benchmark_viewport = SubViewport.new()
	_benchmark_viewport.name = "PerformanceRenderTarget1080p"
	_benchmark_viewport.size = _target_resolution
	_benchmark_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_benchmark_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_benchmark_viewport.transparent_bg = false
	root.add_child(_benchmark_viewport)


func _measure_scene(
	scene_path: String,
	label: String,
	warmup_seconds: float,
	sample_seconds: float
) -> Dictionary:
	print("\n--- Measuring %s ---" % label)
	if not ResourceLoader.exists(scene_path):
		_fail("Scene is missing: %s" % scene_path)
		return {}
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("Could not load scene: %s" % scene_path)
		return {}

	seed(20260716)
	Engine.time_scale = 1.0
	var match_config := root.get_node_or_null("MatchConfig")
	match_config.set("slots", [
		match_config.SlotType.HUMAN,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
		match_config.SlotType.AI,
	])

	var orphan_nodes_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var object_count_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var arena := packed.instantiate()
	arena.name = "%sPerformanceArena" % label
	_benchmark_viewport.add_child(arena)
	await process_frame
	await process_frame
	await physics_frame
	if label == "twin_bays" and _art_v5_review_enabled \
			and not bool(arena.get_meta("art_v5_performance_direct", false)):
		_fail("Art V5 direct performance route did not initialize")
		return {}
	if label == "twin_bays" and _art_v6_review_enabled \
			and not bool(arena.get_meta("art_v6_performance_direct", false)):
		_fail("Art V6 direct performance route did not initialize")
		return {}
	# Arena startup can reapply the project's default 960x540 window. Restore
	# the production 1080p target after scene instantiation, before warmup.
	_apply_target_window_state()
	await process_frame
	await process_frame
	await _wait_wall_seconds(warmup_seconds)
	# Bind the actual sample to 1080p even if a runtime resize signal fired
	# during warmup. This happens before timing and shader synchronization.
	_apply_target_window_state()
	await process_frame
	await process_frame
	RenderingServer.force_sync()
	var headless_sample := DisplayServer.get_name().to_lower() == "headless"
	var focus_at_sample_start := true if headless_sample else DisplayServer.window_is_focused()
	var focus_lock_at_sample_start := false if headless_sample else DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP)
	var window_mode_at_sample_start := -1 if headless_sample else DisplayServer.window_get_mode()
	var vsync_at_sample_start := (
		DisplayServer.VSYNC_DISABLED
		if headless_sample
		else DisplayServer.window_get_vsync_mode()
	)
	var window_size_at_sample_start := DisplayServer.window_get_size()
	var viewport_size_at_sample_start := _benchmark_viewport.size
	if viewport_size_at_sample_start != _target_resolution:
		_fail("%s benchmark resolution changed before sampling" % label)
	if vsync_at_sample_start != DisplayServer.VSYNC_DISABLED:
		_fail("%s benchmark VSync is not disabled" % label)

	var frame_time_samples: Array[float] = []
	var draw_call_samples: Array[float] = []
	var primitive_samples: Array[float] = []
	var video_memory_samples: Array[float] = []
	var static_memory_samples: Array[float] = []
	var sample_times: Array[float] = []
	var tide_phase_frame_times: Dictionary = {}
	var tide_controller := arena.find_child("TwinBaysTideController", true, false)
	var rejected_frame_samples := 0
	var rejected_unfocused_frames := 0
	var rejected_focus_recovery_frames := 0
	var started_usec := Time.get_ticks_usec()
	var previous_usec := started_usec
	var accepted_sample_seconds := 0.0
	var focus_recovery_frames := 0
	var maximum_wall_seconds := sample_seconds * 3.0 + 30.0
	_focus_lost_during_sample = false
	_minimized_during_sample = false
	_focus_abort_requested = false
	_sampling_active = true
	while accepted_sample_seconds < sample_seconds:
		await process_frame
		if headless_sample:
			# A headless host has no swapchain to schedule automatically. Force
			# the UPDATE_ALWAYS 1080p SubViewport through the D3D12 renderer so
			# timing and RenderingServer counters describe real GPU work.
			RenderingServer.force_draw(false, 0.0)
		if _focus_abort_requested:
			_fail("%s benchmark lost focus during sampling" % label)
			break
		var now_usec := Time.get_ticks_usec()
		var wall_seconds := float(now_usec - started_usec) / 1000000.0
		if wall_seconds > maximum_wall_seconds:
			_fail("%s could not collect %.1f focused seconds within %.1f wall seconds" % [
				label, sample_seconds, maximum_wall_seconds
			])
			break
		if not headless_sample:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
				_minimized_during_sample = true
			if not DisplayServer.window_is_focused():
				rejected_unfocused_frames += 1
		# The 1080p SubViewport is UPDATE_ALWAYS, so desktop focus and host
		# minimization are recorded diagnostics rather than sample rejection.
		var frame_seconds := float(now_usec - previous_usec) / 1000000.0
		previous_usec = now_usec
		if frame_seconds > 0.0:
			frame_time_samples.append(frame_seconds)
			accepted_sample_seconds += frame_seconds
			if _phase_breakdown_enabled and label == "twin_bays" and tide_controller:
				var tide_phase := String(tide_controller.get("_phase"))
				if not tide_phase_frame_times.has(tide_phase):
					tide_phase_frame_times[tide_phase] = []
				(tide_phase_frame_times[tide_phase] as Array).append(frame_seconds)
		else:
			rejected_frame_samples += 1
		draw_call_samples.append(float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		)))
		primitive_samples.append(float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
		)))
		video_memory_samples.append(float(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_VIDEO_MEM_USED
		)))
		static_memory_samples.append(float(Performance.get_monitor(Performance.MEMORY_STATIC)))
		sample_times.append(accepted_sample_seconds)
	var focus_at_sample_end := true if headless_sample else DisplayServer.window_is_focused()
	var window_mode_at_sample_end := -1 if headless_sample else DisplayServer.window_get_mode()
	_sampling_active = false
	if not headless_sample:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	if rejected_frame_samples > 0:
		_fail("%s rejected %d non-positive frame-time samples" % [label, rejected_frame_samples])

	var peak_video_memory := _maximum(video_memory_samples)
	var peak_static_memory := _maximum(static_memory_samples)
	var render_memory_proxy := peak_video_memory if peak_video_memory > 0.0 else peak_static_memory
	var render_memory_proxy_source := "video_memory" if peak_video_memory > 0.0 else "static_memory_fallback"
	var metrics := {
		"scene": scene_path,
		"average_fps": _average_fps(frame_time_samples),
		"one_percent_low_fps": _one_percent_low_fps(frame_time_samples),
		"worst_one_percent_sample_count": maxi(1, int(ceil(float(frame_time_samples.size()) * 0.01))),
		"frame_time_p95_ms": _percentile(frame_time_samples, 0.95) * 1000.0,
		"frame_time_p99_ms": _percentile(frame_time_samples, 0.99) * 1000.0,
		"frame_time_p99_9_ms": _percentile(frame_time_samples, 0.999) * 1000.0,
		"maximum_frame_time_ms": _maximum(frame_time_samples) * 1000.0,
		"frames_over_18_18_ms": _count_over(frame_time_samples, 0.01818),
		"frames_over_25_ms": _count_over(frame_time_samples, 0.025),
		"frames_over_33_33_ms": _count_over(frame_time_samples, 0.03333),
		"average_draw_calls": _average(draw_call_samples),
		"peak_draw_calls": _maximum(draw_call_samples),
		"average_primitives": _average(primitive_samples),
		"peak_primitives": _maximum(primitive_samples),
		"peak_video_memory_bytes": peak_video_memory,
		"peak_static_memory_bytes": peak_static_memory,
		"render_memory_proxy_bytes": render_memory_proxy,
		"render_memory_proxy_source": render_memory_proxy_source,
		"memory_drift_bytes": _tail_memory_drift(static_memory_samples, sample_times),
		"sampled_frames": frame_time_samples.size(),
		"rejected_frame_samples": rejected_frame_samples,
		"rejected_unfocused_frames": rejected_unfocused_frames,
		"rejected_focus_recovery_frames": rejected_focus_recovery_frames,
		"accepted_sample_seconds": accepted_sample_seconds,
		"wall_sample_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
		"orphan_nodes_before": orphan_nodes_before,
		"objects_before": object_count_before,
		"focus_at_sample_start": focus_at_sample_start,
		"focus_at_sample_end": focus_at_sample_end,
		"focus_lock_at_sample_start": focus_lock_at_sample_start,
		"focus_lost_during_sample": _focus_lost_during_sample,
		"minimized_during_sample": _minimized_during_sample,
		"window_mode_at_sample_start": window_mode_at_sample_start,
		"window_mode_at_sample_end": window_mode_at_sample_end,
		"vsync_mode_at_sample_start": vsync_at_sample_start,
		"window_size_at_sample_start": [window_size_at_sample_start.x, window_size_at_sample_start.y],
		"viewport_size_at_sample_start": [viewport_size_at_sample_start.x, viewport_size_at_sample_start.y],
		"render_target_update_mode": _benchmark_viewport.render_target_update_mode,
	}
	if _phase_breakdown_enabled and not tide_phase_frame_times.is_empty():
		metrics["tide_phase_performance"] = _phase_performance(tide_phase_frame_times)

	_cleanup_audio_players(arena)
	current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	RenderingServer.force_sync()
	var orphan_nodes_after := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var object_count_after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	metrics["orphan_nodes_after"] = orphan_nodes_after
	metrics["orphan_node_delta"] = orphan_nodes_after - orphan_nodes_before
	metrics["objects_after"] = object_count_after
	metrics["object_count_delta"] = object_count_after - object_count_before
	if orphan_nodes_after > orphan_nodes_before:
		_fail("%s unload leaked %d orphan nodes" % [label, orphan_nodes_after - orphan_nodes_before])
	if frame_time_samples.size() < 30:
		_fail("%s produced too few valid frame samples: %d" % [label, frame_time_samples.size()])

	print("%s avg=%.2f 1%%low=%.2f draws=%.1f primitives=%.1f render_mem=%.1fMiB drift=%.2fMiB" % [
		label,
		metrics["average_fps"],
		metrics["one_percent_low_fps"],
		metrics["average_draw_calls"],
		metrics["average_primitives"],
		float(metrics["render_memory_proxy_bytes"]) / 1048576.0,
		float(metrics["memory_drift_bytes"]) / 1048576.0,
	])
	return metrics


func _verify_absolute_twin_gate(twin_bays: Dictionary) -> void:
	if twin_bays.is_empty():
		_fail("Twin Bays performance metrics are incomplete")
		return
	if float(twin_bays["average_fps"]) < MIN_AVERAGE_FPS:
		_fail("Twin Bays average FPS %.2f is below %.2f" % [twin_bays["average_fps"], MIN_AVERAGE_FPS])
	if float(twin_bays["one_percent_low_fps"]) < MIN_ONE_PERCENT_LOW_FPS:
		_fail("Twin Bays 1%% low %.2f is below %.2f" % [twin_bays["one_percent_low_fps"], MIN_ONE_PERCENT_LOW_FPS])
	if float(twin_bays["frame_time_p99_ms"]) > MAX_P99_FRAME_TIME_MS:
		_fail("Twin Bays p99 frame time %.2f ms exceeds %.2f ms" % [
			twin_bays["frame_time_p99_ms"],
			MAX_P99_FRAME_TIME_MS,
		])
	if float(twin_bays["memory_drift_bytes"]) > float(MAX_MEMORY_DRIFT_BYTES):
		_fail("Twin Bays final-30-second memory drift %.2f MiB exceeds 5 MiB" % (
			float(twin_bays["memory_drift_bytes"]) / 1048576.0
		))
	if int(twin_bays["orphan_node_delta"]) > 0:
		_fail("Twin Bays unload left orphan nodes")


func _verify_comparison_gate(baseline: Dictionary, twin_bays: Dictionary) -> Dictionary:
	print("\n--- Performance Gate ---")
	if baseline.is_empty() or twin_bays.is_empty():
		_fail("Performance metrics are incomplete")
		return {}
	_verify_absolute_twin_gate(twin_bays)
	var ratios := {
		"draw_calls": _verify_relative_metric(baseline, twin_bays, "average_draw_calls", "draw calls"),
		"primitives": _verify_relative_metric(baseline, twin_bays, "average_primitives", "primitives"),
		"render_memory_proxy": _verify_relative_metric(
			baseline, twin_bays, "render_memory_proxy_bytes", "render memory proxy"
		),
	}
	if _failures.is_empty():
		print("OK  FPS, relative render cost, memory drift, and unload gates")
	return ratios


func _verify_relative_metric(
	baseline: Dictionary,
	target: Dictionary,
	key: String,
	label: String
) -> float:
	var baseline_value := float(baseline.get(key, 0.0))
	var target_value := float(target.get(key, 0.0))
	if baseline_value <= 0.0:
		if target_value > 0.0:
			_fail("Cannot compare %s because Open Ring-Out reported zero" % label)
		return INF if target_value > 0.0 else 1.0
	var ratio := target_value / baseline_value
	print("RATIO  %s=%.3f" % [label, ratio])
	if ratio > MAX_RELATIVE_COST:
		_fail("Twin Bays %s ratio %.3f exceeds %.2f" % [label, ratio, MAX_RELATIVE_COST])
	return ratio


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


func _percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(quantile * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _count_over(values: Array[float], threshold: float) -> int:
	var count := 0
	for value in values:
		if value > threshold:
			count += 1
	return count


func _phase_performance(samples_by_phase: Dictionary) -> Dictionary:
	var result := {}
	for phase_value: Variant in samples_by_phase.keys():
		var phase := String(phase_value)
		var untyped := samples_by_phase[phase_value] as Array
		var samples: Array[float] = []
		for value: Variant in untyped:
			samples.append(float(value))
		result[phase] = {
			"sampled_frames": samples.size(),
			"average_fps": _average_fps(samples),
			"one_percent_low_fps": _one_percent_low_fps(samples),
			"frame_time_p95_ms": _percentile(samples, 0.95) * 1000.0,
			"frame_time_p99_ms": _percentile(samples, 0.99) * 1000.0,
			"maximum_frame_time_ms": _maximum(samples) * 1000.0,
			"frames_over_18_18_ms": _count_over(samples, 0.01818),
			"frames_over_25_ms": _count_over(samples, 0.025),
			"frames_over_33_33_ms": _count_over(samples, 0.03333),
		}
	return result


func _average_fps(frame_times: Array[float]) -> float:
	var total_seconds := 0.0
	for frame_time in frame_times:
		total_seconds += frame_time
	return float(frame_times.size()) / total_seconds if total_seconds > 0.0 else 0.0


func _one_percent_low_fps(frame_times: Array[float]) -> float:
	if frame_times.is_empty():
		return 0.0
	var sorted := frame_times.duplicate()
	sorted.sort()
	sorted.reverse()
	var worst_count := maxi(1, int(ceil(float(sorted.size()) * 0.01)))
	var worst_total := 0.0
	for index in range(worst_count):
		worst_total += sorted[index]
	var worst_average := worst_total / float(worst_count)
	return 1.0 / worst_average if worst_average > 0.0 else 0.0


func _tail_memory_drift(samples: Array[float], sample_times: Array[float]) -> float:
	if samples.size() < 2 or samples.size() != sample_times.size():
		return 0.0
	var cutoff := maxf(0.0, sample_times[-1] - 30.0)
	var start_index := 0
	for index in range(sample_times.size()):
		if sample_times[index] >= cutoff:
			start_index = index
			break
	return maxf(0.0, samples[-1] - samples[start_index])


func _cleanup_audio_players(search_root: Node) -> void:
	if search_root is AudioStreamPlayer or search_root is AudioStreamPlayer3D:
		search_root.stop()
	for child in search_root.get_children():
		_cleanup_audio_players(child)


func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback


func _argument_float(prefix: String, fallback: float) -> float:
	var value := _argument_value(prefix, str(fallback))
	return float(value) if value.is_valid_float() else fallback


func _argument_resolution(fallback: Vector2i) -> Vector2i:
	var width := _argument_value("--benchmark-width=", str(fallback.x)).to_int()
	var height := _argument_value("--benchmark-height=", str(fallback.y)).to_int()
	if width < 320 or height < 180:
		_fail("Benchmark resolution must be at least 320x180")
		return fallback
	return Vector2i(width, height)


func _is_valid_report_path(path: String) -> bool:
	return path.begins_with("res://reports/") and path.ends_with(".json")


func _write_report(report: Dictionary) -> void:
	report["failures"] = _failures
	report["passed"] = _failures.is_empty()
	report["generated_at_unix"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write performance report: %s" % _report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _on_window_focus_exited() -> void:
	if _sampling_active:
		_focus_lost_during_sample = true
		_focus_abort_requested = true
		_minimized_during_sample = (
			_minimized_during_sample
			or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
		)


func _finish(report: Dictionary) -> void:
	_write_report(report)
	_sampling_active = false
	Engine.time_scale = 1.0
	current_scene = null
	root.set_meta("disable_runtime_audio", false)
	if root.focus_exited.is_connected(_on_window_focus_exited):
		root.focus_exited.disconnect(_on_window_focus_exited)

	# Godot 4.6 on Windows can tear down the Vulkan swapchain while queued
	# frames are still retiring. Both benchmark samples have already unloaded
	# their arenas at this point, so release the focus-only window flag and give
	# RenderingServer a deterministic drain point before exiting. Do not toggle
	# BORDERLESS here: that recreates the swapchain during shutdown and is one
	# of the failure modes this drain is intended to avoid. A native shutdown
	# crash remains a release-gate failure; this is lifecycle cleanup, not a
	# wrapper exception for that failure.
	var has_render_window := DisplayServer.get_name().to_lower() != "headless"
	if has_render_window:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	await process_frame
	await process_frame
	if has_render_window:
		RenderingServer.force_sync()
	# Let deferred viewport/window frees run after the final synchronized draw.
	# Do not await frame_post_draw after current_scene has been cleared: Windows
	# can stop scheduling draw notifications for that empty viewport, leaving a
	# completed benchmark process alive forever while the wrapper waits.
	await create_timer(0.35, true, false, true).timeout
	if has_render_window:
		RenderingServer.force_sync()
	await process_frame

	print("==================================================")
	var exit_code := 0 if _failures.is_empty() else 1
	if _failures.is_empty():
		print("[Twin Bays Splash Arena Performance] PASS")
	else:
		print("[Twin Bays Splash Arena Performance] FAIL")
		for failure in _failures:
			print("- ", failure)
	quit(exit_code)
