# Twin Bays Splash Arena release checklist

Record each item as PASS, FAIL, or BLOCKED with an evidence path. A FAIL or unreviewed veto item blocks player-facing map routing.

## Current implementation evidence — 2026-07-18

- P23-P27 implementation is present: frozen layout, deterministic dry PBR,
  restrained visual-only environment motion, export-only mesh consolidation,
  and shared match presentation.
- The floor texture is 2K; cyan, dark-cyan, and coral texture families are 1K.
  Each family has deterministic albedo, normal, and roughness maps. Albedo now
  carries display-referred sRGB samples and is decoded once; normal and
  roughness are Non-Color payloads. All 12 PBR maps embedded in the two generated
  GLBs use Basis Universal import (`gltf/embedded_image_handling=2`), resolving
  the earlier approximately `1.28x` relative video-memory ratio (about `77 MiB`
  above Open Ring-Out on the prior Vulkan import path).
- The editable production foreground remains 40 modular meshes and exports as
  7 material batches while retaining 33 semantic anchors.
- Environment limits are `0.12` world-unit float travel, `1.5 degrees` float
  tilt, `2 degrees` palm sway, and `4%` pipe-entry foam/ripple scale variation.
- Shared presentation uses a `1.35 s` reveal, `READY -> GO!`, `0.78 s` winner
  focus, and `22%` HUD opacity during focus.
- Eleven rendered captures exist as the current owner-review candidate set;
  see `docs/art-direction/twin-bays-p23-p27-implementation-review.md`.
- The project owner approved the current art at `34/40`. The dual-authority
  reference sheet is generated from a frozen Godot capture; the original
  concept is Mood Reference Only and cannot override layout geometry.
- **Formal AI PASS:** fixed-seed `8 x 30 s`; armed/kills/ring-out rounds all
  `8/8`, 21 portal events, and zero illegal spawn, NaN/Inf, stuck, ping-pong,
  engine/script error, or shutdown leak findings. Evidence:
  `reports/twin_bays_splash_arena_ai_batch.json`.
- **Formal performance PASS:** Windows D3D12 Forward+, 1080p, matched Open
  Ring-Out run. Twin Bays measured `215.81 FPS` average, `70.60 FPS` 1% low,
  draw-call/primitive/render-memory ratios `0.521/0.235/0.405`, and `1.29 MiB`
  drift. Both processes exited `0` with no leak warning. Evidence:
  `reports/twin_bays_splash_arena_performance.json`.
- **Quick rendered runner PASS:** all `11/11` captures completed and are bound
  in `reports/twin_bays_release_validation.json`. Its exact result is
  `DEVELOPMENT PASS (release gates skipped)`, not RELEASE PASS.
- **Golden status:** no Twin Bays Golden baseline has been established. The 11
  current captures are candidates and must not be promoted without explicit
  owner approval and `--update-baseline`.
- **Remaining release gate:** after owner approval, create the first Golden with
  an explicit update run, then complete a full run without the update flag to
  prove that the baseline remains unchanged.

The complete local gate is release-only and must state why it is being run:

```powershell
.\scripts\tests\run_twin_bays_release_validation.ps1 `
  -GodotPath "E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" `
  -ReleaseCandidate `
  -ReleaseReason "Owner-approved frozen Twin Bays release candidate"
