---
request_feedback: true
---

# 目标描述

当前游戏中的瞄准和射击机制被强制限制在水平面（X-Z平面）上。随着跳台和斜坡的加入，玩家和敌人有了不同的高度变化，因此需要支持射击时不仅能在水平方向索敌，还能在垂直（Y轴高度）方向瞄准目标。由于是上帝视角/俯视视角的射击游戏，对于带有辅助瞄准逻辑的本地多人控制，需要调整 `PlayerCharacter` 的辅助瞄准计算，并同时修改 `AICharacter` 以支持立体射击判定。

## 影响范围分析

*   **辅助瞄准 (Aim Assist)**: 修改后，玩家依然在水平面调整面朝方向，但子弹会朝向带有高度变化的目标发射，需要保证计算锥角时不受高度差影响导致辅助瞄准失效。
*   **AI行为**: AI 的开火方向会变成 3D 向量，能够向上或向下攻击站在斜坡上的玩家。面朝方向 (Model Rotation) 仍应保留在水平面上，防止模型竖直乱转。
*   **抛射物系统**: `WeaponManager` 目前发射弹药是依靠 `try_fire(weapon_point, fire_dir, self)`。只要 `fire_dir` 是三维的，抛射物自身的施加力天然支持 3D。

## 拟议变更

### [MODIFY] `PlayerCharacter`
[res://scripts/player/player_character.gd](file:///Users/geng/Projects/ChaosGun/ChaosGun/scripts/player/player_character.gd)
*   **`_get_aim_assisted_dir`**: 当前将 `to_target.y = 0` 强制应用在所有地方。
    *   **计划修改**: 分离“计算辅助瞄准判定”与“返回的射击向量”。使用去除了 `Y` 轴的向量计算夹角（判断是否在辅助瞄准的锥角视野内），但如果选中目标，则返回真实的 3D 向量 `(target.global_position - global_position).normalized()`，使得子弹具备俯仰角。

### [MODIFY] `AICharacter`
[res://scripts/player/ai_character.gd](file:///Users/geng/Projects/ChaosGun/ChaosGun/scripts/player/ai_character.gd)
*   **`_do_shoot`**: 当前逻辑将 `to_target.y = 0` 用于面朝方向与射击方向。
    *   **计划修改**: 使用 `to_target_flat` (去除Y) 专门给 `_face_direction` 做模型旋转，同时使用原始的带有高度差的 `to_target_3d = _target.global_position - global_position` 来计算真实的 `aim_dir`，从而支持对处于不同高度的玩家开火。

## 验收标准 (DoD)

- [ ] 玩家在使用手柄/键鼠射击时，即使自身面朝方向只有水平转动，子弹也会自动追踪视锥范围内的敌人高度进行纵向抛射。
- [ ] AI 敌人可以向站在高台上的玩家发射具有仰角的子弹。
- [ ] 角色的模型面朝（Transform.basis）不能发生俯仰角（Pitch）旋转，只能在水平方向（Yaw）转动。

## 任务清单 (Task Checklist)

- [ ] 在 `player_character.gd` 修改 `_get_aim_assisted_dir` 保持水平视锥判定的基础上返回 3D 方向。
- [ ] 在 `ai_character.gd` 修改 `_do_shoot` 分离水平旋转和 3D 开火方向判定。
- [ ] 运行测试确认射击逻辑是否符合预期。

## 待定问题

*   没有特别大的设计风险。上帝视角的射击目前武器弹道依赖 `projectile.gd`，该脚本内如果只是使用 `apply_central_impulse(dir * speed)` ，将天然继承给定的 3D `dir`。
*   需要询问用户：目标判定时，是使用 `target.global_position` （通常在脚底或者包围盒中心），还是要给目标加上一个高度偏移（如 `target.global_position + Vector3(0, 1.0, 0)`）来瞄准胸口高度以免子弹打脚？

## 验证方案

1. 启动 `demo_arena.tscn`。
2. 控制玩家跳上前面添加的 4米高台。
3. 观察 AI 能否从底层往斜上方射击攻击玩家。
4. 玩家站在台上向底层的 AI 射击，观察子弹是否会朝下射击。
