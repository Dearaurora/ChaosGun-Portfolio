# Character Rig V3 Concept Convergence Review

Decision: PRODUCTION VISUAL PASS

## Goal

Move the playable character from the pear-shaped bean silhouette toward the
approved four-view toy astronaut while preserving the existing rig, weapon
contacts, authored motion, runtime recoloring, and gameplay scale.

## Implemented

- Added a non-destructive `hero_character_rig_v3` Blender source and GLB;
  `hero_character_rig_v2` remains available as the rollback asset.
- Rebuilt `HeroCloudBody` as one runtime mesh containing separate helmet,
  collar, and short tunic volumes.
- Raised the tunic hem, narrowed the torso, exposed more of the legs, and kept
  the original overall height and foot contact.
- Recessed the face panel behind a thicker helmet opening and increased the
  warm eye size and saturation.
- Slimmed the sleeves and cuffs, added spine-to-arm shoulder weighting, shaped
  a separate mitten thumb lobe, and softened the boots and soles.
- Added locked-camera proportion compensation at `0.90 × 1.08 × 1.06`, so the
  gameplay silhouette reads narrower and more upright without changing the
  collision body or movement parameters.
- Regenerated the four player-color character portraits and switched runtime
  and release validation paths to the v3 GLB.

## Asset Contract

- Armature: 15 bones.
- Imported meshes: 16.
- Skinned meshes: 13.
- Runtime polygons: 9,856.
- Authored actions: 31.
- All existing production mesh names, material names, weapon poses, locomotion
  clips, and weapon contact targets remain valid.

## Evidence

- `reports/hero_character_rig_v3_reference_comparison.png`
- `reports/hero_character_rig_v3_front.png`
- `reports/hero_character_rig_v3_side.png`
- `reports/hero_character_rig_v3_back.png`
- `reports/hero_character_rig_v3_three_quarter.png`
- `reports/hero_character_rig_v3_pistol.png`
- `reports/hero_character_rig_v3_shotgun.png`
- `reports/hero_character_rig_v3_gatling.png`
- `reports/hero_character_rig_v3_runtime_showcase.png`
- `reports/hero_character_rig_v3_character_select.png`
- `reports/hero_character_rig_v3_gameplay_closeup.png`
- `reports/hero_character_rig_v3_gameplay_proportion_final.png`

## Verification

- Blender GLB round-trip and polygon budget: PASS.
- Six weapon support/trigger contacts and stock seating: PASS.
- Godot skeleton, skin, mesh, and 31-animation import: PASS.
- Weapon readability and torso clearance: PASS.
- Authored locomotion, recoil, hit, and respawn feedback: PASS.
- Character material and player-color runtime profiles: PASS.
- Open Ring-Out gameplay integration: PASS.
