extends Node
## Global presentation timing: hitstop, slow motion, random shake, and directional camera kick.

var _hitstop_timer: float = 0.0

var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0

var _camera: Camera3D = null
var _camera_original_h_offset: float = 0.0
var _camera_original_v_offset: float = 0.0
var _camera_kick_offset := Vector2.ZERO
var _camera_kick_duration: float = 0.0
var _camera_kick_timer: float = 0.0


func hitstop(duration: float = 0.04) -> void:
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(_hitstop_timer, duration)
		return
	_hitstop_timer = duration
	Engine.time_scale = 0.05


func kill_slowmo(duration: float = 0.25) -> void:
	_hitstop_timer = duration
	Engine.time_scale = 0.15


func screen_shake(intensity: float = 0.3, duration: float = 0.12) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_timer = _shake_duration
	_ensure_camera()


func camera_kick(world_direction: Vector3, intensity: float = 0.08, duration: float = 0.10) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return
	_ensure_camera()
	if not is_instance_valid(_camera):
		return

	var flat_direction := Vector3(world_direction.x, 0.0, world_direction.z)
	if flat_direction.length_squared() <= 0.0001:
		flat_direction = Vector3.FORWARD
	else:
		flat_direction = flat_direction.normalized()
	var camera_right := Vector3(_camera.global_basis.x.x, 0.0, _camera.global_basis.x.z).normalized()
	var camera_forward := Vector3(-_camera.global_basis.z.x, 0.0, -_camera.global_basis.z.z).normalized()
	var screen_direction := Vector2(
		-flat_direction.dot(camera_right),
		-flat_direction.dot(camera_forward) * 0.32 - 0.28
	)
	if screen_direction.length_squared() <= 0.0001:
		screen_direction = Vector2(0.0, -1.0)

	_camera_kick_offset += screen_direction.normalized() * intensity
	if _camera_kick_offset.length() > 0.62:
		_camera_kick_offset = _camera_kick_offset.normalized() * 0.62
	_camera_kick_duration = maxf(_camera_kick_duration, duration)
	_camera_kick_timer = maxf(_camera_kick_timer, duration)


func _process(delta: float) -> void:
	var unscaled_delta := delta / maxf(Engine.time_scale, 0.01)
	_update_hitstop(unscaled_delta)
	_update_camera_feedback(unscaled_delta)


func _update_hitstop(unscaled_delta: float) -> void:
	if _hitstop_timer <= 0.0:
		return
	_hitstop_timer -= unscaled_delta
	if _hitstop_timer <= 0.0:
		_hitstop_timer = 0.0
		Engine.time_scale = 1.0


func _update_camera_feedback(unscaled_delta: float) -> void:
	var shake_offset := Vector2.ZERO
	if _shake_timer > 0.0:
		_shake_timer -= unscaled_delta
		var t := maxf(_shake_timer, 0.0) / maxf(_shake_duration, 0.01)
		var current_intensity := _shake_intensity * t
		shake_offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity) * 0.5
		)
		if _shake_timer <= 0.0:
			_shake_timer = 0.0
			_shake_intensity = 0.0
			_shake_duration = 0.0

	if _camera_kick_timer > 0.0:
		_camera_kick_timer -= unscaled_delta
		var recovery_rate := 5.2 / maxf(_camera_kick_duration, 0.05)
		_camera_kick_offset = _camera_kick_offset.lerp(
			Vector2.ZERO,
			clampf(unscaled_delta * recovery_rate, 0.0, 1.0)
		)
		if _camera_kick_timer <= 0.0:
			_camera_kick_timer = 0.0
			_camera_kick_duration = 0.0
			_camera_kick_offset = Vector2.ZERO

	if _shake_timer > 0.0 or _camera_kick_timer > 0.0:
		_ensure_camera()
	_apply_camera_presentation_offset(shake_offset + _camera_kick_offset)


func _apply_camera_presentation_offset(offset: Vector2) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.h_offset = _camera_original_h_offset + offset.x
	_camera.v_offset = _camera_original_v_offset + offset.y


func _ensure_camera() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	if not is_instance_valid(_camera) or viewport.get_camera_3d() != _camera:
		_find_camera()


func _find_camera() -> void:
	var viewport := get_viewport()
	if viewport == null:
		_camera = null
		return
	_camera = viewport.get_camera_3d()
	if _camera:
		_camera_original_h_offset = _camera.h_offset
		_camera_original_v_offset = _camera.v_offset


func get_camera_feedback_debug() -> Dictionary:
	return {
		"shake_intensity": _shake_intensity,
		"shake_timer": _shake_timer,
		"kick_offset": _camera_kick_offset,
		"kick_timer": _camera_kick_timer,
		"camera_bound": is_instance_valid(_camera),
	}
