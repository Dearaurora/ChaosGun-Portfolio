extends BaseCharacter
class_name PlayerCharacter


# 狙击硬直 (已移除)


func _ready() -> void:
	if weapon_manager:
		weapon_manager.weapon_dropped.connect(_on_weapon_dropped)

func _process(delta: float) -> void:
	super._base_process(delta)

func _physics_process(delta: float) -> void:
	if is_dead or is_game_over:
		return

	# --- 坠落检测 ---
	_check_fall()
	if is_dead: return

	_apply_gravity(delta)

	# --- 移动输入 ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()


	var target_vel = direction * speed

	_apply_movement(target_vel, delta)

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
	if not weapon_manager:
		return

	var fire_dir = -transform.basis.z
	var fire_mode = weapon_manager.get_current_fire_mode()

	var should_fire = false
	match fire_mode:
		WeaponData.FireMode.SEMI_AUTO, WeaponData.FireMode.BOLT_ACTION:
			should_fire = Input.is_action_just_pressed("fire")
		WeaponData.FireMode.FULL_AUTO:
			should_fire = Input.is_action_pressed("fire")

	if should_fire:
		weapon_manager.try_fire(weapon_point, fire_dir, self)

# ------------------------------------------------------------------
#  武器切换 & 换弹输入
# ------------------------------------------------------------------
func _handle_weapon_input() -> void:
	if not weapon_manager:
		return
	if Input.is_action_just_pressed("weapon_slot_1"):
		weapon_manager.switch_to_slot(0)
	elif Input.is_action_just_pressed("weapon_slot_2"):
		weapon_manager.switch_to_slot(1)

	if Input.is_action_just_pressed("weapon_cycle"):
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

# 信号回调 (已移除 _on_stun_started)


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

