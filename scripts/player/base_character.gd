extends RigidBody3D
class_name BaseCharacter

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const CharacterCombatFeedbackScript = preload("res://scripts/effects/character_combat_feedback.gd")
const CharacterTransitionBurstScene: PackedScene = preload("res://scenes/effects/character_transition_burst.tscn")
const POWERUP_CONTROLLER_PATH := "res://scripts/powerups/powerup_controller.gd"

@onready var weapon_point: Marker3D = get_node_or_null("WeaponPoint")
@onready var weapon_manager: WeaponManager = get_node_or_null("WeaponManager")

signal eliminated(character: BaseCharacter)

# 音效
var _sfx_hit_light: AudioStream = preload("res://assets/audio/generated/combat/impact_light_v2.ogg")
var _sfx_hit_light2: AudioStream = preload("res://assets/audio/sfx/hit_light2.ogg")
var _sfx_hit_heavy: AudioStream = preload("res://assets/audio/generated/combat/impact_heavy_v2.ogg")
var _sfx_fall: AudioStream = preload("res://assets/audio/generated/combat/ringout_v2.ogg")
var _sfx_shield: AudioStream = preload("res://assets/audio/sfx/shield_up.ogg")
var _last_hit_feedback_msec: int = -1000
var _last_hit_feedback_weight: int = 0
var _hit_feedback_serial: int = 0

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
var _combat_feedback: CharacterCombatFeedback = null
var _last_safe_visual_position := Vector3.ZERO
var _knockback_feedback_timer := 0.0
var movement_speed_multiplier := 1.0
var outgoing_knockback_multiplier := 1.0
var combat_owner: BaseCharacter = null
var _powerup_controller: Node = null

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
	if weapon_manager and not weapon_manager.weapon_switched.is_connected(_on_weapon_muzzle_switched):
		weapon_manager.weapon_switched.connect(_on_weapon_muzzle_switched)
	_sync_weapon_muzzle(&"pistol")
	_last_safe_visual_position = global_position
	_ensure_combat_feedback()
	_ensure_powerup_controller()
	# 禁用接触摩擦，水平减速完全由 horizontal_damp 控制，
	# 避免高重力下法向力过大导致角色走不动。
	var mat = PhysicsMaterial.new()
	mat.friction = 0.0
	physics_material_override = mat

func _base_process(delta: float) -> void:
	# A game-over death exits before assigning a respawn timer. Keep eliminated
	# characters out of the normal respawn branch on subsequent process frames.
	if is_game_over:
		return
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
	_knockback_feedback_timer = maxf(0.0, _knockback_feedback_timer - delta)
	_update_ringout_motion_feedback(current_on_floor)

	if global_position.y > -2.0:
		_last_safe_visual_position = global_position

	if is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false
			_set_all_meshes_visible(true)
			if _combat_feedback:
				_combat_feedback.set_shield_active(false)

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

func get_movement_speed() -> float:
	return _game_config_float("character_speed", 550.0) * movement_speed_multiplier

func get_outgoing_knockback_multiplier() -> float:
	return outgoing_knockback_multiplier

func apply_powerup(powerup_id: StringName) -> bool:
	_ensure_powerup_controller()
	if _powerup_controller == null:
		return false
	return bool(_powerup_controller.call("apply_powerup", powerup_id))

func get_powerup_state_debug() -> Dictionary:
	_ensure_powerup_controller()
	if _powerup_controller == null:
		return {}
	return _powerup_controller.call("get_state_debug") as Dictionary

func get_combat_identity() -> BaseCharacter:
	if combat_owner and is_instance_valid(combat_owner):
		return combat_owner
	return self

func is_friendly_to(other: BaseCharacter) -> bool:
	if other == null or not is_instance_valid(other):
		return false
	return get_combat_identity() == other.get_combat_identity()

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
	_knockback_feedback_timer = 0.52
	
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

func apply_hit(
	impulse: Vector3,
	damage: float = 0.0,
	attacker: Node3D = null,
	weapon_id: StringName = &""
) -> void:
	## 被敌人子弹击中时调用：施加冲量 + 扣血 + 受击闪白 + 顿帧/震屏
	if is_invincible or is_dead:
		return
	if attacker is BaseCharacter:
		last_hit_by = (attacker as BaseCharacter).get_combat_identity()
	apply_knockback(impulse)
	var visual = get_visual()
	if visual:
		visual.animate_hit(impulse, clampf(damage / 70.0, 0.45, 1.35))
	if _combat_feedback:
		_combat_feedback.play_hit(impulse, clampf(damage / 70.0, 0.45, 1.35))
	
	_play_hit_feedback(weapon_id, damage, impulse)
	if damage > 0.0:
		current_hp -= damage
		if current_hp <= 0.0:
			current_hp = 0.0
			_die()

