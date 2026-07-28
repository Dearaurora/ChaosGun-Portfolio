extends Node
class_name PartyShooterCameraDirector

const RINGOUT_HUD_SCRIPT = preload("res://scripts/ui/ringout_hud.gd")

const FOCUS_SMOOTH_TIME := 0.28
const ZOOM_IN_SMOOTH_TIME := 0.52
const ZOOM_OUT_SMOOTH_TIME := 0.24
const MAX_CAMERA_DELTA := 0.05
const FOCUS_CENTROID_WEIGHT := 0.30
const VELOCITY_LOOK_AHEAD := 0.16
const MAX_LOOK_AHEAD := 3.5
const MAX_RENDER_PREDICTION_DISTANCE := 0.75
const OCCLUSION_SEARCH_ITERATIONS := 14
const OCCLUSION_SIZE_EPSILON := 0.02
const DISCONTINUITY_HOLD_DURATION := 0.10
const DISCONTINUITY_RETRIGGER_HOLD_DURATION := 0.05
const DISCONTINUITY_ANCHOR_DURATION := 0.60
const DISCONTINUITY_RECOVER_SMOOTH_TIME := 0.55
const DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND := 0.55
const DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND_SQUARED := 1.25
const DISCONTINUITY_SETTLE_DISTANCE := 1.5
const DISCONTINUITY_SETTLE_SIZE_RATIO := 0.025
const DISCONTINUITY_MAX_RECOVER_DURATION := 2.4
const BEHAVIOR_CONTRACT_VERSION := 3

# The toy-island camera establishes the party shooter's downward tilt. Arenas
# may choose a different horizontal yaw to keep map mechanics readable, but the
# pitch and follow behavior remain global.
const STANDARD_GAMEPLAY_VIEW_OFFSET := Vector3(38.0, 50.0, 53.0)
const STANDARD_GAMEPLAY_PITCH_TANGENT := 0.766694438545985
const STANDARD_GAMEPLAY_DOWNWARD_PITCH_DEGREES := 37.4771817105026

var _camera: Camera3D = null
var _enabled := true
var _profile_id := "party_shooter"
var _map_focus := Vector3(0.0, 1.0, 0.0)
var _view_offset := STANDARD_GAMEPLAY_VIEW_OFFSET
var _initial_size := 58.0
var _idle_overview_size := 62.0
var _min_size := 36.0
var _max_size := 92.0
var _discontinuity_max_size := 132.0
var _playable_min := Vector2(-48.0, -39.0)
var _playable_max := Vector2(48.0, 39.0)
var _focus_min := Vector2(-43.0, -33.0)
var _focus_max := Vector2(44.0, 34.0)
var _track_min_y := -2.0
var _world_frame_padding := 4.5
var _character_screen_radius := 3.2
var _screen_edge_gutter := 20.0
var _min_layout_viewport := Vector2(640.0, 360.0)
var _fallback_layout_viewport := Vector2(1152.0, 648.0)
var _reserve_corner_hud := true
var _hud_occlusion_regions: Array = []
var _hud_occlusion_group: StringName = &""
var _hud_occlusion_gutter := 0.0
var _reveal_focus := Vector3(0.0, 1.0, 0.0)
var _reveal_size := 76.0
var _reveal_duration := 1.35
var _winner_focus_size := 38.5
var _winner_focus_duration := 0.72

var _current_focus := Vector3.ZERO
var _target_focus := Vector3.ZERO
var _target_size := 58.0
var _focus_velocity := Vector3.ZERO
var _zoom_velocity := 0.0
var _view_basis := Basis.IDENTITY
var _screen_right := Vector3.RIGHT
var _screen_up := Vector3.UP
var _physics_tick_seconds := 1.0 / 60.0
var _tracked_count := 0
var _hud_panel_count := 0
var _viewport_size := Vector2.ZERO
var _presentation_mode: StringName = &"none"
var _presentation_elapsed := 0.0
var _presentation_duration := 0.0
var _presentation_start_focus := Vector3.ZERO
var _presentation_start_size := 58.0
var _presentation_target: Node3D = null
var _spatial_discontinuity_pending := false
var _discontinuity_phase: StringName = &"idle"
var _discontinuity_hold_remaining := 0.0
var _discontinuity_elapsed := 0.0
var _discontinuity_event_serial := 0
var _discontinuity_events: Array[Dictionary] = []
var _discontinuity_safety_size := 0.0
var _discontinuity_focus_speed := 0.0
var _discontinuity_pan_velocity := Vector3.ZERO


