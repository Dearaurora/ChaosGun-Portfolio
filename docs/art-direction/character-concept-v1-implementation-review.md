# Character Concept V1 Implementation Review

## Approved Reference

- `docs/art-direction/references/character_concept_v1.png`
- Simple premium-vinyl bean silhouette.
- Pear-shaped body with a narrower crown and fuller lower torso.
- Small recessed face opening with two warm eyes.
- Short separated feet and continuous bent arms.
- Weapons remain visibly outside the torso and are supported by both hands.

## Implemented

- Replaced the spherical body with a controlled ten-ring profile mesh that defines a rounded crown, narrower shoulders, full lower torso, and raised leg opening.
- Replaced segmented arm ellipsoids with continuous Bezier-derived soft arm meshes and two compact grip hands.
- Replaced the oversized visor with a thin rounded-rectangle plum face panel and two warm emissive eye elements.
- Added colored ankle cuffs and separate dark soles so the feet connect to the body instead of reading as detached discs.
- Added separate close-grip pistol arms and forward-support long-gun arms, switched at runtime per weapon category.
- Preserved stable left/right grip marker nodes for map integration and later animation work.
- Unified weapon materials around dark plum and graphite bodies, restrained category accents, warm function trim, and compact muzzle glow.
- Corrected the asset-axis contract: Blender `+Y` maps to Godot `-Z` during glTF conversion.
- Rotated weapon assets 180 degrees so barrels point away from the body.
- Centered the weapon holder in front of the chest and rebalanced all weapon scales.
- Added geometric torso-clearance verification using transformed mesh bounds.

## Clearance Gate

- Pistol: `0.501`
- SMG: `0.344`
- AK rifle: `0.115`
- Sniper: `0.099`
- Required minimum: `0.040`

All values are positive distances between the weapon's rear-most point and the torso's front-most depth plane.

## Evidence

- `reports/character_weapon_p9_showcase.png`
- `reports/open_ringout_character_concept_v1_screenshot.png`
- `reports/open_ringout_character_concept_v1_detail.png`
- `reports/open_ringout_character_weapon_v3_screenshot.png`

## Remaining Work

- Replace the two static pose sets with a lightweight arm rig when animation production begins.
- Apply locomotion squash and stretch to the complete character assembly rather than only the core body mesh.
- Add a controlled face-expression set after the base silhouette is accepted in gameplay.
