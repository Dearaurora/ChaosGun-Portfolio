# Open Ring-Out A1 Art Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将默认 `Open Ring-Out Slice` 升级成 A1 高级玩具天空岛英雄主视觉资产，同时保持现有碰撞、出生点、武器点、镜头和回归验证稳定。

**Architecture:** Godot 继续拥有玩法层、碰撞层、角色、武器、HUD、灯光和截图验证；Blender Python 生成的 GLB 作为 `OpenRingoutBlenderVisuals` 下的主要可见舞台。执行顺序先补 Open Ring-Out 专用 Blender 美术验收门槛，再重做 `tools/build_open_ringout_blender_visuals.py` 的平台、桥、边缘、深渊和外围道具资产，最后通过 Godot 导入、自动验证和截图人工评分。

**Tech Stack:** Godot 4.6 GDScript, Blender 5.1 Python, glTF/GLB, PowerShell test runners, existing `open_ringout_slice` scene/runtime.

---

## Execution Boundary

本计划执行 `docs/superpowers/specs/2026-07-09-open-ringout-a1-art-upgrade-design.md` 中已批准的 A1 方向。禁止改玩法拓扑、碰撞尺寸、出生点、武器刷新规则、角色行为、伤害、击飞、得分和菜单流程。允许重做 GLB 可见资产、追加非碰撞装饰、调整非玩法材质密度、更新美术验收脚本和截图评审记录。

必须保留 `scripts/tests/open_ringout_slice_verifier.gd` 已依赖的 Blender 节点名，包括：

- `main_deck_irregular_top_slab`
- `main_deck_cliff_block_south_0`
- `main_deck_cliff_block_west_0`
- `north_deck_irregular_top_slab`
- `north_deck_cliff_block_south_0`
- `east_deck_irregular_top_slab`
- `south_deck_irregular_top_slab`
- `west_deck_irregular_top_slab`
- `north_bridge_irregular_top_slab`
- `east_bridge_irregular_top_slab`
- `south_bridge_irregular_top_slab`
- `west_bridge_irregular_top_slab`
- `EastCombatLaneFloorInset`
- `ChunkyCoverClusterWest`
- all existing `BridgeWarningCone*` body nodes
- existing concept edge glow nodes
- existing depth nodes such as `WarmCloudBankNorth`, `WarmCloudBankSouth`, `FarFloatingIslandLeft_cliff`, `FarAbyssCloudPuff_0`, and `FarAbyssGlowMote_0`

## File Structure

- Create `scripts/tests/open_ringout_blender_visual_verifier.gd`: focused GLB art gate for Open Ring-Out. It checks the imported GLB exists, counts mesh/material richness, verifies A1 hero asset anchors, keeps bridge deck sizes readable, and proves the GLB stays collision-free.
- Create `scripts/tests/run_open_ringout_blender_visual_verifier.ps1`: PowerShell runner matching existing Godot verifier runners.
- Create `tools/rebuild_open_ringout_blender_visuals.ps1`: Blender build plus Godot import wrapper for `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`.
- Modify `tools/build_open_ringout_blender_visuals.py`: keep current export path and old required node names, then rebuild the generated stage into A1 asset groups: playable shells, bridge set, edge language, surface treatment, depth set, and prop framing.
- Modify `scripts/tests/open_ringout_slice_verifier.gd`: only after the GLB builder adds stable A1 anchor names, extend the existing broad regression gate with a few high-value anchors. Do not duplicate the focused verifier's full mesh/material count logic here.
- Update `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`: generated output from Blender script.
- Update generated Godot import files under `assets/models/generated/open_ringout_slice/` if Godot import writes or refreshes them.
- Update `reports/open_ringout_slice_screenshot.png`: final visual proof.
- Create `docs/workflow/open-ringout-a1-art-review-2026-07-09.md`: screenshot review with the eight approved scoring categories and a pass/fail decision.

## Acceptance Bar

Automated gates must pass:

- `scripts/tests/run_open_ringout_blender_visual_verifier.ps1`
- `scripts/tests/run_open_ringout_slice_verifier.ps1`
- direct screenshot capture through `scripts/tests/capture_open_ringout_screenshot.gd`

Manual screenshot gate must pass:

- Total art score at least 34 out of 40.
- No category below 3.
- `A1 Reference Fidelity`, `Composition`, `Geometry Language`, `Gameplay Readability`, and `Screenshot Appeal` each at least 4.
- The three largest remaining gaps are recorded in the review doc.

Use this Godot executable unless the local install changes:

```powershell
E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe
```

Use this Blender executable unless the local install changes:

```powershell
C:\Program Files\Blender Foundation\Blender 5.1\blender.exe
```

---

### Task 1: Add Focused Open Ring-Out Blender Visual Gate

**Files:**
- Create: `scripts/tests/open_ringout_blender_visual_verifier.gd`

- [ ] **Step 1: Write the failing focused verifier**

Create `scripts/tests/open_ringout_blender_visual_verifier.gd` with this content:

