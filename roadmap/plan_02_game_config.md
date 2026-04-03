---
plan: 集中管理游戏配置 (GameConfig)
priority: 🟡 中
request_feedback: true
---

# 计划 02：集中管理游戏配置 (GameConfig)

## 目标描述

目前游戏参数散落在多个脚本中硬编码：
- `MAP_HALF = 50.0` 同时出现在 `ai_character.gd` 和 `weapon_spawner.gd` 中
- `RESPAWN_POINTS` 硬编码在 `player_character.gd` 和 `ai_character.gd` 中
- `FALL_THRESHOLD`, `RESPAWN_DELAY`, `INVINCIBLE_DURATION` 等常量也被重复定义
- 调试参数（如 `initial_delay: float = 5.0 ## TODO: 测试完毕后改回 20.0`）容易遗忘

目标是创建一个全局 `GameConfig` AutoLoad，集中管理所有游戏规则参数，方便调参和多地图支持。

## 拟议变更

### [NEW] `scripts/globals/game_config.gd`

创建全局配置脚本，作为 AutoLoad 单例：

```gdscript
extends Node
class_name GameConfig

# 地图参数
static var map_half_size: float = 50.0
static var fall_threshold: float = -10.0

# 生命系统
static var default_lives: int = 10
static var respawn_delay: float = 3.0
static var invincible_duration: float = 3.0
static var respawn_points: Array[Vector3] = [...]

# 武器刷新
static var weapon_initial_delay: float = 20.0
static var weapon_stay_duration: float = 30.0
static var weapon_respawn_cooldown: float = 10.0
static var weapon_spawn_margin: float = 10.0
```

### [MODIFY] `project.godot`

在 `[autoload]` section 中注册 `GameConfig`。

### [MODIFY] `scripts/player/player_character.gd` (或 `base_character.gd`)

将 `FALL_THRESHOLD`, `RESPAWN_DELAY`, `INVINCIBLE_DURATION`, `RESPAWN_POINTS`, `lives` 等常量替换为引用 `GameConfig` 中的值。

### [MODIFY] `scripts/player/ai_character.gd`

将 `MAP_HALF`, `RESPAWN_POINTS` 等常量替换为引用 `GameConfig`。

### [MODIFY] `scripts/weapons/weapon_spawner.gd`

将 `initial_delay`, `stay_duration`, `respawn_cooldown`, `spawn_margin`, `map_half_size` 等 `@export` 改为引用 `GameConfig`（或保留 @export 但默认值从 GameConfig 取）。

## 待定问题

> [!IMPORTANT]
> 1. **使用 AutoLoad 还是 Resource？** AutoLoad 方便全局访问，但 Resource（`.tres` 文件）更适合序列化和编辑器内修改。你们倾向哪种？
> 2. **是否保留 WeaponSpawner 上的 @export？** 如果保留 @export，可以在编辑器里逐场景覆盖默认值，灵活性更强。
> 3. **复活点应该从场景节点读取还是配置文件？** 未来多地图时，每张地图有不同的复活点，可以考虑在地图场景中放置 `Marker3D` 节点作为复活点。

## 验证方案

### 手动验证
1. 运行游戏，确认所有参数行为与重构前一致
2. 修改 `GameConfig` 中的某个参数（如 `default_lives = 3`），运行游戏验证生效
3. 确认 `weapon_spawner.gd` 中的 TODO 注释已被清理
