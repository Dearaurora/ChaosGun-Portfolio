extends BaseCharacter
class_name AICharacter
## AI 对手 —— FSM 状态机驱动，复用武器系统与击退/生命系统

@export var patrol_speed: float = 250.0

# ============================================================
#  AI 参数
# ============================================================
const FIRE_RANGE: float = 30.0
const FIRE_RANGE_EXIT: float = 35.0   # 滞回：退出射击状态的距离
const VISION_RANGE: float = 100.0
const EDGE_SAFE_DIST: float = 8.0
const AIM_OFFSET_DEG: float = 5.0     # 瞄准偏移（±度）
const REACTION_TIME: float = 0.3
const PICKUP_RANGE: float = 35.0
const LANE_TARGET_Z_TOLERANCE: float = 4.0
const NAV_GROUND_NEAR: float = 3.0
const NAV_GROUND_FAR: float = 5.5
const EDGE_ESCAPE_PROBE: float = 3.5
const PICKUP_PROGRESS_EPSILON: float = 0.45
const PICKUP_PROGRESS_TIMEOUT: float = 1.25
const PICKUP_IGNORE_SECONDS: float = 3.0
const TARGET_SWITCH_RATIO: float = 0.72
const TARGET_STICK_RANGE_MULTIPLIER: float = 1.35
const STUCK_RECOVERY_DELAY: float = 1.1
const STUCK_RECOVERY_SECONDS: float = 0.75
const SHOOT_STRAFE_SPEED_RATIO: float = 0.42

const CONTROL_MODE_LANE := "lane_2d"
const CONTROL_MODE_LOCK_ON := "lock_on"

enum State { PATROL, CHASE, SHOOT, FLEE_EDGE }
var _state: State = State.PATROL
var _target: Node3D = null            # 追踪的玩家
var _patrol_dest: Vector3 = Vector3.ZERO
var _reaction_timer: float = 0.0
var _visual_move_dir: Vector3 = Vector3.ZERO
var _visual_move_speed_ratio: float = 0.0
var _fire_cooldown_ai: float = 0.0    # AI 自己的开火节奏控制

var _ignored_pickups: Dictionary = {}
var _pickup_progress_id: int = 0
var _pickup_best_distance: float = INF
var _pickup_no_progress_seconds: float = 0.0
var _navigation_last_position: Vector3 = Vector3.ZERO
var _planned_move_dir: Vector3 = Vector3.ZERO
var _stuck_seconds: float = 0.0
var _recovery_dir: Vector3 = Vector3.ZERO
var _recovery_seconds: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_seconds: float = 0.0

func _ready() -> void:
	super._ready()
	_navigation_last_position = global_position
	_strafe_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
	_pick_patrol_dest()
	if weapon_manager:
		weapon_manager.weapon_switched.connect(_on_weapon_switched)