static func view_offset_with_standard_pitch(horizontal_x: float, horizontal_z: float) -> Vector3:
	var horizontal_length := Vector2(horizontal_x, horizontal_z).length()
	if horizontal_length <= 0.001:
		return STANDARD_GAMEPLAY_VIEW_OFFSET
	return Vector3(
		horizontal_x,
		horizontal_length * STANDARD_GAMEPLAY_PITCH_TANGENT,
		horizontal_z
	)


static func downward_pitch_degrees(view_offset: Vector3) -> float:
	var horizontal_length := Vector2(view_offset.x, view_offset.z).length()
	return rad_to_deg(atan2(view_offset.y, horizontal_length))


func configure(camera: Camera3D, profile: Dictionary = {}) -> void:
	_camera = camera
	_apply_profile(profile)
	_current_focus = _map_focus
	_target_focus = _map_focus
	_target_size = _initial_size
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0
	_clear_spatial_discontinuity()
	if _camera == null:
		return
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = _initial_size
	_camera.current = true
	_camera.position = _current_focus + _view_offset
	_camera.look_at(_current_focus, Vector3.UP)
	_view_basis = _camera.transform.basis
	_screen_right = _camera.global_transform.basis.x.normalized()
	_screen_up = _camera.global_transform.basis.y.normalized()
	var physics_ticks := float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60.0))
	_physics_tick_seconds = 1.0 / maxf(physics_ticks, 1.0)


func _apply_profile(profile: Dictionary) -> void:
	_profile_id = String(profile.get("profile_id", _profile_id))
	_map_focus = profile.get("map_focus", _map_focus) as Vector3
	# Map profiles may rotate horizontally when their mechanics need a different
	# presentation. Rebuild Y from the toy-island pitch so downward tilt cannot
	# silently drift between maps.
	var requested_view_offset := profile.get("view_offset", STANDARD_GAMEPLAY_VIEW_OFFSET) as Vector3
	var requested_horizontal := Vector2(requested_view_offset.x, requested_view_offset.z)
	if requested_horizontal.length() <= 0.001:
		push_warning("Party-shooter map profile has no horizontal viewing direction; using toy-island default")
		_view_offset = STANDARD_GAMEPLAY_VIEW_OFFSET
	else:
		_view_offset = view_offset_with_standard_pitch(requested_view_offset.x, requested_view_offset.z)
		if absf(requested_view_offset.y - _view_offset.y) > 0.001:
			push_warning(
				"Party-shooter map pitch corrected to %.3f degrees: %s -> %s" % [
					STANDARD_GAMEPLAY_DOWNWARD_PITCH_DEGREES,
					requested_view_offset,
					_view_offset,
				]
			)
	_initial_size = float(profile.get("initial_size", _initial_size))
	_idle_overview_size = float(profile.get("idle_overview_size", _idle_overview_size))
	_min_size = float(profile.get("min_size", _min_size))
	_max_size = float(profile.get("max_size", _max_size))
	_discontinuity_max_size = maxf(
		float(profile.get("discontinuity_max_size", _max_size * 1.45)),
		_max_size
	)
	_playable_min = profile.get("playable_min", _playable_min) as Vector2
	_playable_max = profile.get("playable_max", _playable_max) as Vector2
	_focus_min = profile.get("focus_min", _focus_min) as Vector2
	_focus_max = profile.get("focus_max", _focus_max) as Vector2
	_track_min_y = float(profile.get("track_min_y", _track_min_y))
	_world_frame_padding = float(profile.get("world_frame_padding", _world_frame_padding))
	_character_screen_radius = float(profile.get("character_screen_radius", _character_screen_radius))
	_screen_edge_gutter = float(profile.get("screen_edge_gutter", _screen_edge_gutter))
	_min_layout_viewport = profile.get("min_layout_viewport", _min_layout_viewport) as Vector2
	_fallback_layout_viewport = profile.get("fallback_layout_viewport", _fallback_layout_viewport) as Vector2
	_reserve_corner_hud = bool(profile.get("reserve_corner_hud", _reserve_corner_hud))
	_hud_occlusion_regions = (profile.get("hud_occlusion_regions", []) as Array).duplicate(true)
	_hud_occlusion_group = StringName(profile.get("hud_occlusion_group", _hud_occlusion_group))
	_hud_occlusion_gutter = maxf(float(profile.get("hud_occlusion_gutter", _hud_occlusion_gutter)), 0.0)
	_reveal_focus = profile.get("reveal_focus", _map_focus) as Vector3
	_reveal_size = float(profile.get("reveal_size", _reveal_size))
	_reveal_duration = float(profile.get("reveal_duration", _reveal_duration))
	_winner_focus_size = float(profile.get("winner_focus_size", _winner_focus_size))
	_winner_focus_duration = float(profile.get("winner_focus_duration", _winner_focus_duration))
	_initial_size = clampf(_initial_size, _min_size, _max_size)
	_idle_overview_size = clampf(_idle_overview_size, _min_size, _max_size)
	_reveal_size = clampf(_reveal_size, _min_size, _max_size)
	_winner_focus_size = clampf(_winner_focus_size, maxf(18.0, _min_size * 0.65), _max_size)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func notify_spatial_discontinuity(
	subject: Node3D = null,
	source_world: Variant = null,
	destination_world: Variant = null
) -> void:
	# Presentation cameras own focus absolutely. Absorb late deferred portal
	# signals instead of leaving a stale transition for after the reveal/result.
	if _presentation_mode != &"none":
		return
	if subject is BaseCharacter:
		var character := subject as BaseCharacter
		if character.is_dead or character.is_game_over:
			return

	var was_active := _discontinuity_phase != &"idle"
	_discontinuity_phase = &"hold"
	_discontinuity_hold_remaining = maxf(
		_discontinuity_hold_remaining,
		DISCONTINUITY_RETRIGGER_HOLD_DURATION if was_active else DISCONTINUITY_HOLD_DURATION
	)
	_discontinuity_elapsed = 0.0
	_discontinuity_event_serial += 1
	_discontinuity_safety_size = maxf(_discontinuity_safety_size, _camera.size if _camera else 0.0)
	_discontinuity_focus_speed = 0.0
	_discontinuity_pan_velocity = Vector3.ZERO
	_focus_velocity = Vector3.ZERO
	_register_discontinuity_event(subject, source_world, destination_world)
	_spatial_discontinuity_pending = true


