# Character Combat Feedback V1 Review

## Goal

Complete the readable combat loop after muzzle, projectile, and impact effects without changing damage, knockback, respawn timing, or weapon balance.

## Implemented

- Replaced whole-character visibility flicker with a stable translucent cyan respawn shield.
- Reduced body hit feedback to a single 0.12 second warm-white pulse.
- Added three short directional hit slashes at the incoming side of the character.
- Replaced the old disc and sphere burst with deterministic ring-out and respawn transitions.
- Ring-out uses one dark-edged red ring, one compressed core, and six controlled rays.
- Respawn uses one cyan landing ring, one compressed core, and four controlled rays.
- Disabled shadow casting on all feedback geometry to prevent dirty marks on the arena floor.
- Ring-out effects use the last safe character position when the character has fallen below the visible play space.
- Respawn protection still resets the character to the base pistol through the existing gameplay path.

## Timing Budget

| Feedback | Duration |
| --- | ---: |
| Body hit pulse | 0.12 s |
| Directional hit slashes | 0.145 s max |
| Ring-out transition | 0.24 s |
| Respawn transition | 0.30 s |
| Respawn shield | Existing gameplay invincibility duration |

## Evidence

- `reports/character_combat_feedback_showcase_final_v3.png`
- `reports/character_combat_feedback_gameplay_final.png`

## Acceptance

- No floating shield facets, sphere motes, decals, or persistent particles.
- No whole-body flicker during invincibility.
- Hit direction remains readable without obscuring the weapon or visor.
- Transition geometry has no cast shadows.
- All transient nodes remove themselves within the timing budget.
