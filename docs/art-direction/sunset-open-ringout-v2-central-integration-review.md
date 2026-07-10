# Sunset Open Ring-Out V2 Central Integration Review

Gameplay screenshot: `reports/open_ringout_slice_sunset_v3_screenshot.png`

Selected reference: `docs/art-direction/references/sunset-toy-sky-islands-selected.png`

Blender source: `assets/source/sunset_toy_sky_islands/open_ringout_v2_preview.blend`

Generated GLB: `assets/models/generated/sunset_toy_sky_islands/open_ringout_v2_preview.glb`

Decision: RUNTIME STRUCTURE PASS / CONCEPT-QUALITY HOLD

## Review

| Category | Score | Assessment |
| --- | ---: | --- |
| Gameplay Alignment | 5/5 | The V2 shell follows the existing central footprint and east bridge without changing collision, spawns, covers, or pickup positions. |
| Direction Fit | 3/5 | The rounded orange deck and plum cliff move toward the reference, but the asset density and authored surface character remain well below it. |
| Surface Readability | 2/5 | Broad panels and seams are readable, but the surface is still materially flat and lacks production-quality wood, edge wear, and controlled variation. |
| Bridge Language | 3/5 | Individual planks, support beams, fasteners, posts, and cyan caps read clearly, but the bridge remains a first-pass modular asset. |
| Combat Readability | 5/5 | Player colors, weapons, covers, center pickup, HUD, and hit effects remain visually dominant over the environment. |
| Runtime Integration | 5/5 | The visual-only GLB is loaded under a dedicated root; replaced A1 meshes remain available but hidden for reversible iteration. |
| Full-Map Coherence | 1/5 | The four side islands, three unreplaced bridges, and most props still use A1 materials and geometry. |

Total: 24/35

## Approved For Expansion

- Central platform layered shell: orange panel top, warm side band, and tapered plum cliff.
- Broad modular panel variation instead of a uniform floor color.
- Wooden bridge planks with restrained alternating tones and cyan endpoint markers.
- Visual-only replacement architecture that leaves gameplay collision authoritative.

These items are approved as technical modules, not as final-quality art assets.

## Held Back

- The north, south, and west bridges remain A1 and must be rebuilt from the approved east-bridge module.
- All four side islands remain A1 and need the same top, band, cliff, and edge-detail hierarchy.
- Current covers are readable but still belong to the earlier asset generation; they need a separate prop-family pass.
- Backdrop clouds, distant islands, and world lighting have not yet received the final sunset composition pass.

## Verification

- Sunset Open Ring-Out V2 integration verifier: PASS.
- Open Ring-Out broad gameplay verifier: PASS.
- Open Ring-Out A1 Blender visual verifier: PASS, 554 mesh instances and 51 materials.
- Render-capable gameplay screenshot review at 1536 x 960: PASS for height, overlap, bridge connection, and combat readability.
- Legacy A1 center halos, burst ticks, and duplicate yellow edge beacons are hidden;
  the center pickup now uses only the grounded runtime marker.

The next environment step should propagate the approved shell to the four side
islands and remaining bridges. It should keep the current collision and map
coordinates as authority, then perform a single full-map palette and lighting
normalization pass after all five islands share one asset generation.
