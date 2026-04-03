extends CharacterBody3D
class_name PlayerCharacter

@export var speed: float = 24.0
@export var acceleration: float = 12.0
@export var friction: float = 6.0
@export var gravity: float = 20.0

@onready var weapon_point: Marker3D = get_node_or_null("WeaponPoint")
@onready var weapon_manager: WeaponManager = get_node_or_null("WeaponManager")
@onready var _mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")

var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_resistance: float = 0.0

# 射击输入追踪
var _prev_fire_pressed: bool = false

# 狙击硬直
var _stun_timer: float = 0.0

# ============================================================
#  生命与复活系统
# ============================================================
const FALL_THRESHOLD: float = -10.0
const RESPAWN_DELAY: float = 3.0
const INVINCIBLE_DURATION: float = 3.0
const RESPAWN_POINTS: Array[Vector3] = [
	Vector3(25, 0.5, 25),
	Vector3(-25, 0.5, 25),
	Vector3(25, 0.5, -25),
	Vector3(-25, 0.5, -25),
]

var lives: int = 10
var is_dead: bool = false
var is_invincible: bool = false
var is_game_over: bool = false
var _respawn_timer: float = 0.0
var _invincible_timer: float = 0.0

func _ready() -> void:
	if weapon_manager:
		weapon_manager.stun_started.connect(_on_stun_started)
		weapon_manager.weapon_dropped.connect(_on_weapon_dropped)

func _process(delta: float) -> void:
	if knockback_resistance > 0.0:
		knockback_resistance = max(0.0, knockback_resistance - delta * 0.5)
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)

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

func _physics_process(delta: float) -> void:
	if is_dead or is_game_over:
		return

	# --- 坠落检测 ---
	if global_position.y < FALL_THRESHOLD:
		_die()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	# --- 移动输入 ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		var x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		var z = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		input_dir = Vector2(x, z).normalized()

	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	# --- 击退衰减 ---
	if knockback_velocity.length_squared() > 0.1:
		knockback_velocity = knockback_velocity.lerp(Vector3.ZERO, friction * 0.4 * delta)
	else:
		knockback_velocity = Vector3.ZERO

	var current_move_vel = velocity - knockback_velocity
	current_move_vel.y = 0

	# 硬直期间不能移动/转向
	if _stun_timer > 0.0:
		direction = Vector3.ZERO

	var target_vel = direction * speed
	var control_factor = 1.0
	if knockback_velocity.length() > speed * 0.3:
		control_factor = 0.05

	if direction:
		current_move_vel = current_move_vel.lerp(target_vel, acceleration * control_factor * delta)
	else:
		current_move_vel = current_move_vel.lerp(Vector3.ZERO, friction * delta)

	velocity.x = current_move_vel.x + knockback_velocity.x
	velocity.z = current_move_vel.z + knockback_velocity.z

	if _stun_timer <= 0.0:
		_look_at_mouse()

	# --- 射击输入 ---
	_handle_fire_input()

	# --- 武器切换输入 ---
	_handle_weapon_input()

	move_and_slide()

# ------------------------------------------------------------------
#  生命系统
# ------------------------------------------------------------------
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

	_respawn_timer = RESPAWN_DELAY

func _respawn() -> void:
	is_dead = false

	# 随机复活点
	var spawn_point = RESPAWN_POINTS.pick_random()
	global_position = spawn_point
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	knockback_resistance = 0.0

	# 显示角色
	visible = true
	set_physics_process(true)

	# 启动无敌盾
	is_invincible = true
	_invincible_timer = INVINCIBLE_DURATION

# ------------------------------------------------------------------
#  射击输入处理
# ------------------------------------------------------------------
func _handle_fire_input() -> void:
	if not weapon_manager or _stun_timer > 0.0:
		return

	var fire_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var fire_just_pressed = fire_pressed and not _prev_fire_pressed
	_prev_fire_pressed = fire_pressed

	var fire_dir = -transform.basis.z
	var fire_mode = weapon_manager.get_current_fire_mode()

	var should_fire = false
	match fire_mode:
		WeaponData.FireMode.SEMI_AUTO, WeaponData.FireMode.BOLT_ACTION:
			should_fire = fire_just_pressed
		WeaponData.FireMode.FULL_AUTO:
			should_fire = fire_pressed

	if should_fire:
		weapon_manager.try_fire(weapon_point, fire_dir, self)

# ------------------------------------------------------------------
#  武器切换 & 换弹输入
# ------------------------------------------------------------------
func _handle_weapon_input() -> void:
	if not weapon_manager:
		return
	if Input.is_key_pressed(KEY_1):
		weapon_manager.switch_to_slot(0)
	elif Input.is_key_pressed(KEY_2):
		weapon_manager.switch_to_slot(1)

	if Input.is_action_just_pressed("ui_focus_next"):
		weapon_manager.cycle_weapon()

# ------------------------------------------------------------------
#  击退
# ------------------------------------------------------------------
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

# ------------------------------------------------------------------
#  鼠标瞄准
# ------------------------------------------------------------------
func _look_at_mouse() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera: return

	var mouse_position = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_position)
	var ray_dir = camera.project_ray_normal(mouse_position)
	var plane_y = global_position.y
	if ray_dir.y >= 0: return

	var t = (plane_y - ray_origin.y) / ray_dir.y
	var target_pos = ray_origin + ray_dir * t
	var look_dir = target_pos - global_position
	look_dir.y = 0
	if look_dir.length_squared() > 0.01:
		look_dir = look_dir.normalized()
		var target_basis = Basis.looking_at(look_dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, 0.4)

# ------------------------------------------------------------------
#  信号回调
# ------------------------------------------------------------------
func _on_stun_started(duration: float) -> void:
	_stun_timer = duration

func _on_weapon_dropped(drop_position: Vector3) -> void:
	_spawn_drop_visual(drop_position)

func _spawn_drop_visual(pos: Vector3) -> void:
	var drop = MeshInstance3D.new()
	drop.mesh = BoxMesh.new()
	drop.mesh.size = Vector3(0.5, 0.5, 0.5)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.6, 1)
	drop.material_override = mat
	get_tree().current_scene.add_child(drop)
	drop.global_position = pos + Vector3.UP * 1.5

	var forward = -transform.basis.z
	var tween = drop.create_tween()
	var end_pos = pos + forward * 3.0
	tween.tween_property(drop, "global_position", end_pos, 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(drop, "global_position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(drop.queue_free)

# ------------------------------------------------------------------
#  滚轮输入（通过 _input 捕获）
# ------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and weapon_manager:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				weapon_manager.cycle_weapon()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				weapon_manager.cycle_weapon()
