# ChaosGun 作品集演示指南

这份指南面向第一次打开仓库的面试官，目标是用最少步骤看到可玩成果、视觉成果和工程能力。

## 推荐观看顺序

1. **先看 README 截图**：快速了解项目风格与竞技场布局。
2. **运行主场景**：在 Godot 4.6 中打开 `project.godot`，按 F6/F5 运行当前主场景。
3. **看 Momentum Circuit**：关注击退、边缘掉落、AI、武器拾取和环境机制。
4. **看 Twin Bays**：关注场景构图、材质、传送门、水体/潮汐和可重复的资产制作流程。
5. **看工程证据**：浏览 `scripts/tests/`、`tools/` 与 `docs/workflow/`，了解自动化验证和从概念到可玩切片的流程。

## 操作

- W/A/S/D：移动
- 鼠标：瞄准
- 鼠标左键：射击
- 1 / 2 / 滚轮：切换武器
- Esc：暂停

## 推荐代码入口

| 目标 | 文件 |
| --- | --- |
| 玩家与 AI | `scripts/player/player_character.gd`、`scripts/player/ai_character.gd` |
| 武器与子弹 | `scripts/weapons/`、`scripts/projectile.gd` |
| 竞技场 | `scripts/maps/momentum_circuit_arena.gd`、`scripts/maps/twin_bays_splash_arena.gd` |
| UI | `scripts/ui/`、`scenes/ui/` |
| 自动化验证 | `scripts/tests/` |
| 资产构建 | `tools/`、`assets/source/` |

## 验证说明

自动化验证优先使用 Godot headless 模式。可见测试窗口遵循仓库根目录 `AGENTS.md` 的安全约束：普通窗口、带装饰、非全屏、非置顶，最大 960×540。

## 如果只看 3 分钟

看 README 的两张图 → 运行主场景移动/射击 → 打开 `scripts/maps/` 和 `scripts/tests/`。这三步即可看到作品效果、核心玩法和工程化能力。