func begin_arena_reveal(duration: float = -1.0) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	_clear_spatial_discontinuity()
	_presentation_mode = &"reveal"
	_presentation_elapsed = 0.0
	_presentation_duration = maxf(duration if duration > 0.0 else _reveal_duration, 0.01)
	_presentation_start_focus = _reveal_focus
	_presentation_start_size = _reveal_size
	_presentation_target = null
	_current_focus = _presentation_start_focus
	_camera.size = _presentation_start_size
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0
	_apply_camera_transform()


func begin_winner_focus(target: Node3D, duration: float = -1.0) -> void:
	if _camera == null or not is_instance_valid(_camera) or target == null or not is_instance_valid(target):
		return
	_clear_spatial_discontinuity()
	_presentation_mode = &"winner_focus"
	_presentation_elapsed = 0.0
	_presentation_duration = maxf(duration if duration > 0.0 else _winner_focus_duration, 0.01)
	_presentation_start_focus = _current_focus
	_presentation_start_size = _camera.size
	_presentation_target = target
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0


func settle_winner_focus() -> void:
	if _presentation_mode != &"winner_focus" or _camera == null \
		or _presentation_target == null or not is_instance_valid(_presentation_target):
		return
	var winner_focus := _clamp_track_point(_presentation_target.global_position)
	_current_focus = winner_focus
	_target_focus = winner_focus
	_target_size = _winner_focus_size
	_camera.size = _winner_focus_size
	_presentation_mode = &"winner_hold"
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0
	_apply_camera_transform()


func release_presentation_override() -> void:
	_presentation_mode = &"none"
	_presentation_target = null
	_focus_velocity = Vector3.ZERO
	_zoom_velocity = 0.0


