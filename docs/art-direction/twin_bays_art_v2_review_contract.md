# Twin Bays Art V2 review contract

Status: `candidate_pending_human_approval`

This review migrates Twin Bays from the historical dry-floor art direction to a controlled,
interactive extremely shallow-water treatment. The current Godot scene and
`resources/maps/twin_bays_layout_v1.json` remain the only structure, collision, camera,
portal, spawn, pickup, and combat authorities. The original concept image is mood-only.

## Hard gates

- `resources/maps/twin_bays_art_v2.json` is bound to the exact current layout SHA-256.
- `-HeroReviewOnly` writes only Art V2 review outputs. It hashes the production Blend,
  production foreground GLB, production Hero GLB, production manifest, and production
  previews before and after the build, and fails if any byte changes.
- The review manifest sets `golden_update_allowed=false` and
  `production_foreground_overwritten=false`.
- Full production rollout and Golden updates are blocked until explicit human approval of
  the Godot review captures.
- Each pool has three deterministic, visual-only static mesh batches: a translucent wet
  bed, a water surface raised 0.012 units, and a narrow meniscus/wet edge. Runtime shaders
  add low-amplitude world-space highlights without screen reflection or Decal projection.
- `TwinBaysShallowWater` owns fixed ripple, wet-footprint, splash-particle, and audio pools.
  It queries the same polygons directly and creates no collision, Area, or navigation node.
- Character physics, friction, damping, knockback, jump, AI, damage, and weapon values are
  unchanged. The provider only replaces a footstep sound/effect when it handles water or
  one of the three post-exit wet steps.

## Automated art contract

- Production target: 8-12 major clusters; this candidate uses 10 plus 12 small droplets.
- Coverage: 12%-18% of the visible platform.
- Minimum clean radii: ordinary pickup 2.5, special pickup 3.5, spawn 2.5, portal exit 2.5.
- Cover footprints are expanded by 0.5 and lethal/platform edges by 1.0.
- All mark polygons must stay inside the production platform and outside every clean zone.
- The exported review GLB contains no camera, light, armature, or collision authority.
- Runtime feedback is capped at 32 ripple instances, 24 footprint instances, 12 audio
  players, and 24 projectile-water events per second. Same-cell shotgun/Gatling feedback
  is throttled for 0.06 seconds.
- Five deterministic one-shot SFX are generated locally: three steps, one landing splash,
  and one projectile plip. There is no continuous water ambience.

## Reproduce the review

```powershell
./tools/rebuild_twin_bays_splash_arena.ps1 -HeroReviewOnly -ImportGodot -GodotExe <godot-console-exe>
<godot-console-exe> --headless --path . --script res://scripts/tests/twin_bays_shallow_water_verifier.gd
<godot-exe> --path . --script res://scripts/tests/capture_twin_bays_splash_arena.gd -- --mode=art_v2_water_static
<godot-exe> --path . --script res://scripts/tests/capture_twin_bays_splash_arena.gd -- --mode=art_v2_water_steps
<godot-exe> --path . --script res://scripts/tests/capture_twin_bays_splash_arena.gd -- --mode=art_v2_water_landing
<godot-exe> --path . --script res://scripts/tests/capture_twin_bays_splash_arena.gd -- --mode=art_v2_water_exit
<godot-exe> --path . --script res://scripts/tests/capture_twin_bays_splash_arena.gd -- --mode=art_v2_water_projectiles
```

The static frame checks tile visibility, water thickness, meniscus, and clean gameplay
anchors. The four dynamic frames cover water steps, two landing strengths, exactly three
post-exit footprints, and all six weapon families. Every frame uses the production Twin
Bays camera direction, lighting, character rigs, and shared weapon assets. These files are
review evidence only and are not Golden baselines.
