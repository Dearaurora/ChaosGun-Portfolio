extends Resource
class_name WeaponData

enum FireMode {SEMI_AUTO, FULL_AUTO, BOLT_ACTION}

@export var weapon_name: String = ""
@export var weapon_id: StringName = &""
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
@export var fire_rate: float = 4.0 ## 发/秒
@export var bullet_speed: float = 60.0
@export var knockback_power: float = 18.0
@export var base_spread: float = 0.0 ## 基础散布角度（度）
@export var max_spread: float = 0.0
@export var spread_increase_per_shot: float = 0.0
@export var spread_recovery_speed: float = 15.0
@export var magazine_size: int = -1 ## -1 = 无限
@export var switch_time: float = 0.3
@export var bullet_radius: float = 0.4
@export var bullet_lifetime: float = 2.0
@export var stun_duration: float = 0.0 ## 射击硬直（秒）
@export var recoil_force: float = 0.0 ## 后坐力（射击时推自己后退）
@export var projectile_scene: PackedScene
@export var has_infinite_ammo: bool = true

# ============================================================
#  工厂方法 —— 每把武器的完整参数定义
# ============================================================

static func create_pistol() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Pistol"
	d.weapon_id = &"pistol"
	d.fire_mode = FireMode.SEMI_AUTO
	d.fire_rate = 4.0
	d.bullet_speed = 60.0
	d.knockback_power = 90.0
	d.base_spread = 0.0
	d.max_spread = 0.0
	d.spread_increase_per_shot = 0.0
	d.spread_recovery_speed = 15.0
	d.magazine_size = -1
	d.switch_time = 0.3
	d.bullet_radius = 0.4
	d.bullet_lifetime = 2.0
	d.stun_duration = 0.0
	d.recoil_force = 16.0
	d.projectile_scene = load("res://scenes/weapons/pistol_projectile.tscn")
	d.has_infinite_ammo = true
	return d

static func create_smg() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "SMG"
	d.weapon_id = &"smg"
	d.fire_mode = FireMode.FULL_AUTO
	d.fire_rate = 12.0
	d.bullet_speed = 55.0
	d.knockback_power = 36.0
	d.base_spread = 8.0
	d.max_spread = 12.0
	d.spread_increase_per_shot = 0.4
	d.spread_recovery_speed = 30.0
	d.magazine_size = 40
	d.switch_time = 0.3
	d.bullet_radius = 0.3
	d.bullet_lifetime = 1.5
	d.stun_duration = 0.0
	d.recoil_force = 4.0
	d.projectile_scene = load("res://scenes/weapons/smg_projectile.tscn")
	d.has_infinite_ammo = false
	return d

static func create_ak_rifle() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "AK Rifle"
	d.weapon_id = &"ak_rifle"
	d.fire_mode = FireMode.FULL_AUTO
	d.fire_rate = 6.0
	d.bullet_speed = 70.0
	d.knockback_power = 60.0
	d.base_spread = 2.0
	d.max_spread = 8.0
	d.spread_increase_per_shot = 1.0
	d.spread_recovery_speed = 15.0
	d.magazine_size = 25
	d.switch_time = 0.3
	d.bullet_radius = 0.5
	d.bullet_lifetime = 2.5
	d.stun_duration = 0.0
	d.recoil_force = 10.0
	d.projectile_scene = load("res://scenes/weapons/ak_projectile.tscn")
	d.has_infinite_ammo = false
	return d

static func create_sniper() -> WeaponData:
	var d = WeaponData.new()
	d.weapon_name = "Sniper"
	d.weapon_id = &"sniper"
	d.fire_mode = FireMode.BOLT_ACTION
	d.fire_rate = 0.8
	d.bullet_speed = 120.0
	d.knockback_power = 240.0
	d.base_spread = 0.0
	d.max_spread = 0.0
	d.spread_increase_per_shot = 0.0
	d.spread_recovery_speed = 15.0
	d.magazine_size = 5
	d.switch_time = 0.3
	d.bullet_radius = 0.3
	d.bullet_lifetime = 3.0
	d.stun_duration = 0.3
	d.recoil_force = 30.0
	d.projectile_scene = load("res://scenes/weapons/sniper_projectile.tscn")
	d.has_infinite_ammo = false
	return d

## 返回所有可在地图上刷新的武器（不含手枪）
static func get_spawnable_weapons() -> Array[Callable]:
	return [create_smg, create_ak_rifle, create_sniper]