func update_camera(characters: Array, delta: float) -> void:
	if not _enabled or _camera == null or not is_instance_valid(_camera):
		return

	_viewport_size = _camera.get_viewport().get_visible_rect().size
	if _viewport_size.x < _min_layout_viewport.x or _viewport_size.y < _min_layout_viewport.y:
		# Headless tests expose a synthetic viewport where production HUD layout cannot exist.
		_viewport_size = _fallback_layout_viewport

	var camera_delta := _unscaled_camera_delta(delta)
	var sample := _collect_tracking_sample(characters)
	var points := sample.get("points", []) as Array
	var average_velocity := sample.get("average_velocity", Vector3.ZERO) as Vector3
	_tracked_count = points.size()
	_hud_panel_count = clampi(characters.size(), 0, 4) if _reserve_corner_hud else 0

	var transition_active := _discontinuity_phase != &"idle"
	var framing_points: Array = points.duplicate()
	if transition_active:
		framing_points.append_array(_discontinuity_anchor_points())

	var desired_focus := _map_focus
	var desired_size := _idle_overview_size
	if not points.is_empty():
		desired_focus = _calculate_focus(points, average_velocity)
	if not framing_points.is_empty():
		var size_limit := _discontinuity_max_size if transition_active else _max_size
		desired_size = _calculate_required_size_with_limit(
			framing_points, desired_focus, _viewport_size, size_limit
		)
		# Keep the actual subjects safe while the damped focus is between the old
		# and new fight. During a portal transition this remains active every frame,
		# instead of only on the teleport frame.
		desired_size = maxf(
			desired_size,
			_calculate_required_size_with_limit(
				framing_points, _current_focus, _viewport_size, size_limit
			)
		)
	if transition_active:
		# Do not pump zoom in/out while several players pass through the pair. The
		# largest safe view is held until focus recovery finishes, then normal zoom
		# easing is allowed to bring the fight close again.
		_discontinuity_safety_size = maxf(
			_discontinuity_safety_size,
			maxf(desired_size, _camera.size)
		)
		desired_size = _discontinuity_safety_size

	_target_focus = desired_focus
	_target_size = desired_size
	var expand_for_discontinuity := _spatial_discontinuity_pending
	_spatial_discontinuity_pending = false
	if _update_presentation(camera_delta, desired_focus, desired_size):
		_apply_camera_transform()
		return

	if transition_active:
		_update_discontinuity_focus(desired_focus, camera_delta)
	else:
		var focus_state := _critical_damp_vector3(
			_current_focus,
			_target_focus,
			_focus_velocity,
			FOCUS_SMOOTH_TIME,
			camera_delta
		)
		_current_focus = focus_state[0] as Vector3
		_focus_velocity = focus_state[1] as Vector3
		_discontinuity_focus_speed = 0.0

	if expand_for_discontinuity:
		_camera.size = maxf(_camera.size, _target_size)
		_zoom_velocity = 0.0
	else:
		var zoom_smooth_time := ZOOM_OUT_SMOOTH_TIME if _target_size > _camera.size else ZOOM_IN_SMOOTH_TIME
		var zoom_state := _critical_damp_float(
			_camera.size,
			_target_size,
			_zoom_velocity,
			zoom_smooth_time,
			camera_delta
		)
		# A portal safety expansion may temporarily exceed the normal composition
		# ceiling. Let it settle naturally instead of cutting back to max_size on
		# the next frame and exposing the teleported character again.
		_camera.size = maxf(float(zoom_state[0]), _min_size)
		_zoom_velocity = float(zoom_state[1])
	if transition_active:
		_finish_discontinuity_if_ready(desired_focus)
	_apply_camera_transform()


func _update_discontinuity_focus(desired_focus: Vector3, delta: float) -> void:
	_discontinuity_elapsed += delta
	_advance_discontinuity_events(delta)
	if _discontinuity_hold_remaining > 0.0:
		_discontinuity_phase = &"hold"
		_discontinuity_hold_remaining = maxf(_discontinuity_hold_remaining - delta, 0.0)
		_target_focus = _current_focus
		_focus_velocity = Vector3.ZERO
		_discontinuity_focus_speed = 0.0
		_discontinuity_pan_velocity = Vector3.ZERO
		return

	_discontinuity_phase = &"recover"
	_target_focus = desired_focus
	var focus_state := _critical_damp_vector3(
		_current_focus,
		_target_focus,
		_focus_velocity,
		DISCONTINUITY_RECOVER_SMOOTH_TIME,
		delta
	)
	var candidate := focus_state[0] as Vector3
	var step := candidate - _current_focus
	var safe_view_size := maxf(_camera.size, _target_size)
	var max_speed := safe_view_size * DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND
	var proposed_velocity := step / delta if delta > 0.0 else Vector3.ZERO
	if proposed_velocity.length() > max_speed:
		proposed_velocity = proposed_velocity.normalized() * max_speed
	var max_acceleration := safe_view_size * DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND_SQUARED
	var velocity_delta := proposed_velocity - _discontinuity_pan_velocity
	var max_velocity_delta := max_acceleration * delta
	if max_velocity_delta > 0.0 and velocity_delta.length() > max_velocity_delta:
		velocity_delta = velocity_delta.normalized() * max_velocity_delta
	var candidate_velocity := _discontinuity_pan_velocity + velocity_delta
	step = candidate_velocity * delta
	candidate = _current_focus + step
	_current_focus = candidate
	_focus_velocity = candidate_velocity
	_discontinuity_pan_velocity = candidate_velocity
	_discontinuity_focus_speed = step.length() / delta if delta > 0.0 else 0.0


