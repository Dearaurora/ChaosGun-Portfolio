# Sunset Toy Sky Islands Topology Paintover V1 Review

Paintover: `docs/art-direction/references/sunset-toy-sky-islands-topology-paintover-v1.png`

Decision: DIRECTION PASS / TOPOLOGY REFERENCE ONLY

## What Passed

- The warm orange deck, deep purple cliffs, wooden bridges, pink-violet clouds,
  distant islands, and sparse side-island vignettes match the selected direction.
- Characters now read as grounded toy gunners with held weapons, compact muzzle
  flashes, short colored trails, and smaller icon-led HUD clusters.
- Large floor fields remain calm and the central action stays readable.

## Structural Caveat

The generated paintover preserves the one-center/four-side/four-bridge concept,
but it simplifies the exact central footprint and shifts some cover proportions.
It is therefore not authoritative for collision or object coordinates. The current
Open Ring-Out gameplay scene and screenshot remain the structural source of truth.

## 3D Hero Slice Gate

Before any full-map replacement, produce and review these modules in an isolated
Blender source scene:

1. Warm rounded platform top, side band, and tapered purple cliff.
2. One wooden bridge mouth with cyan jewel markers.
3. One red soft bumper and one rounded golden crate.
4. One grounded ChaosGun toy character holding a pistol.
5. One compact muzzle flash and segmented projectile trail.

The slice must export as a collision-free GLB and render from a fixed orthographic
camera. Passing node or material checks does not constitute visual approval.
