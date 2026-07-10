# ChaosGun Visual Slice V2 Contract

## Product Goal

Create one five-second, four-player combat beat that can stand beside leading
commercial party games in a store page or trailer. The target is whole-frame
cohesion: environment, character silhouettes, weapons, animation pose, VFX,
lighting, backdrop, camera composition, and HUD must read as one product.

The approved umbrella identity is **Cloudtop Toy Arsenal / 云端玩具兵工厂**.
The arena is a playful floating workshop where toy weapons, recoil mechanisms,
targets, ammo capsules, and launch rails define both the world and the gameplay
language. It must feel original to ChaosGun and must not copy a specific level,
character, prop, or UI treatment from another game.

## Reference Hierarchy

1. Primary structural reference: the current Open Ring-Out screenshot. Preserve
   its fixed isometric camera, central island, four side islands, four bridges,
   combat routes, ring-out edges, four-player staging, and pickup positions.
2. Primary quality reference: the whole-frame cohesion, material clarity, and
   readable toy scale associated with top commercial party games.
3. Secondary action reference: compact silhouettes, immediate projectile paths,
   and exaggerated hit feedback associated with fast top-down party combat.
4. Forbidden influence: direct copying of Overcooked, Boomerang Fu, Among Us,
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
- Backdrop depth comes from cloud layers, distant workshop islands, suspended
  rails, and atmospheric value separation, not random floating particles.
- Surface detail uses large readable panels first, medium trim second, and sparse
  small accents last. No uniformly scattered decoration.

## Material And Lighting Tokens

- Main deck: warm ivory or light honey plastic, with a readable top-to-side value
  break and subtle molded texture.
- Structural underside: deep plum, charcoal violet, or desaturated navy.
- Traversal accents: cyan or clean sky blue.
- Danger accents: coral red or safety orange.
- Reward/energy accents: focused gold; emissive effects are reserved for active
  pickups, projectiles, and danger signals.
- Use soft key light, cool fill, strong contact shadows, restrained bloom, and
  visible material roughness differences. Avoid flat unlit pastel surfaces.
- Prefer a small shared material system, vertex color variation, a trim/gradient
  atlas, and instanced modules over many one-off flat-color materials.

## Paintover Directions

### A. Modular Arsenal Workshop

Chunky molded construction plates, toy gun assembly rails, ammo capsules, target
discs, and recoil pistons. Palette: honey plastic, charcoal-plum structure, cyan
routes, coral danger pieces, and focused gold energy. This is the recommended
direction because it connects the environment directly to ChaosGun's core verb.

### B. Clockwork Shooting Carnival

Wind-up mechanisms, spring launchers, rotating target plates, striped safety
rails, and compact carnival-machine details. Palette: warm cream, mint, vermilion,
navy, and brass. More expressive and playful, but must avoid becoming a generic
theme park or steampunk scene.

### C. Capsule Ballistics Lab

Rounded toy-lab modules, transparent or glossy ammo capsules, pneumatic tubes,
charging pads, and clean modular test-bay markings. Palette: off-white, turquoise,
coral, deep violet, and lemon energy. Cleaner and more modern, but must avoid
clinical sci-fi, holographic-dashboard, or neon-cyber styling.

## Immediate Failure Conditions

- Camera, island arrangement, bridges, or gameplay routes change materially.
- Environment remains a collection of flat beveled boxes with decorative strips.
- Characters remain stiff capsules with floating weapons and no grounded pose.
- HUD remains four large black cards dominating the corners.
- The image relies on bloom, particles, or saturation instead of material depth.
- Small props are distributed evenly without compositional purpose.
- Any commercial game's recognizable art, character, prop, or UI is reproduced.

## Paintover Deliverables And Gate

Produce one 16:9 concept frame for each direction using the current screenshot as
the edit target. Each frame must preserve topology while showing the proposed
environment, character treatment, weapon grip, one active projectile/impact beat,
compact HUD, and backdrop treatment.

Only one direction advances to 3D. Acceptance order:

1. ChaosGun identity and direction fit.
2. Gameplay topology and readability preservation.
3. Character, weapon, and action focal quality.
4. Material, lighting, depth, and HUD cohesion.
5. Feasibility as a reusable modular Blender kit.

After approval, the first 3D task is limited to one central-platform quadrant,
one hero character, one pistol, one shot/impact effect, and one compact HUD unit.