func _register_discontinuity_event(
	subject: Node3D,
	source_world: Variant,
	destination_world: Variant
) -> void:
	if not source_world is Vector3 and not destination_world is Vector3:
		return
	var subject_id := subject.get_instance_id() if subject and is_instance_valid(subject) else 0
	var event := {
		"subject_id": subject_id,
		"source": source_world if source_world is Vector3 else null,
		"destination": destination_world if destination_world is Vector3 else null,
		"remaining": DISCONTINUITY_ANCHOR_DURATION,
	}
	for index in range(_discontinuity_events.size()):
		if int(_discontinuity_events[index].get("subject_id", -1)) == subject_id:
			_discontinuity_events[index] = event
			return
	_discontinuity_events.append(event)
	while _discontinuity_events.size() > 4:
		_discontinuity_events.remove_at(0)


func _discontinuity_anchor_points() -> Array:
	var points: Array = []
	for event in _discontinuity_events:
		for key in [&"source", &"destination"]:
			var point_value: Variant = event.get(key)
			if not point_value is Vector3:
				continue
			var point := point_value as Vector3
			var duplicate := false
			for existing in points:
				if (existing as Vector3).distance_squared_to(point) <= 0.0001:
					duplicate = true
					break
			if not duplicate:
				points.append(point)
	return points


func _advance_discontinuity_events(delta: float) -> void:
	for index in range(_discontinuity_events.size() - 1, -1, -1):
		var event := _discontinuity_events[index]
		var remaining := float(event.get("remaining", 0.0)) - delta
		if remaining <= 0.0:
			_discontinuity_events.remove_at(index)
		else:
			event["remaining"] = remaining
			_discontinuity_events[index] = event


func _finish_discontinuity_if_ready(desired_focus: Vector3) -> void:
	if _discontinuity_phase != &"recover":
		return
	var settle_distance := maxf(
		DISCONTINUITY_SETTLE_DISTANCE,
		_camera.size * DISCONTINUITY_SETTLE_SIZE_RATIO
	)
	var settled := _discontinuity_events.is_empty() \
		and _current_focus.distance_to(desired_focus) <= settle_distance
	if settled or _discontinuity_elapsed >= DISCONTINUITY_MAX_RECOVER_DURATION:
		_clear_spatial_discontinuity()


func _clear_spatial_discontinuity() -> void:
	_spatial_discontinuity_pending = false
	_discontinuity_phase = &"idle"
	_discontinuity_hold_remaining = 0.0
	_discontinuity_elapsed = 0.0
	_discontinuity_events.clear()
	_discontinuity_safety_size = 0.0
	_discontinuity_focus_speed = 0.0
	_discontinuity_pan_velocity = Vector3.ZERO


func get_debug_state() -> Dictionary:
	return {
		"enabled": _enabled,
		"profile_id": _profile_id,
		"tracked_count": _tracked_count,
		"hud_panel_count": _hud_panel_count,
		"hud_occlusion_regions": _resolved_hud_occlusion_rects(_viewport_size),
		"map_focus": _map_focus,
		"view_offset": _view_offset,
		"view_basis": _view_basis,
		"current_focus": _current_focus,
		"target_focus": _target_focus,
		"current_size": _camera.size if _camera else 0.0,
		"target_size": _target_size,
		"focus_velocity": _focus_velocity,
		"zoom_velocity": _zoom_velocity,
		"min_size": _min_size,
		"max_size": _max_size,
		"discontinuity_max_size": _discontinuity_max_size,
		"discontinuity_phase": String(_discontinuity_phase),
		"discontinuity_event_serial": _discontinuity_event_serial,
		"discontinuity_event_count": _discontinuity_events.size(),
		"discontinuity_anchor_count": _discontinuity_anchor_points().size(),
		"discontinuity_hold_remaining": _discontinuity_hold_remaining,
		"discontinuity_elapsed": _discontinuity_elapsed,
		"discontinuity_safety_size": _discontinuity_safety_size,
		"discontinuity_focus_speed": _discontinuity_focus_speed,
		"discontinuity_pan_velocity": _discontinuity_pan_velocity,
		"safety_expansion_active": _discontinuity_phase != &"idle",
		"viewport_size": _viewport_size,
		"presentation_mode": String(_presentation_mode),
		"presentation_progress": _presentation_progress(),
	}


