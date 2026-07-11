extends BaseCharacter
class_name PlayerCharacter

## 本地多人版 —— 朝向射击 + 瞄准辅助
## 通过 input_prefix 区分不同玩家的输入（p1_ / p2_）

const AIM_ASSIST_CONE_DEG := 42.0
const AIM_ASSIST_CLOSE_CONE_DEG := 100.0
const AIM_ASSIST_CLOSE_RANGE := 22.0
const AIM_ASSIST_RANGE := 75.0
const POINTER_AIM_MIN_DISTANCE := 1.5
const LANE_TARGET_Z_TOLERANCE := 4.0
const LOCK_ON_RANGE := 72.0

const CONTROL_MODE_LANE := "lane_2d"
const CONTROL_MODE_TWIN_STICK := "twin_stick"
const CONTROL_MODE_LOCK_ON := "lock_on"

## 输入前缀：由对战场景在生成时设置（"p1_" 或 "p2_"）
var input_prefix: String = "p1_"
## 玩家槽位索引（0-3）
var slot_index: int = 0

var _face_dir: Vector3 = Vector3.FORWARD
var _lane_face_sign: float = 1.0
var _lock_target: BaseCharacter = null
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

	var grounded_speed = _game_config_float("character_speed", 550.0)
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
		_face_dir = _face_dir.slerp(direction, 0.25).normalized()

	if _face_dir.length_squared() > 0.01:
		var target_basis = Basis.looking_at(_face_dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, 0.4)

	# --- 射击 ---
	_handle_fire_input()

	# --- 武器切换 ---
	_handle_weapon_input()

# ------------------------------------------------------------------
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
		var to_target = target.global_position - global_position
		if absf(to_target.z) > LANE_TARGET_Z_TOLERANCE: continue
		var x_gap = absf(to_target.x)
		if x_gap < 1.0 or x_gap > AIM_ASSIST_RANGE: continue
		if x_gap < best_x_gap:
			best_x_gap = x_gap
			best_target = target
	return best_target

func _get_lock_on_fire_dir(base_dir: Vector3) -> Vector3:
	var target = _get_lock_target()
	if target:
		var target_aim_pos = target.global_position + Vector3(0, 1.0, 0)
		var fire_origin = weapon_point.global_position if weapon_point else global_position
		return (target_aim_pos - fire_origin).normalized()
	return _get_aim_assisted_dir(base_dir)

func _get_lock_target() -> BaseCharacter:
	if _lock_target and is_instance_valid(_lock_target) and not _lock_target.is_dead:
		if global_position.distance_to(_lock_target.global_position) <= LOCK_ON_RANGE:
			return _lock_target
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return null
	var best_score := -9999.0
	var best_target: BaseCharacter = null
	for node in scene_root.get_children():
		if node == self: continue
		if not (node is BaseCharacter): continue
		var target := node as BaseCharacter
		if target.is_dead: continue
		var to_target = target.global_position - global_position
		to_target.y = 0.0
		var dist = to_target.length()
		if dist < 1.0 or dist > LOCK_ON_RANGE: continue
		var dir_to = to_target.normalized()
		var facing_score = maxf(0.0, _face_dir.normalized().dot(dir_to))
		var distance_score = 1.0 - clampf(dist / LOCK_ON_RANGE, 0.0, 1.0)
		var score = distance_score * 0.70 + facing_score * 0.30
		if score > best_score:
			best_score = score
			best_target = target
	_lock_target = best_target
	return _lock_target

func _update_lock_indicator() -> void:
	if _control_mode() != CONTROL_MODE_LOCK_ON:
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
	mat.albedo_color = Color(1.0, 0.88, 0.20, 0.52)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.10)
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
		var to_target = target.global_position - global_position
		to_target.y = 0
		var dist = to_target.length()
		if dist < 1.0 or dist > AIM_ASSIST_RANGE: continue
		var dir_to = to_target.normalized()
		var dot = aim_dir.dot(dir_to)
		var cone_deg = AIM_ASSIST_CLOSE_CONE_DEG if dist <= AIM_ASSIST_CLOSE_RANGE else AIM_ASSIST_CONE_DEG
		if dot < cos(deg_to_rad(cone_deg)): continue
		var closeness_bonus = 1.0 - clampf(dist / AIM_ASSIST_RANGE, 0.0, 1.0)
		var score = dot + closeness_bonus * 0.55
		if score > best_score:
			best_score = score
			best_target = target
			
	if best_target:
		var target_aim_pos = best_target.global_position + Vector3(0, 1.0, 0)
		var fire_origin = weapon_point.global_position if weapon_point else global_position
		return (target_aim_pos - fire_origin).normalized()

	return aim_dir

# ------------------------------------------------------------------
func _handle_weapon_input() -> void:
	if not weapon_manager:
		return
	var cycle_action = input_prefix + "weapon_cycle"
	if Input.is_action_just_pressed(cycle_action):
		weapon_manager.cycle_weapon()

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
