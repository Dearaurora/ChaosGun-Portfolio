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
