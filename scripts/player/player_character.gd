extends BaseCharacter
class_name PlayerCharacter

# 射击输入追踪
var _prev_fire_pressed: bool = false

# 狙击硬直
var _stun_timer: float = 0.0

func _ready() -> void:
	if weapon_manager:
		weapon_manager.stun_started.connect(_on_stun_started)
		weapon_manager.weapon_dropped.connect(_on_weapon_dropped)

func _process(delta: float) -> void:
	super._base_process(delta)
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_game_over:
		return

	# --- 坠落检测 ---
	_check_fall()
	if is_dead: return

	_apply_gravity(delta)

	# --- 移动输入 ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir == Vector2.ZERO:
		var x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		var z = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		input_dir = Vector2(x, z).normalized()

	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	# 硬直期间不能移动/转向
	if _stun_timer > 0.0:
		direction = Vector3.ZERO

	var target_vel = direction * speed

	_apply_movement(target_vel, delta)

	if _stun_timer <= 0.0:
		_look_at_mouse()

	# --- 射击输入 ---
	_handle_fire_input()

	# --- 武器切换输入 ---
	_handle_weapon_input()

	move_and_slide()



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
