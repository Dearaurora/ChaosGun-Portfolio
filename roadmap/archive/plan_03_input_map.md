---
plan: 统一 InputMap 输入系统
priority: 🟡 中
request_feedback: true
---

# 计划 03：统一 InputMap 输入系统

## 目标描述

当前 `player_character.gd` 中的输入处理存在多种混用方式：

1. **`Input.get_vector("move_left", "move_right", ...)`**：使用 InputMap 动作（但 `project.godot` 中未定义这些动作，所以 fallback 到了第 2 种方式）
2. **`Input.is_key_pressed(KEY_W/A/S/D)`**：硬编码按键检测（实际在用的方式）
3. **`Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)`**：直接检测鼠标按键
4. **`Input.is_action_just_pressed("ui_focus_next")`**：使用 Godot 内置的 UI 动作（Tab 键）
5. **`_input(event)`**：在回调中检测滚轮事件

这导致：
- 不同输入在不同的帧阶段处理（`_physics_process` vs `_input`）
- 无法通过 InputMap 重新映射按键
- 未来无法支持手柄

## 任务清单 (Task Checklist)

- [x] 1. 编写辅助脚本并执行，将自定义动作添加到 `project.godot` 的 InputMap 中。
- [x] 2. 重构 `player_character.gd`，移除所有硬编码的输入检测和状态追踪（`_prev_fire_pressed` 等）。
- [x] 3. 运行 Godot 系统验证 Input 映射是否生效。

## 拟议变更

### [MODIFY] `project.godot`

在 `[input]` section 中定义所有自定义输入动作：

```
move_left    → KEY_A
move_right   → KEY_D
move_forward → KEY_W
move_backward → KEY_S
fire         → MOUSE_BUTTON_LEFT
weapon_slot_1 → KEY_1
weapon_slot_2 → KEY_2
weapon_cycle  → MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, KEY_TAB
```

### [MODIFY] `scripts/player/player_character.gd`

- 删除 `Input.is_key_pressed(KEY_W/A/S/D)` 的 fallback 分支
- `Input.get_vector()` 将直接生效（因为 InputMap 已定义）
- 射击改为 `Input.is_action_pressed("fire")` / `Input.is_action_just_pressed("fire")`
- 武器切换改为 `Input.is_action_just_pressed("weapon_slot_1")` 等
- 删除 `_input(event)` 中的滚轮处理，统一到 `_handle_weapon_input()` 中使用 `Input.is_action_just_pressed("weapon_cycle")`
- 删除 `_prev_fire_pressed` 手动跟踪，改用 `is_action_just_pressed`

## 待定问题

> [!IMPORTANT]
> 1. **武器切换滚轮方向**：目前滚轮上下都执行 `cycle_weapon()`（同一方向循环）。是否应该区分滚轮上 = 上一把、滚轮下 = 下一把？
> 2. **是否预留手柄支持？** 如果考虑未来支持手柄，可以在 InputMap 中同时绑定手柄按钮（如 RT 射击、LB/RB 切换武器）。
> 3. **Tab 键是否继续作为武器切换？** 目前用的是 `ui_focus_next`（Godot 内置 UI 动作），这会影响 UI 导航。改为自定义动作更安全。

## 验证方案

### 手动验证
1. 运行游戏，测试 WASD 移动
2. 测试鼠标左键射击（半自动、全自动、栓动）
3. 测试 1/2 键切换武器
4. 测试滚轮和 Tab 切换武器
5. 确认所有输入响应与重构前一致
