# Combat Map Feel Loop

## Current Playtest Standard

- Normal movement should feel recoverable. Bridges and connectors should be route bands, not balance beams.
- Falling should mostly come from being pressured, knocked out, or choosing to fight near an edge.
- The pistol should visibly move an AI when shots connect, while shooter recoil should not be a common self-ring-out cause.
- Aim assist should help close and mid-range fights without fully replacing player facing.
- A profile is acceptable for manual playtest when static map verification, Blender visual verification, and a short AI smoke batch all pass.

## Repeatable Loop

1. Record the complaint as one or more causes: aim acquisition, target knockback, shooter recoil, bridge width, spawn safety, weapon pickup pacing.
2. Change only the smallest connected group of variables that can affect that cause.
3. Rebuild the Blender visual layer when map dimensions change.
4. Run `commercial_slice_playtest_preset_verifier`, `commercial_slice_whitebox_verifier`, and `commercial_slice_blender_visual_verifier`.
5. Run a short AI smoke batch and a focused feel tuning batch for the changed profiles.
6. Keep the profile with the best manual-readiness balance, not just the highest ring-out count.

## Feedback I Need After Manual Play

- Which weapon you used and whether you were on center, bridge, or side island.
- Whether a fall was caused by enemy hit, your recoil, normal movement, jump, or unclear collision.
- Whether missed shots felt like wrong facing, too little assist, projectile speed, or target movement.
- Whether a successful pistol hit moved the AI enough, too much, or in a hard-to-read direction.
