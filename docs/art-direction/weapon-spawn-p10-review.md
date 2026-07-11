# Weapon Spawn P10 Review

## Goal

Replace the demo pickup disc with a persistent, readable weapon-resource loop for the guaranteed center spawn and the four outer candidate locations.

## Implemented

- Added one premium center pedestal and four lightweight outer pedestals.
- Added deterministic cooling, prewarm, and active visual states.
- Center pedestal uses a larger radius, six status lights, and four structural clamps.
- Outer pedestals use a smaller radius and four status lights.
- Replaced procedural weapon-box icons with the generated pistol, SMG, AK, and sniper assets.
- Reduced pickup rotation and hover amplitude for a heavier toy presentation.
- Added a two-step materialize squash when a weapon appears.
- Added a 0.12 second weapon-to-character collect animation.
- Replaced pickup sphere motes with one ring and four controlled shards.
- Unselected random pedestals return to cooling instead of remaining in prewarm.

## Gameplay Contract

- Center and random spawn timing is unchanged.
- Stay duration, cooldown, active pickup count, collision radius, and equip behavior are unchanged.
- The center spawn remains guaranteed and exactly one outer random pickup can be active.

## Evidence

- `reports/weapon_spawn_p10_showcase_final.png`
- `reports/weapon_spawn_p10_gameplay_final.png`

## Acceptance

- Center and outer pedestals are distinguishable without HUD labels.
- Active, prewarm, and cooling states are readable against the orange arena.
- Every pickup uses a generated weapon asset.
- Weapon models do not intersect the pedestal.
- Empty outer pedestals remain subdued and do not resemble active pickups.
