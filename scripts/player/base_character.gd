extends CharacterBody3D
class_name BaseCharacter

@export var speed: float = 24.0
@export var acceleration: float = 12.0
@export var friction: float = 6.0
@export var gravity: float = 20.0

@onready var weapon_point: Marker3D = get_node_or_null("WeaponPoint")
@onready var weapon_manager: WeaponManager = get_node_or_null("WeaponManager")
@onready var _mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")

var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_resistance: float = 0.0

# ============================================================
#  生命与复活系统
# ============================================================

var lives: int = GameConfig.default_lives
var is_dead: bool = false
var is_invincible: bool = false
var is_game_over: bool = false
var _respawn_timer: float = 0.0
var _invincible_timer: float = 0.0

func _base_process(delta: float) -> void:
	if knockback_resistance > 0.0:
		knockback_resistance = max(0.0, knockback_resistance - delta * 0.5)

	# 复活倒计时
	if is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	# 无敌盾倒计时 + 闪烁效果
	if is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false
			if _mesh:
				_mesh.visible = true
		elif _mesh:
			# 半透明闪烁：每 0.15 秒切换可见性
			_mesh.visible = fmod(_invincible_timer, 0.3) > 0.15

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _check_fall() -> void:
	if global_position.y < GameConfig.fall_threshold:
		_die()

func _apply_movement(desired_vel: Vector3, delta: float) -> void:
	if knockback_velocity.length_squared() > 0.1:
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, friction * 0.4 * delta)
	else:
		knockback_velocity = Vector3.ZERO

	var current_move_vel = velocity - knockback_velocity
	current_move_vel.y = 0

	var control_factor = 1.0
	if knockback_velocity.length() > speed * 0.3:
		control_factor = 0.05

	if desired_vel.length() > 0.1:
		current_move_vel = current_move_vel.lerp(desired_vel, acceleration * control_factor * delta)
	else:
		current_move_vel = current_move_vel.lerp(Vector3.ZERO, friction * delta)

	velocity.x = current_move_vel.x + knockback_velocity.x
	velocity.z = current_move_vel.z + knockback_velocity.z

func apply_knockback(force: Vector3) -> void:
	# 无敌期间免疫击退
	if is_invincible or is_dead:
		return
	var actual_force = force * max(0.2, (1.0 - knockback_resistance))
	knockback_velocity += actual_force
	knockback_resistance = min(0.4, knockback_resistance + 0.1)

func _is_near_edge(push_dir: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var check_pos = global_position + push_dir * 4.0 + Vector3.UP * 0.5
	var query = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 2.0)
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _die() -> void:
	if is_dead:
		return
	lives -= 1
	is_dead = true
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO

	# 隐藏角色
	visible = false
	# 关闭碰撞
	set_physics_process(false)

	if lives <= 0:
		is_game_over = true
		return

	_respawn_timer = GameConfig.respawn_delay

func _respawn() -> void:
	is_dead = false

	# 随机复活点
	var spawn_point = GameConfig.respawn_points.pick_random()
	global_position = spawn_point
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	knockback_resistance = 0.0

	# 显示角色
	visible = true
	set_physics_process(true)

	# 启动无敌盾
	is_invincible = true
	_invincible_timer = GameConfig.invincible_duration
