extends BaseCharacter
class_name AICharacter
## AI 对手 —— FSM 状态机驱动，复用武器系统与击退/生命系统

@export var patrol_speed: float = 250.0

# ============================================================
#  AI 参数
# ============================================================
const FIRE_RANGE: float = 30.0
const FIRE_RANGE_EXIT: float = 35.0   # 滞回：退出射击状态的距离
const VISION_RANGE: float = 50.0
const EDGE_SAFE_DIST: float = 8.0
const AIM_OFFSET_DEG: float = 5.0     # 瞄准偏移（±度）
const REACTION_TIME: float = 0.3
const PICKUP_RANGE: float = 15.0

enum State { PATROL, CHASE, SHOOT, FLEE_EDGE }
var _state: State = State.PATROL
var _target: Node3D = null            # 追踪的玩家
var _patrol_dest: Vector3 = Vector3.ZERO
var _reaction_timer: float = 0.0
var _fire_cooldown_ai: float = 0.0    # AI 自己的开火节奏控制

func _ready() -> void:
	_pick_patrol_dest()
	if weapon_manager:
		weapon_manager.weapon_switched.connect(_on_weapon_switched)

func _process(delta: float) -> void:
	super._base_process(delta)
	# 弹跳动画
	var visual = get_visual()
	if visual and not is_dead:
		var is_moving = linear_velocity.length() > 1.0
		visual.animate_movement(is_moving, delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_game_over:
		return

	# --- 坠落检测 ---
	_check_fall()
	if is_dead: return

	# --- 寻找目标 ---
	_find_target()

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

	# --- 应用移动 ---
	if move_dir.length() > 0.1:
		apply_central_force(move_dir.normalized() * GameConfig.character_speed)

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
			elif dist < FIRE_RANGE:
				_state = State.SHOOT
		State.SHOOT:
			if dist > FIRE_RANGE_EXIT:
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
	var dir = to_dest.normalized()
	# 前方悬崖检测 / 障碍物检测
	if not _has_ground_ahead(dir, 5.0) or _has_wall_ahead(dir, 3.0):
		_pick_patrol_dest()
		return Vector3.ZERO
	return dir * patrol_speed

func _do_chase(_delta: float) -> Vector3:
	if not _target or not is_instance_valid(_target):
		_state = State.PATROL
		return Vector3.ZERO
	var to_target = _target.global_position - global_position
	to_target.y = 0
	var chase_dir = to_target.normalized()
	# 前方悬崖 / 障碍物检测
	if not _has_ground_ahead(chase_dir, 5.0) or _has_wall_ahead(chase_dir, 3.0):
		if _target is BaseCharacter:
			_state = State.SHOOT  # 有障碍挡着，站着打
		else:
			_state = State.PATROL
			_pick_patrol_dest()
		return Vector3.ZERO
	_face_direction(chase_dir)
	return chase_dir * GameConfig.character_speed

func _do_shoot(delta: float) -> Vector3:
	if not _target or not is_instance_valid(_target):
		_state = State.PATROL
		return Vector3.ZERO

	var to_target_flat = _target.global_position - global_position
	to_target_flat.y = 0
	_face_direction(to_target_flat.normalized())

	# 反应时间
	if _reaction_timer > 0.0:
		_reaction_timer -= delta
		return Vector3.ZERO

	# 射击
	if weapon_manager and weapon_point:
		var target_aim_pos = _target.global_position + Vector3(0, 1.0, 0)
		var fire_origin = weapon_point.global_position if weapon_point else global_position
		var aim_dir = (target_aim_pos - fire_origin).normalized()
		# 瞄准偏移
		var offset_rad = deg_to_rad(randf_range(-AIM_OFFSET_DEG, AIM_OFFSET_DEG))
		aim_dir = aim_dir.rotated(Vector3.UP, offset_rad)
		weapon_manager.try_fire(weapon_point, aim_dir, self)

	return Vector3.ZERO  # 射击时站定

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
	_face_direction(best_dir)
	return best_dir * GameConfig.character_speed

func _respawn() -> void:
	super._respawn()
	_state = State.PATROL
	_pick_patrol_dest()

# ============================================================
#  辅助方法
# ============================================================
func _face_direction(dir: Vector3) -> void:
	if dir.length_squared() < 0.01: return
	var target_basis = Basis.looking_at(dir, Vector3.UP)
	transform.basis = transform.basis.slerp(target_basis, 0.3)

func _find_target() -> void:
	# 如果当前目标是拾取物且已被捡走，重新找玩家
	if _target and not is_instance_valid(_target):
		_target = null
	if _target and _target is WeaponPickup:
		# 拾取物还在就继续追
		return
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
		var d = global_position.distance_to(p.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = p
	_target = closest

func _find_nearby_pickup() -> WeaponPickup:
	if weapon_manager and weapon_manager.has_primary():
		return null  # 已有主武器，不需要拾取
	var pickups = get_tree().get_nodes_in_group("weapon_pickup")
	for p in pickups:
		if is_instance_valid(p) and global_position.distance_to(p.global_position) < PICKUP_RANGE:
			return p as WeaponPickup
	return null

func _pick_patrol_dest() -> void:
	# 从重生点列表中随机选一个作为巡逻目的地（保证目的地有地面）
	var points = GameConfig.respawn_points
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
	# 用射线检测：检查四个方向，任一方向 EDGE_SAFE_DIST 内没有地面即为边缘
	var directions = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	for dir in directions:
		if not _has_ground_ahead(dir, EDGE_SAFE_DIST):
			return true
	return false

## 检测指定方向 dist 距离处是否有地面
func _has_ground_ahead(dir: Vector3, dist: float) -> bool:
	var space_state = get_world_3d().direct_space_state
	var check_pos = global_position + dir * dist + Vector3.UP * 2.0
	var query = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 10.0)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

## 检测指定方向 dist 距离内是否有墙壁/障碍物（水平射线）
func _has_wall_ahead(dir: Vector3, dist: float) -> bool:
	var space_state = get_world_3d().direct_space_state
	var origin = global_position + Vector3.UP * 1.0  # 从角色腰部高度发射
	var end = origin + dir * dist
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

## 获取指定方向上连续有地面的最远距离
func _get_ground_distance(dir: Vector3) -> float:
	var max_dist := 0.0
	for step in [4.0, 8.0, 12.0, 20.0, 30.0]:
		if _has_ground_ahead(dir, step):
			max_dist = step
		else:
			break
	return max_dist

func _on_weapon_switched(weapon_data: WeaponData) -> void:
	var visual = get_visual()
	if visual:
		visual.set_weapon_visual(weapon_data.weapon_id)