func _play_hit_feedback(weapon_id: StringName, damage: float, impulse: Vector3) -> void:
	var profile := get_hit_feedback_profile_debug(weapon_id, damage)
	var feedback_weight := 2 if bool(profile["heavy"]) else 1
	var now_msec := Time.get_ticks_msec()
	if now_msec - _last_hit_feedback_msec < 48 and feedback_weight <= _last_hit_feedback_weight:
		return
	_last_hit_feedback_msec = now_msec
	_last_hit_feedback_weight = feedback_weight
	_hit_feedback_serial += 1
	var stream := _sfx_hit_heavy if bool(profile["heavy"]) else _sfx_hit_light
	if not bool(profile["heavy"]) and weapon_id in [&"pistol", &"ak_rifle"] and randf() > 0.58:
		stream = _sfx_hit_light2
	_play_sfx(
		stream,
		float(profile["volume_db"]),
		float(profile["pitch_min"]),
		float(profile["pitch_max"])
	)
	var game_feel := _game_feel()
	if game_feel == null:
		return
	var hitstop_duration := float(profile["hitstop"])
	if hitstop_duration > 0.0:
		game_feel.hitstop(hitstop_duration)
	game_feel.screen_shake(float(profile["shake"]), float(profile["shake_duration"]))
	if game_feel.has_method("camera_kick"):
		game_feel.camera_kick(
			impulse,
			float(profile["kick"]),
			float(profile["kick_duration"])
		)

func get_hit_feedback_profile_debug(weapon_id: StringName, damage: float = 0.0) -> Dictionary:
	match weapon_id:
		&"smg":
			return {"heavy": false, "volume_db": -10.0, "pitch_min": 0.96, "pitch_max": 1.06, "hitstop": 0.006, "shake": 0.025, "shake_duration": 0.040, "kick": 0.012, "kick_duration": 0.060}
		&"ak_rifle":
			return {"heavy": false, "volume_db": -5.5, "pitch_min": 0.96, "pitch_max": 1.03, "hitstop": 0.028, "shake": 0.120, "shake_duration": 0.075, "kick": 0.050, "kick_duration": 0.100}
		&"sniper":
			return {"heavy": true, "volume_db": -1.0, "pitch_min": 0.98, "pitch_max": 1.02, "hitstop": 0.075, "shake": 0.320, "shake_duration": 0.150, "kick": 0.180, "kick_duration": 0.180}
		&"gatling":
			return {"heavy": false, "volume_db": -13.0, "pitch_min": 0.97, "pitch_max": 1.07, "hitstop": 0.0, "shake": 0.012, "shake_duration": 0.028, "kick": 0.006, "kick_duration": 0.045}
		&"shotgun":
			return {"heavy": true, "volume_db": -2.5, "pitch_min": 0.97, "pitch_max": 1.02, "hitstop": 0.050, "shake": 0.230, "shake_duration": 0.120, "kick": 0.130, "kick_duration": 0.150}
		&"pistol":
			return {"heavy": false, "volume_db": -7.5, "pitch_min": 0.96, "pitch_max": 1.04, "hitstop": 0.018, "shake": 0.080, "shake_duration": 0.060, "kick": 0.025, "kick_duration": 0.080}
	if damage >= 50.0:
		return {"heavy": true, "volume_db": -2.0, "pitch_min": 0.97, "pitch_max": 1.03, "hitstop": 0.070, "shake": 0.300, "shake_duration": 0.140, "kick": 0.160, "kick_duration": 0.170}
	return {"heavy": false, "volume_db": -8.0, "pitch_min": 0.94, "pitch_max": 1.06, "hitstop": 0.018, "shake": 0.080, "shake_duration": 0.060, "kick": 0.025, "kick_duration": 0.080}

func get_hit_feedback_debug() -> Dictionary:
	return {
		"serial": _hit_feedback_serial,
		"last_feedback_msec": _last_hit_feedback_msec,
		"last_feedback_weight": _last_hit_feedback_weight,
	}

