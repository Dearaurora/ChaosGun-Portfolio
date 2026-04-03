---
plan: UI 系统重构
priority: 🟡 中
request_feedback: true
---

# 计划 11：UI 系统重构

## 目标描述

当前的 `debug_hud.gd` 是纯代码生成的临时 Label，作为调试用途。需要替换为正式的 HUD 场景，并增加更多游戏信息展示。

## 当前 UI 问题

- HUD 完全由代码生成（`Label.new()`），不方便调整布局
- 只显示武器名 + 弹药 + 生命数
- Game Over 文字过于简陋
- 没有准星
- 没有击杀提示
- AI 没有 HUD（无法看到 AI 的状态）

## 拟议变更

### [NEW] `scenes/ui/game_hud.tscn`

使用 Godot 场景编辑器设计正式 HUD：

**左下角 — 武器信息面板**
- 当前武器图标/颜色标识
- 弹药数字 + 弹药条
- 武器名称
- 槽位指示（1/2）

**右下角 — 生命信息**
- 心形图标 × 剩余生命数
- 可选：百分比/HP（如果实施计划 04）

**中上方 — 比赛信息**（依赖计划 06）
- 回合倒计时
- 击杀数

**屏幕中央 — 准星**
- 简单的十字准星
- 可选：散布指示器（准星随散布值放大/缩小）

**全屏 — 事件通知**
- 击杀提示（"你击杀了 AI_1"）
- 武器拾取提示（"+1 SMG"）
- 复活倒计时（"3... 2... 1..."）

### [NEW] `scripts/ui/game_hud.gd`
替代 `debug_hud.gd`，从 GameManager / WeaponManager 读取数据。

### [NEW] `scenes/ui/game_over_screen.tscn`
Game Over 画面：赢家公告、最终分数、"按 R 重新开始"。

### [DELETE] `scripts/ui/debug_hud.gd`
在正式 HUD 完成后删除。

### [MODIFY] `scenes/characters/player.tscn`
替换 DebugHUD 节点为新的 GameHUD。

## 待定问题

> [!IMPORTANT]
> 1. **准星样式**：简单十字？圆点？还是动态散布圈？
> 2. **HUD 是挂在 Player 下还是独立场景？** 当前 DebugHUD 是 Player 的子节点。如果去掉可能更易管理。
> 3. **是否需要 AI 血条/名字浮在头顶？** 即 3D 世界中的 UI（Billboard）。
> 4. **这个计划是否应该等计划 06（计分系统）之后再做？** UI 需要展示的信息取决于有哪些游戏系统。

## 验证方案

### 手动验证
1. 确认 HUD 在不同窗口分辨率下正确显示
2. 确认弹药数实时更新
3. 确认武器切换时 HUD 更新
4. 确认 Game Over 屏幕正确显示
5. 确认准星始终在屏幕中央
