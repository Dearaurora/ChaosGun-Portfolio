# Twin Bays P23-P28 implementation review

Review date: `2026-07-18`  
Scope: implementation evidence only  
Decision: `OWNER ART APPROVED / AUTOMATED RELEASE CLOSURE IN PROGRESS`

This record closes P23-P27 implementation and records the current P28 automated
evidence. The project owner's subjective approval and finalized `34/40` art
score were recorded on `2026-07-18`. A Golden baseline and final RELEASE PASS
still require the explicit update run followed by a complete no-update rerun.

## P23 — frozen structure

- `resources/maps/twin_bays_layout_v1.json` remains the gameplay authority and
  was not changed by P24-P27.
- Frozen layout SHA-256:
  `ea69b591ae88df766967596a18dacbcaff047c07e65b41fc008330f5e94a0227`.
- Surface, light, backdrop, export, and presentation work preserves the current
  platform, walls, portal pipes, 10 covers, four ordinary pickup candidates,
  center-special pickup, four spawns, and paired portal coordinates.

## P24 — deterministic dry PBR surfaces

- The builder deterministically generates albedo, tangent normal, and roughness
  maps for four surface families.
- The dry cream floor uses `2048 x 2048`; cyan wall, dark-cyan structural side,
  and coral soft-cap families use `1024 x 1024`.
- The albedo payload fix stores display-referred sRGB samples and marks the image
  as `sRGB`, so the image node performs the sRGB-to-linear conversion exactly
  once. Normal and roughness payloads remain `Non-Color`.
- The two generated GLB import contracts use
  `gltf/embedded_image_handling=2`, importing all 12 embedded PBR maps as Basis
  Universal. This resolves the earlier approximately `1.28x` relative
  video-memory ratio (about `77 MiB` above Open Ring-Out on the prior Vulkan
  import path).
- The gameplay floor remains dry. No puddle, wet-mark Decal, wetness mask,
  water-stain texture, standing-water gloss, or floor-water mesh was added.
- Generated texture paths, per-map hashes, resolutions, and surface roles are
  recorded in
  `assets/models/generated/twin_bays_splash_arena/twin_bays_splash_arena_manifest.json`.

## P25 — restrained visual-only environment motion

- Four inflatable rings and 20 buoys use deterministic, out-of-phase motion:
  vertical travel is capped at `0.12` world units and tilt at `1.5 degrees`.
- Eight palms sway no more than `2 degrees`.
- Pipe-entry foam and ripple scale varies no more than `4%`.
- Every moving object is visual-only; water remains below the gameplay plane,
  and no motion changes collision, portal exits, pickups, spawns, or camera
  targets.
- Automated contract:
  `scripts/tests/twin_bays_environment_ambient_motion_verifier.gd`.

## P26 — modular source and export-only consolidation

- The editable `.blend` remains modular and unbatched.
- Static meshes are joined by material only in the in-memory export stage; the
  production foreground GLB contains `7` meshes versus `40` editable-source
  meshes, an `82.5%` reduction.
- The Hero Kit similarly records `14 -> 8` meshes.
- All `33` production semantic anchors remain available for alignment checks.
- Foreground and backdrop art remain visual-only and do not own gameplay
  collision, cameras, lights, characters, or weapons.

## P27 — shared match presentation

- `PartyShooterMatchPresentation` is map-independent and exposes:
  - `configure(arena, camera_director, characters, profile)`
  - `start_intro()`
  - `present_result(winner, winner_color)`
  - `get_debug_state()`
- The common contract is a `1.35 s` arena reveal, player-color spawn emphasis,
  `READY -> GO!`, a `0.78 s` winner-focus hold, and HUD opacity reduced to
  `22%` during result focus.
- Open Ring-Out uses its compatibility wrapper; Twin Bays supplies only its own
  framing/profile and does not add a map-specific water-splash presentation.

## P28 — automated evidence now passed

- Formal fixed-seed AI `8 x 30 s`: PASS. Armed, kill, and ring-out rounds are
  all `8/8`; 21 portal events were observed; illegal spawn, NaN/Inf, stuck,
  ping-pong, engine/script error, and shutdown leak counts are zero.
- Formal matched performance: PASS under Windows D3D12 Forward+ at 1080p. Twin
  Bays measured `215.81 FPS` average, `70.60 FPS` 1% low,
  `0.521/0.235/0.405` draw-call/primitive/render-memory ratios, and `1.29 MiB`
  drift. Both map processes exited `0` without leak warnings.
- Windows `project.godot` now selects Godot 4.6's recommended `d3d12`
  rendering-device driver.
- The Quick rendered runner completed with all `11/11` candidate images. Its
  evidence result is `DEVELOPMENT PASS (release gates skipped)` because Quick
  mode is not a release-complete invocation.
- Evidence:
  - `reports/twin_bays_splash_arena_ai_batch.json`
  - `reports/twin_bays_splash_arena_performance.json`
  - `reports/twin_bays_release_validation.json`

## Owner-review candidate set

The following 11 captures are candidates, not Golden files:

1. `reports/twin_bays_splash_arena_empty_1536x1024.png`
2. `reports/twin_bays_splash_arena_battle_1920x1080.png`
3. `reports/twin_bays_splash_arena_portal_1920x1080.png`
4. `reports/twin_bays_splash_arena_left_portal_1024.png`
5. `reports/twin_bays_splash_arena_right_portal_1024.png`
6. `reports/twin_bays_splash_arena_mobile_1280x720.png`
7. `reports/twin_bays_splash_arena_ambient_start_1536x1024.png`
8. `reports/twin_bays_splash_arena_ambient_end_1536x1024.png`
9. `reports/twin_bays_splash_arena_intro_ready_1920x1080.png`
10. `reports/twin_bays_splash_arena_intro_go_1920x1080.png`
11. `reports/twin_bays_splash_arena_winner_1920x1080.png`

## Remaining gate

- Project-owner art review is approved at `34/40`.
- The dual-authority as-built reference sheet and manifest are bound to layout
  SHA-256 `ea69b591ae88df766967596a18dacbcaff047c07e65b41fc008330f5e94a0227`;
  the original concept is Mood Reference Only.
- No Twin Bays Golden baseline has been established.
- After owner approval, the first Golden must be created through an explicit
  update-baseline run. A complete second run without the update flag must then
  prove that the baseline is not silently replaced.
- Final RELEASE PASS is intentionally not claimed before those two steps.
