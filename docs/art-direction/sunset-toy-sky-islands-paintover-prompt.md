# Sunset Toy Sky Islands Topology-Preserving Paintover Prompt

## Input Roles

- Image 1: edit target and structural authority -
  `reports/open_ringout_slice_screenshot.png`
- Image 2: visual style reference -
  `docs/art-direction/references/sunset-toy-sky-islands-selected.png`

Image 1 controls camera, framing, island footprints, bridge locations, cover
locations, player count, approximate player positions, and center pickup. Image 2
controls palette, material impression, rounded shape language, lighting, cloud
depth, prop density, and storybook toy mood. Never swap these roles.

## Built-In Image Edit Prompt

```text
Use case: stylized-concept
Asset type: topology-preserving game-art paintover for a commercial party-game vertical slice

Input images:
- Image 1 is the edit target and absolute structural authority: the current playable ChaosGun Open Ring-Out screenshot.
- Image 2 is only the visual style reference: the selected warm sunset toy sky-island concept.

Primary request:
Restyle Image 1 into the warm sunset toy-sky-island art direction of Image 2 while preserving Image 1's playable level exactly. This is a paintover of the existing map, not a new arena design.

Structural invariants from Image 1:
- Keep the exact fixed isometric camera angle and near-identical framing.
- Keep one large central island, the same four side islands, the same four bridges, the same ring-out gaps, and the same safe routes.
- Keep the central island's asymmetric footprint and current bridge widths and directions recognizable.
- Keep existing cover count and approximate cover positions: red cylindrical bumpers, low block covers, and the center pickup.
- Keep exactly four fighters, red, green, cyan, and yellow, in approximately the same gameplay positions.
- Do not add or remove islands, bridges, walls, cover, ramps, paths, characters, or gameplay objects.

Visual translation from Image 2:
- Warm orange-honey toy wood or resin island tops with broad calm tile divisions and subtle grain.
- Thick rounded warm side bands over tapered deep plum-violet cliff bodies.
- Simple chunky wooden plank bridges with toy end caps and tiny cyan safe-route markers.
- Saturated red upholstered bumpers, rounded golden crates, and a small number of circular pickup pads.
- Pink-violet sunset clouds, periwinkle sky, simplified distant floating islands, and one distant balloon silhouette outside gameplay.
- Sparse authored side-island vignettes: windmill and toy ducks on one island, simple trees and blocks on another, barrels and tires on another, flag and small toys on the last. Keep the central combat floor mostly open.

Character and action upgrade:
- Preserve compact bean-like gameplay readability but create original ChaosGun toy gunners with a distinct visor, tiny feet, small gripping hands, forward firing poses, and grounded contact shadows.
- Weapons must be visibly held close to the body, with dark neutral bodies and player-color accents.
- Show one clean active combat beat: compact muzzle flashes, short segmented player-color projectile trails, one directional impact burst, and one readable knockback reaction.
- Keep effects small enough that all routes, edges, and fighters remain readable.

HUD:
- Replace the four large black cards with compact icon-dominant corner clusters.
- Preserve player color, lives, weapon silhouette, and ammo meaning without requiring precise text.
- Do not cover the side islands.

Lighting and rendering:
- Warm sunset key from the upper-left, cool violet-blue fill from the opposite side, soft directional cast shadows, strong contact shadows, restrained bloom, and clear material roughness differences.
- Polished stylized real-time 3D game screenshot, 16:9 landscape, practical to reproduce in Blender and Godot.

Avoid:
- no white laboratory panels
- no factory or arsenal machinery
- no steampunk gears
- no dense bolts, screws, pipes, targets, panel seams, decals, or evenly scattered props
- no neon cyberpunk, holograms, or dashboard motifs
- no flat graybox surfaces
- no floating weapons
- no oversized HUD cards
- no random particle clutter
- no copied commercial characters, props, arenas, logos, or UI
- no watermark, captions, labels, or split screen
```

## Acceptance Gate

The paintover fails before any quality scoring if the camera, island footprints,
bridge topology, major cover placement, player count, or center pickup differ
materially from Image 1.

If topology passes, review in this order:

1. Match to the warm orange / purple sunset reference.
2. Large rounded island and wooden bridge language.
3. Open combat floor and purposeful side-island prop clusters.
4. Grounded characters, held weapons, and readable combat effects.
5. Compact HUD and whole-frame commercial cohesion.
