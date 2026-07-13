extends Node
class_name Weapon
## 单把武器的运行时状态与射击逻辑

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const MuzzleFlashScene: PackedScene = preload("res://scenes/effects/muzzle_flash.tscn")
const ShotTracerScript = preload("res://scripts/effects/shot_tracer.gd")

var weapon_data: WeaponData
var current_ammo: int = -1
var current_spread: float = 0.0
var fire_cooldown: float = 0.0
var _time_since_last_shot: float = 999.0

signal fired()
signal ammo_depleted()

func init_weapon(data: WeaponData) -> void:
	weapon_data = data.duplicate(true)
	_apply_profile_overrides()
	current_ammo = -1 if weapon_data.has_infinite_ammo else weapon_data.magazine_size
	current_spread = weapon_data.base_spread
	fire_cooldown = 0.0

func _apply_profile_overrides() -> void:
	var game_config = RuntimeGlobals.game_config()
	if game_config == null or weapon_data == null:
		return
	var overrides = game_config.get("weapon_feel_overrides")
	if not (overrides is Dictionary):
		return
	var weapon_overrides = overrides.get(String(weapon_data.weapon_id), {})
	if not (weapon_overrides is Dictionary):
		return
	for key in weapon_overrides.keys():
		var property_name = String(key)
		if property_name in weapon_data:
			weapon_data.set(property_name, weapon_overrides[key])

func _process(delta: float) -> void:
	if fire_cooldown > 0:
		fire_cooldown = max(0.0, fire_cooldown - delta)
	_time_since_last_shot += delta
	_update_spread(delta)

# ------------------------------------------------------------------
#  射击
# ------------------------------------------------------------------
func try_fire(fire_point: Marker3D, direction: Vector3, shooter: Node3D) -> bool:
	if not weapon_data or fire_cooldown > 0 or current_ammo == 0:
		return false

	var scene_root = RuntimeGlobals.active_scene(fire_point.get_tree())
	if scene_root == null:
		return false

	var game_config = RuntimeGlobals.game_config()
	var bullet_speed_multiplier = game_config.get("bullet_speed_multiplier") if game_config and game_config.get("bullet_speed_multiplier") is float else 10.0
	var knockback_multiplier = game_config.get("knockback_multiplier") if game_config and game_config.get("knockback_multiplier") is float else 1.8

	var projectile_color := _projectile_color_for_weapon(weapon_data.weapon_id)
	var shot_direction := _apply_spread(direction).normalized()
	var projectile_count := maxi(1, weapon_data.projectiles_per_shot)
	for projectile_index in range(projectile_count):
		var projectile_direction := _pellet_direction(shot_direction, projectile_index, projectile_count)
		_spawn_projectile(
			scene_root,
			fire_point.global_position,
			projectile_direction,
			shooter,
			projectile_color,
			bullet_speed_multiplier,
			knockback_multiplier
		)

	# 枪口焰
	var flash = MuzzleFlashScene.instantiate() as Node3D
	if flash and flash.has_method("configure"):
		flash.call("configure", shot_direction, projectile_color, weapon_data.weapon_id)
	scene_root.add_child(flash)
	flash.global_position = fire_point.global_position

	# 射击音效
	if weapon_data.shoot_sound and not RuntimeGlobals.runtime_audio_disabled():
		var sfx = AudioStreamPlayer3D.new()
		sfx.stream = weapon_data.shoot_sound
		sfx.volume_db = -6.0
		sfx.max_db = 3.0
		sfx.pitch_scale = randf_range(0.95, 1.05)
		scene_root.add_child(sfx)
		sfx.global_position = fire_point.global_position
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

	# 射速冷却
	fire_cooldown = 1.0 / weapon_data.fire_rate

	# 消耗弹药
	if not weapon_data.has_infinite_ammo:
		current_ammo -= 1

	# 后坐力累积（散布）
	current_spread = min(current_spread + weapon_data.spread_increase_per_shot,
						 weapon_data.max_spread)
	_time_since_last_shot = 0.0

	# 后坐力反推（推射手后退）
	if weapon_data.recoil_force > 0.0 and shooter.has_method("apply_recoil"):
		var recoil_dir = -shot_direction  # 与弹道方向相反
		recoil_dir.y = 0
		shooter.apply_recoil(recoil_dir * weapon_data.recoil_force)

	# 射击屏幕震动（武器越重越强）
	var shake_strength = weapon_data.recoil_force * 0.008
	var game_feel = RuntimeGlobals.game_feel()
	if game_feel:
		game_feel.screen_shake(clampf(shake_strength, 0.1, 0.6), 0.08)

	fired.emit()

	if current_ammo == 0:
		ammo_depleted.emit()

	return true

