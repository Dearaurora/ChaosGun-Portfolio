extends BaseCharacter
class_name PlayerCharacter

## 本地多人版 —— 朝向射击 + 瞄准辅助
## 通过 input_prefix 区分不同玩家的输入（p1_ / p2_）

const AIM_ASSIST_CONE_DEG := 15.0
const AIM_ASSIST_RANGE := 60.0

## 输入前缀：由对战场景在生成时设置（"p1_" 或 "p2_"）
var input_prefix: String = "p1_"
## 玩家槽位索引（0-3）
var slot_index: int = 0

var _face_dir: Vector3 = Vector3.FORWARD

func _ready() -> void:
	super._ready()
	if weapon_manager:
		weapon_manager.weapon_dropped.connect(_on_weapon_dropped)
		weapon_manager.weapon_switched.connect(_on_weapon_switched)

func _process(delta: float) -> void:
	super._base_process(delta)
	var visual = get_visual()
	if visual and not is_dead:
		var is_moving = linear_velocity.length() > 1.0
		visual.animate_movement(is_moving, delta)

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
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()

	var current_speed = GameConfig.character_speed if is_on_floor() else GameConfig.character_speed * GameConfig.character_air_control_multiplier

	if direction.length() > 0.1:
		apply_central_force(direction * current_speed)

	if Input.is_action_just_pressed(input_prefix + "jump"):
		jump()

	# --- 面朝方向 = 输入方向 + 平滑插值 ---
	if direction.length() > 0.1:
		_face_dir = _face_dir.slerp(direction, 0.25).normalized()

	if _face_dir.length_squared() > 0.01:
		var target_basis = Basis.looking_at(_face_dir, Vector3.UP)
		transform.basis = transform.basis.slerp(target_basis, 0.4)

	# --- 射击 ---
	_handle_fire_input()

	# --- 武器切换 ---
	_handle_weapon_input()

# ------------------------------------------------------------------
func _handle_fire_input() -> void:
	if not weapon_manager:
		return
	var fire_mode = weapon_manager.get_current_fire_mode()
	var fire_action = input_prefix + "fire"
	var should_fire = false

	match fire_mode:
		WeaponData.FireMode.SEMI_AUTO, WeaponData.FireMode.BOLT_ACTION:
			should_fire = Input.is_action_just_pressed(fire_action)
		WeaponData.FireMode.FULL_AUTO:
			should_fire = Input.is_action_pressed(fire_action)

	if should_fire:
		var fire_dir = _get_aim_assisted_dir(_face_dir)
		weapon_manager.try_fire(weapon_point, fire_dir, self)

# ------------------------------------------------------------------
func _get_aim_assisted_dir(base_dir: Vector3) -> Vector3:
	var best_dot: float = cos(deg_to_rad(AIM_ASSIST_CONE_DEG))
	var best_dir: Vector3 = base_dir

	for node in get_tree().current_scene.get_children():
		if node == self: continue
		if not (node is BaseCharacter): continue
		var target := node as BaseCharacter
		if target.is_dead: continue
		var to_target = target.global_position - global_position
		to_target.y = 0
		var dist = to_target.length()
		if dist < 1.0 or dist > AIM_ASSIST_RANGE: continue
		var dir_to = to_target.normalized()
		var dot = base_dir.dot(dir_to)
		if dot > best_dot:
			best_dot = dot
			best_dir = dir_to
	return best_dir

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
	get_tree().current_scene.add_child(drop)
	drop.global_position = pos + Vector3.UP * 1.5
	var forward = -transform.basis.z
	var tween = drop.create_tween()
	var end_pos = pos + forward * 3.0
	tween.tween_property(drop, "global_position", end_pos, 0.3).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(drop, "global_position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(drop.queue_free)