func get_behavior_contract() -> Dictionary:
	return {
		"version": BEHAVIOR_CONTRACT_VERSION,
		"downward_pitch_degrees": STANDARD_GAMEPLAY_DOWNWARD_PITCH_DEGREES,
		"pitch_tangent": STANDARD_GAMEPLAY_PITCH_TANGENT,
		"focus_smooth_time": FOCUS_SMOOTH_TIME,
		"zoom_in_smooth_time": ZOOM_IN_SMOOTH_TIME,
		"zoom_out_smooth_time": ZOOM_OUT_SMOOTH_TIME,
		"max_camera_delta": MAX_CAMERA_DELTA,
		"focus_centroid_weight": FOCUS_CENTROID_WEIGHT,
		"velocity_look_ahead": VELOCITY_LOOK_AHEAD,
		"max_look_ahead": MAX_LOOK_AHEAD,
		"max_render_prediction_distance": MAX_RENDER_PREDICTION_DISTANCE,
		"discontinuity_hold_duration": DISCONTINUITY_HOLD_DURATION,
		"discontinuity_retrigger_hold_duration": DISCONTINUITY_RETRIGGER_HOLD_DURATION,
		"discontinuity_anchor_duration": DISCONTINUITY_ANCHOR_DURATION,
		"discontinuity_recover_smooth_time": DISCONTINUITY_RECOVER_SMOOTH_TIME,
		"discontinuity_max_screen_heights_per_second": DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND,
		"discontinuity_max_screen_heights_per_second_squared": DISCONTINUITY_MAX_SCREEN_HEIGHTS_PER_SECOND_SQUARED,
		"discontinuity_settle_distance": DISCONTINUITY_SETTLE_DISTANCE,
		"discontinuity_settle_size_ratio": DISCONTINUITY_SETTLE_SIZE_RATIO,
		"discontinuity_max_recover_duration": DISCONTINUITY_MAX_RECOVER_DURATION,
	}


func _update_presentation(delta: float, runtime_focus: Vector3, runtime_size: float) -> bool:
	if _presentation_mode == &"none":
		return false
	if _presentation_mode == &"reveal":
		_presentation_elapsed = minf(_presentation_elapsed + delta, _presentation_duration)
		var reveal_progress := _presentation_progress()
		var reveal_eased := _smoothstep(reveal_progress)
		_current_focus = _presentation_start_focus.lerp(runtime_focus, reveal_eased)
		_camera.size = lerpf(_presentation_start_size, runtime_size, reveal_eased)
		if reveal_progress >= 1.0:
			_presentation_mode = &"none"
			_current_focus = runtime_focus
			_camera.size = runtime_size
			_focus_velocity = Vector3.ZERO
			_zoom_velocity = 0.0
		return true
	if _presentation_mode == &"winner_focus" or _presentation_mode == &"winner_hold":
		if _presentation_target == null or not is_instance_valid(_presentation_target):
			release_presentation_override()
			return false
		var winner_focus := _clamp_track_point(_presentation_target.global_position)
		_target_focus = winner_focus
		_target_size = _winner_focus_size
		if _presentation_mode == &"winner_focus":
			_presentation_elapsed = minf(_presentation_elapsed + delta, _presentation_duration)
			var winner_progress := _presentation_progress()
			var winner_eased := _smoothstep(winner_progress)
			_current_focus = _presentation_start_focus.lerp(winner_focus, winner_eased)
			_camera.size = lerpf(_presentation_start_size, _winner_focus_size, winner_eased)
			if winner_progress >= 1.0:
				_presentation_mode = &"winner_hold"
		else:
			_current_focus = winner_focus
			_camera.size = _winner_focus_size
		return true
	release_presentation_override()
	return false


