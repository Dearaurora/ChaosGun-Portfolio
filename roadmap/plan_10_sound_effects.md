---
plan: 音效系统
priority: 🟡 中
request_feedback: true
---

# 计划 10：音效系统

## 目标描述

当前游戏完全没有声音。音效对射击游戏的手感至关重要。

## 音效清单

| 音效 | 触发时机 | 优先级 |
|------|----------|--------|
| 枪声 (每种武器不同) | 射击时 | 🔴 高 |
| 击中音效 | 子弹命中目标 | 🔴 高 |
| 坠落/死亡音效 | 角色坠落 | 🟡 中 |
| 武器拾取音效 | 捡起武器 | 🟡 中 |
| 武器切换音效 | 切换武器 | 🟡 中 |
| 弹药耗尽(咔) | 无弹药时射击 | 🟡 中 |
| 复活音效 | 角色复活 | 🟢 低 |
| Game Over 音效 | 游戏结束 | 🟢 低 |
| BGM | 全程 | 🟢 低 |

## 资源来源

- [Freesound.org](https://freesound.org/) / [Kenney.nl](https://kenney.nl/assets?q=audio)
- [sfxr](https://sfxr.me/)：快速生成复古风格音效

## 拟议变更

### [NEW] `assets/audio/sfx/` 目录
存放所有音效文件（.ogg 或 .wav）。

### [NEW] `scripts/globals/audio_manager.gd` (AutoLoad)
全局音效管理器，提供 `play_sfx(name, position)` 接口，内部使用对象池避免反复实例化。

### [MODIFY] `scripts/weapons/weapon.gd`
`try_fire()` 成功后播放对应枪声。

### [MODIFY] `scripts/weapons/projectile.gd`
`_on_body_entered` 中播放击中音效。

### [MODIFY] `scripts/weapons/weapon_pickup.gd`
拾取时播放音效。

### [MODIFY] `scripts/weapons/weapon_manager.gd`
切换武器 / 弹药耗尽时播放音效。

### [MODIFY] `scripts/player/base_character.gd`
`_die()` 和 `_respawn()` 播放音效。

## 待定问题

> [!IMPORTANT]
> 1. **音效风格**：写实枪声还是复古卡通风格 (sfxr)？
> 2. **是否用 AudioStreamPlayer3D？** 当前正交相机视角下空间音效感知有限，2D 可能就够了。
> 3. **音效资源谁负责？** 你们自行找素材还是先用 sfxr 占位？

## 验证方案

### 手动验证
1. 射击每种武器确认有枪声且不同
2. SMG 连射时确认音效不重叠卡顿
3. 拾取/切换/死亡等音效正常触发
