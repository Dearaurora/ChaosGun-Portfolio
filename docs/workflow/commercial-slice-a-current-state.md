# Commercial Slice A Current State

Last updated: 2026-04-26

## Target

Commercial Slice A is a top-down, fixed-camera arena inspired by the readability and rhythm of Boomerang Fu:

- A large central grass island with four side islands.
- Every island remains connected by readable roads and bridges.
- Gaps between islands stay wide enough to create real cliff/ring-out risk.
- Combat pacing should favor quick re-engagement, route choice, and recoverable mistakes.
- The visual direction is soft, toy-like, pastel, and low-noise: light grass, lavender-blue low walls, warm wooden connectors, trees, rocks, foliage, and soft ground patches.

## Completed

- The map was rebuilt from a small boxed arena into a multi-island combat layout.
- The runtime camera is fixed for this map, so falling or moving characters no longer pull the view away.
- The previous over-bright visual profile was reduced through softer lighting, lower exposure, controlled ambient light, and reduced fog density.
- The old off-theme dressing set was replaced with nature-only props from the curated Kenney assets.
- The main cover pieces now have rounded, low-wall visual shells while preserving their existing gameplay collision.
- Decorative collision-free shell walls were added around main bridge mouths, side-link entries, side island rims, and central turns to move the arena closer to the reference-image maze-wall language.
- The arena footprint was enlarged by 25% horizontally: the center island is now 35x35, side island offset is 35, the backdrop is 130x130, and pickup/spawn/dressing positions scale with the larger layout.
- Island shadow pads and path-wear overlays now add a first layer of authored ground treatment around islands and bridge routes.
- A collision-free island edge layer now softens the top edges of the center and side islands so they read less like raw whitebox slabs.
- A collision-free wall-cap layer now adds rounded terminals and corner accents to bridge mouths, side-link entries, and center turns.
- Weapon spawn pacing is constrained to two active pickups so routes matter without flooding the arena.
- AI pickup awareness now matches the enlarged side-route pickup radius.

## Current Verification Gates

- Required map nodes exist and legacy whitebox nodes are removed.
- Spawn points, bridges, side links, enlarged arena scale, pickup clusters, AI pickup awareness, and fixed camera behavior are checked by the whitebox verifier.
- The art direction gate checks grass/bridge/wall palette, nature-only dressing, soft ground patches, soft wall shells, and a restrained post-processing profile.
- The visual quality gate in `docs/workflow/commercial-slice-a-art-quality-gate-v1.md` is now the acceptance bar for all future art changes; script checks are only the minimum floor.
- The AI smoke batch confirms the map still produces deaths, ring-outs, armed AI, and pickup usage.

## Active Gap

The broad style and footprint are closer, but the art quality gate estimates the current map at 28/40, below the 32/40 acceptance bar. The biggest gaps are insufficient authored perimeter composition and broader board-level framing.

## Next Increment

- Strengthen perimeter framing with tree/rock clusters that create depth without cluttering routes.
- Add another pass of broad ground-paint variation only where it supports composition.
- Re-score the visual pass against the art quality gate before calling the art iteration complete.
