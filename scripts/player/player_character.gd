extends BaseCharacter
class_name PlayerCharacter

## 本地多人版 —— 朝向射击 + 瞄准辅助
## 通过 input_prefix 区分不同玩家的输入（p1_ - p4_）

const AIM_ASSIST_CONE_DEG := 42.0
const AIM_ASSIST_CLOSE_CONE_DEG := 100.0
const AIM_ASSIST_CLOSE_RANGE := 22.0
const AIM_ASSIST_RANGE := 75.0
const POINTER_AIM_MIN_DISTANCE := 1.5
const LANE_TARGET_Z_TOLERANCE := 4.0
const LOCK_ON_RANGE := 72.0
const LOCK_SOFT_GRACE_SECONDS := 0.30
const LOCK_MANUAL_PROTECTION_SECONDS := 0.50
const LOCK_OCCLUSION_GRACE_SECONDS := 0.30
const LOCK_REACQUIRE_ANGLE_DEG := 35.0
const LOCK_SWITCH_SCORE_MARGIN := 0.18
const LOCK_FACING_WEIGHT := 0.65
const LOCK_DISTANCE_WEIGHT := 0.25
const LOCK_VISIBILITY_WEIGHT := 0.10
const LOCK_INDICATOR_COLORS := [
	Color("#4da4ff"),
	Color("#ff6248"),
	Color("#d66bdc"),
	Color("#77cf6b"),
]

const CONTROL_MODE_LANE := "lane_2d"
const CONTROL_MODE_TWIN_STICK := "twin_stick"
const CONTROL_MODE_LOCK_ON := "lock_on"

enum LockState {
	UNLOCKED,
	SOFT,
	HARD,
}

## 输入前缀：由对战场景在生成时设置（"p1_" - "p4_"）
var input_prefix: String = "p1_"
## 玩家槽位索引（0-3）
var slot_index: int = 0

var _face_dir: Vector3 = Vector3.FORWARD
var _lane_face_sign: float = 1.0
var _lock_target: BaseCharacter = null
var _lock_state := LockState.UNLOCKED
var _soft_lock_remaining: float = 0.0
var _manual_lock_remaining: float = 0.0
var _lock_occluded_time: float = 0.0
var _lock_switch_serial: int = 0
var _lock_indicator: MeshInstance3D = null
var _visual_move_dir: Vector3 = Vector3.ZERO
var _visual_move_speed_ratio: float = 0.0

func _ready() -> void:
	super._ready()
	if weapon_manager:
		weapon_manager.weapon_dropped.connect(_on_weapon_dropped)
		weapon_manager.weapon_switched.connect(_on_weapon_switched)

func _process(delta: float) -> void:
	super._base_process(delta)
	var visual = get_visual()
	if visual and not is_dead:
		var move_dir := _visual_move_dir
		var speed_ratio := _visual_move_speed_ratio
		if move_dir.length_squared() <= 0.01:
			var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
			if horizontal_velocity.length() > 0.8:
				move_dir = horizontal_velocity.normalized()
				speed_ratio = clampf(horizontal_velocity.length() / 16.0, 0.0, 1.0)
		visual.animate_locomotion(move_dir, _face_dir, speed_ratio, delta)
	_update_lock_indicator()

