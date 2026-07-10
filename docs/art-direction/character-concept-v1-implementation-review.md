# Character Concept V1 Implementation Review

## Approved Reference

- `docs/art-direction/references/character_concept_v1.png`
- Simple premium-vinyl bean silhouette.
- Pear-shaped body with a narrower crown and fuller lower torso.
- Small recessed face opening with two warm eyes.
- Short separated feet and continuous bent arms.
- Weapons remain visibly outside the torso and are supported by both hands.

## Implemented

- Replaced the spherical body and duplicate hand setup with one pear body, two articulated soft arm chains, two grip hands, and compact feet.
- Replaced the oversized visor with a small plum face opening and two warm eye elements.
- Corrected the asset-axis contract: Blender `+Y` maps to Godot `-Z` during glTF conversion.
- Rotated weapon assets 180 degrees so barrels point away from the body.
- Centered the weapon holder in front of the chest and rebalanced all weapon scales.
- Added geometric torso-clearance verification using transformed mesh bounds.

## Clearance Gate

- Pistol: `0.483`
- SMG: `0.326`
- AK rifle: `0.097`
- Sniper: `0.081`
- Required minimum: `0.040`

All values are positive distances between the weapon's rear-most point and the torso's front-most depth plane.

## Evidence

- `reports/character_weapon_p9_showcase.png`
- `reports/open_ringout_character_concept_v1_screenshot.png`
- `reports/open_ringout_character_concept_v1_detail.png`

## Remaining Work

- Replace static soft-limb pieces with a lightweight arm rig or weapon-specific pose targets.
- Apply locomotion squash and stretch to the complete character assembly rather than only the core body mesh.
- Add a controlled face-expression set after the base silhouette is accepted in gameplay.
