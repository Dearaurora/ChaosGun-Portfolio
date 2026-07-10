# Sunset Toy Sky Islands Reference Translation

## Decision

The selected direction is the warm sunset toy-sky-island reference stored at:

`docs/art-direction/references/sunset-toy-sky-islands-selected.png`

The three V2 exploratory variants are rejected as primary directions. Their more
compact HUD and stronger character/weapon integration remain useful execution
lessons, but their arsenal, carnival-machine, and laboratory environment themes
must not drive the final stage.

## Why This Direction Wins

- The orange island tops and purple cliff bodies create a memorable, friendly
  warm/cool identity without depending on complex materials.
- Large rounded island shapes and broad floor tiles read immediately at the fixed
  camera distance.
- Peripheral vignettes create story and charm while leaving the center readable.
- Clouds, distant islands, sunset light, and one large balloon provide depth with
  fewer assets than a dense mechanical backdrop.
- The environment supports ChaosGun's combat instead of competing with it. Guns,
  projectiles, impacts, and player colors can own the action layer.

## Structural Translation To The Playable Map

The reference is a style target, not a new level layout. Current Open Ring-Out
collision, center footprint, four side islands, four bridges, spawn positions,
pickup points, and fixed camera remain authoritative.

Map translation priorities:

1. Replace the current layered rectangular skirts with rounded tapered cliff
   modules and a clean warm side band.
2. Simplify the central surface into broad authored tiles with subtle wood/resin
   grain and much less strip decoration.
3. Rebuild bridge shells as chunky wooden planks with toy end caps.
4. Preserve existing cover collision while replacing visual shells with red soft
   bumpers, golden toy crates, and a small number of circular pads.
5. Stage one unique prop vignette on each side island; begin with the windmill
   island, then tree/blocks, barrels/tires, and flag/toy clusters.
6. Replace soft abstract background shapes with layered clouds, simplified distant
   islands, and one balloon silhouette placed outside the gameplay read.

## Execution Boundary

Execution agents do not explore or reinterpret the direction. They implement the
tokens and module list in `chaosgun-visual-slice-v2-contract.md`, deliver fixed
camera screenshots, and stop when constraints conflict. The lead agent owns
visual comparison against the selected reference and the pass/fail decision.

Automated tests continue to protect topology, loading, collisions, and runtime
behavior. They do not award visual quality based on mesh or material counts.
