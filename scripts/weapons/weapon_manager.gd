extends Node
class_name WeaponManager
## 管理角色的武器槽位、切换、装备与丢弃

var sidearm: Weapon          # 副武器（手枪），永久持有
var primary: Weapon          # 主武器（拾取），可为 null
var current_weapon: Weapon
var is_switching: bool = false
var _switch_timer: float = 0.0

signal weapon_switched(weapon_data: WeaponData)
signal weapon_dropped(drop_position: Vector3)
signal weapon_fired(weapon_data: WeaponData)


func _ready() -> void:
	# 初始化手枪
	sidearm = Weapon.new()
	sidearm.name = "Sidearm"
	sidearm.init_weapon(WeaponData.create_pistol())
	add_child(sidearm)
	current_weapon = sidearm

func _process(delta: float) -> void:
	if is_switching:
		_switch_timer -= delta
		if _switch_timer <= 0:
			is_switching = false

# ------------------------------------------------------------------
#  射击（代理给当前武器）
# ------------------------------------------------------------------
func try_fire(fire_point: Marker3D, direction: Vector3, shooter: Node3D) -> bool:
	if is_switching or not current_weapon:
		return false
	var did_fire = current_weapon.try_fire(fire_point, direction, shooter)
	if did_fire and current_weapon.weapon_data:
		weapon_fired.emit(current_weapon.weapon_data)
	return did_fire

# ------------------------------------------------------------------
#  武器状态
# ------------------------------------------------------------------
func discard_current_weapon() -> bool:
	if primary == null or current_weapon == sidearm:
		return false
	is_switching = false
	_switch_timer = 0.0
	_drop_primary()
	_perform_switch(sidearm)
	return true

func _perform_switch(target: Weapon) -> void:
	is_switching = true
	_switch_timer = target.weapon_data.switch_time
	current_weapon = target
	weapon_switched.emit(target.weapon_data)

# ------------------------------------------------------------------
#  装备 & 丢弃
# ------------------------------------------------------------------
func equip_weapon(data: WeaponData) -> void:
	# 丢弃当前主武器
	if primary:
		_drop_primary()
	# 创建新主武器
	primary = Weapon.new()
	primary.name = "Primary"
	primary.init_weapon(data)
	add_child(primary)
	primary.ammo_depleted.connect(_on_primary_ammo_depleted)
	# 自动切换到新武器
	_perform_switch(primary)

func _drop_primary() -> void:
	if not primary:
		return
	if primary.ammo_depleted.is_connected(_on_primary_ammo_depleted):
		primary.ammo_depleted.disconnect(_on_primary_ammo_depleted)
	weapon_dropped.emit(get_parent().global_position)
	primary.queue_free()
	primary = null

func reset_to_sidearm() -> void:
	is_switching = false
	_switch_timer = 0.0
	if primary:
		if primary.ammo_depleted.is_connected(_on_primary_ammo_depleted):
			primary.ammo_depleted.disconnect(_on_primary_ammo_depleted)
		primary.queue_free()
		primary = null
	if sidearm == null:
		sidearm = Weapon.new()
		sidearm.name = "Sidearm"
		add_child(sidearm)
	sidearm.init_weapon(WeaponData.create_pistol())
	current_weapon = sidearm
	weapon_switched.emit(sidearm.weapon_data)

func _on_primary_ammo_depleted() -> void:
	# 弹药耗尽 → 丢弃主武器 → 切回手枪
	if current_weapon == primary:
		_drop_primary()
		_perform_switch(sidearm)

# ------------------------------------------------------------------
#  查询
# ------------------------------------------------------------------
func get_current_fire_mode() -> WeaponData.FireMode:
	if current_weapon and current_weapon.weapon_data:
		return current_weapon.weapon_data.fire_mode
	return WeaponData.FireMode.SEMI_AUTO

func get_current_ammo() -> int:
	return current_weapon.current_ammo if current_weapon else -1

func get_current_weapon_name() -> String:
	if current_weapon and current_weapon.weapon_data:
		return current_weapon.weapon_data.weapon_name
	return ""

func has_primary() -> bool:
	return primary != null
