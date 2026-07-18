# Continuous Main-Island Underbody Fix

## Problem

The production main island combined one continuous sculpted cliff with ten separate cliff-facet modules. From the gameplay camera those protruding modules occluded the continuous body and produced open sky gaps between several hanging purple shapes. The silhouette stopped reading as one floating island.

## Fix

- Removed the detached south, east, and north-front cliff modules from the source asset.
- Added a dedicated continuous main-cliff outline without bridge-socket cuts.
- Kept all four bridge sockets in the deck and warm side shell, so the connection language remains visible at the top surface.
- Continued the purple structural body behind each shallow socket instead of carrying the opening through the whole island.
- Retained the multi-ring taper and four-tone cliff facets inside one connected mesh.
- Added forbidden-node checks so detached cliff modules cannot silently return.
- Added a Blender source check that enforces one connected central-cliff component and the approved main-island span.

No collision, bridge traversal, spawn, pickup, camera, or combat values changed.

## Evidence

- `reports/main_island_underbody_continuity_full.png`
- `reports/main_island_underbody_south_review.png`
- `reports/main_island_underbody_east_review.png`

## Verification

- Sunset V2 integration: PASS.
- Open Ring-Out render-cost contract: PASS, 218 exported meshes and 233 surfaces.
- Open Ring-Out full scene contract: PASS.
- Blender source connectivity: one component, no detached cliff modules.
