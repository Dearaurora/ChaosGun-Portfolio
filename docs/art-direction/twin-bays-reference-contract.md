# Twin Bays dual-authority reference contract

Status: owner-approved production reference  
Map: `Twin Bays Splash Arena`  
Contract version: `1`  
Layout SHA-256: `ea69b591ae88df766967596a18dacbcaff047c07e65b41fc008330f5e94a0227`

## Authority order

1. `resources/maps/twin_bays_layout_v1.json` and the current Godot production
   scene own gameplay geometry, collision, semantic placement, and camera.
2. `twin_bays_as_built_reference_v1.png` is the approved human-readable
   structure, composition, and camera reference. It was built from a frozen
   Godot empty-scene capture, not generated from concept art.
3. `twin_bays_splash_arena_selected_background.png` is **Mood Reference Only**.
   It may inform palette, material language, rounded forms, water-park backdrop,
   and party-shooter tone, but never geometry or gameplay placement.
4. If any image conflicts with the canonical layout or current production
   scene, the layout and production scene win.

The machine-readable companion
`twin_bays_as_built_reference_v1.json` binds the reference sheet, frozen source
capture, mood reference, canonical layout, counts, and SHA-256 values.

## Frozen as-built structure

- Current 116-point platform and both lethal bays.
- Current fixed production camera and approved framing.
- Current perimeter-following walls and paired inward-mounted portal pipes.
- 10 covers, four player spawns, four ordinary pickup candidates, one fixed
  center-special pickup, two portal anchors, and two portal pipes.
- Dry cream gameplay floor, with water permitted only below/outside the deck or
  in short-lived depth-tested portal effects.

Any structural change invalidates this contract and requires a new versioned
as-built source capture, reference sheet, manifest, review, screenshots, and
Golden baseline.

## Mood-reference prohibitions

The following retired details visible in earlier concepts must not return:

- corner towers or high pillars;
- legacy wall-mounted portals instead of the paired water pipes;
- retired inner covers or removed south wall sections;
- zig-zag portal-side wall geometry;
- floor splash paint, wet marks, puddles, wetness masks, or wet Decals;
- legacy pickup placement or spawn rules.

## Rebuild and validation

Run `python tools/build_twin_bays_as_built_reference.py` to reproduce the sheet
from the frozen source. Replacing that source requires the explicit
`--refresh-source` flag and therefore a renewed owner review.

Release validation binds the layout, reference manifest, frozen source, mood
image, and final reference image. Dynamic water means later runtime captures
are not required to match the reference pixel-for-pixel; structural and
semantic verifiers remain authoritative.
