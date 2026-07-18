# Render Consolidation P26 Review

Decision: PASS

## Goal

Reduce the approved Open Ring-Out arena's render overhead and repeated combat
effect allocation without changing its composition, materials, ambient motion,
collision, weapon balance, or camera framing.

## Implemented

- Kept the editable Blender source unbatched and applied static batching only to
  the exported GLB.
- Parsed the integration verifier as a preservation contract. Named landmarks,
  windmill rotors, clouds, the complete balloon, edge gems, barrels, tree
  trunks, and gameplay-inspected meshes remain individually addressable.
- Joined compatible static single-material meshes into 32 export batches.
- Added a finite shared resource cache for immutable combat meshes and
  materials.
- Removed duplicate construction of every spawned projectile and shot tracer.
- Preserved the P25 runtime motion contract: two rotors, one balloon assembly,
  ten cloud origins, 22 edge gems, and state-driven pedestal lights.
- Folded the approved yellow-white teardrop projectile correction into the same
  shared-resource path. It does not restore per-shot mesh or material creation.

## Render Cost

- V2 source meshes: `814` editable meshes.
- V2 export meshes: `222` meshes (`-72.7%`).
- V2 visible surface proxy: `756 -> 164` (`-78.3%`).
- P25 baseline average draw calls: approximately `1,661`.
- P26 final average draw calls: `938.9` (`-43.5%`) during a four-character
  combat sample.
- Shared combat cache verification: `11` meshes and `10` materials for the
  tested repeated effect set; duplicate instances reference the same resources.

## Frame Pacing

The final sample used Forward+, Vulkan, 1920x1080, one human plus three AI,
VSync disabled, a ten-second warmup, and 60 focused sample seconds.

- Average: `225.37 FPS` (`+80.6%` from the P25 baseline).
- One-percent low: `72.36 FPS` (`+246.6%` from the P25 baseline).
- Frame-time p95: `6.12 ms`.
- Frame-time p99: `8.03 ms`.
- Frame-time p99.9: `18.22 ms`.
- Maximum frame: `27.44 ms`.
- Frames above 33.33 ms: `0`.
- Static-memory drift: `1.84 MiB`.
- Orphan-node delta: `0`.
- Focus interruptions and rejected focus frames: `0`.

Report: `reports/p26_open_ringout_performance_focus_filtered_final.json`.

## Visual Preservation

- The first post-batch pixel comparison measured `0.132 / 255` mean absolute
  channel error against the P25 frame; 95% of channels were identical.
- Final fixed-camera evidence:
  - `reports/p26_final_start.png`
  - `reports/p26_final_end.png`
- Yellow-white projectile evidence:
  - `reports/projectile_teardrop_showcase_v3.png`
  - `reports/projectile_teardrop_gameplay_final.png`

No missing material, broken normal, detached landmark, bridge regression, or
ambient-motion regression is visible in the final evidence.

## Verification

- P26 technical-art regression: 14/14 PASS.
- V2 render-cost and named-node preservation: PASS.
- P14 background and P25 ambient motion: PASS.
- Map topology, bridge surfaces, collision, camera, respawn, and pickups: PASS.
- Weapon pedestal, six-weapon projectile, tracer, muzzle, and hit language: PASS.
- Formal 60-second performance gate: PASS.

## Next

P27 should target match presentation rather than more static prop density:

1. a short arena reveal that settles into the runtime camera;
2. coherent character spawn-in choreography using player colors;
3. a restrained round-start cue that does not block combat;
4. a round-end focus and winner beat before the result screen.

This has higher player-visible value than further mesh consolidation or minor
background decoration.
