# P11 Arena Prop Refinement

## Goal

Raise the most frequently visible arena props from blockout geometry to a consistent toy-production pass while preserving every gameplay collision and route.

## Refined Assets

- Soft bumpers: segmented padded highlights, restrained end plates, collars, and short grounding feet.
- Production crates: recessed side panels, small latches, corner caps, top plate, and structural rails.
- South barrels: bottom foot, inset lid, hoop construction, and framed front label.
- West tire stack: paired sidewalls for a fuller rubber profile.
- West barricade: three readable front panels to break up the large cover mass.

The second visual pass reduced high-contrast frame and highlight sizes so details remain subordinate to each prop's silhouette at the gameplay camera distance.

## Gameplay Contract

- The generated GLB remains a collision-free visual layer.
- Godot collision boxes, cover extents, traversal routes, spawn points, and weapon spawn positions are unchanged.
- Representative P11 nodes are checked by `sunset_open_ringout_v2_integration_verifier.gd` to prevent silent loss during future Blender rebuilds.

## Evidence

- Runtime overview: `reports/scene_props_p11_final.png`
- Blender source: `assets/source/sunset_toy_sky_islands/open_ringout_v2_preview.blend`
- Runtime asset: `assets/models/generated/sunset_toy_sky_islands/open_ringout_v2_preview.glb`
