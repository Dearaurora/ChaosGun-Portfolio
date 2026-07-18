# Twin Bays Splash Arena production specification

Status: active  
Layout schema: `chaos_gun.twin_bays_layout` v1  
Production scene: `res://scenes/maps/twin_bays_splash_arena.tscn`  
Development scene: `res://scenes/maps/twin_bays_whitebox.tscn`

## Product scope

Ship the validated Twin Bays whitebox as the second player-selectable party-shooter map. The player-facing pool contains exactly Open Ring-Out at index 0 and Twin Bays at index 1. Quick AI randomly selects from those two maps on initial entry and every rematch; local battle preserves the player's manual selection. Characters, skeletons, grips, weapons, weapon values, and combat audiovisual language stay on the shared `party_shooter_v1` system.

## Ownership boundaries

- `res://resources/maps/twin_bays_layout_v1.json` is the single coordinate source for Godot and Blender.
- The current Godot production scene and versioned as-built reference own
  structure, camera, and composition. The original water-park concept is Mood
  Reference Only and owns palette/material/background tone, never geometry.
- `Gameplay` owns all collisions, spawn/pickup scheduling, lethal-fall behavior, and integration with the shared party-shooter camera director.
- `ForegroundVisuals` owns production platform, walls, mirrored water pipes, covers, pads, and trim; it has no collision.
- `Backdrop` owns collision-free water, caustics, and peripheral low-poly scenery.
- `Portals` owns character-only trigger areas, paired exits, and temporary portal visuals.
- Imported GLBs own no collision, camera, light, character, weapon, or background.

## Frozen gameplay semantics

- Four safe spawns, four open ordinary-weapon candidates sharing one active weapon, and one fixed center-special point restricted to Gatling/Sniper.
- Four lives; delayed respawn and base-sidearm restoration use the shared runtime path.
- Falling below the map threshold costs a life. Water has no collision, swim, or bounce behavior.
- Portals use `TwinBaysPortal.configure_pair()`, `0.55 s` cooldown, inward exits, cleared linear/angular velocity, and character-only filtering.
- Projectiles and pickups do not traverse portals.
- Twin Bays uses the shared party-shooter camera contract: follow living combatants, apply dynamic zoom, ignore dead/falling actors, and preserve the approved high-overview framing. On the first frame of a portal traversal the camera immediately widens the view and keeps tracked actors HUD-safe while its focus continues to relocate smoothly. The camera profile selects the HUD occluder group, and the director reads every visible `Control`'s actual global rectangle each frame; the legacy duel HUD responds to viewport `size_changed`, while all-AI matches with no visible HUD reserve no empty safety region.
- Quick AI and local battle are explicit match modes. Every restart surface delegates to `MatchConfig.restart_current_match()` so Quick AI rerolls the two-map pool while local battle reloads the selected map.

## Asset outputs

- Deterministic Blender builder and rebuild wrapper.
- Source `.blend`, Hero Kit GLB, production foreground GLB, preview, and material/node manifest.
- At most 12 primary materials, with stable semantic anchors for platform, six wall sections/pipes, 10 covers, four ordinary pickup pads, one center-special pad, and two portal pipe mouths.

## P23-P28 implementation and validation record

- P23: the layout remains frozen at SHA-256
  `ea69b591ae88df766967596a18dacbcaff047c07e65b41fc008330f5e94a0227`;
  subsequent art and presentation work did not alter gameplay coordinates.
- P24: the deterministic builder produces a 2K dry-cream floor set and 1K
  cyan, dark-cyan, and coral sets, each with albedo, normal, and roughness. The
  albedo image payload uses display-referred sRGB and is decoded exactly once;
  normal and roughness use Non-Color data. All 12 PBR maps embedded in the
  generated GLBs use Basis Universal import. Wet gameplay-floor visuals remain
  a veto and are absent.
