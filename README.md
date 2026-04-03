# 🔫 ChaosGun

> **2.5D 击退射击对战原型** — 用枪的击退力把对手打下平台！

## 📖 项目简介

ChaosGun 是一款基于 **Godot 4.6** 开发的 2.5D 多人对战射击游戏原型。游戏的核心玩法不是传统的 HP 伤害，而是通过武器的**击退力 (Knockback)** 将对手推出竞技场边缘。灵感来自《任天堂明星大乱斗》的场外击飞机制。

## 🎮 核心玩法

- **击退为王**：所有武器造成击退而非伤害，目标是把对手推下平台
- **武器系统**：4 种风格各异的武器（手枪、SMG、AK 步枪、狙击枪），各有不同的射速、击退力、后坐力和散布特性
- **武器拾取**：地图上会周期性刷新强力武器，拾取后替换当前主武器
- **AI 对手**：FSM 状态机驱动的 AI，具备巡逻、追击、射击、边缘逃离行为
- **生命复活**：每位角色有 10 条命，坠落后倒计时复活，复活时附带无敌盾

## 🛠️ 技术栈

| 项目 | 技术 |
|------|------|
| 引擎 | Godot 4.6 (Forward+, gl_compatibility) |
| 语言 | GDScript |
| 视角 | 2.5D 正交投影 (120 单位视野) |
| 渲染 | gl_compatibility 模式 |

## 📁 项目结构

```
ChaosGun/
├── project.godot              # Godot 项目配置
├── README.md                  # 本文件
├── scenes/
│   ├── characters/
│   │   ├── player.tscn        # 玩家角色场景
│   │   ├── ai_character.tscn  # AI 对手场景
│   │   └── dummy_target.tscn  # 测试用靶子
│   ├── maps/
│   │   └── demo_arena.tscn    # 演示竞技场（主场景）
│   └── weapons/
│       ├── pistol_projectile.tscn
│       ├── smg_projectile.tscn
│       ├── ak_projectile.tscn
│       ├── sniper_projectile.tscn
│       └── weapon_pickup.tscn # 武器拾取物
├── scripts/
│   ├── player/
│   │   ├── player_character.gd  # 玩家控制器
│   │   ├── ai_character.gd      # AI 状态机
│   │   └── dummy_target.gd      # 靶子逻辑
│   ├── weapons/
│   │   ├── weapon.gd            # 单把武器运行时逻辑
│   │   ├── weapon_data.gd       # 武器数据资源 + 工厂方法
│   │   ├── weapon_manager.gd    # 武器槽位管理
│   │   ├── weapon_pickup.gd     # 武器拾取物
│   │   ├── weapon_spawner.gd    # 武器刷新系统
│   │   └── projectile.gd       # 通用子弹
│   └── ui/
│       └── debug_hud.gd        # 临时调试 HUD
└── roadmap/                     # 开发计划（见下方）
```

## 🎯 操作方式

| 操作 | 按键 |
|------|------|
| 移动 | W / A / S / D |
| 射击 | 鼠标左键 |
| 瞄准 | 鼠标方向 |
| 切换武器 | 1 / 2 / 滚轮 / Tab |

## 🗺️ 开发路线图

详细的改进计划存放在 `roadmap/` 文件夹中，每个文件对应一个独立的改进方向。请参考各计划文件了解具体实现方案。

## 🚀 如何运行

1. 安装 [Godot 4.6](https://godotengine.org/download)
2. 克隆本仓库：`git clone <仓库地址>`
3. 在 Godot 中打开 `project.godot`
4. 按 **F5** 运行主场景 (`demo_arena.tscn`)

## 🤝 协作指南

- 使用 **Feature Branch** 工作流：每个功能在独立分支上开发
- 通过 **Pull Request** 进行代码审查后合并到 `main`
- Commit 信息请使用中文或 Angular 规范（`feat:` / `fix:` / `refactor:` 等）
- 参考 `roadmap/` 中的计划文件分配任务

## 📄 License

待定