func _is_near_edge(push_dir: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var check_pos = global_position + push_dir * 4.0 + Vector3.UP * 0.5
	var query = PhysicsRayQueryParameters3D.create(check_pos, check_pos + Vector3.DOWN * 2.0)
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _die() -> void:
	if is_dead:
		return
	if _powerup_controller:
		_powerup_controller.call("clear_timed_powerups")
		
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
	if _combat_feedback:
		_combat_feedback.set_shield_active(false)
		_combat_feedback.update_motion_feedback(Vector3.ZERO, false, false)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_spawn_character_transition(&"ringout", Color("#ff4d62"), 1.45)

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
	_spawn_character_transition(&"respawn", Color("#6ee7ff"), 1.15)

	# 回满血量
	current_hp = max_hp

	# 启动无敌盾
	is_invincible = true
	_invincible_timer = _game_config_float("invincible_duration", 3.0)
	if _combat_feedback:
		_combat_feedback.set_shield_active(true)
		_combat_feedback.update_motion_feedback(Vector3.ZERO, false, false)
	_play_sfx(_sfx_shield, -4.0)

func _spawn_character_transition(mode: StringName, color: Color, radius: float) -> void:
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return

	var effect_pos := global_position
	if mode == &"ringout" and effect_pos.y < -2.0:
		effect_pos = _last_safe_visual_position
	var burst := CharacterTransitionBurstScene.instantiate() as Node3D
	if burst == null:
		return
	match mode:
		&"respawn":
			burst.name = "RespawnBurst"
		&"match_spawn":
			burst.name = "MatchSpawnBurst"
		&"winner":
			burst.name = "WinnerBurst"
		_:
			burst.name = "RingoutBurst"
	burst.call("configure", mode, color, radius)
	scene_root.add_child(burst, true)
	burst.global_position = effect_pos

func play_match_spawn_presentation(color: Color) -> void:
	visible = true
	var visual := get_visual()
	if visual:
		if visual.has_method("animate_match_spawn"):
			visual.call("animate_match_spawn")
		else:
			visual.animate_respawn()
	_spawn_character_transition(&"match_spawn", color, 1.34)

func play_match_winner_presentation(color: Color) -> void:
	var visual := get_visual()
	if visual and visual.has_method("animate_match_winner"):
		visual.call("animate_match_winner")
	_spawn_character_transition(&"winner", color, 1.72)


func _ensure_combat_feedback() -> void:
	_combat_feedback = get_node_or_null("CombatFeedback") as CharacterCombatFeedback
	if _combat_feedback:
		return
	_combat_feedback = CharacterCombatFeedbackScript.new() as CharacterCombatFeedback
	_combat_feedback.name = "CombatFeedback"
	add_child(_combat_feedback)

func _ensure_powerup_controller() -> void:
	if _powerup_controller and is_instance_valid(_powerup_controller):
		return
	var controller_script := load(POWERUP_CONTROLLER_PATH) as Script
	if controller_script == null:
		return
	_powerup_controller = controller_script.new() as Node
	_powerup_controller.name = "PowerupController"
	add_child(_powerup_controller)
	_powerup_controller.call("setup", self)

func _update_ringout_motion_feedback(on_floor: bool) -> void:
	if _combat_feedback == null:
		return
	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var launched := _knockback_feedback_timer > 0.0 and not on_floor
	var danger := not on_floor and global_position.y < 0.2 and linear_velocity.y < 0.0
	if on_floor and horizontal_velocity.length() > 6.0:
		danger = _is_near_edge(horizontal_velocity.normalized())
	_combat_feedback.update_motion_feedback(linear_velocity, launched, danger)

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

func _on_weapon_muzzle_switched(weapon_data: WeaponData) -> void:
	if weapon_data:
		_sync_weapon_muzzle(weapon_data.weapon_id)

func _sync_weapon_muzzle(weapon_id: StringName) -> void:
	var visual = get_visual()
	if visual and weapon_point and visual.has_method("get_weapon_muzzle_local_position"):
		weapon_point.position = visual.get_weapon_muzzle_local_position(weapon_id)

# ============================================================
#  音效辅助
# ============================================================
func _play_sfx(
	stream: AudioStream,
	volume_db: float = -6.0,
	pitch_min: float = 0.92,
	pitch_max: float = 1.08
) -> void:
	if not stream or not is_inside_tree():
		return
	if RuntimeGlobals.runtime_audio_disabled():
		return
	var sfx = AudioStreamPlayer3D.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	sfx.pitch_scale = randf_range(pitch_min, pitch_max)
	sfx.unit_size = 18.0
	sfx.max_distance = 180.0
	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return
	scene_root.add_child(sfx)
	sfx.global_position = global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
