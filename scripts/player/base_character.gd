extends RigidBody3D
class_name BaseCharacter

@onready var weapon_point: Marker3D = get_node_or_null("WeaponPoint")
@onready var weapon_manager: WeaponManager = get_node_or_null("WeaponManager")

signal eliminated(character: BaseCharacter)

# 音效
var _sfx_hit_light: AudioStream = preload("res://assets/audio/sfx/hit_light.ogg")
var _sfx_hit_light2: AudioStream = preload("res://assets/audio/sfx/hit_light2.ogg")
var _sfx_hit_heavy: AudioStream = preload("res://assets/audio/sfx/hit_heavy.ogg")
var _sfx_fall: AudioStream = preload("res://assets/audio/sfx/fall_death.ogg")
var _sfx_shield: AudioStream = preload("res://assets/audio/sfx/shield_up.ogg")

# ============================================================
#  生命与复活系统
# ============================================================

var lives: int = GameConfig.default_lives
var max_hp: float = 3000.0
var current_hp: float = 3000.0
var is_dead: bool = false
var is_invincible: bool = false
var is_game_over: bool = false
var kills: int = 0
var deaths: int = 0
var last_hit_by: BaseCharacter = null
var _respawn_timer: float = 0.0
var _invincible_timer: float = 0.0
var _jump_cooldown: float = 0.0
var _was_on_floor: bool = true

func _ready() -> void:
	gravity_scale = GameConfig.character_gravity_scale
	# 禁用接触摩擦，水平减速完全由 horizontal_damp 控制，
	# 避免高重力下法向力过大导致角色走不动。
	var mat = PhysicsMaterial.new()
	mat.friction = 0.0
	physics_material_override = mat

func _base_process(delta: float) -> void:
	# 复活倒计时
	if is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return

	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta
		
	# 落地压扁检测
	var current_on_floor = is_on_floor()
	if current_on_floor and not _was_on_floor and linear_velocity.y < -1.0:
		var visual = get_visual()
		if visual:
			visual.animate_squash(0.6, 1.25, 0.2)
	_was_on_floor = current_on_floor

	# 无敌盾倒计时 + 闪烁效果
	if is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false
			_set_all_meshes_visible(true)
		else:
			# 半透明闪烁：每 0.15 秒切换可见性
			var flicker = fmod(_invincible_timer, 0.3) > 0.15
			_set_all_meshes_visible(flicker)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# 模拟全局阻尼，但仅作用于水平面（X/Z）
	var current_damp = GameConfig.character_horizontal_damp if is_on_floor() else GameConfig.character_air_horizontal_damp
	if current_damp > 0.0:
		var current_vel = state.linear_velocity
		var h_vel = Vector3(current_vel.x, 0, current_vel.z)
		# 阻力反向于运动方向，与其速度和阻尼系数成正比
		var damping_force = - h_vel * current_damp * mass
		apply_central_force(damping_force)

func is_on_floor() -> bool:
	if _jump_cooldown > 0.0:
		return false
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0 # 稍小于角色半径 1.2
	query.shape = shape
	# 角色原点在脚底，将球体放置在上方 0.9 处，那么它下探的最低点可以到达脚底 0.1 处，深入地面
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.9)
	query.exclude = [ self.get_rid()]
	var result = space_state.intersect_shape(query, 1)
	return result.size() > 0

func jump() -> void:
	if is_on_floor():
		apply_central_impulse(Vector3.UP * GameConfig.character_jump_impulse)
		_jump_cooldown = 0.2
		# 跳起拉伸
		var visual = get_visual()
		if visual:
			visual.animate_stretch(1.4, 0.7)

func _check_fall() -> void:
	if global_position.y < GameConfig.fall_threshold:
		_die()

func apply_knockback(impulse: Vector3) -> void:
	# 无敌期间免疫击退
	if is_invincible or is_dead:
		return
		
	# 击退累积缩放 (Damage Scaling)：HP越低，击退越强（大乱斗机制）
	var damage_percent = maxf(0.0, max_hp - current_hp) / max_hp # 0.0 ~ 1.0
	var scaling_multiplier = 1.0 + (damage_percent * 2.0) # 满血1.0x，空血3.0x
	var final_raw_impulse = impulse * scaling_multiplier
	
	# Gun Mayhem 风格：击退带向上发射，让角色飞起抛物线
	var h_impulse = Vector3(final_raw_impulse.x, 0, final_raw_impulse.z)
	var lift = h_impulse.length() * GameConfig.knockback_lift_ratio
	var final_impulse = h_impulse + Vector3.UP * lift
	apply_central_impulse(final_impulse)
	
	# 受击根据受力方向压扁
	var visual = get_visual()
	if visual:
		visual.animate_squash(0.7, 1.3)

