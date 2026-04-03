extends Node
class_name WeaponSpawner
## 全局武器刷新循环：开局 20s → 刷新 → 保留 30s → 冷却 10s → 循环

@export var initial_delay: float = GameConfig.weapon_initial_delay
@export var stay_duration: float = GameConfig.weapon_stay_duration
@export var respawn_cooldown: float = GameConfig.weapon_respawn_cooldown
@export var spawn_margin: float = GameConfig.weapon_spawn_margin
@export var map_half_size: float = GameConfig.map_half_size

var _current_pickup: Node3D = null
var _pickup_scene: PackedScene
var _expire_timer_id: int = 0  # 用于追踪超时定时器，避免竞态

func _ready() -> void:
	_pickup_scene = load("res://scenes/weapons/weapon_pickup.tscn")
	get_tree().create_timer(initial_delay).timeout.connect(_spawn_weapon)

func _spawn_weapon() -> void:
	# 清理残留
	if _current_pickup and is_instance_valid(_current_pickup):
		_current_pickup.queue_free()
		_current_pickup = null

	# 随机位置（避开边缘）
	var half = map_half_size - spawn_margin
	var pos = Vector3(randf_range(-half, half), 1.5, randf_range(-half, half))

	# 随机武器
	var factories = WeaponData.get_spawnable_weapons()
	var factory = factories.pick_random() as Callable
	var weapon_data = factory.call() as WeaponData

	# 实例化拾取物
	_current_pickup = _pickup_scene.instantiate()
	get_tree().current_scene.add_child(_current_pickup)
	_current_pickup.global_position = pos
	_current_pickup.setup(weapon_data)
	_current_pickup.picked_up.connect(_on_picked_up)

	# 超时定时器
	_expire_timer_id += 1
	var this_id = _expire_timer_id
	get_tree().create_timer(stay_duration).timeout.connect(
		func(): _on_expired(this_id)
	)

func _on_picked_up() -> void:
	_current_pickup = null
	_expire_timer_id += 1  # 使旧的超时回调失效
	get_tree().create_timer(respawn_cooldown).timeout.connect(_spawn_weapon)

func _on_expired(timer_id: int) -> void:
	# 只有最新的超时定时器才生效
	if timer_id != _expire_timer_id:
		return
	if _current_pickup and is_instance_valid(_current_pickup):
		_current_pickup.queue_free()
		_current_pickup = null
	get_tree().create_timer(respawn_cooldown).timeout.connect(_spawn_weapon)