- P25: visual-only environmental motion is capped at `0.12` world units and
  `1.5 degrees` for floats, `2 degrees` for palms, and `4%` scale variation for
  pipe-entry foam/ripples.
- P26: the editable `.blend` remains modular. Static meshes are batched by
  material only for GLB export; production foreground changes from `40` source
  meshes to `7` exported meshes while preserving 33 semantic anchors.
- P27: the two maps share `PartyShooterMatchPresentation` through
  `configure(...)`, `start_intro()`, `present_result(...)`, and
  `get_debug_state()`. Common timing is a `1.35 s` reveal, `READY -> GO!`, a
  `0.78 s` winner focus, and `22%` HUD opacity during focus.
- P28 formal AI: fixed-seed `8 x 30 s` PASS with armed/kills/ring-out rounds
  all `8/8`, 21 portal events, and zero illegal spawn, NaN/Inf, stuck,
  ping-pong, engine/script error, or shutdown leak findings.
- P28 formal performance: D3D12 Forward+ 1080p PASS. Twin Bays measured
  `215.81 FPS` average, `70.60 FPS` 1% low, `0.521/0.235/0.405`
  draw-call/primitive/render-memory ratios, and `1.29 MiB` drift; both paired
  processes exited `0` without leak warnings.
- P28 rendered development runner: Quick mode passed with all `11/11`
  screenshots. The captures are owner-review candidates, not Golden.
- No Golden baseline has been established as of `2026-07-18`. RELEASE PASS
  remains gated on owner art approval, an explicit first-baseline update, and a
  complete no-update rerun proving that the Golden remains unchanged.

## Release gates

1. Layout migration: critical coordinates within `0.01` world units; ground/void ray samples unchanged.
2. Gameplay: spawn, two-way escape, pickup, fall, respawn, pistol reset, result, pause, and portal behavior pass.
3. Shared camera: follow, dynamic zoom, dead/falling exclusion, first-frame portal widening, smooth focus relocation, and profile-driven HUD-safe framing pass the dedicated Twin Bays camera verifier.
4. Hero Kit and one-sided in-camera integration receive human approval before full-map art.
5. Structure: mask IoU `>= 0.95`, bbox/centroid `>= 0.98`, normalized chamfer `>= 0.99` against executable whitebox.
6. Collision: cover center error `<= 16%` of visual size and collision footprint `>= 72%`; visual/backdrop GLBs have no collision.
7. Dry floor: any forbidden wet-floor artifact vetoes release.
8. Runtime, AI batch, screenshots, art review, and performance meet the validation checklist.
9. Only after all gates pass may the production scene become `MatchConfig.MAPS[1]`.

## Tool and baseline record

- Godot: `4.6.2.stable.official.71f334935`
- Windows rendering-device driver: `d3d12` (Godot 4.6 recommended driver).
- Blender: `5.1.1` (build `2026-04-14`)
- Baseline date: `2026-07-16`
- Runtime texture import: both generated GLBs use
  `gltf/embedded_image_handling=2` for their 12 embedded PBR maps (Basis
  Universal). This resolves the earlier approximately `1.28x` relative
  video-memory ratio (about `77 MiB` above Open Ring-Out on the prior Vulkan
  import path); the formal Twin Bays render-memory proxy is about `457 MiB`.
- Current evidence: `reports/twin_bays_splash_arena_ai_batch.json`,
  `reports/twin_bays_splash_arena_performance.json`, and
  `reports/twin_bays_release_validation.json`.
- Golden status: not created; baseline date above refers to the original
  whitebox/reference freeze, not a rendered Twin Bays Golden.
- Whitebox verifier: PASS before production migration — 116 outline points / 114 triangles, four curved wall strips, visible causeway `12.4`, safety width `16.0`, four grounded spawns, two open voids, four collision-free pickup markers, paired vertical portals, safe exits, bidirectional runtime teleport, cooldown, and cleared momentum.
