# ChaosGun V2 Baseline Manifest 2026-07-10

## Purpose

This manifest separates the reproducible playable Demo baseline from local logs,
temporary design sessions, experiments, and future V2 art-direction work.

The V2 art pass starts from branch `codex/art-vertical-slice-v2`. Existing
Open Ring-Out A1 commits remain the visual and regression baseline; no existing
working-tree change is discarded during consolidation.

## Reproducible Demo Scope

The baseline commit must include these functional groups:

- Existing tracked runtime changes under `scenes/globals`, `scenes/weapons`,
  `scripts/globals`, `scripts/maps`, `scripts/player`, `scripts/ui`, and
  `scripts/weapons`.
- Open Ring-Out, Commercial Slice A, and A1 reference map scenes and scripts.
- Generated bean-character and four toy-weapon GLBs used by the current runtime.
- Curated Kenney GLBs referenced by map dressing.
- Gameplay-feel profiles, visual effects, playtest presets, and their focused
  verifier scripts.
- Blender builders and PowerShell runners required to rebuild the current
  generated visual assets.
- Workflow documentation that explains the Demo baseline and its validation.

## Deliberate Exclusions

The baseline must not include:

- Root Godot stdout/stderr capture files.
- Blender MCP stdout/stderr logs.
- Python bytecode and `tools/__pycache__`.
- `.superpowers` browser/session state and generated brainstorm pages.
- `unity_migration`, which is a separate engine experiment.
- `blender_mcp_addon.py` and local Blender MCP launcher state unless a later
  tools-only change explicitly adopts them.

## V2 Boundary

The current A1 GLB is retained as a playable visual blockout and fallback. V2
does not continue adding decorative primitives to the A1 generator. New visual
work begins only after a paintover direction is approved and will use a modular
Blender source scene plus deterministic export and validation.

## Required Baseline Verification

Run these after the baseline files are staged and before committing:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_blender_visual_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
powershell -ExecutionPolicy Bypass -File scripts/tests/run_open_ringout_slice_verifier.ps1 -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

The branch is considered reproducible only when a fresh checkout contains the
Open Ring-Out scene, its runtime script, all referenced GLBs, and both verifier
runners without relying on untracked files.
