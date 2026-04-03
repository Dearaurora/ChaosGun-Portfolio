extends CharacterBody3D
class_name AICharacter
## AI 对手 —— FSM 状态机驱动，复用武器系统与击退/生命系统

# ============================================================
#  基础参数（与 PlayerCharacter 对齐）
# ============================================================
@export var speed: float = 18.0
@export var patrol_speed: float = 12.0
@export var acceleration: float = 10.0
@export var friction: float = 6.0
@export var gravity: float = 20.0

@onready var weapon_point: Marker3D = get_node_or_null("WeaponPoint")
@onready var weapon_manager: WeaponManager = get_node_or_null("WeaponManager")
@onready var _mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")

# ============================================================
#  击退物理（与 PlayerCharacter 完全相同）
# ============================================================
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_resistance: float = 0.0

# ============================================================
#  生命与复活（与 PlayerCharacter 完全相同）
# ============================================================
const FALL_THRESHOLD: float = -10.0
const RESPAWN_DELAY: float = 3.0
const INVINCIBLE_DURATION: float = 3.0
const RESPAWN_POINTS: Array[Vector3] = [
	Vector3(25, 0.5, 25), Vector3(-25, 0.5, 25),
	Vector3(25, 0.5, -25), Vector3(-25, 0.5, -25),
]
var lives: int = 10
var is_dead: bool = false
var is_invincible: bool = false
var is_game_over: bool = false
var _respawn_timer: float = 0.0
var _invincible_timer: float = 0.0

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
const MAP_HALF: float = 50.0

enum State { PATROL, CHASE, SHOOT, FLEE_EDGE }
var _state: State = State.PATROL
var _target: Node3D = null            # 追踪的玩家
var _patrol_dest: Vector3 = Vector3.ZERO
var _reaction_timer: float = 0.0
var _fire_cooldown_ai: float = 0.0    # AI 自己的开火节奏控制

func _ready() -> void:
	_pick_patrol_dest()
	if weapon_manager:
		weapon_manager.stun_started.connect(func(_d): pass)  # AI 不受硬直影响（可选）

func _process(delta: float) -> void:
	# 击退抗性衰减
	if knockback_resistance > 0.0:
		knockback_resistance = max(0.0, knockback_resistance - delta * 0.5)

	# 复活倒计时
	if is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	# 无敌盾
	if is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false
			if _mesh: _mesh.visible = true
		elif _mesh:
			_mesh.visible = fmod(_invincible_timer, 0.3) > 0.15

func _physics_process(delta: float) -> void:
	if is_dead or is_game_over:
		return

	# --- 坠落检测 ---
	if global_position.y < FALL_THRESHOLD:
		_die()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

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

	# --- 应用移动（与 PlayerCharacter 相同的物理） ---
	_apply_movement(move_dir, delta)
	move_and_slide()

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

# ============================================================
#  移动物理（与 PlayerCharacter 对齐）
# ============================================================
func _apply_movement(desired_vel: Vector3, delta: float) -> void:
	# 击退衰减
	if knockback_velocity.length_squared() > 0.1:
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, friction * 0.8 * delta)
	else:
		knockback_velocity = Vector3.ZERO

	var current_move_vel = velocity - knockback_velocity
	current_move_vel.y = 0

	var control_factor = 1.0
	if knockback_velocity.length() > speed * 0.5:
		control_factor = 0.2

	if desired_vel.length() > 0.1:
		current_move_vel = current_move_vel.lerp(desired_vel, acceleration * control_factor * delta)
	else:
		current_move_vel = current_move_vel.lerp(Vector3.ZERO, friction * delta)

	velocity.x = current_move_vel.x + knockback_velocity.x
	velocity.z = current_move_vel.z + knockback_velocity.z

# ============================================================
#  击退 & 生命
# ============================================================
func apply_knockback(force: Vector3) -> void:
	if is_invincible or is_dead:
		return
	var push_dir = force.normalized()
	var edge_damping = 1.0
	if _is_near_edge(push_dir):
		edge_damping = 0.4
	var actual_force = force * edge_damping * max(0.2, (1.0 - knockback_resistance))
	knockback_velocity += actual_force
	knockback_resistance = min(0.75, knockback_resistance + 0.3)

func _die() -> void:
	if is_dead: return
	lives -= 1
	is_dead = true
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	visible = false
	set_physics_process(false)
	if lives <= 0:
		is_game_over = true
		return
	_respawn_timer = RESPAWN_DELAY

func _respawn() -> void:
	is_dead = false
	global_position = RESPAWN_POINTS.pick_random()
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	knockback_resistance = 0.0
	visible = true
	set_physics_process(true)
	is_invincible = true
	_invincible_timer = INVINCIBLE_DURATION
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
	var range_val = MAP_HALF * 0.5  # 在地图中心 50% 区域巡逻
	_patrol_dest = Vector3(
		randf_range(-range_val, range_val),
		0.5,
		randf_range(-range_val, range_val)
	)

func _is_self_near_edge() -> bool:
	var x_edge = abs(global_position.x) > MAP_HALF - EDGE_SAFE_DIST
	var z_edge = abs(global_position.z) > MAP_HALF - EDGE_SAFE_DIST
	return x_edge or z_edge

func _is_near_edge(push_dir: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var check_pos = global_position + push_dir * 4.0 + Vector3.UP * 0.5
	var query = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 2.0)
	var result = space_state.intersect_ray(query)
	return result.is_empty()
