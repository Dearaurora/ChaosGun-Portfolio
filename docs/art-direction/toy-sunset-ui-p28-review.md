# P28 Toy-Sunset UI Review

## Verdict

PASS for Open Ring-Out. The live HUD and every player-facing flow now use one
compact toy-sunset interface language without the previous nested black cards,
neon glow, or disconnected result treatment.

## Delivered

- Added one shared palette and style resource in `toy_sunset_ui.gd`.
- Rebuilt the four-player HUD around a `200x72` base panel with one translucent
  warm-plum surface, a player-color rail, avatar, lives, weapon silhouette, and
  ammunition. The old nested weapon box and progress bars are gone.
- HUD scale follows viewport height and is clamped to `0.85-1.15`.
- `RingoutHUD.camera_occlusion_rects()` now returns the actual scaled footprint,
  including margin and an eight-pixel gameplay gutter.
- Rebuilt pause and result presentation with a light full-screen wash, compact
  controls, a flat statistics table, and no card nesting.
- Rebuilt the main menu, local character setup, and keybind screen around the
  approved sunset backplate. Player 3 and Player 4 keybinds remain collapsible.
- Preserved `VictoryScreen.show_victory(...)`, restart/menu actions, keybind
  behavior, HUD data flow, and camera occlusion integration.

## Locked Visual Rules

- Projectiles remain yellow-white teardrops with a tapered wake.
- Clouds remain single visible volumes without a detached dark lower layer.
- Open Ring-Out may not restore four oversized black HUD cards.
- Legacy map HUD rollout remains deferred until the P31 Open Ring-Out sample is
  frozen; P28 does not silently reskin other maps.

## Fixed Evidence

- `reports/p28_gameplay_1280x720.png`
- `reports/p28_gameplay_1536x960.png`
- `reports/p28_gameplay_1920x1080.png`
- `reports/p28_gameplay_2560x1440.png`
- `reports/p28_pause.png`
- `reports/p28_result.png`
- `reports/p28_menu.png`
- `reports/p28_keybinds_expanded.png`
- `reports/p28_character_select.png`

## Verification

- `p28_ui_system_verifier.gd`: PASS at 1280x720, 1536x960, 1920x1080, and
  2560x1440. All four HUD panels stay in frame, do not overlap, and remain
  enclosed by their camera-avoidance rectangles.
- `local_keybinds_verifier.gd`: PASS.
- `open_ringout_slice_verifier.gd`: PASS.
- `open_ringout_camera_verifier.gd`: PASS.
- `open_ringout_match_presentation_verifier.gd`: PASS.

## Next Gate

P29 replaces the current reconstructed character surface with one clean,
continuous subdivision shell while preserving the verified skeleton, actions,
weapon contacts, anchors, palette swaps, and runtime asset path.