```gdscript
extends SceneTree

const SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const VISUAL_ROOT_PATH := "OpenRingoutBlenderVisuals"
const VISUAL_SCENE_PATH := "res://assets/models/generated/open_ringout_slice/open_ringout_visuals.glb"
const MIN_MESH_COUNT := 170
const MIN_MATERIAL_COUNT := 14

const REQUIRED_MESHES := [
	"main_deck_irregular_top_slab",
	"north_deck_irregular_top_slab",
	"east_deck_irregular_top_slab",
	"south_deck_irregular_top_slab",
	"west_deck_irregular_top_slab",
	"north_bridge_irregular_top_slab",
	"east_bridge_irregular_top_slab",
	"south_bridge_irregular_top_slab",
	"west_bridge_irregular_top_slab",
	"A1MainDeckOuterSkirtNorth",
	"A1MainDeckOuterSkirtSouth",
	"A1MainDeckOuterSkirtWest",
	"A1MainDeckOuterSkirtEast",
	"A1NorthDeckHeroCrown",
	"A1EastDeckHeroCrown",
	"A1SouthDeckHeroCrown",
	"A1WestDeckHeroCrown",
	"A1NorthBridgeRouteRailL",
	"A1NorthBridgeRouteRailR",
	"A1EastBridgeRouteRailL",
	"A1EastBridgeRouteRailR",
	"A1SouthBridgeRouteRailL",
	"A1SouthBridgeRouteRailR",
	"A1WestBridgeRouteRailL",
	"A1WestBridgeRouteRailR",
	"A1CenterPickupRuneOuter",
	"A1CenterPickupRuneInner",
	"A1SkyIslandToyWindmillNE_pole",
	"A1SkyIslandToyWindmillNE_blade_a",
	"A1SkyIslandFlagSW_pole",
	"A1SkyIslandFlagSW_banner",
	"A1DepthCloudRibbonNorth",
	"A1DepthCloudRibbonSouth",
	"A1DepthIslandClusterNW_cliff",
	"A1DepthIslandClusterSE_cliff"
]

const REQUIRED_PREFIX_COUNTS := {
	"A1EdgeBeacon": 18,
	"A1SurfacePanel": 22,
	"A1BridgeMouthMarker": 8,
	"A1DepthGlowMote": 14
}

const FORBIDDEN_NAME_PARTS := [
	"_front_lip",
	"_back_lip",
	"bumper_east",
	"bumper_se",
	"round_drum_",
	"round_drum_cap_",
	"tiny_cone_",
	"blue_panel_",
	"metal_plate_"
]

var _failures: Array[String] = []
var _host: Node = null

func _initialize() -> void:
	print("==================================================")
	print("[Blender Visual Verifier] Open Ring-Out A1")
	print("==================================================")

	if not ResourceLoader.exists(VISUAL_SCENE_PATH):
		_fail("Blender visual GLB is not imported or loadable: %s" % VISUAL_SCENE_PATH)

	var scene = load(SCENE_PATH) as PackedScene
	if scene == null:
		_fail("Could not load %s" % SCENE_PATH)
		await _finish()
		return

	var match_config = root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]

	_host = Node.new()
	root.add_child(_host)

	var arena = scene.instantiate()
	_host.add_child(arena)

	await process_frame
	await process_frame

	var visual_root = arena.get_node_or_null(VISUAL_ROOT_PATH)
	if visual_root == null:
		_fail("Missing %s" % VISUAL_ROOT_PATH)
		await _finish()
		return

	_verify_counts(visual_root)
	_verify_required_meshes(visual_root)
	_verify_prefix_counts(visual_root)
	_verify_forbidden_names(visual_root)
	_verify_no_collision(visual_root)
	_verify_bridge_deck_readability(visual_root)

	await _finish()

func _verify_counts(visual_root: Node) -> void:
	var mesh_count := _count_mesh_instances(visual_root)
	var material_names: Dictionary = {}
	_collect_material_names(visual_root, material_names)
	print("Mesh instances: ", mesh_count)
	print("Unique materials: ", material_names.size())
	if mesh_count < MIN_MESH_COUNT:
		_fail("Expected at least %d Blender visual mesh instances, got %d" % [MIN_MESH_COUNT, mesh_count])
	if material_names.size() < MIN_MATERIAL_COUNT:
		_fail("Expected at least %d Blender visual materials, got %d" % [MIN_MATERIAL_COUNT, material_names.size()])

func _verify_required_meshes(visual_root: Node) -> void:
	for mesh_name in REQUIRED_MESHES:
		if not _has_named_descendant(visual_root, String(mesh_name)):
			_fail("Open Ring-Out A1 GLB is missing required mesh: %s" % mesh_name)

func _verify_prefix_counts(visual_root: Node) -> void:
	for prefix in REQUIRED_PREFIX_COUNTS.keys():
		var count := _count_descendants_with_prefix(visual_root, String(prefix))
		var expected := int(REQUIRED_PREFIX_COUNTS[prefix])
		if count < expected:
			_fail("Expected at least %d nodes with prefix %s, got %d" % [expected, prefix, count])

func _verify_forbidden_names(visual_root: Node) -> void:
	for name_part in FORBIDDEN_NAME_PARTS:
		if _has_descendant_name_containing(visual_root, String(name_part)):
			_fail("Open Ring-Out A1 GLB still has forbidden stale visual name: %s" % name_part)

func _verify_no_collision(visual_root: Node) -> void:
	if _has_collision_descendant(visual_root):
		_fail("Blender visual GLB must remain non-colliding; collision belongs to OpenRingoutPlayable/OpenRingoutCovers")

func _verify_bridge_deck_readability(visual_root: Node) -> void:
	var checks := [
		["north_bridge_irregular_top_slab", Vector2(8.0, 4.0), "north bridge deck"],
		["east_bridge_irregular_top_slab", Vector2(5.5, 6.0), "east bridge deck"],
		["south_bridge_irregular_top_slab", Vector2(8.0, 3.8), "south bridge deck"],
		["west_bridge_irregular_top_slab", Vector2(5.0, 7.0), "west bridge deck"],
	]
	for check in checks:
		var mesh_name := check[0] as String
		var min_size := check[1] as Vector2
		var role := check[2] as String
		var mesh := _find_mesh_instance_by_name(visual_root, mesh_name)
		if mesh == null:
			_fail("Missing obvious bridge connector mesh: %s" % mesh_name)
			continue
		var size := _mesh_visual_size(mesh)
		if size.x < min_size.x or size.z < min_size.y:
			_fail("%s is too small to read as %s, size %s" % [mesh_name, role, str(size)])

func _count_mesh_instances(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count

func _collect_material_names(node: Node, material_names: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh:
			for surface in range(mesh.get_surface_count()):
				var material := mesh_node.get_surface_override_material(surface)
				if material == null:
					material = mesh.surface_get_material(surface)
				if material:
					material_names[String(material.resource_name)] = true
	for child in node.get_children():
		_collect_material_names(child, material_names)

func _has_named_descendant(node: Node, target_name: String) -> bool:
	if node.name == target_name:
		return true
	for child in node.get_children():
		if _has_named_descendant(child, target_name):
			return true
	return false

func _has_descendant_name_containing(node: Node, name_part: String) -> bool:
	if String(node.name).contains(name_part):
		return true
	for child in node.get_children():
		if _has_descendant_name_containing(child, name_part):
			return true
	return false

func _count_descendants_with_prefix(node: Node, prefix: String) -> int:
	var count := 1 if String(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_descendants_with_prefix(child, prefix)
	return count

func _has_collision_descendant(node: Node) -> bool:
	if node is StaticBody3D or node is CollisionShape3D or node is Area3D:
		return true
	for child in node.get_children():
		if _has_collision_descendant(child):
			return true
	return false

func _find_mesh_instance_by_name(node: Node, target_name: String) -> MeshInstance3D:
	if node.name == target_name and node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance_by_name(child, target_name)
		if found:
			return found
	return null

func _mesh_visual_size(mesh: MeshInstance3D) -> Vector3:
	if mesh.mesh == null:
		return Vector3.ZERO
	var local_size := mesh.mesh.get_aabb().size
	var scale := mesh.global_transform.basis.get_scale()
	return Vector3(absf(local_size.x * scale.x), absf(local_size.y * scale.y), absf(local_size.z * scale.z))

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	await process_frame
	if _host and is_instance_valid(_host):
		_host.queue_free()
		await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Blender Visual Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Blender Visual Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
```