```

The default run includes the fixed-seed AI batch, matched Forward+ benchmark,
and rendered captures. `-Quick` and `-SkipRender` are development-only and
cannot produce release-complete evidence. The current candidate captures are
not Golden. A first Golden may be established only after owner approval by
explicitly including `--update-baseline` (alias of `-UpdateBaseline`). Add
`-RebuildAssets` to regenerate Blender outputs before validation.

The runner enforces the machine-readable
`resources/validation/twin_bays_verification_policy_v1.json`: the same release
fingerprint may fail only twice consecutively, and an exceptional retry must
include both `-OverrideRetryLimit` and `-OverrideReason`. Development changes
must use the smallest relevant gate described in
`docs/workflow/twin-bays-value-scoped-validation.md`; the complete runner is
not a debugging loop.

## Structure and asset integrity

- [ ] Layout JSON schema/version valid; 116 platform points, four wall polylines / six visible wall sections, two mirrored portal pipes, 10 covers, four spawns, four ordinary pickup candidates, one center-special pickup, and two portals; the four corner pillars, four retired inner covers, two south wall sections, and both retired portal wall bodies are absent.
- [ ] Migrated anchors differ from the frozen layout by no more than `0.01` world units.
- [ ] Whitebox-to-production platform mask IoU `>=0.95`, bbox/centroid score `>=0.98`, normalized chamfer `>=0.99`.
- [ ] Visible cream floor covers the complete safe central route.
- [ ] Production foreground and Hero Kit GLBs contain no collision, camera, light, character, weapon, or background.
- [ ] `ForegroundVisuals` and `Backdrop` contain no `CollisionObject3D`, `CollisionShape3D`, or collision-enabled CSG.
- [ ] Every cover center error is `<=16%` of its visible size; collision footprint is `>=72%` of the visual footprint.
- [ ] Whitebox visuals are hidden in production; no doubled art or z-fighting.

## Dry-floor veto

- [ ] No `FloorWetMarks`, `FloorPuddles`, gameplay-floor `Decal`, water-stain texture, puddle mesh, wetness shader parameter/mask, or glossy wet patch.
- [ ] Background water remains below/outside gameplay and collision-free.
- [ ] Portal spray is temporary, depth-tested, and leaves no floor mark.

## Runtime

- [ ] Four characters spawn safely with two viable escape directions each.
- [ ] The four ordinary candidates share at most one SMG/AK/Shotgun and retain the `2.5/10/4 s` pooled schedule; the grounded center point independently spawns at most one Gatling/Sniper on the `0.45/10/17 s` fixed schedule. All five pads remain open and collision-free.
- [ ] Fall costs a life; delayed respawn is grounded, invincible as configured, and restores the base pistol.
- [ ] Result and pause flows work.
- [ ] Left-to-right and right-to-left portal travel land at safe exits, clear dangerous momentum, and respect `0.55 s` anti-ping-pong cooldown.
- [ ] Projectiles and pickups do not trigger portals.
- [ ] The shared party-shooter camera follows live combat, applies dynamic zoom, ignores dead/falling characters, and preserves the approved high-overview framing. On the first frame of a portal traversal it immediately widens the view, keeps tracked characters HUD-safe, and continues smooth focus relocation; this remains safe at `1280x720` and `1920x1080`.
- [ ] The camera profile selects the HUD occluder group, and the director reads every visible `Control`'s actual global rectangle each frame. The legacy duel HUD responds to viewport `size_changed`; all-AI matches with no visible HUD reserve no empty safety region.
- [ ] HUD and map switching work; whitebox is absent from the player map list.
- [ ] Exactly two player-facing maps exist: Open Ring-Out index 0 and Twin Bays index 1; Quick AI rerolls this pool on entry/rematch, while local battle preserves manual selection.

## AI batch (`8 x 30 s`, fixed seeds) — formal PASS

- [x] Zero script/engine errors, illegal spawns, NaNs, portal ping-pong, shutdown leaks, or non-combat stuck states.
- [x] 8/8 rounds have three AI obtain a primary weapon.
- [x] 8/8 rounds contain a kill.
- [x] 8/8 rounds contain a ring-out.
- [x] No first spawn death occurs before 2.0 seconds.
- [x] AI portal use is recorded only (21 events); the AI system was not changed to satisfy this observation.

## Render and human art review

- [x] 1536x1024 empty structure candidate capture.
- [x] 1920x1080 four-character battle candidate capture.
- [x] Portal/background and left/right portal candidate captures.
- [x] 1280x720 candidate capture keeps all spawns, characters, and portals in frame and clear of HUD.
- [x] Ambient-motion start/end, intro READY/GO, and winner-focus candidates complete the 11/11 set.
- [x] Human score is owner-approved at `34/40`, no category below 3; fidelity, party-shooter tone, background, and gameplay readability are each `>=4`.

## Performance and cleanup — formal PASS

- [x] D3D12 Forward+, 1080p, one player + three AI; warmup 10 s and sample 60 s.
- [x] Twin Bays average `215.81 FPS` and 1% low `70.60 FPS`.
- [x] Draw-call, primitive, and render-memory ratios are `0.521`, `0.235`, and `0.405`, each `<=110%` of matched Open Ring-Out.
- [x] Final-tail memory drift is `1.29 MiB`, below `5 MiB`.
- [x] Both paired processes exit `0` with no orphan/leak warning.
- [x] Windows rendering-device driver is Godot 4.6's recommended `d3d12`.
- [x] All 12 embedded PBR maps use Basis Universal; the previous approximately `1.28x` relative video-memory ratio (about `77 MiB` over Open Ring-Out) is resolved.
- [ ] Owner-approved human review, first-Golden hashes, and final no-update full-run record are complete.
- [ ] A Golden was created only with explicit `--update-baseline`, then remained unchanged during a complete rerun without that flag.