func _process(delta: float) -> void:
	super._base_process(delta)
	# 弹跳动画
	var visual = get_visual()
	if visual and not is_dead:
		var facing_dir := -transform.basis.z
		facing_dir.y = 0.0
		var move_dir := _visual_move_dir
		var speed_ratio := _visual_move_speed_ratio
		if move_dir.length_squared() <= 0.01:
			var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
			if horizontal_velocity.length() > 0.8:
				move_dir = horizontal_velocity.normalized()
				speed_ratio = clampf(horizontal_velocity.length() / 16.0, 0.0, 1.0)
		visual.animate_locomotion(move_dir, facing_dir, speed_ratio, delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_game_over:
		return

	# --- 坠落检测 ---
	_check_fall()
	if is_dead: return

	# --- 寻找目标 ---
	_tick_navigation_memory(delta)
	_find_target()
	_update_pickup_progress(delta)

	# --- FSM 状态更新 ---
	_update_state()

	# --- 执行行为 ---
	var move_dir := Vector3.ZERO
	match _state:
		State.PATROL:
			move_dir = _do_patrol(delta)
		State.CHASE:
			move_dir = _do_chase(delta)
		State.SHOOT:
			move_dir = _do_shoot(delta)
		State.FLEE_EDGE:
			move_dir = _do_flee_edge(delta)

	move_dir = _apply_stuck_recovery(move_dir, delta)
	move_dir = _apply_map_hazard_bias(move_dir)
	_planned_move_dir = move_dir.normalized() if move_dir.length_squared() > 0.01 else Vector3.ZERO

	if move_dir.length() > 0.1:
		_visual_move_dir = move_dir.normalized()
		_visual_move_speed_ratio = clampf(move_dir.length() / maxf(get_movement_speed(), 1.0), 0.0, 1.0)
	else:
		_visual_move_dir = Vector3.ZERO
		_visual_move_speed_ratio = 0.0

	# --- 应用移动 ---
	if move_dir.length() > 0.1:
		var force_scale := SHOOT_STRAFE_SPEED_RATIO if _state == State.SHOOT else 1.0
		apply_central_force(move_dir.normalized() * get_movement_speed() * force_scale)

# ============================================================
#  FSM 状态切换
# ============================================================
func _update_state() -> void:
	# 最高优先级：逃离边缘
	if _is_self_near_edge():
		if _state != State.FLEE_EDGE:
			_state = State.FLEE_EDGE
		return

	# 从逃离边缘恢复
	if _state == State.FLEE_EDGE and not _is_self_near_edge():
		_state = State.PATROL if not _target else State.CHASE

	var priority_pickup := _find_nearby_pickup()
	if priority_pickup:
		_target = priority_pickup
		_state = State.CHASE
		return

	if not _target:
		_state = State.PATROL
		return

	var dist = global_position.distance_to(_target.global_position)

	match _state:
		State.PATROL:
			if dist < VISION_RANGE:
				_state = State.CHASE
				_reaction_timer = REACTION_TIME
		State.CHASE:
			if dist > VISION_RANGE:
				_state = State.PATROL
				_pick_patrol_dest()
			elif _target is BaseCharacter and dist < FIRE_RANGE and _has_line_of_sight_to_target():
				_state = State.SHOOT
				_reaction_timer = REACTION_TIME
		State.SHOOT:
			if not (_target is BaseCharacter) or dist > FIRE_RANGE_EXIT or not _has_line_of_sight_to_target():
				_state = State.CHASE
			elif dist > VISION_RANGE:
				_state = State.PATROL
				_pick_patrol_dest()

	# 武器拾取检查：巡逻/追击时如果附近有武器就去捡
	if _state in [State.PATROL, State.CHASE]:
		var pickup = _find_nearby_pickup()
		if pickup:
			_target = pickup  # 临时把拾取物当目标
			_state = State.CHASE

# ============================================================
#  各状态行为
# ============================================================
func _do_patrol(_delta: float) -> Vector3:
	var to_dest = _patrol_dest - global_position
	to_dest.y = 0
	if to_dest.length() < 3.0:
		_pick_patrol_dest()
		to_dest = _patrol_dest - global_position
		to_dest.y = 0.0
	var desired_dir := to_dest.normalized()
	var safe_dir := _pick_safe_local_direction(desired_dir)
	if safe_dir.length_squared() <= 0.01:
		return Vector3.ZERO
	_face_direction(safe_dir)
	return safe_dir * patrol_speed

func _do_chase(_delta: float) -> Vector3:
	if not _target or not is_instance_valid(_target):
		_state = State.PATROL
		return Vector3.ZERO
	var to_target = _target.global_position - global_position
	to_target.y = 0
	if to_target.length_squared() <= 0.01:
		return Vector3.ZERO
	if _target is BaseCharacter and to_target.length() <= FIRE_RANGE and _has_line_of_sight_to_target():
		_state = State.SHOOT
		_reaction_timer = REACTION_TIME
		return Vector3.ZERO
	var chase_dir := _pick_safe_local_direction(to_target.normalized())
	if chase_dir.length_squared() <= 0.01:
		return Vector3.ZERO
	_face_direction(chase_dir)
	return chase_dir * get_movement_speed()

func _do_shoot(delta: float) -> Vector3:
	if not _target or not is_instance_valid(_target) or not (_target is BaseCharacter):
		_state = State.PATROL
		return Vector3.ZERO
	if not _has_line_of_sight_to_target():
		_state = State.CHASE
		return _do_chase(delta)

	var to_target_flat = _target.global_position - global_position
	to_target_flat.y = 0
	var is_lane_mode = _control_mode() == CONTROL_MODE_LANE
	if is_lane_mode:
		var x_sign = 1.0 if to_target_flat.x >= 0.0 else -1.0
		_face_direction(Vector3(x_sign, 0.0, 0.0))
		if absf(to_target_flat.z) > LANE_TARGET_Z_TOLERANCE:
			var lane_align_sign = 1.0 if to_target_flat.z >= 0.0 else -1.0
			return Vector3(0.0, 0.0, lane_align_sign) * get_movement_speed()
	else:
		_face_direction(to_target_flat.normalized())

	# 反应时间
	if _reaction_timer > 0.0:
		_reaction_timer -= delta
		return Vector3.ZERO

	# 射击
	if weapon_manager and weapon_point:
		var target_aim_pos = _target.global_position + Vector3(0, 1.0, 0)
		var fire_origin = weapon_point.global_position if weapon_point else global_position
		var aim_dir = _get_lane_fire_dir_to(_target) if is_lane_mode else (target_aim_pos - fire_origin).normalized()
		# 瞄准偏移
		if not is_lane_mode:
			var offset_rad = deg_to_rad(randf_range(-AIM_OFFSET_DEG, AIM_OFFSET_DEG))
			aim_dir = aim_dir.rotated(Vector3.UP, offset_rad)
		weapon_manager.try_fire(weapon_point, aim_dir, self)

	_strafe_seconds -= delta
	if _strafe_seconds <= 0.0:
		_strafe_seconds = 1.15
		_strafe_sign *= -1.0
	var strafe_dir := Vector3(-to_target_flat.z, 0.0, to_target_flat.x).normalized() * _strafe_sign
	var safe_strafe := _pick_safe_local_direction(strafe_dir, false)
	if safe_strafe.length_squared() <= 0.01:
		_strafe_sign *= -1.0
		safe_strafe = _pick_safe_local_direction(-strafe_dir, false)
	return safe_strafe * get_movement_speed() * SHOOT_STRAFE_SPEED_RATIO

func _do_flee_edge(_delta: float) -> Vector3:
	# 寻找有地面的安全方向后退，而不是盲目跑向原点
	var best_dir := Vector3.ZERO
	var best_dist := 0.0
	# 测试 8 个方向，选择地面最远的方向
	for i in range(8):
		var angle = i * (PI / 4.0)
		var test_dir = Vector3(cos(angle), 0, sin(angle))
		var check_dist = _get_ground_distance(test_dir)
		if check_dist > best_dist:
			best_dist = check_dist
			best_dir = test_dir
	if best_dir.length() < 0.1:
		# 四面楚歌，站着不动
		return Vector3.ZERO
	var safe_dir := _pick_safe_local_direction(best_dir)
	if safe_dir.length_squared() <= 0.01:
		return Vector3.ZERO
	_face_direction(safe_dir)
	return safe_dir * get_movement_speed()

func _respawn() -> void:
	super._respawn()
	_state = State.PATROL
	_target = null
	_reset_navigation_memory()
	_pick_patrol_dest()

# ============================================================
#  辅助方法
# ============================================================
func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.01: return
	var target_basis = Basis.looking_at(dir, Vector3.UP)
	transform.basis = transform.basis.slerp(target_basis, 0.3)

func _control_mode() -> String:
	var config = _game_config()
	if config == null:
		return CONTROL_MODE_LOCK_ON
	var value = config.get("control_mode")
	if value is String:
		return value
	return CONTROL_MODE_LOCK_ON

func _get_lane_fire_dir_to(target: Node3D) -> Vector3:
	var x_sign = 1.0
	if target and is_instance_valid(target):
		x_sign = 1.0 if target.global_position.x >= global_position.x else -1.0
	return Vector3(x_sign, 0.0, 0.0)

func _find_target() -> void:
	# 如果当前目标是拾取物且已被捡走，重新找玩家
	if _target and not is_instance_valid(_target):
		_target = null
	if _target and _is_pickup_target(_target):
		if not _ignored_pickups.has(_target.get_instance_id()):
			return
		_target = null
	# 寻找最近的活着的对手
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_target = null
		return
	var closest: Node3D = null
	var closest_dist := INF
	for p in players:
		if p == self: continue
		if p is BaseCharacter and (p as BaseCharacter).is_dead: continue
		if p is BaseCharacter and is_friendly_to(p as BaseCharacter): continue
		var d = global_position.distance_to(p.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = p
	if closest == null:
		_target = null
		return
	if is_instance_valid(_target) and _target is BaseCharacter and _is_valid_enemy(_target as BaseCharacter):
		var current_distance := global_position.distance_to(_target.global_position)
		if current_distance <= VISION_RANGE * TARGET_STICK_RANGE_MULTIPLIER:
			if closest == _target or closest_dist >= current_distance * TARGET_SWITCH_RATIO:
				return
	_target = closest

func _find_nearby_pickup() -> Node3D:
	var closest: Node3D = null
	var closest_distance := PICKUP_RANGE
	var candidates: Array[Node] = []
	if weapon_manager and not weapon_manager.has_primary():
		candidates.append_array(get_tree().get_nodes_in_group("weapon_pickup"))
	candidates.append_array(get_tree().get_nodes_in_group("powerup_pickup"))
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not (candidate is Node3D):
			continue
		if _ignored_pickups.has(candidate.get_instance_id()):
			continue
		var distance := global_position.distance_to((candidate as Node3D).global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate as Node3D
	return closest

func _is_pickup_target(node: Node) -> bool:
	return node.is_in_group("weapon_pickup") or node.is_in_group("powerup_pickup")

func _is_valid_enemy(character: BaseCharacter) -> bool:
	return (
		is_instance_valid(character)
		and not character.is_dead
		and not character.is_game_over
		and not is_friendly_to(character)
	)

func _pick_patrol_dest() -> void:
	# 从重生点列表中随机选一个作为巡逻目的地（保证目的地有地面）
	var points = _game_config_respawn_points()
	if points.is_empty():
		_patrol_dest = global_position
		return
	# 尝试几次，优先选离自己有一定距离的点
	var best_point: Vector3 = points.pick_random()
	for _i in range(3):
		var candidate: Vector3 = points.pick_random()
		var d = global_position.distance_to(candidate)
		if d > 20.0:
			best_point = candidate
			break
	_patrol_dest = best_point

func _is_self_near_edge() -> bool:
	if not _has_ground_ahead(Vector3.ZERO, 0.0):
		return true
	var motion_dir := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if motion_dir.length() <= 1.5:
		motion_dir = _planned_move_dir
	if motion_dir.length_squared() <= 0.01:
		return false
	return not _has_ground_ahead(motion_dir.normalized(), EDGE_ESCAPE_PROBE)

## 检测指定方向 dist 距离处是否有地面
func _has_ground_ahead(dir: Vector3, dist: float) -> bool:
	var space_state = get_world_3d().direct_space_state
	var check_pos = global_position + dir * dist + Vector3.UP * 2.0
	var query = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 10.0)
	query.exclude = _navigation_exclusions()
	query.collision_mask = 1
	query.collide_with_areas = false
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

## 检测指定方向 dist 距离内是否有墙壁/障碍物（水平射线）
func _has_wall_ahead(dir: Vector3, dist: float) -> bool:
	var space_state = get_world_3d().direct_space_state
	var origin = global_position + Vector3.UP * 1.0  # 从角色腰部高度发射
	var end = origin + dir * dist
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = _navigation_exclusions()
	query.collide_with_areas = false
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _pick_safe_local_direction(desired_dir: Vector3, require_far_ground: bool = true) -> Vector3:
	var flat_desired := Vector3(desired_dir.x, 0.0, desired_dir.z)
	if flat_desired.length_squared() <= 0.01:
		return Vector3.ZERO
	flat_desired = flat_desired.normalized()
	for angle_degrees in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0]:
		var candidate := flat_desired.rotated(Vector3.UP, deg_to_rad(angle_degrees)).normalized()
		if not _has_ground_ahead(candidate, NAV_GROUND_NEAR):
			continue
		if require_far_ground and not _has_ground_ahead(candidate, NAV_GROUND_FAR):
			continue
		if _has_wall_ahead(candidate, 2.8):
			continue
		return candidate
	return Vector3.ZERO

## Optional map-owned movement bias.  Providers cannot change AI state, target,
## aim, or fire decisions; they only blend the final movement direction.
func _apply_map_hazard_bias(move_dir: Vector3) -> Vector3:
	if not is_inside_tree():
		return move_dir
	var best_direction := Vector3.ZERO
	var best_weight := 0.0
	for provider: Node in get_tree().get_nodes_in_group(&"party_shooter_ai_hazard_provider"):
		if not is_instance_valid(provider) or not provider.has_method("get_ai_movement_bias"):
			continue
		var response: Variant = provider.call("get_ai_movement_bias", self)
		if not response is Dictionary:
			continue
		var bias := response as Dictionary
		var direction_value: Variant = bias.get("direction", Vector3.ZERO)
		if not direction_value is Vector3:
			continue
		var candidate := direction_value as Vector3
		candidate.y = 0.0
		var weight := clampf(float(bias.get("weight", 0.0)), 0.0, 1.0)
		if candidate.length_squared() <= 0.01 or weight <= best_weight:
			continue
		best_direction = candidate.normalized()
		best_weight = weight
	if best_weight <= 0.0:
		return move_dir

	var magnitude := move_dir.length()
	if magnitude <= 0.1:
		return best_direction * get_movement_speed() * best_weight
	var blended := move_dir.normalized().lerp(best_direction, best_weight)
	if blended.length_squared() <= 0.01:
		return best_direction * magnitude
	return blended.normalized() * magnitude

func _has_line_of_sight_to_target() -> bool:
	if not (_target is BaseCharacter) or not is_instance_valid(_target):
		return false
	var origin := weapon_point.global_position if weapon_point else global_position + Vector3.UP
	var target_position := _target.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, target_position)
	query.exclude = _line_of_sight_exclusions()
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == _target

