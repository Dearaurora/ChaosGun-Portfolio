extends BaseCharacter
class_name AICharacter
## AI 对手 —— FSM 状态机驱动，复用武器系统与击退/生命系统

@export var patrol_speed: float = 12.0

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


func _process(delta: float) -> void:
	super._base_process(delta)

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
		apply_central_force(move_dir.normalized() * speed)

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
	return to_dest.normalized() * patrol_speed

func _do_chase(_delta: float) -> Vector3:
	if not _target or not is_instance_valid(_target):
		_state = State.PATROL
		return Vector3.ZERO
	var to_target = _target.global_position - global_position
	to_target.y = 0
	_face_direction(to_target.normalized())
	return to_target.normalized() * speed

func _do_shoot(delta: float) -> Vector3:
	if not _target or not is_instance_valid(_target):
		_state = State.PATROL
		return Vector3.ZERO

	var to_target = _target.global_position - global_position
	to_target.y = 0
	_face_direction(to_target.normalized())

	# 反应时间
	if _reaction_timer > 0.0:
		_reaction_timer -= delta
		return Vector3.ZERO

	# 射击
	if weapon_manager and weapon_point:
		var aim_dir = to_target.normalized()
		# 瞄准偏移
		var offset_rad = deg_to_rad(randf_range(-AIM_OFFSET_DEG, AIM_OFFSET_DEG))
		aim_dir = aim_dir.rotated(Vector3.UP, offset_rad)
		weapon_manager.try_fire(weapon_point, aim_dir, self)

	return Vector3.ZERO  # 射击时站定

func _do_flee_edge(_delta: float) -> Vector3:
	# 向地图中心跑
	var to_center = -global_position
	to_center.y = 0
	_face_direction(to_center.normalized())
	return to_center.normalized() * speed

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
	# 寻找最近的玩家
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_target = null
		return
	var closest: Node3D = null
	var closest_dist := INF
	for p in players:
		if p == self: continue
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
	# 随机选择地图中心区域的一个点
	var range_val = GameConfig.map_half_size * 0.5  # 在地图中心 50% 区域巡逻
	_patrol_dest = Vector3(
		randf_range(-range_val, range_val),
		0.5,
		randf_range(-range_val, range_val)
	)

func _is_self_near_edge() -> bool:
	var x_edge = abs(global_position.x) > GameConfig.map_half_size - EDGE_SAFE_DIST
	var z_edge = abs(global_position.z) > GameConfig.map_half_size - EDGE_SAFE_DIST
	return x_edge or z_edge