func _physics_process(delta: float) -> void:
	if is_dead or is_game_over:
		return
	if is_scripted_traversal_active():
		return

	_check_fall()
	if is_dead: return

	# --- 移动（使用前缀输入） ---
	var input_dir := Input.get_vector(
		input_prefix + "move_left",
		input_prefix + "move_right",
		input_prefix + "move_forward",
		input_prefix + "move_backward")
	var direction := _movement_direction_from_input(input_dir)
	_visual_move_dir = direction if direction.length() > 0.1 else Vector3.ZERO
	_visual_move_speed_ratio = 1.0 if direction.length() > 0.1 else 0.0

	var grounded_speed = get_movement_speed()
	var air_control = _game_config_float("character_air_control_multiplier", 0.2)
	var current_speed = grounded_speed if is_on_floor() else grounded_speed * air_control

	if direction.length() > 0.1:
		apply_central_force(direction * current_speed)

	if Input.is_action_just_pressed(input_prefix + "jump"):
		jump()

	# --- 面朝方向 = 输入方向 + 平滑插值 ---
	var control_mode = _control_mode()
	if control_mode == CONTROL_MODE_TWIN_STICK and _uses_pointer_aim():
		var pointer_dir = _get_pointer_aim_dir()
		if pointer_dir.length_squared() > 0.01:
			_face_dir = pointer_dir
	elif control_mode == CONTROL_MODE_LANE:
		if absf(input_dir.x) > 0.1:
			_lane_face_sign = 1.0 if input_dir.x >= 0.0 else -1.0
			_face_dir = Vector3(_lane_face_sign, 0.0, 0.0)
	elif direction.length() > 0.1:
		var holds_hard_lock := (
			control_mode == CONTROL_MODE_LOCK_ON
			and Input.is_action_pressed(input_prefix + "fire")
			and _get_lock_target() != null
		)
		if not holds_hard_lock:
			_face_dir = _face_dir.slerp(direction, 0.25).normalized()

	if _face_dir.length_squared() > 0.01:
		var target_basis = Basis.looking_at(_face_dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, 0.4)

	_update_lock_on_input(delta, direction, control_mode)

	# --- 射击 ---
	_handle_fire_input()

	# --- 丢弃当前主武器 ---
	_handle_weapon_input()

func _movement_direction_from_input(input_dir: Vector2) -> Vector3:
	if input_dir.length_squared() <= 0.0001:
		return Vector3.ZERO
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	var screen_right := _ground_project(camera.global_transform.basis.x)
	var screen_up := _ground_project(camera.global_transform.basis.y)
	var direction := screen_right * input_dir.x - screen_up * input_dir.y
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	return direction.normalized()

func _ground_project(direction: Vector3) -> Vector3:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() <= 0.0001:
		return Vector3.ZERO
	return flat.normalized()

# ------------------------------------------------------------------
func _handle_fire_input() -> void:
	if not weapon_manager:
		return
	var fire_action = input_prefix + "fire"
	if Input.is_action_pressed(fire_action):
		var fire_dir = _get_fire_dir_for_current_mode()
		_face_dir = Vector3(fire_dir.x, 0.0, fire_dir.z).normalized()
		weapon_manager.try_fire(weapon_point, fire_dir, self)

# ------------------------------------------------------------------
func _control_mode() -> String:
	var config = _game_config()
	if config == null:
		return CONTROL_MODE_LOCK_ON
	var value = config.get("control_mode")
	if value is String:
		return value
	return CONTROL_MODE_LOCK_ON

func _get_fire_dir_for_current_mode() -> Vector3:
	var control_mode = _control_mode()
	if control_mode == CONTROL_MODE_LANE:
		return _get_lane_fire_dir()
	if control_mode == CONTROL_MODE_TWIN_STICK and _uses_pointer_aim():
		return _get_pointer_aim_dir()
	if control_mode == CONTROL_MODE_LOCK_ON:
		return _get_lock_on_fire_dir(_face_dir)
	return _get_aim_assisted_dir(_face_dir)

func _uses_pointer_aim() -> bool:
	return input_prefix == "p1_"

func _get_pointer_aim_dir() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return _face_dir
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	if absf(ray_dir.y) <= 0.001:
		return _face_dir
	var hit_t = (global_position.y - ray_origin.y) / ray_dir.y
	if hit_t <= 0.0:
		return _face_dir
	var hit_pos = ray_origin + ray_dir * hit_t
	var aim_dir = hit_pos - global_position
	aim_dir.y = 0.0
	if aim_dir.length() < POINTER_AIM_MIN_DISTANCE:
		return _face_dir
	return aim_dir.normalized()

