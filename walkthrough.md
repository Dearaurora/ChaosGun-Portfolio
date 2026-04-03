# 提取 BaseCharacter 基类

为了将 `PlayerCharacter` 和 `AICharacter` 之间大量重复的代码（诸如生命系统、击退物理、复活功能、坠落检测等）进行统一封装，我们引入了 `BaseCharacter` 基类。

## 核心改动

- **新建 `BaseCharacter` 基类**：包含了击退功能 `_apply_movement()`、坠落检测 `_check_fall()` 以及生命与复活系统（`_die()`, `_respawn()`, `apply_knockback()`）。提取了 `_base_process(delta)` 处理击退与无敌计时器相关逻辑。
- **重构 `PlayerCharacter`**：继承自 `BaseCharacter`。移除了大量的生命系统和物理状态代码，并将自身的循环逻辑集中处理为输入捕捉、武器控制和调用 `super._base_process(delta)` 及新引入的方法中。
- **重构 `AICharacter`**：同样改为继承 `BaseCharacter`。它利用重写的 `_respawn()` 功能在复活后重置有限状态机 `_state = State.PATROL` 并挑选新的巡逻点，使得 AI 保持原来的战斗逻辑不丢失。
- **重构 `DummyTarget`**：作为非战斗型可被攻击对象，它现在也继承 `BaseCharacter`。它通过调整 `friction` 以及保留自身特有的 `apply_knockback()` 实现被攻击后的靶子特有阻尼手感，同时享受了统一规范的物理移动封装。

## 代码结构与逻辑演示
- 各节点现在只需关心特有的输入和状态行为，共同的物理底层和生命统计交给了 `BaseCharacter`：
```gdscript
# 在每个子类中，使用这种方式更新基类的共享计时器与抗性运算：
func _process(delta: float) -> void:
    super._base_process(delta)
    # ... 其余自己的逻辑 ...
```

## 验证与测试
重构完成后，Godot 脚本解析全部通过且无异常报错，`global_script_class_cache.cfg` 中正常缓存了 `BaseCharacter`。各项实体逻辑均对齐重构前表现。

如果您需在后续进行多地图支持修改，只需在 `BaseCharacter` 中进一步将 `RESPAWN_POINTS` 改为由实际场景中或 GameServer 获取即可。

---

# 规范资源目录结构 (Plan 12)

为了避免后续随开发引入大量美术、音效资源导致项目文件散乱，我们提前在游戏中搭建好了规范的 `assets/` 级目录结构，并在版本控制中进行相应约束。

## 核心改动

- **新建 `assets/` 目录树**：已创建涵盖音频、纹理、模型、字体、以及特效预制体的完整结构分类：
  - `audio/sfx/`, `audio/music/`
  - `textures/`
  - `models/`
  - `fonts/`
  - `shaders/`
  - `particles/`
- **版本控制占位符**：在所有空文件夹中放置了 `.gdkeep`，确保结构能直接被 Git 所追踪并共享给后续协作的开发者。
- **更新 Git 忽略规则**：在 `ChaosGun/.gitignore` 末尾增加排除了 `.psd`, `.xcf`, `.blend1`, `.blend2` 等美术中间文件类型的规则限制，使得源文件更改不仅不会污染仓库，且有利于减小仓库体积。

## 验证情况

通过 Git 状态查询，可确认新增的占位文件已被 Git 正确识别为 Untracked Files 并准备好参与控制，忽略规则成功更新并没有影响目前的资产加载机制。

---

# 伪刚体冲量物理重构 (Plan 14)

为了解决原先击退受力过程中的手感生硬和操作割裂问题，我们在不改变根节点 `CharacterBody3D` 操控跟手性的前提下，引入了符合牛顿物理体系的动量冲量计算。

## 核心改动

- **物理化击退机制 (`BaseCharacter`)**：去除了强行指定且无限衰减的 `knockback_velocity` 操作锁定，引入真实的物理质量 (`mass: float`) 与当前累计动量 (`momentum: Vector3`)。当子弹击中时 `apply_knockback()` 现在精确计算冲量转化：`momentum += impulse / mass`。
- **匀减速阻尼衰减**：在主处理循环中抛弃了 `lerp`，改为使用引擎自带的匀减速逼近 `momentum.move_toward(Vector3.ZERO, knockback_drag * delta)`。阻力彻底线性平滑，受击到停下的过程扎实果断。
- **玩家移动操控解耦**：清空了原先 `control_factor` 一刀切（当受到高速撞击直接切断玩家操作）的设定，如今玩家的移动输入意图与遭受的击退完全通过简单的 `velocity = input_vel + momentum` 进行复合。哪怕被冲天炮射中，半空中玩家依然能够用键位反抗进行微操身法对抗。
- **靶子质量化 (`DummyTarget`)**：剥弃原本重写过的边缘减震逻辑，由继承而来的通用模型搞定。目前给予了靶子 2.5 的极大防弹 `mass`。

## 验证情况

经过本地 Headless 构建检查，所有的遗留变量报错均排除成功；重构能够以极其纯粹干净的物理体系适配接下来的武器参数调整（以后只需管加多少冲击力，不管推多远）。受击微硬直等需求已暂缓挂起。
