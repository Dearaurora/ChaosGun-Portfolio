---
plan: 生命值 (HP) 系统
priority: 🟡 中
request_feedback: true
---

# 计划 04：生命值 (HP) 系统

## 目标描述

当前游戏中，角色**只能被击退至坠落才会死亡**，没有 HP 概念。这在纯击退玩法中是可行的，但限制了：
- 封闭地图的设计空间（有墙壁挡住就永远不会死）
- 武器差异化（无法设计"高伤低击退"或"低伤高击退"武器）
- 累积击退机制（类似大乱斗的百分比系统：HP 越低，受到的击退越大）

## 设计方案（供讨论）

### 方案 A：纯击退（当前）+ 百分比累积
类似大乱斗的 % 系统：
- 每个角色有一个 `damage_percent`（0% 起步，累积增长）
- 受到攻击时 `damage_percent` 增加
- 击退力 = 武器击退力 × (1 + damage_percent / 100)
- 角色仍然通过坠落死亡，但高百分比时更容易被打飞
- 复活后 `damage_percent` 重置为 0

### 方案 B：传统 HP + 击退
- 每个角色有 `max_hp` 和 `current_hp`
- 子弹同时造成 HP 伤害和击退
- HP 归零 = 直接死亡（不需要坠落）
- 坠落也触发死亡

### 方案 C：保持现状
当前的纯击退坠落机制已经足够，暂不添加 HP。

## 拟议变更（以方案 A 为例）

### [MODIFY] `scripts/player/base_character.gd`（或 Player/AI）

- 新增 `var damage_percent: float = 0.0`
- 修改 `apply_knockback()`：击退力乘以 `(1 + damage_percent / 100)`
- 修改 `_respawn()`：重置 `damage_percent = 0.0`

### [MODIFY] `scripts/weapons/projectile.gd`

- 新增 `var damage: float` 属性
- `_on_body_entered` 中调用 `body.add_damage(damage)` 增加百分比

### [MODIFY] `scripts/weapons/weapon_data.gd`

- 新增 `@export var damage: float` 属性
- 各武器工厂方法添加 `damage` 参数

### [MODIFY] `scripts/ui/debug_hud.gd`

- 显示当前 `damage_percent`

## 待定问题

> [!WARNING]
> 1. **选哪个方案？** 方案 A（百分比累积）最契合当前的纯击退玩法。方案 B 会改变核心体验。方案 C 暂不实施。请确认。
> 2. **百分比上限？** 大乱斗的 % 可以到 999%。ChaosGun 要设上限吗？
> 3. **是否影响自身后坐力？** 高百分比时，武器后坐力是否也放大？

## 验证方案

### 手动验证
1. 射击 AI 多次，观察其百分比增长和击退力增大
2. 在低百分比时确认击退力变化不明显
3. 在高百分比时确认一发手枪就能把 AI 打飞很远
4. 复活后确认百分比重置为 0