func _presentation_progress() -> float:
	if _presentation_duration <= 0.0:
		return 0.0
	return clampf(_presentation_elapsed / _presentation_duration, 0.0, 1.0)


func _smoothstep(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func is_world_point_hud_occluded(world_point: Vector3) -> bool:
	if _camera == null or _viewport_size.x <= 1.0 or _viewport_size.y <= 1.0:
		return false
	return _point_hits_blocked_screen_area(
		_clamp_track_point(world_point),
		_current_focus,
		_camera.size,
		_viewport_size
	)


func _collect_tracking_sample(characters: Array) -> Dictionary:
	var points: Array[Vector3] = []
	var velocity_sum := Vector3.ZERO
	var prediction_seconds := _render_prediction_seconds()
	for item in characters:
		if not is_instance_valid(item) or not (item is BaseCharacter):
			continue
		var character := item as BaseCharacter
		if character.is_dead or character.is_game_over or character.global_position.y < _track_min_y:
			continue
		var horizontal_velocity := Vector3(character.linear_velocity.x, 0.0, character.linear_velocity.z)
		var render_prediction := horizontal_velocity * prediction_seconds
		if render_prediction.length() > MAX_RENDER_PREDICTION_DISTANCE:
			render_prediction = render_prediction.normalized() * MAX_RENDER_PREDICTION_DISTANCE
		points.append(_clamp_track_point(character.global_position + render_prediction))
		velocity_sum += horizontal_velocity

	var average_velocity := Vector3.ZERO
	if not points.is_empty():
		average_velocity = velocity_sum / float(points.size())
	return {
		"points": points,
		"average_velocity": average_velocity,
	}


func _calculate_focus(points: Array, average_velocity: Vector3) -> Vector3:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var centroid := Vector3.ZERO
	for point_variant in points:
		var point := point_variant as Vector3
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
		centroid += point
	centroid /= float(points.size())
	var bounds_center := Vector3((min_x + max_x) * 0.5, _map_focus.y, (min_z + max_z) * 0.5)
	var framing_center := bounds_center.lerp(centroid, FOCUS_CENTROID_WEIGHT)

	var look_ahead := average_velocity * VELOCITY_LOOK_AHEAD
	look_ahead.y = 0.0
	if look_ahead.length() > MAX_LOOK_AHEAD:
		look_ahead = look_ahead.normalized() * MAX_LOOK_AHEAD

	return Vector3(
		clampf(framing_center.x + look_ahead.x, _focus_min.x, _focus_max.x),
		_map_focus.y,
		clampf(framing_center.z + look_ahead.z, _focus_min.y, _focus_max.y)
	)


func _calculate_required_size(points: Array, focus: Vector3, viewport_size: Vector2) -> float:
	return _calculate_required_size_with_limit(points, focus, viewport_size, _max_size)


func _calculate_required_size_with_limit(
	points: Array,
	focus: Vector3,
	viewport_size: Vector2,
	size_limit: float
) -> float:
	if points.is_empty():
		return _idle_overview_size
	var resolved_limit := maxf(size_limit, _max_size)
	var aspect := maxf(viewport_size.x / viewport_size.y, 0.5)
	var min_horizontal := INF
	var max_horizontal := -INF
	var min_vertical := INF
	var max_vertical := -INF

	for point_variant in points:
		var offset := (point_variant as Vector3) - focus
		var horizontal := offset.dot(_screen_right)
		var vertical := offset.dot(_screen_up)
		min_horizontal = minf(min_horizontal, horizontal)
		max_horizontal = maxf(max_horizontal, horizontal)
		min_vertical = minf(min_vertical, vertical)
		max_vertical = maxf(max_vertical, vertical)

	var horizontal_span := max_horizontal - min_horizontal + _world_frame_padding * 2.0
	var vertical_span := max_vertical - min_vertical + _world_frame_padding * 2.0
	var required_size := clampf(
		maxf(vertical_span, horizontal_span / aspect),
		_min_size,
		resolved_limit
	)

	if not _points_hit_blocked_screen_area(points, focus, required_size, viewport_size):
		return required_size
	if _points_hit_blocked_screen_area(points, focus, resolved_limit, viewport_size):
		return resolved_limit

	var blocked_size := required_size
	var clear_size := resolved_limit
	for _iteration in range(OCCLUSION_SEARCH_ITERATIONS):
		var candidate_size := (blocked_size + clear_size) * 0.5
		if _points_hit_blocked_screen_area(points, focus, candidate_size, viewport_size):
			blocked_size = candidate_size
		else:
			clear_size = candidate_size
	return minf(clear_size + OCCLUSION_SIZE_EPSILON, resolved_limit)


func _points_hit_blocked_screen_area(points: Array, focus: Vector3, size: float, viewport_size: Vector2) -> bool:
	for point_variant in points:
		if _point_hits_blocked_screen_area(point_variant as Vector3, focus, size, viewport_size):
			return true
	return false


func _point_hits_blocked_screen_area(point: Vector3, focus: Vector3, size: float, viewport_size: Vector2) -> bool:
	var aspect := maxf(viewport_size.x / viewport_size.y, 0.5)
	var offset := point - focus
	var horizontal := offset.dot(_screen_right)
	var vertical := offset.dot(_screen_up)
	var normalized := Vector2(
		0.5 + horizontal / (size * aspect),
		0.5 - vertical / size
	)
	var screen_center := Vector2(normalized.x * viewport_size.x, normalized.y * viewport_size.y)
	var pixels_per_world_unit := viewport_size.y / size
	var radius := Vector2.ONE * _character_screen_radius * pixels_per_world_unit
	var character_rect := Rect2(screen_center - radius, radius * 2.0)
	var viewport_inner := Rect2(
		Vector2.ONE * _screen_edge_gutter,
		viewport_size - Vector2.ONE * _screen_edge_gutter * 2.0
	)
	if not viewport_inner.encloses(character_rect):
		return true
	for blocked_rect in _resolved_hud_occlusion_rects(viewport_size):
		if (blocked_rect as Rect2).intersects(character_rect):
			return true
	return false


func _resolved_hud_occlusion_rects(viewport_size: Vector2) -> Array[Rect2]:
	if not _hud_occlusion_group.is_empty():
		var live_rects: Array[Rect2] = []
		if not is_inside_tree():
			return live_rects
		for node in get_tree().get_nodes_in_group(_hud_occlusion_group):
			var control := node as Control
			if control == null or not control.is_visible_in_tree():
				continue
			live_rects.append(control.get_global_rect().grow(_hud_occlusion_gutter))
		return live_rects
	if _hud_occlusion_regions.is_empty():
		return RINGOUT_HUD_SCRIPT.camera_occlusion_rects(viewport_size, _hud_panel_count)
	var resolved: Array[Rect2] = []
	for region_variant: Variant in _hud_occlusion_regions:
		var region := region_variant as Dictionary
		var anchor := region.get("anchor", Vector2.ZERO) as Vector2
		var offset := region.get("offset", Vector2.ZERO) as Vector2
		var size := region.get("size", Vector2.ZERO) as Vector2
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		resolved.append(Rect2(viewport_size * anchor + offset, size))
	return resolved


func _clamp_track_point(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, _playable_min.x, _playable_max.x),
		_map_focus.y,
		clampf(point.z, _playable_min.y, _playable_max.y)
	)


