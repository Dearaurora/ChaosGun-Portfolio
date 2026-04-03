---
description: 实现角色跳跃功能
---

# 添加跳跃功能 (Jump Feature)

在我们将重力与物理系统重构为 `RigidBody3D` 之后，需要重新考虑角色控制手感并实现跳跃。刚体没有内置的 `is_on_floor()` 方法和精确的边界检测，所以我们要引入基于形体投射（ShapeCast/ShapeQuery）的地面检测，以防止因为单根射线踩在边缘悬空而导致的无法跳跃问题，并给刚体施加向上的冲量（Impulse）。

## User Review Required

> [!IMPORTANT]
> **刚体控制与锁定确认**：
> 作为使用 RigidBody3D 的代价，我们需要确认是否已在编辑器中将玩家与敌人的**旋转锁定 (Axis Lock -> Angular X, Y, Z 全部勾选)**。否则遇到底墙边缘或产生相互碰撞时角色可能会摔倒或滚动。
> 
> **跳跃手感设计确认**：
> 当前计划采用**固定冲量跳跃**（按一下固定起跳，不支持长按高跳，更加清脆干练），在空中时，依然允许一定的水平方向移动控制（Air Control），但我们将加入**空中控制减弱**和**落地阻尼恢复**逻辑，以保持射击游戏的灵活身法又不会显得太过漂浮。

## Proposed Changes

### Configuration
#### [MODIFY] [project.godot](file:///Users/geng/Projects/ChaosGun/ChaosGun/project.godot)
- 向 `[input]` 映射表中补充定义 `jump` 动作。
- 绑定按键为 `Space` (空格键，Physical Keycode 32)。

---

### Player / Character Core
#### [MODIFY] [base_character.gd](file:///Users/geng/Projects/ChaosGun/ChaosGun/scripts/player/base_character.gd)
- **新增导出的移动参数**：
  - `@export var jump_impulse: float = 8.0`: 垂直跳跃冲量。
  - `@export var air_control_multiplier: float = 0.5`: 空中移动控制系数（允许在空中稍微改变方向）。
  
- **升级地面判定 `is_on_floor() -> bool`**：
  - 废弃不可靠的单根射线 (`intersect_ray`)。
  - 改用 `PhysicsShapeQueryParameters3D` 创建一个稍微比角色底部小一点的 `SphereShape3D` 球体进行范围探测 (`intersect_shape`)，能完美解决角色只有一脚踩在边缘时无法跳跃的尴尬问题。
  
- **新增跳跃功能 `jump() -> void`**：
  - 检测 `if is_on_floor():`。
  - 成功时调用 `apply_central_impulse(Vector3.UP * jump_impulse)`。
  - 跳跃发生后增加短暂的检测冷却或将自身临时标记为空中，防止刚起跳的 0.1 秒内受力异常。

- **重构阻尼手感 (`_integrate_forces`)**：
  - 在我们目前的 `base_character.gd` 中，我们已经只针对水平面 (X/Z) 施加了 `horizontal_damp = 5.0`。竖直方向 (Y轴) 目前不受阻尼影响，是纯自由落体。
  - **核心问题**：这个巨大的 `horizontal_damp` 让刚体能在地面“急停急起”，但如果角色跳到空中，它依然会粗暴地把角色的**前冲惯性（水平速度）**吃光，导致你“跳不远”，感觉像是在在极具阻力的空气（泥潭）里往前跳。
  - **修改逻辑**：我们将为起跳后的空中状态引入 `air_horizontal_damp` (水平空气阻尼)，取代地面的强摩擦阻尼。同时，如果您需要限制角色的最大掉落速度，我们也可以顺便拆分出一个专门针对 Y 轴的 `vertical_fall_damp`。

#### [MODIFY] [player_character.gd](file:///Users/geng/Projects/ChaosGun/ChaosGun/scripts/player/player_character.gd)
- **输入处理**：
  - 在已有的输入控制代码中新增按键侦测：`if Input.is_action_just_pressed("jump"): jump()`。
  - 修改推力代码：根据空中状态，动态调整向玩家输入的 `move_dir` 施加的力度。

## Verification Plan

### Manual Verification
1. 测试平台**边缘起跳**：让人物走到悬崖最边缘（一半身体悬空），按下空格。使用 ShapeQuery 应该依然能判定并成功起跳，而不会按了没反应。
2. 测试**空中抛物线**：起跳后，空中应具有完全正常的抛物线位移，不能像地面急停那样瞬间卡停。
3. 检查**防翻滚锁定**：无论角色是与敌人数次相撞，还是跳上几何体边缘，自身姿态必须保持直立不倾斜。此状态应该已经在 `.tscn` 中锁定，如有遗漏需要一并勾选。

## 任务清单 (Task Checklist)
- [x] 1. 编辑 `project.godot` 添加 `jump` 输入映射。
- [x] 2. 检查刚体场景 `.tscn` 中的 Axis Lock 设置。
- [x] 3. 修改 `base_character.gd` 添加基于 ShapeQuery 的 `is_on_floor()` 逻辑。
- [x] 4. 修改 `base_character.gd` 中的 `_integrate_forces` 以区分地面与空中的物理阻尼表现。
- [x] 5. 修改 `base_character.gd` 添加向上的脉冲推力 `jump()` 方法。
- [x] 6. 修改 `player_character.gd` 接入输入与空中控制系数。
