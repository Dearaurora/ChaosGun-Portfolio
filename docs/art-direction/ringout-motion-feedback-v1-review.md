# Ringout Motion Feedback V1 Review

## Goal

Connect character hit feedback to the final ring-out with readable states for launch velocity, edge danger, falling danger, and elimination.

## State Logic

- `LAUNCHED`: two short white streaks appear only during the 0.52 second post-knockback window while airborne.
- `EDGE WARNING`: a red floor ring and two forward chevrons appear when a fast grounded character is moving toward missing floor.
- `FALLING`: the same warning remains active below the platform while descending; recent knockback can keep the short streaks visible.
- `RING-OUT`: the existing red transition burst plays at the last safe visible position and removes itself in 0.24 seconds.

## Constraints

- No changes to impulse, gravity, air control, fall threshold, lives, or respawn timing.
- Ordinary grounded movement does not show flight streaks.
- Ordinary jumping does not open the knockback trail window.
- All new geometry is deterministic and does not cast shadows.
- Warning state is cleared immediately on death and respawn.

## Evidence

- `reports/ringout_motion_feedback_final.png`
- `reports/ringout_motion_feedback_gameplay_final.png`

## Acceptance

- Flight direction remains readable at gameplay camera scale.
- Edge warning contrasts against the orange arena without resembling a weapon pickup.
- Falling combines danger and velocity feedback without adding particles or persistent motes.
- Final ring-out remains the strongest state in the sequence.
