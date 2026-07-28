# ChaosGun UI 设计 QA

## 结论

- 目标方向：用户选定的方案 2「中央角色舞台」。
- 运行时状态：PASS。
- 阻断问题：P0 0 项，P1 0 项。
- 可编辑设计源：`docs/ui/chaosgun_ui_system.pen` 尚未生成；Pencil 编辑器 WebSocket 当前未连接。运行时实现不依赖该文件。

## 对照基准

- 视觉目标：`docs/ui/references/chaosgun-character-select-selected-v2.png`
- 同尺寸合并对照：`reports/ui_redesign/character_select_reference_comparison.png`
- 当前角色配置：`reports/ui_redesign/character_select_1672x941.png`
- 主菜单：`reports/ui_redesign/menu_1920x1080.png`
- 键位设置：`reports/ui_redesign/keybinds_1920x1080.png`
- 暂停：`reports/ui_redesign/pause_1920x1080.png`
- 胜利与平局：`reports/ui_redesign/result_1920x1080.png`、`reports/ui_redesign/draw_1920x1080.png`
- 双地图 HUD：`reports/ui_redesign/open_ringout_hud_1920x1080.png`、`reports/ui_redesign/twin_bays_hud_2p_1920x1080.png`、`reports/ui_redesign/twin_bays_hud_4p_1920x1080.png`
- 战斗状态：`reports/ui_redesign/ready_1920x1080.png`、`reports/ui_redesign/low_ammo_1920x1080.png`、`reports/ui_redesign/last_life_1920x1080.png`

## 人工视觉审查

### 构图与层级

- 四槽位层级清晰：P1/P2 是中央主舞台，P3/P4 以收窄侧栏表示未加入状态。
- 底部玩家摘要、地图选择和主操作形成稳定的横向操作带。
- 暂停、READY/GO、胜利与平局使用同一暖梅色半透明表面和奶油白文字。
- 结算统计使用真实网格，姓名、KO、出界与得分不依赖空格对齐。

### 字体、对比度与焦点

- 中文为主，保留 `CHAOS GUN`、`READY`、`GO`、`KO` 等短竞技词。
- 主按钮、危险状态和玩家色均有独立轮廓；键鼠焦点环可见。
- HUD 使用深色半透明底和玩家色边框，在暖色 Open Ring-Out 与冷色 Twin Bays 上均可读。
- 低弹药与最后一命状态采用颜色和文案双重提示，不只依赖颜色。

### 响应式与占屏预算

- 自动检查覆盖 1280×720、1536×960、1920×1080、2560×1440。
- 所有可见文字均在视口内，玩家槽位、键位列和主要操作不重叠。
- MatchHUD 保持约 200×72 的角落占屏预算，并提供相机避让矩形。

## 已修复的 P2 问题

- 填充焦点按钮的文字对比不足。
- 暂停弹窗首帧透明度导致短暂难读。
- 长枪缩略图裁切。
- P3/P4 空位卡与 P1/P2 主舞台抢层级。
- 旧 HUD 验证节点与统一 MatchHUD 接口兼容，同时避免双 HUD 实例。

## 有意保留的差异

- 未复制概念图中的虚构 3D 擂台装饰，避免引入与真实地图脱节的假资产。
- 角色与武器采用现有 Blender 源模型的确定性透明渲染。
- 地图名称、参赛状态和弹药数据来自真实 MatchConfig 与运行时对象。

## 验证状态

- `chaosgun_ui_flow_verifier.gd`：PASS。
- `p28_ui_system_verifier.gd`：PASS。
- `local_keybinds_verifier.gd`：PASS。
- `local_match_roster_respects_slots_verifier.gd`：PASS。
- `playable_match_routes_open_ringout_verifier.gd`：PASS。
- Open Ring-Out 与 Twin Bays 运行时及比赛表现验证：PASS。