func _spawn_projectile(
	scene_root: Node,
	spawn_position: Vector3,
	projectile_direction: Vector3,
	shooter: Node3D,
	projectile_color: Color,
	bullet_speed_multiplier: float,
	knockback_multiplier: float
) -> void:
	var proj = weapon_data.projectile_scene.instantiate() as Projectile
	if proj == null:
		return
	proj.direction = projectile_direction
	proj.speed = weapon_data.bullet_speed * bullet_speed_multiplier
	proj.knockback_power = weapon_data.knockback_power * knockback_multiplier
	proj.damage = weapon_data.damage
	proj.lifetime = weapon_data.bullet_lifetime
	proj.shooter = shooter
	proj.configure_visual_profile(weapon_data.weapon_id, projectile_color)
	proj.configure_knockback_falloff(
		spawn_position,
		weapon_data.close_range_knockback_multiplier,
		weapon_data.knockback_falloff_start,
		weapon_data.knockback_falloff_end,
		weapon_data.far_range_knockback_multiplier
	)
	scene_root.add_child(proj)
	proj.global_position = spawn_position
	proj.look_at(proj.global_position + projectile_direction)
	proj.set_projectile_color(projectile_color)
	_spawn_shot_tracer(scene_root, spawn_position, projectile_direction, projectile_color, weapon_data.weapon_id)

func _pellet_direction(base_direction: Vector3, index: int, count: int) -> Vector3:
	if count <= 1 or weapon_data.pellet_spread_degrees <= 0.01:
		return base_direction
	var spread_ratio := float(index) / float(count - 1)
	var angle_degrees := lerpf(
		-weapon_data.pellet_spread_degrees * 0.5,
		weapon_data.pellet_spread_degrees * 0.5,
		spread_ratio
	)
	return base_direction.rotated(Vector3.UP, deg_to_rad(angle_degrees)).normalized()

# ------------------------------------------------------------------
#  散布 & 后坐力
# ------------------------------------------------------------------
func _apply_spread(direction: Vector3) -> Vector3:
	if current_spread <= 0.01:
		return direction
	var spread_rad = deg_to_rad(current_spread)
	var rand_angle = randf_range(-spread_rad, spread_rad)
	return direction.rotated(Vector3.UP, rand_angle)

func _update_spread(delta: float) -> void:
	if not weapon_data:
		return
	if _time_since_last_shot > 0.2 and current_spread > weapon_data.base_spread:
		current_spread = move_toward(current_spread, weapon_data.base_spread,
									 weapon_data.spread_recovery_speed * delta)

func _projectile_color_for_weapon(weapon_id: StringName) -> Color:
	match weapon_id:
		&"smg":
			return Color("#55d93c")
		&"ak_rifle":
			return Color("#e96525")
		&"sniper":
			return Color("#35c8e8")
		&"gatling":
			return Color("#ffd34d")
		&"shotgun":
			return Color("#d884ff")
		_:
			return Color("#f04455")

func _spawn_shot_tracer(scene_root: Node, start_position: Vector3, direction: Vector3, color: Color, weapon_id: StringName) -> void:
	if scene_root == null:
		return
	var tracer := ShotTracerScript.new() as Node3D
	tracer.name = "ShotTracer"
	scene_root.add_child(tracer)
	tracer.call("setup", start_position, direction, color, _shot_tracer_profile_for_weapon(weapon_id))

func _shot_tracer_profile_for_weapon(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {
				"length": 1.20,
				"width": 0.10,
				"lifetime": 0.040,
			}
		&"ak_rifle":
			return {
				"length": 2.00,
				"width": 0.17,
				"lifetime": 0.055,
			}
		&"sniper":
			return {
				"length": 2.80,
				"width": 0.14,
				"lifetime": 0.070,
			}
		&"gatling":
			return {
				"length": 1.10,
				"width": 0.09,
				"lifetime": 0.036,
			}
		&"shotgun":
			return {
				"length": 1.45,
				"width": 0.11,
				"lifetime": 0.050,
			}
		_:
			return {
				"length": 1.55,
				"width": 0.15,
				"lifetime": 0.052,
			}