func _get_lane_fire_dir() -> Vector3:
	var target = _find_lane_target()
	if target:
		var dx = target.global_position.x - global_position.x
		if absf(dx) > 0.5:
			_lane_face_sign = 1.0 if dx >= 0.0 else -1.0
	return Vector3(_lane_face_sign, 0.0, 0.0)

func _find_lane_target() -> BaseCharacter:
	var best_target: BaseCharacter = null
	var best_x_gap := INF
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return null
	for node in scene_root.get_children():
		if node == self: continue
		if not (node is BaseCharacter): continue
		var target := node as BaseCharacter
		if target.is_dead: continue
		if is_friendly_to(target): continue
		var to_target = target.global_position - global_position
		if absf(to_target.z) > LANE_TARGET_Z_TOLERANCE: continue
		var x_gap = absf(to_target.x)
		if x_gap < 1.0 or x_gap > AIM_ASSIST_RANGE: continue
		if x_gap < best_x_gap:
			best_x_gap = x_gap
			best_target = target
	return best_target

func _get_lock_on_fire_dir(base_dir: Vector3) -> Vector3:
	var target := _get_lock_target()
	if target == null:
		target = _acquire_lock_target(base_dir)
		if target:
			_lock_state = LockState.HARD
	if target:
		var fire_origin := weapon_point.global_position if weapon_point else global_position
		var horizontal_direction := target.global_position - fire_origin
		horizontal_direction.y = 0.0
		if horizontal_direction.length_squared() > 0.0001:
			return horizontal_direction.normalized()
	return _get_aim_assisted_dir(base_dir)

func _get_lock_target() -> BaseCharacter:
	return _lock_target if _is_lock_target_valid(_lock_target) else null

func _update_lock_on_input(delta: float, intent_dir: Vector3, control_mode: String) -> void:
	if control_mode != CONTROL_MODE_LOCK_ON:
		_clear_lock_target()
		return

	var fire_action := input_prefix + "fire"
	var cycle_action := input_prefix + "target_cycle"
	var is_firing := Input.is_action_pressed(fire_action)
	if Input.is_action_just_pressed(cycle_action):
		_cycle_lock_target(is_firing, intent_dir)
	if Input.is_action_just_pressed(fire_action):
		_begin_lock_session(intent_dir)
	elif Input.is_action_just_released(fire_action):
		_end_lock_session()
	_tick_lock_state(delta, intent_dir, is_firing)

func _begin_lock_session(intent_dir: Vector3) -> void:
	var target := _get_lock_target()
	if target and _manual_lock_remaining <= 0.0:
		if _lock_intent_angle_to_target(intent_dir, target) > LOCK_REACQUIRE_ANGLE_DEG:
			_clear_lock_target()
			target = _acquire_lock_target(intent_dir)
		else:
			target = _acquire_lock_target(intent_dir, true)
	elif target == null:
		target = _acquire_lock_target(intent_dir)

	_soft_lock_remaining = 0.0
	_lock_state = LockState.HARD if target else LockState.UNLOCKED

func _end_lock_session() -> void:
	if _get_lock_target():
		_lock_state = LockState.SOFT
		_soft_lock_remaining = LOCK_SOFT_GRACE_SECONDS
	else:
		_clear_lock_target()

