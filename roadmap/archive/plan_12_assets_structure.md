---
plan: 规范资源目录结构
priority: 🟢 低
request_feedback: true
---

# 计划 12：规范资源目录结构

## 目标描述

当前项目没有独立的美术资源目录。随着后续添加贴图、模型、音效等资源，需要提前规范目录结构，避免文件散落。

## 拟议变更

### [NEW] 目录结构

```
ChaosGun/
├── assets/
│   ├── audio/
│   │   ├── sfx/         # 音效文件
│   │   └── music/       # 背景音乐
│   ├── textures/        # 贴图、UI 图片
│   ├── models/          # 3D 模型 (.glb/.gltf)
│   ├── fonts/           # 自定义字体
│   ├── shaders/         # Shader 文件
│   └── particles/       # 粒子模板
├── scenes/              # 已有
├── scripts/             # 已有
└── roadmap/             # 已有
```

### [MODIFY] `.gitignore`

添加常见的大文件类型排除（如 `.psd`, `.blend1` 等中间文件）：

```
# Asset source files (keep only exports)
*.psd
*.xcf
*.blend1
*.blend2
```

### [NEW] `assets/` 下各子目录的 `.gdkeep` 文件

Git 不跟踪空目录，在每个空目录放一个占位文件确保目录结构被提交。

## 待定问题

> [!IMPORTANT]
> 1. **是否将 particle 场景放在 `assets/particles/` 还是 `scenes/effects/`？** 粒子既是资源也是场景，放哪边都可以，需要统一。
> 2. **Shader 文件放哪里？** `assets/shaders/` 还是与使用它的场景放在一起？
> 3. **这个结构是否现在就建还是等需要时再建？** 建议现在建好空目录，免得以后资源文件东一个西一个。

## 验证方案

### 手动验证
1. `git status` 确认新目录被正确追踪
2. 确认 `.gitignore` 更新后不会误排除游戏资源
3. 确认现有场景和脚本引用路径不受影响
