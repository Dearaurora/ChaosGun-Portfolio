extends RigidBody3D
class_name BaseCharacter

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")

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

var lives: int = 10
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

func _game_config() -> Node:
	return RuntimeGlobals.game_config()

func _game_feel() -> Node:
	return RuntimeGlobals.game_feel()

func _game_config_float(key: String, fallback: float) -> float:
	var config = _game_config()
	if config == null:
		return fallback
	var value = config.get(key)
	if value is float or value is int:
		return value
	return fallback

func _game_config_int(key: String, fallback: int) -> int:
	var config = _game_config()
	if config == null:
		return fallback
	var value = config.get(key)
	if value is int:
		return value
	return fallback

func _game_config_respawn_points() -> Array[Vector3]:
	var config = _game_config()
	var points: Array[Vector3] = []
	if config == null:
		return points
	var value = config.get("respawn_points")
	if value is Array:
		for point in value:
			if point is Vector3:
				points.append(point)
	return points

func _ready() -> void:
	lives = _game_config_int("default_lives", lives)
	gravity_scale = _game_config_float("character_gravity_scale", 20.0)
	if weapon_manager and not weapon_manager.weapon_fired.is_connected(_on_weapon_fired):
		weapon_manager.weapon_fired.connect(_on_weapon_fired)
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
	var current_damp = _game_config_float("character_horizontal_damp", 2.0) if is_on_floor() else _game_config_float("character_air_horizontal_damp", 0.5)
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
		apply_central_impulse(Vector3.UP * _game_config_float("character_jump_impulse", 400.0))
		_jump_cooldown = 0.2
		# 跳起拉伸
		var visual = get_visual()
		if visual:
			visual.animate_stretch(1.4, 0.7)

func _check_fall() -> void:
	if global_position.y < _game_config_float("fall_threshold", -120.0):
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
	var lift = h_impulse.length() * _game_config_float("knockback_lift_ratio", 0.35)
	var final_impulse = h_impulse + Vector3.UP * lift
	apply_central_impulse(final_impulse)
	
	# 受击根据受力方向压扁
	var visual = get_visual()
	if visual:
		visual.animate_squash(0.7, 1.3)

func apply_recoil(impulse: Vector3) -> void:
	if is_dead:
		return
	var h_impulse = Vector3(impulse.x, 0.0, impulse.z)
	if h_impulse.length_squared() <= 0.0001:
		return
	var recoil_dir = h_impulse.normalized()
	var max_recoil = _game_config_float("max_recoil_impulse", 16.0)
	if max_recoil > 0.0 and h_impulse.length() > max_recoil:
		h_impulse = recoil_dir * max_recoil
	if not is_on_floor():
		h_impulse *= _game_config_float("air_recoil_multiplier", 0.35)
	elif _is_near_edge(recoil_dir):
		h_impulse *= _game_config_float("edge_recoil_multiplier", 0.25)
	apply_central_impulse(h_impulse)

func apply_hit(impulse: Vector3, damage: float = 0.0, attacker: Node3D = null) -> void:
	## 被敌人子弹击中时调用：施加冲量 + 扣血 + 受击闪白 + 顿帧/震屏
	if is_invincible or is_dead:
		return
	if attacker is BaseCharacter:
		last_hit_by = attacker
	apply_knockback(impulse)
	var visual = get_visual()
	if visual:
		visual.animate_hit(impulse, clampf(damage / 70.0, 0.45, 1.35))
	_flash_damage()
	
	# 受击音效与震屏/顿帧 (Hitstop & Screenshake)
	if damage >= 50.0:  # 狙击枪重击
		_play_sfx(_sfx_hit_heavy, -3.0)
		var heavy_game_feel = _game_feel()
		if heavy_game_feel:
			heavy_game_feel.hitstop(0.08)
			heavy_game_feel.screen_shake(0.35, 0.15)
	else:
		_play_sfx([_sfx_hit_light, _sfx_hit_light2].pick_random(), -8.0)
		var light_game_feel = _game_feel()
		if light_game_feel:
			light_game_feel.hitstop(0.03)
			light_game_feel.screen_shake(0.15, 0.08)
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
	var death_game_feel = _game_feel()
	if death_game_feel:
		death_game_feel.kill_slowmo(0.3)
		death_game_feel.screen_shake(0.5, 0.25)
	
	deaths += 1
	# 归属击杀
	if last_hit_by and is_instance_valid(last_hit_by):
		last_hit_by.kills += 1
	last_hit_by = null
	lives -= 1
	is_dead = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_spawn_character_burst("RingoutBurst", Color("#ff6a3d"), 1.45)

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

	_respawn_timer = _game_config_float("respawn_delay", 0.0)

func _respawn() -> void:
	is_dead = false
	if weapon_manager:
		weapon_manager.reset_to_sidearm()

	# 随机复活点
	var respawn_points = _game_config_respawn_points()
	var spawn_point = respawn_points.pick_random() if not respawn_points.is_empty() else global_position
	global_position = spawn_point
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# 显示角色
	visible = true
	freeze = false
	set_physics_process(true)
	var visual = get_visual()
	if visual:
		visual.animate_respawn()
	_spawn_character_burst("RespawnBurst", Color("#6ee7ff"), 1.15)

	# 回满血量
	current_hp = max_hp

	# 启动无敌盾
	is_invincible = true
	_invincible_timer = _game_config_float("invincible_duration", 3.0)
	_play_sfx(_sfx_shield, -4.0)

func _spawn_character_burst(effect_name: String, color: Color, radius: float) -> void:
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return

	var effect_pos = global_position
	if effect_pos.y < _game_config_float("fall_threshold", -120.0) + 2.0:
		effect_pos.y = 1.25

	var burst = Node3D.new()
	burst.name = effect_name
	scene_root.add_child(burst)
	burst.global_position = effect_pos

	var disc = MeshInstance3D.new()
	disc.name = "BurstDisc"
	var disc_mesh = CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.08
	disc_mesh.radial_segments = 30
	disc_mesh.material = _effect_material(Color(color.r, color.g, color.b, 0.42), color, 2.6)
	disc.mesh = disc_mesh
	burst.add_child(disc)

	for i in range(8):
		var angle = TAU * float(i) / 8.0
		var spark = MeshInstance3D.new()
		spark.name = "BurstSpark"
		var spark_mesh = SphereMesh.new()
		spark_mesh.radius = 0.18
		spark_mesh.height = 0.18
		spark_mesh.material = _effect_material(color.lerp(Color.WHITE, 0.35), color, 2.0)
		spark.mesh = spark_mesh
		spark.position = Vector3(cos(angle) * radius * 0.55, 0.35, sin(angle) * radius * 0.55)
		burst.add_child(spark)

	var tween = burst.create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 1.75, 0.22).set_ease(Tween.EASE_OUT)
	tween.tween_callback(burst.queue_free)

func _effect_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.5
	if albedo.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat

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

func _on_weapon_fired(weapon_data: WeaponData) -> void:
	var visual = get_visual()
	if visual and weapon_data:
		visual.animate_fire(weapon_data.weapon_id)

# ============================================================
#  音效辅助
# ============================================================
func _play_sfx(stream: AudioStream, volume_db: float = -6.0) -> void:
	if not stream or not is_inside_tree():
		return
	if RuntimeGlobals.runtime_audio_disabled():
		return
	var sfx = AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.pitch_scale = randf_range(0.92, 1.08)
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	scene_root.add_child(sfx)
	sfx.global_position = global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