func _tick_lock_state(delta: float, intent_dir: Vector3, is_firing: bool) -> void:
	_manual_lock_remaining = maxf(0.0, _manual_lock_remaining - delta)
	var target := _get_lock_target()
	if target == null:
		if _lock_target != null:
			_clear_lock_target()
		if is_firing:
			target = _acquire_lock_target(intent_dir)
			_lock_state = LockState.HARD if target else LockState.UNLOCKED
		return

	if _has_line_of_sight_to_lock_target(target):
		_lock_occluded_time = 0.0
	else:
		_lock_occluded_time += delta
		if _lock_occluded_time >= LOCK_OCCLUSION_GRACE_SECONDS:
			_clear_lock_target()
			if is_firing:
				target = _acquire_lock_target(intent_dir)
				_lock_state = LockState.HARD if target else LockState.UNLOCKED
			return

	if is_firing:
		_lock_state = LockState.HARD
		_soft_lock_remaining = 0.0
		return

	if _lock_state == LockState.HARD:
		_end_lock_session()
	if _lock_state != LockState.SOFT:
		return

	if (
		_manual_lock_remaining <= 0.0
		and intent_dir.length_squared() > 0.01
		and _lock_intent_angle_to_target(intent_dir, target) > LOCK_REACQUIRE_ANGLE_DEG
	):
		_clear_lock_target()
		return

	_soft_lock_remaining = maxf(0.0, _soft_lock_remaining - delta)
	if _soft_lock_remaining <= 0.0 and _manual_lock_remaining <= 0.0:
		_clear_lock_target()

func _acquire_lock_target(intent_dir: Vector3, keep_current_hysteresis: bool = false) -> BaseCharacter:
	var candidates := _collect_lock_candidates()
	if candidates.is_empty():
		_clear_lock_target()
		return null
	var aim_intent := _normalized_lock_intent(intent_dir)
	var best_target: BaseCharacter = null
	var best_score := -INF
	for candidate in candidates:
		var score := _score_lock_target(candidate, aim_intent)
		if score > best_score:
			best_score = score
			best_target = candidate

	var current := _get_lock_target()
	if keep_current_hysteresis and current and current in candidates and best_target != current:
		var current_score := _score_lock_target(current, aim_intent)
		if best_score < current_score + LOCK_SWITCH_SCORE_MARGIN:
			best_target = current
	_set_lock_target(best_target)
	return best_target

func _cycle_lock_target(is_firing: bool = false, intent_dir: Vector3 = Vector3.ZERO) -> BaseCharacter:
	var candidates := _collect_lock_candidates()
	if candidates.is_empty():
		_clear_lock_target()
		return null

	var current := _get_lock_target()
	var next_target: BaseCharacter = null
	if current == null:
		next_target = _find_best_lock_candidate(candidates, _normalized_lock_intent(intent_dir))
	else:
		var current_angle := _lock_cycle_angle(current)
		var smallest_delta := INF
		for candidate in candidates:
			var delta_angle := fposmod(_lock_cycle_angle(candidate) - current_angle, TAU)
			if delta_angle < 0.001:
				delta_angle = TAU
			if delta_angle < smallest_delta:
				smallest_delta = delta_angle
				next_target = candidate

	_set_lock_target(next_target)
	_manual_lock_remaining = LOCK_MANUAL_PROTECTION_SECONDS
	_soft_lock_remaining = LOCK_MANUAL_PROTECTION_SECONDS
	_lock_state = LockState.HARD if is_firing else LockState.SOFT
	return next_target

func _collect_lock_candidates() -> Array[BaseCharacter]:
	var candidates: Array[BaseCharacter] = []
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return candidates
	for node in scene_root.get_children():
		if node == self: continue
		if not (node is BaseCharacter): continue
		var target := node as BaseCharacter
		if not _is_lock_target_valid(target): continue
		if not _has_line_of_sight_to_lock_target(target): continue
		candidates.append(target)
	return candidates

func _find_best_lock_candidate(candidates: Array[BaseCharacter], intent_dir: Vector3) -> BaseCharacter:
	var best_target: BaseCharacter = null
	var best_score := -INF
	for target in candidates:
		var score := _score_lock_target(target, intent_dir)
		if score > best_score:
			best_score = score
			best_target = target
	return best_target

