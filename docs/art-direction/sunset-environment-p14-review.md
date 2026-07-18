# Sunset Environment P14 Review

Decision: ENVIRONMENT PRODUCTION PASS / P15 NOT STARTED

## Goal

Close the remaining environment work identified after P8: replace provisional
flat/geometric cloud banks, introduce limited distant landmark variants, and
perform the final lighting and color grade after the production character
materials were integrated.

## Implemented

- Added a reproducible Blender environment layer:
  `p14_sunset_environment.blend` and `p14_sunset_environment.glb`.
- Built ten authored cloud banks from deliberately arranged soft puffs. Each
  six-puff bank is joined into one mesh after authoring, preserving the lobed
  silhouette while reducing cloud draw nodes from 60 to 10.
- Added four rounded distant floating islands positioned from measured runtime
  screen projections rather than Blender-only framing.
- Varied the distant landmarks with a windmill, tree groups, and a beacon while
  keeping their scale subordinate to the playable islands.
- Rebuilt the hot-air balloon as a production P14 asset: alternating integrated
  envelope panels, surface-following gold seams, four angled suspension ropes,
  burner, tapered basket, rim, base, and basket bands replace the old stacked
  ellipsoid construction.
- Re-composed the right background from measured 1536x960 runtime projections:
  the cream cloud now sits below and clear of the playable island silhouette,
  the fourth distant island occupies a top-row safe slot, and the balloon keeps
  an isolated silhouette outside the HUD and playable route.
- Promoted the playable-island landmarks from visual-only meshes to gameplay
  obstacles with visual-aligned static collision: the north windmill, three
  south barrels, west tire stack, and both east trees now block characters and
  projectiles without sealing the gaps between individual props.
- Hid the old flat cloud planes, glow motes, duplicated V2 clouds, and duplicated
  distant islands only after the P14 GLB loads successfully. The abyss gradient
  remains as a fallback depth field.
- Rebalanced the final scene around a warm key and cool shadow fill: lower key
  energy and exposure, lavender ambient light, stronger blue rim separation,
  restrained saturation, lighter fog, and controlled glow.
- Kept the accepted playable islands, bridge topology, covers, collision, camera,
  weapon spawns, and HUD unchanged.

## Asset Metrics

- Runtime mesh nodes: 80.
- Authored cloud-bank meshes: 10.
- Distant floating islands: 4.
- Authored hot-air balloon parts: 14.
- Runtime polygons: 27,002.
- GLB size: 1.38 MB.
- Cloud materials: PBR, roughness 0.98-0.99.

## Evidence

- `reports/open_ringout_p14_environment_final.png`
- `reports/open_ringout_p14_environment_optimized.png`
- `reports/open_ringout_p14_cloud_balloon_final.png`
- `reports/open_ringout_p14_cloud_balloon_closeup.png`
- `reports/character_weapon_p13_showcase.png`
- `reports/character_weapon_p13_heavy_showcase.png`

## Verification

- Blender source structure, polygon budget, and cloud materials: PASS.
- Godot import and P14 runtime integration: PASS.
- Ten optimized cloud banks, four distant islands, and the segmented balloon: PASS.
- Old flat clouds, glow motes, duplicate islands, and V3 balloon effectively hidden: PASS.
- Seven foreground landmark proxies passed both size/alignment checks and
  chest-height runtime physics-ray hits: PASS.
- Warm-key/cool-shadow grade ranges: PASS.
- Full Open Ring-Out gameplay structure and ring-out respawn: PASS.
- Dynamic camera and four-HUD fit: PASS.

## Closure

P14 is complete. The frame now contains four depth levels: playable islands,
volumetric-looking cloud banks, landmark-varied distant islands, and an authored
segmented hot-air balloon. P15 remains a separate full-frame commercial closure
pass and has not been claimed here.
