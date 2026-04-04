extends Node

# 该类通过 project.godot 设置为 AutoLoad 单例（加载 .tscn 场景），
# 可以通过 GameConfig 访问。所有参数使用 @export 暴露到 Inspector 面板，
# 在编辑器中选中 game_config.tscn 的根节点即可直接调整数值。

# 地图参数
@export_group("地图")
@export var map_half_size: float = 50.0
@export var fall_threshold: float = -120.0

# 生命与复活系统
@export_group("生命与复活")
@export var default_lives: int = 10
@export var respawn_delay: float = 0.0
@export var invincible_duration: float = 3.0
@export var respawn_points: Array[Vector3] = [
	Vector3(25, 0.5, 25),
	Vector3(-25, 0.5, 25),
	Vector3(25, 0.5, -25),
	Vector3(-25, 0.5, -25),
]

# 武器刷新控制
@export_group("武器刷新")
@export var weapon_initial_delay: float = 20.0
@export var weapon_stay_duration: float = 30.0
@export var weapon_respawn_cooldown: float = 10.0
@export var weapon_spawn_margin: float = 10.0

# 角色物理参数
@export_group("角色物理")
@export var character_speed: float = 550.0
@export var character_horizontal_damp: float = 2.0
@export var character_air_horizontal_damp: float = 0.5
@export var character_gravity_scale: float = 8
@export var character_jump_impulse: float = 20.0
@export var character_air_control_multiplier: float = 0.2

# 战斗数值倍数
@export_group("战斗调整")
@export var bullet_speed_multiplier: float = 5.0
@export var knockback_multiplier: float = 1.8
@export var knockback_lift_ratio: float = 0.35  ## 击退力中转为向上冲量的比例（0~1）