func _navigation_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group("player"):
		if node is BaseCharacter:
			var rid := (node as BaseCharacter).get_rid()
			if rid not in exclusions:
				exclusions.append(rid)
	return exclusions

func _line_of_sight_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group("player"):
		if node is BaseCharacter and is_friendly_to(node as BaseCharacter):
			var rid := (node as BaseCharacter).get_rid()
			if rid not in exclusions:
				exclusions.append(rid)
	return exclusions

## 获取指定方向上连续有地面的最远距离
func _get_ground_distance(dir: Vector3) -> float:
	var max_dist := 0.0
	for step in [4.0, 8.0, 12.0, 20.0, 30.0]:
		if _has_ground_ahead(dir, step):
			max_dist = step
		else:
			break
	return max_dist

func _tick_navigation_memory(delta: float) -> void:
	for pickup_id in _ignored_pickups.keys():
		var remaining := float(_ignored_pickups[pickup_id]) - delta
		if remaining <= 0.0:
			_ignored_pickups.erase(pickup_id)
		else:
			_ignored_pickups[pickup_id] = remaining

func _update_pickup_progress(delta: float) -> void:
	if not _target or not is_instance_valid(_target) or not _is_pickup_target(_target):
		_pickup_progress_id = 0
		_pickup_best_distance = INF
		_pickup_no_progress_seconds = 0.0
		return
	var pickup_id := _target.get_instance_id()
	var distance := global_position.distance_to(_target.global_position)
	if pickup_id != _pickup_progress_id:
		_pickup_progress_id = pickup_id
		_pickup_best_distance = distance
		_pickup_no_progress_seconds = 0.0
		return
	if distance <= _pickup_best_distance - PICKUP_PROGRESS_EPSILON:
		_pickup_best_distance = distance
		_pickup_no_progress_seconds = 0.0
		return
	_pickup_no_progress_seconds += delta
	if _pickup_no_progress_seconds < PICKUP_PROGRESS_TIMEOUT:
		return
	_ignored_pickups[pickup_id] = PICKUP_IGNORE_SECONDS
	_target = null
	_state = State.PATROL
	_pickup_progress_id = 0
	_pickup_best_distance = INF
	_pickup_no_progress_seconds = 0.0
	_pick_patrol_dest()

