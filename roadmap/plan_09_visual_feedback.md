---
plan: 视觉反馈特效
priority: 🔴 高
request_feedback: true
---

# 计划 09：视觉反馈特效

## 目标描述

当前游戏几乎没有视觉反馈：射击无枪口焰、击中无特效、坠落无动画、无屏幕震动。视觉反馈对**游戏手感 (Game Feel)** 的影响是最大的，少量特效就能让游戏从"程序员原型"变成"有趣的游戏"。

## 拟议变更

### 1. 枪口焰 (Muzzle Flash)

#### [NEW] `scenes/effects/muzzle_flash.tscn`

- 使用 `GPUParticles3D` 或简单的 `MeshInstance3D` + Tween 实现
- 在 `WeaponPoint` 位置生成
- 持续 0.05-0.1 秒的白色/黄色闪光
- 可选：根据武器类型调整大小（狙击 > AK > SMG > 手枪）

#### [MODIFY] `scripts/weapons/weapon.gd`

- `try_fire()` 成功时实例化枪口焰

### 2. 子弹拖尾 (Bullet Trail)

#### [MODIFY] 各 projectile `.tscn` 文件

- 添加 `GPUParticles3D` 或 `Line2D`（3D 中用 `MeshInstance3D` 拉伸的面片）
- 不同武器不同颜色拖尾：
  - 手枪：黄色
  - SMG：橙色
  - AK：红色
  - 狙击：白色/蓝色

### 3. 击中特效 (Hit Effect)

#### [NEW] `scenes/effects/hit_effect.tscn`

- `GPUParticles3D` 爆发型粒子（一次性发射 10-20 个粒子）
- 在子弹命中位置生成
- 持续 0.3-0.5 秒后自动销毁

#### [MODIFY] `scripts/weapons/projectile.gd`

- `_on_body_entered` 中在碰撞位置实例化击中特效

### 4. 受击闪白 (Damage Flash)

#### [MODIFY] `scripts/player/base_character.gd`（或 Player/AI）

- `apply_knockback()` 时将角色材质瞬间变白
- 使用 `ShaderMaterial` 的 `shader_parameter` 或直接修改 `albedo_color`
- 0.1 秒后恢复原色

### 5. 屏幕震动 (Screen Shake)

#### [NEW] `scripts/camera/camera_shake.gd`

- 附加到 `GlobalCamera` 上
- 提供 `shake(intensity, duration)` 方法
- 玩家受到大击退时触发（如被狙击枪命中）
- 射击时轻微震动（增强射击手感）

#### [MODIFY] `scenes/maps/demo_arena.tscn`

- `GlobalCamera` 上挂载 `camera_shake.gd`

### 6. 坠落特效

#### [MODIFY] `scripts/player/base_character.gd`

- `_die()` 触发时，在坠落位置生成一个爆炸粒子
- 可选：死亡前播放缩小 + 旋转的 tween 动画

## 待定问题

> [!IMPORTANT]
> 1. **使用 GPUParticles3D 还是 CPUParticles3D？** GPU 粒子性能更好但 gl_compatibility 模式下可能有限制。当前项目用的是 `gl_compatibility`。
> 2. **屏幕震动是否影响 AI 瞄准？** 相机震动不应影响游戏逻辑，只影响渲染层。需确认 AI 的 `_face_direction` 不依赖相机位置。
> 3. **一次实现全部还是分批？** 建议按影响力排序：枪口焰 > 击中特效 > 屏幕震动 > 子弹拖尾 > 受击闪白 > 坠落特效。

## 验证方案

### 手动验证
1. 射击时确认枪口焰在正确位置闪烁
2. 子弹飞行时确认有拖尾效果
3. 子弹命中目标时确认有粒子爆发
4. 被大击退命中时确认屏幕震动
5. 坠落时确认有死亡特效
6. 确认特效不影响性能（FPS 保持稳定）