func _score_lock_target(target: BaseCharacter, intent_dir: Vector3) -> float:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= 0.001:
		return -INF
	var facing_score := clampf((intent_dir.dot(to_target / distance) + 1.0) * 0.5, 0.0, 1.0)
	var distance_score := 1.0 - clampf(distance / LOCK_ON_RANGE, 0.0, 1.0)
	return (
		facing_score * LOCK_FACING_WEIGHT
		+ distance_score * LOCK_DISTANCE_WEIGHT
		+ LOCK_VISIBILITY_WEIGHT
	)

func _normalized_lock_intent(intent_dir: Vector3) -> Vector3:
	var flat_intent := Vector3(intent_dir.x, 0.0, intent_dir.z)
	if flat_intent.length_squared() <= 0.0001:
		flat_intent = Vector3(_face_dir.x, 0.0, _face_dir.z)
	if flat_intent.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return flat_intent.normalized()

func _lock_intent_angle_to_target(intent_dir: Vector3, target: BaseCharacter) -> float:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.0001:
		return 0.0
	var intent := _normalized_lock_intent(intent_dir)
	return rad_to_deg(acos(clampf(intent.dot(to_target.normalized()), -1.0, 1.0)))

func _lock_cycle_angle(target: BaseCharacter) -> float:
	var offset := target.global_position - global_position
	return atan2(offset.x, offset.z)

func _is_lock_target_valid(target: BaseCharacter) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target == self or target.is_dead or is_friendly_to(target):
		return false
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	return distance >= 1.0 and distance <= LOCK_ON_RANGE

func _has_line_of_sight_to_lock_target(target: BaseCharacter) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not is_inside_tree() or not target.is_inside_tree():
		return true
	var world := get_world_3d()
	if world == null:
		return true
	var origin := weapon_point.global_position if weapon_point else global_position + Vector3.UP
	var target_position := target.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, target_position)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.hit_from_inside = true
	var result := world.direct_space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == target

func _set_lock_target(target: BaseCharacter) -> void:
	if _lock_target != target:
		_lock_switch_serial += 1
	_lock_target = target
	_lock_occluded_time = 0.0

func _clear_lock_target() -> void:
	_lock_target = null
	_lock_state = LockState.UNLOCKED
	_soft_lock_remaining = 0.0
	_manual_lock_remaining = 0.0
	_lock_occluded_time = 0.0
	if _lock_indicator and is_instance_valid(_lock_indicator):
		_lock_indicator.visible = false

func get_lock_on_debug() -> Dictionary:
	var target := _get_lock_target()
	return {
		"state": _lock_state_name(),
		"target": target,
		"target_name": target.name if target else "",
		"soft_lock_remaining": _soft_lock_remaining,
		"manual_lock_remaining": _manual_lock_remaining,
		"occluded_time": _lock_occluded_time,
		"switch_serial": _lock_switch_serial,
	}

func _lock_state_name() -> String:
	match _lock_state:
		LockState.SOFT:
			return "soft"
		LockState.HARD:
			return "hard"
		_:
			return "unlocked"

func _update_lock_indicator() -> void:
	if is_dead or _control_mode() != CONTROL_MODE_LOCK_ON:
		if _lock_indicator and is_instance_valid(_lock_indicator):
			_lock_indicator.visible = false
		return
	var target = _get_lock_target()
	if target == null:
		if _lock_indicator and is_instance_valid(_lock_indicator):
			_lock_indicator.visible = false
		return
	var indicator = _ensure_lock_indicator()
	if indicator == null:
		return
	indicator.visible = true
	indicator.transparency = 0.0 if _lock_state == LockState.HARD else 0.38
	var target_scale := Vector3.ONE * (1.08 if _manual_lock_remaining > 0.0 else 1.0)
	indicator.scale = indicator.scale.lerp(target_scale, 0.25)
	indicator.global_position = target.global_position + Vector3.UP * 0.10

