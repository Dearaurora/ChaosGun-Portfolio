---
plan: 伪刚体冲量物理重构 (Kinematic Impulse)
priority: 🔴 高
request_feedback: true
---

# 计划 14：伪刚体冲量物理重构 (路线 2)

## 目标描述

针对当前“粘滞”与“操作撕裂”的击退物理表现，保留具有极强操作跟手性的 `CharacterBody3D` 根节点，但将其底层的击退和速度合成算法彻底替换为遵循牛顿第二定律（Newton's Second Law）的**纯动量冲量模型**。这样既能保证玩家跑跑跳跳手感清脆，又能让武器的打击感“拳拳到肉”。

## 拟议变更

### 1. [MODIFY] `scripts/player/base_character.gd`
- **引入物理属性**：
  - 新增 `@export var mass: float = 1.0` (质量，越大越难被击退)
  - 新增 `@export var knockback_drag: float = 35.0` (地面阻尼，用于替代原来的无边界 friction lerp)
  - 新增 `var momentum: Vector3 = Vector3.ZERO` 取代原来的 `knockback_velocity`。
  - 删除冗余的而且容易引发 bug 的 `knockback_resistance`。
- **重写冲量衰减**：
  - 弃用曲线无限逼近的 `lerp`，改为使用 `move_toward(Vector3.ZERO, knockback_drag * delta)`，展现出被推着滑行的匀减速制动效果。
- **重写 `apply_knockback()`**：
  - ```gdscript
    func apply_knockback(impulse: Vector3) -> void:
        if is_invincible or is_dead: return
        momentum += impulse / mass
    ```
- **解耦操作剥夺**：
  - 完全移除带有 “30%速度” 魔术数字的阶跃判断 `control_factor`。移动物理直接变为干净彻底的向量相加：`velocity = player_input_vel + momentum`。

### 2. [MODIFY] `scripts/player/dummy_target.gd`
- 通过在 `_ready` 初始化重写 `mass = 2.5` 等属性，取代原有的奇特阻尼手感，用标准质量压住靶子不被一枪击飞过远。
- 去除 `dummy_target` 对 `apply_knockback` 的 `edge_damping` 等晦涩逻辑覆写，统统交给干净的动量公式处理。

### 3. [MODIFY] `scripts/weapons/projectile.gd`
- 现在的 `knockback_power` 将正式在物理意义上代表“冲量”（Impulse=力×时间），对重构后的系统兼容甚至可以说是完美拟合。若冲量不足，只需在场景数据端调大即可。

## 影响范围分析

- **正面收益**：极大地提升操作可预测性。由于玩家操作再也不会在受击瞬间被“强制锁死只剩 5%”，玩家能够做到在被爆炸炸飞的半空中进行微操“后撤步抵消动能”，实现竞技游戏的高端身法。
- **调试波动**：原先的击退距离是由 `lerp` 计算的，现在转化为线性衰减，所有的武器武器击退强度（如散弹枪冲力）都需要进行常数级的**手感重新校调**。

## 验收标准 (DoD)

- 移除涉及 `knockback_resistance` 和 `control_factor` 退化的相关代码。
- 子弹能精确按质量比例造成击退位移（例如 mass 为 2 被击退距离只有 mass 为 1 的一半）。
- 玩家被击退的过程平滑线性，停止极其干脆不再拖泥带水，并在推行过程中依然能提供 100% 的走位抗衡推力。

## 任务清单 (Task Checklist)

- [x] 在 `BaseCharacter` 中声明 `mass`, `knockback_drag` 以及 `momentum` 变量。
- [x] 彻底重写 `BaseCharacter` 中的 `_apply_movement()` 以应用动量匀减速与线性相加。
- [x] 彻底重写 `apply_knockback()` 遵循冲量公式。
- [x] 移除 `DummyTarget` 中遗忘代码并依赖新设计的 `mass` 进行重量级防击退。
- [x] 校验 `demo_arena` 体验。

## 待定问题

> [!IMPORTANT]
> 1. **受击硬直（Hitstun / Stun）**：解除了操作剥夺意味着玩家被击退还能自由开枪/乱走。那我们是否需要引入一个纯粹的 **受击硬直微秒机制**？比如受到极其沉重的攻击（狙击枪）时，直接禁止任何 `input_vel` 长达 0.2 秒（这在格斗游戏或部分射击中用来强化受击表现），还是说维持只要飞出去也能随时反击？

## 验证方案

1. 开启 `demo_arena.tscn`，观察子弹连开后，怪物及靶子的减速度是否从飘逸变成了扎实落地。
2. 控制玩家故意被推向边缘，体验被击退时继续死按向前键反抗的真实角力感。