- [ ] **Step 2: Run the verifier directly and confirm it fails on the current GLB**

Run:

```powershell
& "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path . -s res://scripts/tests/open_ringout_blender_visual_verifier.gd
```

Expected: exit code `1`; stdout includes `[Blender Visual Verifier] FAIL`; failures include missing `A1MainDeckOuterSkirtNorth` or another `A1*` mesh.

- [ ] **Step 3: Commit the failing verifier**

```bash
git add scripts/tests/open_ringout_blender_visual_verifier.gd
git commit -m "test: add open ringout blender art gate"
```

---

### Task 2: Add Open Ring-Out Build And Verify Runners

**Files:**
- Create: `scripts/tests/run_open_ringout_blender_visual_verifier.ps1`
- Create: `tools/rebuild_open_ringout_blender_visuals.ps1`

- [ ] **Step 1: Add the PowerShell verifier runner**

Create `scripts/tests/run_open_ringout_blender_visual_verifier.ps1` with this content:

```powershell
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$stdoutPath = Join-Path $PSScriptRoot "..\..\godot_open_ringout_blender_visual_stdout.txt"
$stderrPath = Join-Path $PSScriptRoot "..\..\godot_open_ringout_blender_visual_stderr.txt"
$projectPath = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if (Test-Path Env:PATH) {
    Remove-Item Env:PATH -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $stdoutPath) {
    Remove-Item -LiteralPath $stdoutPath -Force
}

if (Test-Path -LiteralPath $stderrPath) {
    Remove-Item -LiteralPath $stderrPath -Force
}

$args = @(
    "--headless",
    "--path", $projectPath,
    "-s", "res://scripts/tests/open_ringout_blender_visual_verifier.gd"
)

$process = Start-Process `
    -FilePath $GodotPath `
    -ArgumentList $args `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -NoNewWindow `
    -PassThru `
    -Wait

$stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
$stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }

Write-Output "EXIT=$($process.ExitCode)"
Write-Output "--- STDOUT ---"
if ($stdout) {
    Write-Output $stdout.TrimEnd()
}
Write-Output "--- STDERR ---"
if ($stderr) {
    Write-Output $stderr.TrimEnd()
}

if ($process.ExitCode -ne 0) {
    throw "Godot Open Ring-Out Blender visual verifier exited with code $($process.ExitCode)"
}

if ($stderr -match "SCRIPT ERROR:" -or $stderr -match "(^|`n)ERROR:") {
    throw "Godot Open Ring-Out Blender visual verifier completed with engine or script errors."
}

if ($stderr -match "ObjectDB instances leaked at exit" -or $stderr -match "resources still in use at exit") {
    throw "Godot Open Ring-Out Blender visual verifier completed with shutdown leak warnings."
}
```

- [ ] **Step 2: Add the rebuild/import runner**

Create `tools/rebuild_open_ringout_blender_visuals.ps1` with this content:

```powershell
param(
    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe",
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

$ErrorActionPreference = "Stop"

$projectPath = Split-Path $PSScriptRoot -Parent
$builderPath = Join-Path $PSScriptRoot "build_open_ringout_blender_visuals.py"
$assetPath = Join-Path $projectPath "assets\models\generated\open_ringout_slice\open_ringout_visuals.glb"

if (-not (Test-Path -LiteralPath $BlenderPath)) {
    throw "Blender executable not found: $BlenderPath"
}

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if (-not (Test-Path -LiteralPath $builderPath)) {
    throw "Blender builder script not found: $builderPath"
}

Write-Output "Building Open Ring-Out Blender visual layer..."
& $BlenderPath --background --python $builderPath

if ($LASTEXITCODE -ne 0) {
    throw "Open Ring-Out Blender visual build failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $assetPath)) {
    throw "Expected GLB was not produced: $assetPath"
}

Write-Output "Importing generated Open Ring-Out GLB into Godot..."
& $GodotPath --headless --path $projectPath --import

if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE"
}