func _ensure_lock_indicator() -> MeshInstance3D:
	if _lock_indicator and is_instance_valid(_lock_indicator):
		return _lock_indicator
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return null
	var indicator = MeshInstance3D.new()
	indicator.name = "LockOnTargetIndicator"
	var mesh = TorusMesh.new()
	mesh.inner_radius = 1.46
	mesh.outer_radius = 1.58
	mesh.rings = 32
	mesh.ring_segments = 8
	indicator.mesh = mesh
	var mat = StandardMaterial3D.new()
	var indicator_color := Color(1.0, 0.88, 0.20)
	if slot_index >= 0 and slot_index < LOCK_INDICATOR_COLORS.size():
		indicator_color = LOCK_INDICATOR_COLORS[slot_index]
	mat.albedo_color = Color(indicator_color.r, indicator_color.g, indicator_color.b, 0.58)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = indicator_color
	mat.emission_energy_multiplier = 0.35
	indicator.material_override = mat
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(indicator)
	_lock_indicator = indicator
	return _lock_indicator

# ------------------------------------------------------------------
func _get_aim_assisted_dir(base_dir: Vector3) -> Vector3:
	var aim_dir = base_dir
	aim_dir.y = 0.0
	if aim_dir.length_squared() <= 0.0001:
		aim_dir = Vector3.FORWARD
	else:
		aim_dir = aim_dir.normalized()
	var best_score := -9999.0
	var best_target: BaseCharacter = null
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return aim_dir

	for node in scene_root.get_children():
		if node == self: continue
		if not (node is BaseCharacter): continue
		var target := node as BaseCharacter
		if target.is_dead: continue
		if is_friendly_to(target): continue
		var to_target = target.global_position - global_position
		to_target.y = 0
		var dist := to_target.length()
		if dist < 1.0 or dist > AIM_ASSIST_RANGE: continue
		var dir_to := to_target.normalized()
		var dot = aim_dir.dot(dir_to)
		var cone_deg = AIM_ASSIST_CLOSE_CONE_DEG if dist <= AIM_ASSIST_CLOSE_RANGE else AIM_ASSIST_CONE_DEG
		if dot < cos(deg_to_rad(cone_deg)): continue
		var closeness_bonus = 1.0 - clampf(dist / AIM_ASSIST_RANGE, 0.0, 1.0)
		var score = dot + closeness_bonus * 0.55
		if score > best_score:
			best_score = score
			best_target = target
			
	if best_target:
		var fire_origin := weapon_point.global_position if weapon_point else global_position
		var horizontal_direction := best_target.global_position - fire_origin
		horizontal_direction.y = 0.0
		if horizontal_direction.length_squared() > 0.0001:
			return horizontal_direction.normalized()

	return aim_dir

# ------------------------------------------------------------------
func _handle_weapon_input() -> void:
	if not weapon_manager:
		return
	var drop_action = input_prefix + "drop_weapon"
	if Input.is_action_just_pressed(drop_action):
		weapon_manager.discard_current_weapon()

# ------------------------------------------------------------------
func _on_weapon_dropped(drop_position: Vector3) -> void:
	_spawn_drop_visual(drop_position)

func _on_weapon_switched(weapon_data: WeaponData) -> void:
	var visual = get_visual()
	if visual:
		visual.set_weapon_visual(weapon_data.weapon_id)

func _spawn_drop_visual(pos: Vector3) -> void:
	var drop = MeshInstance3D.new()
	drop.mesh = BoxMesh.new()
	drop.mesh.size = Vector3(0.5, 0.5, 0.5)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.6, 1)
	drop.material_override = mat
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	scene_root.add_child(drop)
	drop.global_position = pos + Vector3.UP * 1.5
	var forward = -transform.basis.z
	var tween = drop.create_tween()
	var end_pos = pos + forward * 3.0
	tween.tween_property(drop, "global_position", end_pos, 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(drop, "global_position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(drop.queue_free)
