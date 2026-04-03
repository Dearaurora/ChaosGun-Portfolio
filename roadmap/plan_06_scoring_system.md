---
plan: 计分与回合系统
priority: 🟡 中
request_feedback: true
---

# 计划 06：计分与回合系统

## 目标描述

当前游戏只有 `lives = 10` 的简单扣命机制，且只检测了玩家的 Game Over。没有：
- 击杀计分
- 赢家判定
- 回合时间限制
- 重新开始 / 返回菜单

## 拟议变更

### [NEW] `scripts/globals/game_manager.gd` (AutoLoad)

全局游戏管理器，负责：
- 追踪所有角色的击杀数和死亡数
- 判定胜负条件
- 管理回合时间

```gdscript
var scores: Dictionary = {}  # { node_name: { kills: int, deaths: int } }
var round_time: float = 180.0  # 3 分钟一局
var round_timer: float = 0.0
var is_round_active: bool = false

signal round_started()
signal round_ended(winner_name: String)
signal score_updated(player_name: String, kills: int, deaths: int)
```

#### 胜负条件（二选一，待讨论）：
- **生存模式**：最后一个存活的角色获胜（当前接近此模式）
- **计分模式**：在时间内击杀数最多的获胜

### [MODIFY] `scripts/player/base_character.gd`（或 Player/AI）

- `_die()` 方法中通知 `GameManager` 记录死亡
- 需要追踪"是谁打死了我"（最后一个攻击者）

### [MODIFY] `scripts/weapons/projectile.gd`

- 记录 `shooter` 的引用，在目标坠落时可溯源

### [NEW] `scripts/ui/scoreboard.gd`

- 显示当前计分板
- 按 Tab 或特定键显示/隐藏

### [MODIFY] `scripts/ui/debug_hud.gd`

- 增加回合倒计时显示
- Game Over 时显示赢家和最终分数
- 增加"按 R 重新开始"提示

### [MODIFY] `scenes/maps/demo_arena.tscn`

- 添加 GameManager 节点（或通过 AutoLoad 自动加载）

## 待定问题

> [!IMPORTANT]
> 1. **生存模式 vs 计分模式？** 生存模式更简单（当前只需加赢家判定），计分模式更有趣但改动更大。
> 2. **是否需要回合时间限制？** 如果有计分模式，时间限制是必要的。纯生存模式则可选。
> 3. **重新开始机制**：按 R 键重载场景？还是做一个简单的菜单？
> 4. **AI 的击杀数是否计入？** AI 之间互杀是否也计分？

## 验证方案

### 手动验证
1. 击杀 AI 后确认计分增加
2. 所有角色命用完后确认赢家判定正确
3. 按重新开始后确认所有状态重置
4. 如有计时，确认倒计时结束后显示结果