Write-Output "Generated and imported: $assetPath"
```

- [ ] **Step 3: Run the new verifier runner and confirm it reports the same expected failure**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_blender_visual_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Expected: the runner throws `Godot Open Ring-Out Blender visual verifier exited with code 1`, and stdout contains `[Blender Visual Verifier] FAIL`.

- [ ] **Step 4: Commit runners**

```bash
git add scripts/tests/run_open_ringout_blender_visual_verifier.ps1 tools/rebuild_open_ringout_blender_visuals.ps1
git commit -m "test: add open ringout blender visual runners"
```

---

### Task 3: Define A1 Asset Contracts In The Blender Builder

**Files:**
- Modify: `tools/build_open_ringout_blender_visuals.py`

- [ ] **Step 1: Add A1 constants and keep legacy materials stable**

In `tools/build_open_ringout_blender_visuals.py`, keep existing `MAT_DECK`, `MAT_DECK_LIGHT`, `MAT_BRIDGE`, `MAT_SIDE`, and `MAT_SIDE_DARK` definitions because existing Godot tests check floor and bridge color logic. Append these A1 materials immediately after the existing material block:

```python
MAT_A1_EDGE_BEACON = emissive_mat("a1_edge_beacon_warm", srgb("#ffb347", 0.86), srgb("#ff8a2a"), 1.55, True)
MAT_A1_RIM_BLUE = emissive_mat("a1_abyss_rim_blue", srgb("#82ccff", 0.62), srgb("#82ccff"), 1.25, True)
MAT_A1_PANEL_SHADE = mat("a1_surface_panel_shade", srgb("#aa8a68", 0.42), 0.93, True)
MAT_A1_PANEL_HIGHLIGHT = mat("a1_surface_panel_highlight", srgb("#f2d5a2", 0.52), 0.86, True)
MAT_A1_CANDY_BLUE = mat("a1_toy_candy_blue", srgb("#35a7d6"), 0.62)
MAT_A1_CANDY_GREEN = mat("a1_toy_candy_green", srgb("#77b96a"), 0.70)
MAT_A1_CANDY_PURPLE = mat("a1_toy_candy_purple", srgb("#8f72d6"), 0.72)
MAT_A1_SOFT_SHADOW = mat("a1_soft_contact_shadow", srgb("#3b3150", 0.22), 0.98, True)
MAT_A1_FLAG_RED = mat("a1_toy_flag_red", srgb("#e34e47"), 0.68)
MAT_A1_FLAG_WHITE = mat("a1_toy_flag_white", srgb("#ffe9bd"), 0.74)
```

- [ ] **Step 2: Add normalized platform and bridge specs**

Insert these constants before `def build_scene():`:

```python
A1_PLATFORM_SPECS = [
    {"name": "main_deck", "title": "MainDeck", "pos": (0, -1, 0), "size": (52, 2, 36), "top": MAT_DECK, "side": MAT_SIDE, "inset": False},
    {"name": "main_west_lip", "title": "MainWestLip", "pos": (-20, -0.98, 9), "size": (18, 2, 20), "top": MAT_DECK, "side": MAT_SIDE, "inset": False},
    {"name": "main_east_lip", "title": "MainEastLip", "pos": (21, -0.98, -3), "size": (18, 2, 23), "top": MAT_DECK, "side": MAT_SIDE, "inset": False},
    {"name": "north_deck", "title": "NorthDeck", "pos": (4, -1, -30), "size": (22, 2, 15), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
    {"name": "east_deck", "title": "EastDeck", "pos": (38, -1, 3), "size": (20, 2, 18), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
    {"name": "south_deck", "title": "SouthDeck", "pos": (9, -1, 30), "size": (24, 2, 16), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
    {"name": "west_deck", "title": "WestDeck", "pos": (-39, -1, 2), "size": (18, 2, 20), "top": MAT_DECK_LIGHT, "side": MAT_SIDE_DARK, "inset": True},
]

A1_BRIDGE_SPECS = [
    {"name": "north_bridge", "title": "NorthBridge", "pos": (4, -0.65, -20.2), "size": (11, 1.3, 5.2), "axis": "x"},
    {"name": "east_bridge", "title": "EastBridge", "pos": (31.8, -0.65, 2), "size": (7.0, 1.3, 8.0), "axis": "z"},
    {"name": "south_bridge", "title": "SouthBridge", "pos": (7, -0.65, 20.0), "size": (11, 1.3, 5.0), "axis": "x"},
    {"name": "west_bridge", "title": "WestBridge", "pos": (-31.8, -0.65, 2), "size": (6.6, 1.3, 9.0), "axis": "z"},
]
```

- [ ] **Step 3: Add title-safe helper**

Insert this helper before the A1 helper functions:

```python
def a1_title(spec):
    return spec["title"]
```

- [ ] **Step 4: Run Blender syntax check through background startup**

Run:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background --python tools/build_open_ringout_blender_visuals.py
```

Expected: exit code `0`; stdout ends with `Exported assets\models\generated\open_ringout_slice\open_ringout_visuals.glb` or `Exported assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`.

- [ ] **Step 5: Commit asset contract constants**

```bash
git add tools/build_open_ringout_blender_visuals.py assets/models/generated/open_ringout_slice/open_ringout_visuals.glb
git commit -m "feat: define open ringout a1 visual contracts"
```

---

### Task 4: Rebuild Playable Shells And Bridges As A1 Hero Geometry

**Files:**
- Modify: `tools/build_open_ringout_blender_visuals.py`
- Update: `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`

- [ ] **Step 1: Add platform shell helpers**

Insert these helpers before `def build_scene():`:

```python
def add_a1_platform_shell(spec):
    name = spec["name"]
    title = a1_title(spec)
    x, y, z = spec["pos"]
    sx, sy, sz = spec["size"]
    add_platform(name, spec["pos"], spec["size"], spec["top"], spec["side"], spec["inset"])

    skirt_y = y - 2.10
    crown_y = y + 1.28
    add_cube(f"A1{title}OuterSkirtNorth", (x, skirt_y, z - sz * 0.56), (sx * 0.86, 2.2, 1.10), spec["side"], bevel=0.35)
    add_cube(f"A1{title}OuterSkirtSouth", (x, skirt_y, z + sz * 0.56), (sx * 0.86, 2.2, 1.10), spec["side"], bevel=0.35)
    add_cube(f"A1{title}OuterSkirtWest", (x - sx * 0.56, skirt_y, z), (1.10, 2.2, sz * 0.78), spec["side"], bevel=0.35)
    add_cube(f"A1{title}OuterSkirtEast", (x + sx * 0.56, skirt_y, z), (1.10, 2.2, sz * 0.78), spec["side"], bevel=0.35)
    add_cube(f"A1{title}HeroCrown", (x, crown_y, z), (sx * 0.78, 0.10, sz * 0.72), MAT_A1_PANEL_HIGHLIGHT, bevel=0.42)

    add_cube(f"A1{title}SoftShadowNorth", (x, y - 0.10, z - sz * 0.48), (sx * 0.66, 0.035, 0.70), MAT_A1_SOFT_SHADOW, bevel=0.20)
    add_cube(f"A1{title}SoftShadowSouth", (x, y - 0.10, z + sz * 0.48), (sx * 0.66, 0.035, 0.70), MAT_A1_SOFT_SHADOW, bevel=0.20)
```

- [ ] **Step 2: Add bridge hero helpers**

Insert this helper below `add_a1_platform_shell`:

```python
def add_a1_bridge_shell(spec):
    name = spec["name"]
    title = a1_title(spec)
    x, y, z = spec["pos"]
    sx, sy, sz = spec["size"]
    axis = spec["axis"]
    add_bridge_platform(name, spec["pos"], spec["size"], MAT_BRIDGE, MAT_SIDE)

    rail_y = 0.58
    if axis == "x":
        add_cube(f"A1{title}RouteRailL", (x, rail_y, z - sz * 0.52), (sx * 0.86, 0.28, 0.34), MAT_A1_RIM_BLUE, bevel=0.12)
        add_cube(f"A1{title}RouteRailR", (x, rail_y, z + sz * 0.52), (sx * 0.86, 0.28, 0.34), MAT_A1_RIM_BLUE, bevel=0.12)
        add_cube(f"A1BridgeMouthMarker{title}A", (x - sx * 0.48, rail_y + 0.10, z), (0.50, 0.46, sz * 0.82), MAT_A1_EDGE_BEACON, bevel=0.16)
        add_cube(f"A1BridgeMouthMarker{title}B", (x + sx * 0.48, rail_y + 0.10, z), (0.50, 0.46, sz * 0.82), MAT_A1_EDGE_BEACON, bevel=0.16)
    else:
        add_cube(f"A1{title}RouteRailL", (x - sx * 0.52, rail_y, z), (0.34, 0.28, sz * 0.86), MAT_A1_RIM_BLUE, bevel=0.12)
        add_cube(f"A1{title}RouteRailR", (x + sx * 0.52, rail_y, z), (0.34, 0.28, sz * 0.86), MAT_A1_RIM_BLUE, bevel=0.12)
        add_cube(f"A1BridgeMouthMarker{title}A", (x, rail_y + 0.10, z - sz * 0.48), (sx * 0.82, 0.46, 0.50), MAT_A1_EDGE_BEACON, bevel=0.16)
        add_cube(f"A1BridgeMouthMarker{title}B", (x, rail_y + 0.10, z + sz * 0.48), (sx * 0.82, 0.46, 0.50), MAT_A1_EDGE_BEACON, bevel=0.16)
```

- [ ] **Step 3: Replace the platform and bridge loops in `build_scene()`**

Replace the existing literal platform and bridge loops in `build_scene()` with:

```python
def build_scene():
    for spec in A1_PLATFORM_SPECS:
        add_a1_platform_shell(spec)

    for spec in A1_BRIDGE_SPECS:
        add_a1_bridge_shell(spec)

    add_concept_outer_edge_glows()
    add_tile_lines()
    add_center_pickup_pad()
    add_props()
    add_chunky_cover_clusters()
    add_background_depth()
```

- [ ] **Step 4: Rebuild and import**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/rebuild_open_ringout_blender_visuals.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Expected: stdout includes `Generated and imported: ...\assets\models\generated\open_ringout_slice\open_ringout_visuals.glb`.

- [ ] **Step 5: Run current broad verifier**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_slice_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Expected: exit code `0`; stdout contains `PASS`; no stderr `SCRIPT ERROR`, `ERROR:`, object leak, or resource leak warnings.

- [ ] **Step 6: Commit shell and bridge rebuild**

```bash
git add tools/build_open_ringout_blender_visuals.py assets/models/generated/open_ringout_slice/open_ringout_visuals.glb assets/models/generated/open_ringout_slice/open_ringout_visuals.glb.import
git commit -m "feat: rebuild open ringout a1 shells and bridges"
```

---

### Task 5: Add A1 Edge Language And Surface Treatment

**Files:**
- Modify: `tools/build_open_ringout_blender_visuals.py`
- Update: `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`

- [ ] **Step 1: Add edge beacon helper**

Insert before `def build_scene():`:

```python
def add_a1_edge_beacons():
    beacon_specs = [
        (-23, 1.56, -17), (-12, 1.56, -19), (0, 1.56, -19), (13, 1.56, -18), (24, 1.56, -14),
        (27, 1.56, -4), (29, 1.56, 8), (21, 1.56, 17), (9, 1.56, 20), (-4, 1.56, 18),
        (-17, 1.56, 17), (-25, 1.56, 9), (-28, 1.56, -3), (-21, 1.56, -12),
        (4, 1.56, -32), (39, 1.56, 3), (9, 1.56, 32), (-39, 1.56, 2),
    ]
    for i, pos in enumerate(beacon_specs):
        add_cylinder(f"A1EdgeBeacon_{i:02d}", pos, 0.34, 0.22, MAT_A1_EDGE_BEACON, 18)
```

- [ ] **Step 2: Add surface panel helper**

Insert below `add_a1_edge_beacons()`:

```python
def add_a1_surface_panels():
    panels = [
        ("A1SurfacePanel_MainNW", (-14, 1.47, -8), (8.0, 0.035, 3.0), -8, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_MainNE", (13, 1.48, -7), (8.4, 0.035, 2.8), 7, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_MainSW", (-13, 1.48, 9), (9.0, 0.035, 2.6), 5, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_MainSE", (13, 1.47, 9), (8.8, 0.035, 2.7), -5, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_WestLipA", (-22, 1.47, 5), (5.8, 0.035, 2.4), 2, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_WestLipB", (-18, 1.48, 13), (5.2, 0.035, 2.2), -9, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_EastLipA", (21, 1.47, -8), (5.8, 0.035, 2.4), -4, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_EastLipB", (24, 1.48, 5), (5.2, 0.035, 2.2), 8, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_NorthA", (0, 1.47, -30), (5.2, 0.035, 2.2), 0, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_NorthB", (9, 1.48, -30), (5.2, 0.035, 2.2), 0, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_EastA", (38, 1.47, -1), (5.2, 0.035, 2.2), 90, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_EastB", (38, 1.48, 7), (5.2, 0.035, 2.2), 90, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_SouthA", (4, 1.47, 30), (5.2, 0.035, 2.2), 0, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_SouthB", (14, 1.48, 30), (5.2, 0.035, 2.2), 0, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_WestA", (-39, 1.47, -3), (5.2, 0.035, 2.2), 90, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_WestB", (-39, 1.48, 7), (5.2, 0.035, 2.2), 90, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_BridgeN", (4, 1.51, -20.2), (6.8, 0.035, 1.0), 0, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_BridgeE", (31.8, 1.51, 2), (1.0, 0.035, 5.8), 0, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_BridgeS", (7, 1.51, 20.0), (6.8, 0.035, 1.0), 0, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_BridgeW", (-31.8, 1.51, 2), (1.0, 0.035, 6.2), 0, MAT_A1_PANEL_HIGHLIGHT),
        ("A1SurfacePanel_CenterRingA", (-3.0, 1.52, 0), (2.0, 0.035, 0.50), 0, MAT_A1_PANEL_SHADE),
        ("A1SurfacePanel_CenterRingB", (3.0, 1.52, 0), (2.0, 0.035, 0.50), 0, MAT_A1_PANEL_SHADE),
    ]
    for name, pos, size, yaw, material in panels:
        add_cube(name, pos, size, material, bevel=0.12, yaw_deg=yaw)
```

- [ ] **Step 3: Add center pickup hero treatment**

Insert below `add_center_pickup_pad()`:

```python
def add_a1_center_pickup_hero():
    add_cylinder("A1CenterPickupRuneOuter", (0, 1.92, 0), 3.25, 0.08, MAT_A1_RIM_BLUE, 40)
    add_cylinder("A1CenterPickupRuneInner", (0, 2.02, 0), 1.28, 0.10, MAT_A1_EDGE_BEACON, 32)
    for i, yaw in enumerate([0, 60, 120, 180, 240, 300]):
        angle = math.radians(yaw)
        x = math.cos(angle) * 2.45
        z = math.sin(angle) * 2.45
        add_cube(f"A1CenterPickupTick_{i}", (x, 2.08, z), (0.22, 0.08, 0.78), MAT_A1_PANEL_HIGHLIGHT, bevel=0.06, yaw_deg=yaw)
```

- [ ] **Step 4: Update `build_scene()` to call the new edge and surface helpers**

In `build_scene()`, keep the existing call order from Task 4 and insert the new calls exactly like this:

```python
    add_concept_outer_edge_glows()
    add_a1_edge_beacons()
    add_tile_lines()
    add_a1_surface_panels()
    add_center_pickup_pad()
    add_a1_center_pickup_hero()
    add_props()
```

- [ ] **Step 5: Rebuild, import, and run the focused art gate**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/rebuild_open_ringout_blender_visuals.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_blender_visual_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Expected: rebuild succeeds; focused verifier still may fail only for Task 6 depth/prop anchors. It must no longer fail on `A1EdgeBeacon`, `A1SurfacePanel`, `A1BridgeMouthMarker`, or center pickup A1 anchors.

- [ ] **Step 6: Commit edge and surface treatment**

```bash
git add tools/build_open_ringout_blender_visuals.py assets/models/generated/open_ringout_slice/open_ringout_visuals.glb assets/models/generated/open_ringout_slice/open_ringout_visuals.glb.import
git commit -m "feat: add open ringout a1 edge and surface treatment"
```

---

### Task 6: Add Depth Set And Prop Framing

**Files:**
- Modify: `tools/build_open_ringout_blender_visuals.py`
- Update: `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`

- [ ] **Step 1: Add A1 prop framing helper**

Insert before `def build_scene():`:

```python
def add_a1_prop_framing():
    add_vertical_cylinder("A1SkyIslandToyWindmillNE_pole", (61, -5.5, -42), 0.34, 4.2, MAT_A1_CANDY_BLUE, 18)
    add_cube("A1SkyIslandToyWindmillNE_hub", (61, -3.12, -42), (0.80, 0.80, 0.80), MAT_A1_FLAG_WHITE, bevel=0.18)
    add_cube("A1SkyIslandToyWindmillNE_blade_a", (61, -3.12, -42), (0.28, 0.18, 4.60), MAT_A1_FLAG_RED, bevel=0.08, yaw_deg=0)
    add_cube("A1SkyIslandToyWindmillNE_blade_b", (61, -3.12, -42), (4.60, 0.18, 0.28), MAT_A1_FLAG_RED, bevel=0.08, yaw_deg=0)

    add_vertical_cylinder("A1SkyIslandFlagSW_pole", (-58, -5.0, 45), 0.22, 3.6, MAT_A1_FLAG_WHITE, 14)
    add_cube("A1SkyIslandFlagSW_banner", (-56.9, -3.55, 45), (2.6, 1.10, 0.16), MAT_A1_FLAG_RED, bevel=0.10)

    for i, (x, z, material) in enumerate([
        (-52, -28, MAT_A1_CANDY_GREEN),
        (-46, 34, MAT_A1_CANDY_PURPLE),
        (49, -32, MAT_A1_CANDY_BLUE),
        (54, 31, MAT_A1_CANDY_GREEN),
        (-12, -49, MAT_A1_CANDY_PURPLE),
        (18, 52, MAT_A1_CANDY_BLUE),
    ]):
        add_cube(f"A1PerimeterToyBlock_{i}", (x, -5.95, z), (3.2, 2.1, 3.2), material, bevel=0.42, yaw_deg=i * 11)
```

- [ ] **Step 2: Add A1 depth ribbon helper**

Insert below `add_a1_prop_framing()`:

```python
def add_a1_depth_ribbons():
    add_ellipsoid("A1DepthCloudRibbonNorth", (0, -10.55, -70), (72, 1.25, 9.0), MAT_CLOUD_CREAM, 36, 12, -2)
    add_ellipsoid("A1DepthCloudRibbonSouth", (3, -10.58, 70), (74, 1.25, 9.5), MAT_CLOUD_PINK, 36, 12, 2)
    add_cube("A1DepthIslandClusterNW_cliff", (-88, -10.6, -42), (16, 5.6, 10), MAT_DISTANCE_CLIFF, bevel=1.25, yaw_deg=-12)
    add_cube("A1DepthIslandClusterNW_grass", (-88, -7.62, -42), (12.5, 0.38, 7.8), MAT_DISTANCE_GRASS, bevel=0.84, yaw_deg=-12)
    add_cube("A1DepthIslandClusterSE_cliff", (88, -10.7, 48), (17, 5.8, 10), MAT_DISTANCE_CLIFF, bevel=1.25, yaw_deg=10)
    add_cube("A1DepthIslandClusterSE_grass", (88, -7.62, 48), (13.2, 0.38, 7.8), MAT_DISTANCE_GRASS, bevel=0.84, yaw_deg=10)
    for i, (x, y, z, material) in enumerate([
        (-67, -9.1, -23, MAT_ABYSS_GLOW_BLUE),
        (-54, -8.9, 17, MAT_ABYSS_GLOW_WARM),
        (-38, -9.2, -52, MAT_ABYSS_GLOW_BLUE),
        (-20, -8.8, 54, MAT_ABYSS_GLOW_WARM),
        (-3, -9.0, -61, MAT_ABYSS_GLOW_BLUE),
        (14, -8.9, 59, MAT_ABYSS_GLOW_WARM),
        (31, -9.1, -54, MAT_ABYSS_GLOW_BLUE),
        (45, -8.9, 48, MAT_ABYSS_GLOW_WARM),
        (58, -9.2, -25, MAT_ABYSS_GLOW_BLUE),
        (68, -8.8, 12, MAT_ABYSS_GLOW_WARM),
        (-74, -9.0, 5, MAT_ABYSS_GLOW_BLUE),
        (76, -9.1, -2, MAT_ABYSS_GLOW_WARM),
        (-29, -8.7, 3, MAT_ABYSS_GLOW_BLUE),
        (26, -8.7, -6, MAT_ABYSS_GLOW_WARM),
    ]):
        add_ellipsoid(f"A1DepthGlowMote_{i:02d}", (x, y, z), (0.58, 0.58, 0.58), material, 16, 8, i * 17)
```

- [ ] **Step 3: Update `build_scene()` to call prop framing and depth helpers**

In `build_scene()`, keep `add_props()` and `add_background_depth()` for legacy required names, then add the new helpers:

```python
    add_props()
    add_chunky_cover_clusters()
    add_a1_prop_framing()
    add_background_depth()
    add_a1_depth_ribbons()
```

- [ ] **Step 4: Rebuild, import, and run focused verifier**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/rebuild_open_ringout_blender_visuals.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_blender_visual_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Expected: both commands exit `0`; focused verifier prints `[Blender Visual Verifier] PASS`.

- [ ] **Step 5: Run broad Open Ring-Out verifier**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_slice_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Expected: exit code `0`; stdout contains broad Open Ring-Out verifier pass output; no engine/script errors and no leak warnings.

- [ ] **Step 6: Commit depth and prop framing**

```bash
git add tools/build_open_ringout_blender_visuals.py assets/models/generated/open_ringout_slice/open_ringout_visuals.glb assets/models/generated/open_ringout_slice/open_ringout_visuals.glb.import
git commit -m "feat: add open ringout a1 depth and prop framing"
```

---

### Task 7: Extend Broad Regression Gate With High-Value A1 Anchors

**Files:**
- Modify: `scripts/tests/open_ringout_slice_verifier.gd`

- [ ] **Step 1: Add a compact A1 anchor list to the existing Blender visual block**

In `scripts/tests/open_ringout_slice_verifier.gd`, inside the existing `else:` block that already iterates `required_visual`, add these names to that same required array:

```gdscript
			"A1MainDeckOuterSkirtNorth",
			"A1MainDeckOuterSkirtSouth",
			"A1NorthBridgeRouteRailL",
			"A1NorthBridgeRouteRailR",
			"A1CenterPickupRuneOuter",
			"A1SkyIslandToyWindmillNE_pole",
			"A1DepthCloudRibbonNorth",
```

- [ ] **Step 2: Run broad verifier**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_slice_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Expected: exit code `0`; stdout contains pass output; no stderr engine or script errors.

- [ ] **Step 3: Commit broad gate extension**

```bash
git add scripts/tests/open_ringout_slice_verifier.gd
git commit -m "test: lock open ringout a1 visual anchors"
```

---

### Task 8: Capture Screenshot And Write A1 Art Review

**Files:**
- Update: `reports/open_ringout_slice_screenshot.png`
- Create: `docs/workflow/open-ringout-a1-art-review-2026-07-09.md`

- [ ] **Step 1: Capture the staged showcase screenshot**

Prerequisite: this screenshot gate assumes the Open Ring-Out scene/demo baseline and generated visuals from prior tasks are present in the current workspace.

Run:

```powershell
& "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --audio-driver Dummy --path . -s res://scripts/tests/capture_open_ringout_screenshot.gd
```

Expected: exit code `0`; stdout includes `Saved screenshot:` and the resolved path to `reports/open_ringout_slice_screenshot.png`.

- [ ] **Step 2: Visually inspect the screenshot**

Open `reports/open_ringout_slice_screenshot.png` and score these categories from 0 to 5:

- A1 Reference Fidelity
- Composition
- Geometry Language
- Color And Lighting
- Surface Detail
- Depth And Backdrop
- Gameplay Readability
- Screenshot Appeal

Pass only if total is at least 34, no category is below 3, and the listed priority categories are each at least 4.

- [ ] **Step 3: Write the art review document**

Create `docs/workflow/open-ringout-a1-art-review-2026-07-09.md` after visual inspection. The file must contain:

- `# Open Ring-Out A1 Art Review 2026-07-09`
- the screenshot path `reports/open_ringout_slice_screenshot.png`
- a `Decision: PASS` line only when the acceptance bar is met
- a `Total Score: N/40` line with the observed total
- a scores table with the eight categories from Step 2, one observed integer score per row, and one screenshot-specific assessment sentence per row
- exactly three numbered largest-gap lines, each naming a concrete visible gap from the screenshot
- verification lines for the focused Blender visual verifier, broad Open Ring-Out verifier, and screenshot capture

If the decision is not `PASS`, write the observed failing decision and run another visual iteration before committing this task.

- [ ] **Step 4: Commit screenshot review**

```bash
git add reports/open_ringout_slice_screenshot.png docs/workflow/open-ringout-a1-art-review-2026-07-09.md
git commit -m "docs: record open ringout a1 art review"
```

---

### Task 9: Final Verification And Scope Audit

**Files:**
- Verify: `tools/build_open_ringout_blender_visuals.py`
- Verify: `scripts/tests/open_ringout_blender_visual_verifier.gd`
- Verify: `scripts/tests/open_ringout_slice_verifier.gd`
- Verify: `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`
- Verify: `reports/open_ringout_slice_screenshot.png`
- Verify: `docs/workflow/open-ringout-a1-art-review-2026-07-09.md`

- [ ] **Step 1: Run full art pipeline from a clean asset rebuild**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools/rebuild_open_ringout_blender_visuals.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_blender_visual_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_slice_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
& "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --audio-driver Dummy --path . -s res://scripts/tests/capture_open_ringout_screenshot.gd
```

The screenshot command assumes the Open Ring-Out scene/demo baseline and generated visuals from prior tasks are present in the current workspace.

Expected:

- Rebuild/import prints `Generated and imported`.
- Focused verifier prints `[Blender Visual Verifier] PASS`.
- Broad verifier exits `0` and contains pass output.
- Screenshot capture prints `Saved screenshot:`.

- [ ] **Step 2: Audit scope drift**

Run:

```powershell
git diff --stat HEAD
git diff -- scripts/maps/open_ringout_slice.gd scripts/player scripts/weapons scripts/globals scenes/maps/open_ringout_slice.tscn
```

Expected: no gameplay, character, weapon, globals, or scene topology changes appear. If `scripts/maps/open_ringout_slice.gd` appears, the diff is limited to visual anchor loading, visual hiding, or lighting/environment constants.

- [ ] **Step 3: Inspect final git status**

Run:

```powershell
git status --short
```

Expected: only intended A1 art plan outputs are modified or untracked for this pass. Existing unrelated dirty worktree files remain unstaged.

- [ ] **Step 4: Commit final verification note if the review file changed during final inspection**

```bash
git add docs/workflow/open-ringout-a1-art-review-2026-07-09.md reports/open_ringout_slice_screenshot.png
git commit -m "docs: finalize open ringout a1 verification"
```

Run this commit only if Step 1 or Step 2 caused a real review or screenshot change after Task 8.

## Self-Review

Spec coverage:

- A1 toy sky-island identity is covered by Tasks 4, 5, 6, and 8.
- Existing gameplay layout stability is protected by the execution boundary, Task 7 broad verifier, and Task 9 scope audit.
- Blender Python -> GLB -> Godot is covered by Tasks 2, 4, 5, 6, and 9.
- Hero visual asset rebuild is covered by Tasks 3 through 6.
- Automated validation is covered by Tasks 1, 2, 7, and 9.
- Manual screenshot review and 34/40 threshold are covered by Task 8.
- Risk mitigation for collision mismatch, route clutter, glow noise, generated drift, and import stability is covered by the focused verifier, broad verifier, retained legacy node names, non-collision checks, and final scope audit.

Red-flag scan:

- The plan contains exact file paths, exact commands, concrete verifier code, concrete runner code, concrete Blender helper code, and explicit expected outputs.
- The screenshot review step requires real observed scores before commit and blocks completion if the acceptance bar is not met.

Type consistency:

- A1 mesh names required by `open_ringout_blender_visual_verifier.gd` are produced by the Blender helper snippets.
- Legacy mesh names required by `open_ringout_slice_verifier.gd` are preserved by continued calls to `add_platform`, `add_bridge_platform`, `add_center_pickup_pad`, `add_props`, and `add_background_depth`.
- PowerShell runner names match the GDScript verifier paths.