func _apply_camera_transform() -> void:
	_camera.transform = Transform3D(_view_basis, _current_focus + _view_offset)


func _render_prediction_seconds() -> float:
	return clampf(
		Engine.get_physics_interpolation_fraction() * _physics_tick_seconds,
		0.0,
		_physics_tick_seconds
	)


func _unscaled_camera_delta(delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	return minf(delta / maxf(Engine.time_scale, 0.01), MAX_CAMERA_DELTA)


func _critical_damp_vector3(
	current: Vector3,
	target: Vector3,
	velocity: Vector3,
	smooth_time: float,
	delta: float
) -> Array:
	if delta <= 0.0:
		return [current, velocity]
	var omega := 2.0 / maxf(smooth_time, 0.001)
	var displacement := current - target
	var decay := exp(-omega * delta)
	var temporal := (velocity + displacement * omega) * delta
	return [
		target + (displacement + temporal) * decay,
		(velocity - temporal * omega) * decay,
	]


func _critical_damp_float(
	current: float,
	target: float,
	velocity: float,
	smooth_time: float,
	delta: float
) -> Array:
	if delta <= 0.0:
		return [current, velocity]
	var omega := 2.0 / maxf(smooth_time, 0.001)
	var displacement := current - target
	var decay := exp(-omega * delta)
	var temporal := (velocity + displacement * omega) * delta
	return [
		target + (displacement + temporal) * decay,
		(velocity - temporal * omega) * decay,
	]