func apply_hit(impulse: Vector3, damage: float = 0.0, attacker: Node3D = null) -> void:
	## 被敌人子弹击中时调用：施加冲量 + 扣血 + 受击闪白 + 顿帧/震屏
	if is_invincible or is_dead:
		return
	if attacker is BaseCharacter:
		last_hit_by = attacker
	apply_knockback(impulse)
	_flash_damage()
	
	# 受击音效与震屏/顿帧 (Hitstop & Screenshake)
	if damage >= 50.0:  # 狙击枪重击
		_play_sfx(_sfx_hit_heavy, -3.0)
		GameFeel.hitstop(0.08)
		GameFeel.screen_shake(0.35, 0.15)
	else:
		_play_sfx([_sfx_hit_light, _sfx_hit_light2].pick_random(), -8.0)
		GameFeel.hitstop(0.03)
		GameFeel.screen_shake(0.15, 0.08)
	if damage > 0.0:
		current_hp -= damage
		if current_hp <= 0.0:
			current_hp = 0.0
			_die()

func _is_near_edge(push_dir: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var check_pos = global_position + push_dir * 4.0 + Vector3.UP * 0.5
	var query = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 2.0)
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _die() -> void:
	if is_dead:
		return
		
	# 击杀慢动作 (Kill slowmo) + 强震屏
	GameFeel.kill_slowmo(0.3)
	GameFeel.screen_shake(0.5, 0.25)
	
	deaths += 1
	# 归属击杀
	if last_hit_by and is_instance_valid(last_hit_by):
		last_hit_by.kills += 1
	last_hit_by = null
	lives -= 1
	is_dead = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# 隐藏角色
	visible = false
	# 坠落音效
	_play_sfx(_sfx_fall, 0.0)
	# 关闭碰撞
	set_physics_process(false)
	freeze = true

	if lives <= 0:
		is_game_over = true
		eliminated.emit(self)
		return

	_respawn_timer = GameConfig.respawn_delay

func _respawn() -> void:
	is_dead = false

	# 随机复活点
	var spawn_point = GameConfig.respawn_points.pick_random()
	global_position = spawn_point
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# 显示角色
	visible = true
	freeze = false
	set_physics_process(true)

	# 回满血量
	current_hp = max_hp

	# 启动无敌盾
	is_invincible = true
	_invincible_timer = GameConfig.invincible_duration
	_play_sfx(_sfx_shield, -4.0)

# ============================================================
#  受击闪白
# ============================================================
var _original_colors: Array = []
var _flash_tween: Tween = null

func _flash_damage() -> void:
	var meshes = _get_all_meshes()
	if meshes.is_empty():
		return
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	else:
		_original_colors.clear()
		for m in meshes:
			var mat = m.get_active_material(0)
			if mat and mat is StandardMaterial3D:
				_original_colors.append({"mat": mat, "color": mat.albedo_color, "emission": mat.emission})
	# 闪白
	for entry in _original_colors:
		entry["mat"].albedo_color = Color.WHITE
		entry["mat"].emission = Color.WHITE
	_flash_tween = create_tween()
	_flash_tween.tween_callback(func():
		for entry in _original_colors:
			entry["mat"].albedo_color = entry["color"]
			entry["mat"].emission = entry["emission"]
	).set_delay(0.1)

# ============================================================
#  Mesh 辅助
# ============================================================
func _get_all_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	_collect_meshes(self, result)
	return result

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
		_collect_meshes(child, result)

func _set_all_meshes_visible(is_vis: bool) -> void:
	var visual = get_node_or_null("Visual")
	if visual:
		visual.visible = is_vis
	else:
		for child in get_children():
			if child is MeshInstance3D:
				child.visible = is_vis

## 获取 CharacterVisual 节点（如果存在）
func get_visual() -> CharacterVisual:
	return get_node_or_null("Visual") as CharacterVisual

# ============================================================
#  音效辅助
# ============================================================
func _play_sfx(stream: AudioStream, volume_db: float = -6.0) -> void:
	if not stream or not is_inside_tree():
		return
	var sfx = AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.pitch_scale = randf_range(0.92, 1.08)
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