func _apply_stuck_recovery(move_dir: Vector3, delta: float) -> Vector3:
	var moved_distance := global_position.distance_to(_navigation_last_position)
	_navigation_last_position = global_position
	if _recovery_seconds > 0.0:
		_recovery_seconds = maxf(0.0, _recovery_seconds - delta)
		var safe_recovery := _pick_safe_local_direction(_recovery_dir, false)
		if safe_recovery.length_squared() > 0.01:
			return safe_recovery * get_movement_speed()
		_recovery_seconds = 0.0

	var expects_movement := move_dir.length_squared() > 0.01 or _state in [State.PATROL, State.CHASE, State.FLEE_EDGE]
	if expects_movement and moved_distance < 0.02:
		_stuck_seconds += delta
	else:
		_stuck_seconds = 0.0
	if _stuck_seconds < STUCK_RECOVERY_DELAY:
		return move_dir

	_recovery_dir = _choose_recovery_direction(move_dir)
	_stuck_seconds = 0.0
	if _recovery_dir.length_squared() <= 0.01:
		_pick_patrol_dest()
		return move_dir
	_recovery_seconds = STUCK_RECOVERY_SECONDS
	return _recovery_dir * get_movement_speed()

func _choose_recovery_direction(move_dir: Vector3) -> Vector3:
	var base_dir := Vector3(move_dir.x, 0.0, move_dir.z)
	if base_dir.length_squared() <= 0.01 and _target and is_instance_valid(_target):
		base_dir = _target.global_position - global_position
		base_dir.y = 0.0
	if base_dir.length_squared() <= 0.01:
		base_dir = -transform.basis.z
	base_dir = base_dir.normalized()
	for angle_degrees in [90.0, -90.0, 135.0, -135.0, 180.0, 45.0, -45.0, 0.0]:
		var candidate := base_dir.rotated(Vector3.UP, deg_to_rad(angle_degrees)).normalized()
		if not _has_ground_ahead(candidate, NAV_GROUND_NEAR):
			continue
		if not _has_ground_ahead(candidate, NAV_GROUND_FAR):
			continue
		if _has_wall_ahead(candidate, 2.8):
			continue
		return candidate
	return Vector3.ZERO

func _reset_navigation_memory() -> void:
	_ignored_pickups.clear()
	_pickup_progress_id = 0
	_pickup_best_distance = INF
	_pickup_no_progress_seconds = 0.0
	_navigation_last_position = global_position
	_planned_move_dir = Vector3.ZERO
	_stuck_seconds = 0.0
	_recovery_dir = Vector3.ZERO
	_recovery_seconds = 0.0

func _on_weapon_switched(weapon_data: WeaponData) -> void:
	var visual = get_visual()
	if visual:
		visual.set_weapon_visual(weapon_data.weapon_id)
