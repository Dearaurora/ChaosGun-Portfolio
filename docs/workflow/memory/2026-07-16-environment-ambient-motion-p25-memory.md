# Environment Ambient Motion P25 Memory Capsule

- Decision: P25 approved. The arena now has restrained ambient motion at the
  hero landmark, distant background, edge-light, and weapon-spawn layers.
- Invariants: no gameplay collision, spawn position, camera behavior, combat
  tuning, floor material, character scale, or P14 grade changes.
- Runtime contract: two windmill pivots, one complete balloon pivot, ten cloud
  origins composed with P14 parallax, 22 phased edge gems, and pedestal lights
  driven by spawn state.
- Evidence: `reports/p25_ambient_motion_start.png` and
  `reports/p25_ambient_motion_end.png` from one fixed-camera render process.
- Automated gate: `scripts/tests/environment_ambient_motion_verifier.gd`
  advances the controller by one deterministic second and checks transform
  deltas plus visual-only collision constraints.
- Supporting gate: `scripts/tests/weapon_spawn_visual_verifier.gd` verifies
  the pedestal light positions match their exposed orbit phase.
- Verification: 10/10 P25 regression PASS, including the 18-second four-AI
  smoke test.
- Rejected direction: stronger motion, more particles, and additional static
  props. These would compete with combat readability for little visual gain.
- Performance risk: the post-P25 paired sampler measured `124.77 FPS` average
  but `20.88 FPS` one-percent low and about `1,661` draw calls on Open Ring-Out.
  The sampler had no engine/script errors, but the frame-time spikes require a
  dedicated technical-art pass.
- Next priority: P26 render consolidation and frame-pacing diagnosis while
  preserving the approved image, followed by match presentation and HUD
  cohesion.
