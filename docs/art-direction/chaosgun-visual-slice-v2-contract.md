# ChaosGun Visual Slice V2 Contract

## Product Goal

Create one five-second, four-player combat beat that can stand beside leading
commercial party games in a store page or trailer. The target is whole-frame
cohesion: environment, character silhouettes, weapons, animation pose, VFX,
lighting, backdrop, camera composition, and HUD must read as one product.

The approved identity is **Sunset Toy Sky Islands / 暖光玩具天空岛**.
The arena is a welcoming floating toy playground built from warm rounded island
slabs, wooden bridges, soft purple cliffs, sunset clouds, and sparse storybook
props. ChaosGun identity comes primarily from the four armed toy characters,
projectile colors, impact effects, ring-out edges, and center pickup rather than
turning the whole environment into a weapon factory.

Selected visual reference:
`docs/art-direction/references/sunset-toy-sky-islands-selected.png`

## Reference Hierarchy

1. Primary visual reference: `sunset-toy-sky-islands-selected.png`. Match its
   warm/cool balance, rounded island language, cloud depth, large clean floor
   fields, sparse playful prop framing, and soft storybook toy rendering.
2. Primary structural reference: the current Open Ring-Out screenshot. Preserve
   its fixed isometric camera, central island, four side islands, four bridges,
   combat routes, ring-out edges, four-player staging, and pickup positions.
3. Primary quality reference: the whole-frame cohesion, material clarity, and
   readable toy scale associated with top commercial party games.
4. Secondary action reference: compact silhouettes, immediate projectile paths,
   and exaggerated hit feedback associated with fast top-down party combat.
5. Forbidden influence: direct copying of Overcooked, Boomerang Fu, Among Us,
   Fall Guys, or any identifiable commercial character, arena, logo, or UI.

## Whole-Frame Rules

- Keep the current gameplay topology and camera angle recognizable in every
  paintover. Do not invent additional islands, bridges, walls, or traversal.
- The central pickup remains the primary environmental focal point; the active
  shot/impact moment becomes the primary action focal point.
- Preserve four clearly separated player colors: red, green, cyan, and yellow.
- Characters must read at gameplay scale through body shape, visor/face area,
  feet or hands, weapon grip, pose, rim light, and a grounded contact shadow.
- Weapons must have distinct silhouettes and must appear held, not floating next
  to the character.
- Ring-out edges use one consistent danger language. Bridge routes use a separate
  safe-traversal language.
- HUD may be redesigned into smaller corner clusters, but it must retain player,
  lives, weapon, and ammo information without covering the side islands.
- Backdrop depth comes from layered pink-violet clouds, distant tiny islands,
  one or two large framing silhouettes such as a balloon, and atmospheric value
  separation, not random floating particles.
- Surface detail uses large readable panels first, medium trim second, and sparse
  small accents last. No uniformly scattered decoration.
- The central combat floor stays mostly open. Prop personality is concentrated
  on the four side islands and dead-space perimeter, with one to three authored
  clusters per island rather than decoration spread evenly across the board.

## Material And Lighting Tokens

- Main deck: warm orange-honey toy wood or resin, approximately `#D47A32`, with
  golden upper highlights near `#F2A354`, subtle broad grain, and a readable
  top-to-side value break.
- Structural underside: deep matte plum-violet around `#3E2D68`, shifting cooler
  and darker toward the island bottoms.
- Bridges: medium warm wood around `#B66E3F`, using broad planks, chunky end caps,
  and small cyan jewel markers at safe entrances.
- Sky and cloud depth: periwinkle blue around `#5968C5`, violet shadow around
  `#51418F`, and soft pink-peach cloud light around `#E8A3B1`.
- Danger accents: saturated toy red around `#E54532`, reserved for bumpers,
  hazards, and hostile projectile language.
- Traversal and player feedback accents: clean cyan around `#45C9EE`.
- Reward/energy accents: focused gold around `#FFD05A`; emissive effects are
  reserved for pickups, projectiles, bridge markers, and ring-out warning edges.
- Use soft key light, cool fill, strong contact shadows, restrained bloom, and
  visible material roughness differences. Avoid flat unlit pastel surfaces.
- Prefer a small shared material system, vertex color variation, a trim/gradient
  atlas, and instanced modules over many one-off flat-color materials.

## Selected Shape And Prop Language

- Islands use broad convex outlines with large rounded corners, thick warm side
  bands, and tapered purple cliff masses. Avoid thin plates and mechanical trays.
- Floor segmentation is large and calm: roughly four to six broad tile divisions
  across the central combat width. Seams are shallow and slightly irregular.
- Bridges use simple chunky wooden planks. They should read as warm handcrafted
  toy connections, not conveyors, laboratory pads, or illuminated metal ramps.
- Covers use red upholstered cylinders, rounded golden crates, low toy blocks,
  and a small number of circular pads. Keep silhouettes bold and familiar.
- Side-island prop families may include a windmill, pinwheel, balloon, toy ducks,
  simple conifer trees, barrels, tires, fences, flags, and stacked blocks.
- Each side island gets one memorable vignette and supporting pieces. Do not place
  every prop family on every island.
- Background islands stay simplified and slightly blurred, with one main prop or
  tree cluster each. They must reinforce scale without becoming new gameplay.

## Character And Action Language

- Preserve the compact bean-like readability from the selected reference, but
  use an original ChaosGun head/visor, small feet, small gripping hands, and a
  clearer forward lean while firing.
- Character height on screen stays close to the reference. Do not enlarge the
  cast until they dominate the board or shrink them into colored dots.
- Weapons are dark neutral toy guns with player-color accents and strong muzzle
  shapes. Each is held close to the body with a readable aim line.
- Projectile trails are short segmented streaks in player colors. Muzzle flashes
  are compact warm stars. Impacts use a fast directional burst plus one readable
  knockback arc; avoid persistent particle clouds.
- Contact shadows and directional cast shadows ground every fighter and cover.

## Immediate Failure Conditions

- Camera, island arrangement, bridges, or gameplay routes change materially.
- The environment becomes a white laboratory, dense arsenal, factory floor,
  steampunk machine, neon sci-fi board, or mechanical target range.
- Environment remains a collection of flat beveled boxes with decorative strips.
- Characters remain stiff capsules with floating weapons and no grounded pose.
- HUD remains four large black cards dominating the corners.
- The image relies on bloom, particles, or saturation instead of material depth.
- Small props are distributed evenly without compositional purpose.
- Repeated target decals, bolts, screws, pipes, and panel seams overwhelm the warm
  open floor fields or make the board feel mass-produced and clinical.
- Any commercial game's recognizable art, character, prop, or UI is reproduced.

## Paintover Deliverables And Gate

Produce one 16:9 topology-preserving translation frame using the current gameplay
screenshot as the structural edit target and the selected image as the visual
reference. It must show the proposed environment, character treatment, weapon
grip, one active projectile/impact beat, compact HUD, and backdrop treatment.

Acceptance order:

1. ChaosGun identity and direction fit.
2. Gameplay topology and readability preservation.
3. Character, weapon, and action focal quality.
4. Material, lighting, depth, and HUD cohesion.
5. Feasibility as a reusable modular Blender kit.

The first 3D task is limited to one central-platform quadrant, one bridge mouth,
one rounded cliff module, one red bumper, one golden crate, one hero character,
one pistol, one shot/impact effect, and one compact HUD unit. The windmill side
island vignette is the first environment extension only after that hero slice
passes screenshot review.
