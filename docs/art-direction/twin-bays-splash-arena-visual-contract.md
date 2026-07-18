# Twin Bays Splash Arena visual contract

Status: implementation contract  
Map: `Twin Bays Splash Arena / 双湾水上竞技场`  
Reference freeze: `res://docs/art-direction/references/twin_bays/README.md`
Dual-authority contract: `res://docs/art-direction/twin-bays-reference-contract.md`

## Player-facing promise

The arena is a bright, toy-scale water-park stage for a party shooter. Cream platforms float above clear aqua water; aqua tile walls, coral soft caps, sunny-yellow fall edges, orange weapon pads, and paired cyan water portals make navigation readable at a glance. The world is playful, clean, and energetic without competing with four characters, weapon silhouettes, shots, hit effects, or the HUD.

## Non-negotiable structure

The executable whitebox, current Godot production scene, and
`twin_bays_layout_v1.json` own all gameplay geometry. The versioned as-built
reference owns human-readable structure, composition, and camera. The original
water-park concept is Mood Reference Only and may not be used to infer
geometry. Production art must preserve the 116-point platform, both lethal
bays, widened central route, perimeter-following portal walls, 10 covers, four
spawns, four ordinary pickup candidates, one center-special pickup, and two
portal anchors. The approved 2026-07-17 amendment removes the four inner covers
and two south wall sections; those retired forms must not return as visuals or
hidden collision. Art can round, bevel, tile, and color these forms; it cannot
alter routes or use scenery to hide a structural mismatch.

Visible cream deck must cover the full safe central collision width. There may be no invisible shoulder outside the visible walkable surface.

## Materials and shape language

- Floor: dry warm cream, matte resin or large tile, sparse low-contrast joints.
- Platform side: aqua/blue, slightly darker than gameplay walls so the silhouette reads over water.
- Fall edge: continuous sunny-yellow guard stripe, wide enough to read at 1280×720.
- Walls and covers: aqua tile/plastic with rounded corners and compact contact shadows.
- Wall caps: coral padded forms with broad highlights, no noisy stitching.
- Pickup points: four flat open orange ordinary pads plus one centered yellow premium pad, all with no surrounding wall or collision.
- Portals: vertical cyan water rings with a white-cyan foam lip and a brief transfer splash.

Primary tokens are `#F4EFE7`, `#4FC5D8`, `#FF8F82`, `#FFD54A`, `#FF8A3D`, and `#36D9FF`. Materials should be readable through color, value, and roughness before emissive bloom is considered.

## Dry-floor veto

Any floor water stain, puddle, wet-mark Decal, wetness mask, or local glossy wet patch rejects the build. This includes assets or nodes named `FloorWetMarks`, `FloorPuddles`, `Decal` used on the gameplay floor, `wetness`, `puddle`, `water_stain`, or `floor_water`. Background water and short-lived portal spray are the only allowed water visuals.

## Background

Use one opaque, collision-free animated water surface below the gameplay plane, with at most two slow caustic layers. The two bays should read deeper/darker than the deck edge. Low-poly palm islets, float rings, buoy lines, and slide ends live only at the frame perimeter, below the gameplay plane, and never obstruct the central voids or portal silhouettes. Avoid screen-space refraction, transparent reflection stacking, or scenery collision.

## Lighting and camera

Use bright afternoon light: warm key, cool aqua fill, compact contact shadows, and restrained portal glow. Final grading is done with the production fixed camera and the existing four shared character/weapon rigs present. All spawns, characters, portals, and the safe central route must remain framed at 1920×1080 and 1280×720 without HUD overlap.

## Explicit exclusions

No character/weapon map skins, new weapon tuning, map-specific animation, projectile portals, swimming, water bounce, music, dedicated water ambience, full 3D water-park simulation, floor wetness, or map-specific AI navigation.
