extends Node

# 该类通过 project.godot 设置为 AutoLoad 单例，可以通过 GameConfig 访问。
# 由于直接挂在全球节点，我们既可以用 `var`，为了直接通过类名作为脚本内静态访问，
# 使用 `static var` 和 `const`。其实在 Godot 4 中只要有了 class_name，即使不 AutoLoad 也可以直接访问静态变量。
# 但为了后续如果需要添加信号或处理逻辑，注册为 AutoLoad 会更为灵活。

# 地图参数
static var map_half_size: float = 50.0
static var fall_threshold: float = -10.0

# 生命与复活系统
static var default_lives: int = 10
static var respawn_delay: float = 3.0
static var invincible_duration: float = 3.0
static var respawn_points: Array[Vector3] = [
	Vector3(25, 0.5, 25),
	Vector3(-25, 0.5, 25),
	Vector3(25, 0.5, -25),
	Vector3(-25, 0.5, -25),
]

# 武器刷新控制
static var weapon_initial_delay: float = 20.0
static var weapon_stay_duration: float = 30.0
static var weapon_respawn_cooldown: float = 10.0
static var weapon_spawn_margin: float = 10.0
