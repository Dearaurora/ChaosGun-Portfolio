# Commercial Slice A Whitebox Rebuild V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild `Commercial Slice A` into a larger medium-connectivity multi-island whitebox arena without breaking the shared runtime used by other maps.

**Architecture:** Keep combat orchestration in the shared arena runtime script, then add overridable hooks for layout, dressing, and spawn points. Implement the new `Commercial Slice A` topology in its own map script so whitebox iteration stays isolated from the other scenes.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scene files, workflow docs in `docs/workflow/`

---

### Task 1: Add The Implementation Scaffold

**Files:**
- Create: `docs/workflow/commercial-slice-a-implementation-plan-v1.md`
- Modify: `docs/workflow/commercial-slice-a-task-card-v1.md`

- [ ] **Step 1: Record the whitebox implementation scope**

Add a note to the task card clarifying that this pass must isolate `Commercial Slice A` from the shared runtime before whitebox layout changes land.

- [ ] **Step 2: Keep the pass limited to whitebox**

Do not add final art dressing, final lighting, or advanced asymmetrical experimentation in this pass.

### Task 2: Make The Shared Arena Runtime Overridable

**Files:**
- Modify: `scripts/maps/battle_arena.gd`

- [ ] **Step 1: Add hook methods for layout, dressing, and spawn points**

Introduce overridable methods such as:

```gdscript
func _build_map_layout() -> void:
	_build_kaykit_floor()

func _build_map_dressing() -> void:
	_build_external_art_dressing()

func _get_spawn_points() -> Array:
	return DEFAULT_SPAWN_POINTS
```

- [ ] **Step 2: Update `_ready()` and character spawn flow to use those hooks**

The shared runtime should keep the same default behavior for existing maps while allowing scene-specific subclasses to replace only the map-building logic.

- [ ] **Step 3: Add a whitebox primitive helper**

Introduce a helper that can spawn a plain box platform with mesh and collision without depending on external art assets.

### Task 3: Implement Commercial Slice A Whitebox Layout

**Files:**
- Create: `scripts/maps/commercial_slice_a.gd`
- Modify: `scenes/maps/commercial_slice_a.tscn`

- [ ] **Step 1: Add a scene-specific script**

Create a script that extends the shared arena runtime and overrides:

```gdscript
func _build_map_layout() -> void
func _build_map_dressing() -> void
func _get_spawn_points() -> Array
```

- [ ] **Step 2: Build the multi-island whitebox topology**

Implement:
- one center island
- four side islands
- four main bridges
- four secondary bridges
- clear lethal gaps
- light whitebox-only cover pieces

- [ ] **Step 3: Disable heavy dressing for this whitebox pass**

Keep the scene readable and plain. Remove or ignore pre-authored commercial dressing while the pass is still in whitebox.

- [ ] **Step 4: Point the scene to the new script**

Update `commercial_slice_a.tscn` so this map uses the new scene-specific whitebox generator instead of the shared default script.

### Task 4: Static Verification And Handoff

**Files:**
- Modify: `docs/workflow/commercial-slice-a-validation-v1.md`

- [ ] **Step 1: Check script wiring statically**

Confirm that:
- `commercial_slice_a.tscn` references the scene-specific script
- the shared runtime still provides defaults
- the whitebox script is isolated to this map

- [ ] **Step 2: Record verification limits**

If no local Godot CLI is available, note that runtime execution remains unverified and leave the whitebox validation checklist ready for the next playable pass.
