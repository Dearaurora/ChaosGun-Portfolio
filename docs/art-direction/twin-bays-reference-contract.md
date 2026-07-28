# Twin Bays dual-authority reference contract

Status: Art V3 commercial-polish migration in progress
Map: `Twin Bays Splash Arena`  
Contract version: `2`
Layout SHA-256: `211ed22c8b9a3af358ec2058bbabf2a976b7a2158d1f18f887bebd9cd966217a`

## Authority order

1. `resources/maps/twin_bays_layout_v1.json` and the current Godot production
   scene own gameplay geometry, collision, semantic placement, and camera.
2. `twin_bays_as_built_reference_v1.png` remains the human-readable
   structure, composition, and camera reference. It was built from a frozen
   Godot empty-scene capture, not generated from concept art.
3. `twin_bays_splash_arena_selected_background.png` is **Mood Reference Only**.
   It may inform palette, material language, rounded forms, water-park backdrop,
   and party-shooter tone, but never geometry or gameplay placement.
4. `twin_bays_art_v3.json` owns surface, lighting, backdrop, asset-budget, and
   tide-art direction. `twin_bays_tide_v1.json` continues to own tide timing
   and gameplay modifiers.
5. If any image conflicts with the canonical layout or current production
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
- Warm cream gameplay floor while dry. During the configured tide cycle the
  platform may carry one full-deck shallow-water surface and source-connected
  retreat residue; these remain visual-only except for the separately frozen
  high-tide movement modifier.

Any structural change invalidates this contract and requires a new versioned
as-built source capture, reference sheet, manifest, review, screenshots, and
Golden baseline.

## Mood-reference prohibitions

The following retired details visible in earlier concepts must not return:

- corner towers or high pillars;
- legacy wall-mounted portals instead of the paired water pipes;
- retired inner covers or removed south wall sections;
- zig-zag portal-side wall geometry;
- static ellipse puddles, painted splash decals, or water unrelated to the
  configured tide and runoff sources;
- legacy pickup placement or spawn rules.

## Rebuild and validation

Run `python tools/build_twin_bays_as_built_reference.py` to reproduce the sheet
from the frozen source. Replacing that source requires the explicit
`--refresh-source` flag and therefore a renewed owner review.

Release validation binds layout, Art V3, Tide V1, the generated asset manifest,
reference manifest, frozen source, mood image, and final reference image.
Dynamic water and lighting are not compared pixel-for-pixel; structural and
semantic verifiers remain authoritative. Art V3 Hero and full-map approval are
separate SHA-bound gates, and neither gate may update Golden implicitly.
