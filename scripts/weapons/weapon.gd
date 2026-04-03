extends Node
class_name Weapon
## 单把武器的运行时状态与射击逻辑

const MuzzleFlashScene: PackedScene = preload("res://scenes/effects/muzzle_flash.tscn")

var weapon_data: WeaponData
var current_ammo: int = -1
var current_spread: float = 0.0
var fire_cooldown: float = 0.0
var _time_since_last_shot: float = 999.0

signal fired()
signal ammo_depleted()

func init_weapon(data: WeaponData) -> void:
	weapon_data = data
	current_ammo = -1 if data.has_infinite_ammo else data.magazine_size
	current_spread = data.base_spread
	fire_cooldown = 0.0

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

	var final_dir = _apply_spread(direction)

	var proj = weapon_data.projectile_scene.instantiate() as Projectile
	fire_point.get_tree().current_scene.add_child(proj)
	proj.global_position = fire_point.global_position
	proj.look_at(proj.global_position + final_dir)
	proj.direction = final_dir
	proj.speed = weapon_data.bullet_speed * GameConfig.bullet_speed_multiplier
	proj.knockback_power = weapon_data.knockback_power * GameConfig.knockback_multiplier
	proj.lifetime = weapon_data.bullet_lifetime
	proj.shooter = shooter

	# 枪口焰
	var flash = MuzzleFlashScene.instantiate()
	fire_point.get_tree().current_scene.add_child(flash)
	flash.global_position = fire_point.global_position
	flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	fire_point.get_tree().create_timer(0.06).timeout.connect(flash.queue_free)

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
	if weapon_data.recoil_force > 0.0 and shooter.has_method("apply_knockback"):
		var recoil_dir = -final_dir  # 与弹道方向相反
		recoil_dir.y = 0
		shooter.apply_knockback(recoil_dir * weapon_data.recoil_force)

	fired.emit()

	if current_ammo == 0:
		ammo_depleted.emit()

	return true

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
