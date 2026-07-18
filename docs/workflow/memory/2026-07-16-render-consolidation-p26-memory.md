# Render Consolidation P26 Memory Capsule

- Decision: P26 approved. Export-only static batching and shared combat visual
  resources preserve the approved image while materially improving frame pacing.
- Editable-source invariant: the Blender source remains unbatched; only the GLB
  export is consolidated.
- Preservation invariant: verifier-required names, dynamic landmark prefixes,
  all edge gems, two windmill rotors, ten clouds, and the complete balloon stay
  individually addressable.
- Render result: V2 export meshes `814 -> 222`; visible surfaces `756 -> 164`;
  combat-sample draw calls approximately `1,661 -> 939`.
- Runtime result: 60 focused seconds at 1920x1080 measured `225.37 FPS` average,
  `72.36 FPS` one-percent low, `8.03 ms` p99, zero frames above 33.33 ms,
  `1.84 MiB` memory drift, and zero orphan-node delta.
- Allocation result: repeated muzzle, tracer, projectile, and impact instances
  share immutable resources; projectile and tracer visuals build once per shot.
- Projectile invariant: all weapons use the approved warm-yellow shell,
  warm-white core, round leading cap, tapered rear, and connected short wake.
  Weapon color remains limited to muzzle and impact identification.
- Evidence: `reports/p26_final_start.png`, `reports/p26_final_end.png`, and
  `reports/p26_open_ringout_performance_focus_filtered_final.json`.
- Verification: 14/14 P25-P26 visual, structural, camera, weapon, and effect
  regressions PASS.
- Rejected direction: additional batching of moving P14 groups or removal of
  legacy warning/background pieces. Their remaining cost is small relative to
  the risk of breaking the approved composition.
- Next priority: P27 match-presentation choreography: arena reveal, spawn-in,
  round-start, and winner focus.
