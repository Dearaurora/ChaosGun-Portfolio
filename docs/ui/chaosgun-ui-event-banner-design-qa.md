# ChaosGun Match Event Banner Design QA

## Comparison target

- Source visual truth:
  - `reports/ui_redesign/ready_1920x1080.png`
  - `docs/ui/references/chaosgun-character-select-selected-v2.png`
  - `resources/ui/chaosgun_theme.tres`
- Previous problem evidence:
  - `reports/ui_inventory_audit/05-tide-warning.png`
- Implementation:
  - `reports/ui_event_banner/ready-open-1920x1080.png`
  - `reports/ui_event_banner/ready-twin-1920x1080.png`
  - `reports/ui_event_banner/tide-warning-1920x1080.png`
  - `reports/ui_event_banner/tide-warning-hud-1920x1080.png`
  - `reports/ui_event_banner/tide-warning-1280x720.png`
- Same-state comparisons:
  - `reports/ui_event_banner/ready-before-after.png`
  - `reports/ui_event_banner/tide-warning-before-after.png`

## Normalization

- READY source: 1920×1080 pixels.
- READY implementation: 1920×1080 pixels.
- Tide-warning before/after: 1920×1080 pixels.
- Responsive evidence: 1280×720 pixels.
- Native Godot viewport, density 1; browser and CSS density do not apply.

## States

- Open Ring-Out READY with four-player pips.
- Twin Bays READY with four-player pips.
- Twin Bays high-tide countdown with and without the live four-player HUD.
- High-tide event dismissal when the tide enters the rising phase.

## Full-view comparison

- READY retains the approved centered hierarchy, dark plum surface, cream/gold type and horizontal rails.
- The authored scene is slightly wider than the previous scripted surface so it can also carry localized event titles and subtitles.
- Twin Bays warning now uses the same component language while remaining outside all four HUD corner budgets.
- The previous naked English label is replaced by “涨潮 2” and the action cue “离开低洼区”.

## Focused-region evidence

- The banner screenshots were inspected at their original 1920×1080 and 1280×720 pixel sizes.
- A separate crop was unnecessary because the title, kicker, subtitle, border and rails are all readable at native resolution.
- `tide-warning-hud-1920x1080.png` confirms the banner remains independent from the live HUD and characters.

## Required fidelity surfaces

- Fonts and typography: existing Godot UI font path is preserved; 36px event title, 11px kicker and 13px action text maintain the established hierarchy without clipping.
- Spacing and layout rhythm: 600×132 authored component, centered or top-center placement, 300×88 surface, symmetrical rails and optional player-pip row.
- Colors and tokens: shared plum panel, cream text, gold event accent and player colors come from the existing ChaosGun theme/ToySunsetUI constants.
- Image quality and assets: the component introduces no new raster or placeholder imagery; live map, character and HUD assets remain unchanged.
- Copy and content: READY/GO remain short competitive terms; high tide is localized and includes an actionable Chinese instruction.

## Iteration history

1. Initial warning capture exposed a P2 first-frame contrast issue because the entry animation began at zero opacity.
2. The component now begins at 78% opacity and reaches full opacity in 140ms, keeping urgent information readable on its first rendered frame.
3. Post-fix evidence:
   - `reports/ui_event_banner/tide-warning-1920x1080.png`
   - `reports/ui_event_banner/tide-warning-1280x720.png`
   - `reports/ui_event_banner/tide-warning-hud-1920x1080.png`

## Findings

- No actionable P0, P1 or P2 issue remains.
- P3: the subtitle is intentionally compact to keep the map center unobstructed; it remains readable at the 1280×720 validation size.

## Verification

- `match_event_banner_verifier.gd`: PASS at 1280×720, 1536×960, 1920×1080 and 2560×1440.
- `twin_bays_match_event_banner_verifier.gd`: PASS.
- Open Ring-Out match presentation: PASS.
- Twin Bays match presentation: PASS.
- Twin Bays tide mechanics: PASS.

final result: passed
