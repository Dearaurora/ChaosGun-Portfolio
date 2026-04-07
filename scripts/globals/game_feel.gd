extends Node
## GameFeel — 全局手感管理器（Hitstop + ScreenShake）
## 通过 project.godot 注册为 AutoLoad 单例

# ============================================================
#  Hitstop（命中顿帧）
# ============================================================
var _hitstop_timer: float = 0.0

## 触发顿帧：duration 秒内游戏近乎暂停
func hitstop(duration: float = 0.04) -> void:
	if _hitstop_timer > 0.0:
		# 已在顿帧中，取较长的
		_hitstop_timer = maxf(_hitstop_timer, duration)
		return
	_hitstop_timer = duration
	Engine.time_scale = 0.05  # 几乎暂停但不为零，避免 delta=0 问题

## 击杀慢动作：较长慢动作 + 缓慢恢复
func kill_slowmo(duration: float = 0.25) -> void:
	_hitstop_timer = duration
	Engine.time_scale = 0.15

# ============================================================
#  Screen Shake（屏幕震动）
# ============================================================
var _shake_intensity: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
var _camera: Camera3D = null
var _camera_original_pos: Vector3 = Vector3.ZERO

## 触发屏幕震动
func screen_shake(intensity: float = 0.3, duration: float = 0.12) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_timer = _shake_duration
	if not _camera:
		_find_camera()

# ============================================================
#  _process：管理所有时间相关效果
# ============================================================
func _process(delta: float) -> void:
	# Hitstop 计时（用真实时间，不受 time_scale 影响）
	if _hitstop_timer > 0.0:
		# 用 unscaled delta 来倒计时
		var real_delta = delta / maxf(Engine.time_scale, 0.01)
		_hitstop_timer -= real_delta
		if _hitstop_timer <= 0.0:
			_hitstop_timer = 0.0
			Engine.time_scale = 1.0

	# Screen Shake
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if _camera:
			var t = _shake_timer / maxf(_shake_duration, 0.01)
			var current_intensity = _shake_intensity * t  # 线性衰减
			var offset = Vector3(
				randf_range(-current_intensity, current_intensity),
				randf_range(-current_intensity, current_intensity) * 0.5,
				0
			)
			_camera.transform.origin = _camera_original_pos + offset
		if _shake_timer <= 0.0:
			_shake_timer = 0.0
			_shake_intensity = 0.0
			_shake_duration = 0.0
			if _camera:
				_camera.transform.origin = _camera_original_pos

func _find_camera() -> void:
	_camera = get_viewport().get_camera_3d()
	if _camera:
		_camera_original_pos = _camera.transform.origin
