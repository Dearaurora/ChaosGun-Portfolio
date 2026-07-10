# Character and Weapon Vertical Slice P9 Review

## Scope

- Removed the runtime readability proxy that covered authored weapon geometry.
- Preserved the GLB materials instead of replacing them with flat unshaded category tints.
- Repositioned the shared weapon holder to align with the modeled grip hands.
- Rebalanced the four weapon scales for a stable party-camera silhouette ladder.
- Rebuilt all four weapon GLBs with authored toy-gun structure and secondary details.
- Added an engine-rendered four-character showcase capture for repeatable visual review.

## Visual Evidence

- `reports/character_weapon_p9_showcase.png`: close three-quarter comparison.
- `reports/open_ringout_character_weapon_p9_screenshot.png`: locked gameplay camera.
- `reports/open_ringout_character_weapon_p9_detail.png`: gameplay detail camera.

## Result

Weapon vertical slice: PASS.

- Pistol: tapered receiver, slide insets, front and rear sights.
- SMG: split receiver and shroud, rail, vents, stock, charging handle.
- AK rifle: receiver and ribbed foregrip, tapered stock, segmented curved magazine, gas tube and sight.
- Sniper: tapered body and stock, cheek rest, scope mounts and rings, barrel shroud and bipod.
- All four assets retain shaded multipart materials and no longer use the proxy box overlay.

Character concept match: HOLD.

The current bean body remains too spherical and static. The next character pass needs a stronger head/body taper, integrated arm silhouette, weapon-specific hand poses, and locomotion deformation across the whole asset rather than the body mesh alone.

## Verification

- Character weapon readability verifier: PASS.
- Open Ring-Out slice verifier: PASS.
- Sunset Open Ring-Out V2 integration verifier: PASS.
- Blender visual verifiers: PASS.
- Full verifier sweep: 19/21 PASS. The two failures are mutually exclusive legacy default-map preset checks for A1 Reference and Commercial Slice; the active product route is Open Ring-Out.
