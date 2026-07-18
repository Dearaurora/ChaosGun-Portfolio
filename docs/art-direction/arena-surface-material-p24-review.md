# Arena Surface Material P24 Review

Decision: PASS

## Goal

Replace the flat orange-whitebox reading of the main arena with a clean,
layered toy-wood surface while preserving topology, collision, camera rules,
combat tuning, and the approved P14 sunset grade.

## Implemented

- Rebuilt five deterministic wood material families as albedo, tangent normal,
  and roughness texture sets.
- Increased central-panel value separation and physical bevel response without
  adding dirt, scratches, speckles, or gameplay-scale visual noise.
- Darkened the structural deck frame, floor seams, and bridge timber so the
  safe routes remain readable against the warm floor panels.
- Unified all four soft bumpers under the red cover family, separating them
  from the orange deck at full-map camera distance.
- Tightened key-light shadows and reduced the SSAO radius while increasing its
  contact strength, improving grounding without washing the floor in gray.
- Upgraded the integration gate to require P24 normal/roughness maps, floor
  value separation, red cover contrast, and the approved grounding profile.

## Evidence

- Before: `reports/p23_combat_feedback_final.png`
- First material pass: `reports/p24_surface_material_v1.png`
- Approved final frame: `reports/p24_surface_material_final.png`

## Verification

- Sunset V2 material and hierarchy contract: PASS.
- Open Ring-Out Blender visual layer: PASS, 1,431 meshes / 110 materials.
- Map topology, bridge integrity, collision, respawn, and pickups: PASS.
- P14 environment composition and grade: PASS.
- Runtime camera framing and smoothing: PASS.
- Character locomotion, authored motion, and combat audio feedback: PASS.
- P24 regression: 8/8 PASS.

## Visual Judgment

The central island now reads as a constructed toy-wood arena rather than a
single orange slab. The gain is visible at the gameplay camera, not only in a
close-up. Additional surface noise would have low value and would reduce
projectile and character readability.

## Next

P25 should target restrained ambient motion and living landmarks: windmill
rotation, balloon drift, cloud parallax, pickup-stage motion, and a small set of
reactive edge cues. It should not add more floor decals or static prop density.
