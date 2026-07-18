# P27 Match Presentation Memory

## Decision

After P26 render consolidation, match presentation was selected over another prop pass because scene entry and match exit were still abrupt and affected every play session.

## Stable Contract

- Intro reveal duration: `1.35s`.
- Open Ring-Out reveal focus: `(-4.5, 1.0, -6.5)`.
- Open Ring-Out reveal size: `76.0`.
- Winner focus duration before result handoff: `0.78s`.
- Winner camera move duration: `0.72s`.
- Winner focus size: `29.5`.
- Result-focus HUD opacity: `0.22`.
- Intro copy: `READY`, then `GO!`.
- Spawn and winner accents use the configured player slot color.
- Presentation overrides must hand control back to the adaptive camera after the reveal.
- Gameplay camera min/max, collision, spawn positions, loadouts, and weapon tuning must not be changed by this layer.

## Implementation Notes

- Presentation belongs in the shared camera director as an override state, not as a competing camera Tween.
- The winner state holds its target until the result screen pauses the tree.
- Unscaled timers keep presentation timing stable during gameplay time-scale effects.
- Ground-level transient rings are acceptable; persistent overhead rings are not part of this language.
- Match transition nodes use readable runtime names so automated checks can count all four simultaneous effects.

## Evidence

- `reports/p27_match_intro_ready.png`
- `reports/p27_match_intro_go.png`
- `reports/p27_winner_focus.png`

P27 closed with all ten focused and cross-map checks passing.
