# Arena Surface Material P24 Memory Capsule

- 决策：批准 P24 主舞台材质与落地感升级。主岛采用三档暖木面板、深色结构框、深木桥梁和红色软护栏；保留干净玩具感，不加入污渍或随机磨损。
- 不变量：不改变地图拓扑、碰撞、桥口、出生点、拾取点、镜头规则、武器数值、角色尺寸和 P14 全局色调合同。
- 输入：`reports/p23_combat_feedback_final.png`、A1 高级玩具天空岛规格、现有 Sunset V2 Blender builder。
- 产物：`tools/generate_sunset_runtime_textures.py`、`tools/build_sunset_open_ringout_v2_preview.py`、15 张木材颜色/法线/粗糙度贴图、`open_ringout_v2_preview.blend`、`open_ringout_v2_preview.glb`、P24 自动验收规则。
- 验证：`sunset_open_ringout_v2_integration_verifier.gd`、`open_ringout_blender_visual_verifier.gd`、`open_ringout_slice_verifier.gd`、`p14_environment_verifier.gd`、`open_ringout_camera_verifier.gd`、角色动作与战斗音频验证器，共 8/8 PASS。
- 证据：`reports/p24_surface_material_v1.png`、`reports/p24_surface_material_final.png`；最终版相较 P23 具备更明确的地板明度节奏、桥梁对比、红色掩体识别和接触阴影。
- 失败与废案：旧验证器要求单一粗糙度数值，与 P24 粗糙度贴图冲突；已升级合同为贴图存在性与视觉层级检查。未采用颗粒、划痕、磨损和更多地面装饰。
- 风险与待办：主舞台静态资产已接近当前边际收益上限。下一优先级是 P25 环境动态表现，不应继续堆叠地面细节。
