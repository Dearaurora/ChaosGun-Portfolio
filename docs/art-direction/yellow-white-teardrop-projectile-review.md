# Yellow-White Teardrop Projectile Contract

## Decision

All six weapons share one readable projectile language:

- rounded leading head;
- one tapered rear point;
- warm-yellow outer body;
- warm-white inset core;
- short yellow-and-white wake overlapping the rear half of the body.

Weapon identity may change projectile scale and wake length. It must not recolor
the projectile, replace the silhouette with a cone, or add fork/lance accents.
Muzzle flashes and hit effects retain weapon-specific color and shape.

## Implementation

- `CombatVisualResourceCache.teardrop_mesh()` authors a planar silhouette on the
  gameplay plane so the approved outline survives every camera pitch.
- `Projectile` uses the same silhouette for its moving body and two connected
  wake layers.
- `ShotTracer` uses a larger, short-lived instance of the same silhouette as a
  motion readability cue. It no longer renders the previous colored fork,
  lance, pellet-wing, or tapered-streak variants.
- Meshes and materials remain immutable shared resources; this visual correction
  does not restore per-shot resource allocation.

## Evidence

- `reports/projectile_teardrop_showcase_v3.png`: enlarged six-weapon silhouette review.
- `reports/yellow_white_teardrop_combat_language.png`: muzzle, tracer, and hit-language comparison.
- `reports/projectile_teardrop_gameplay_final.png`: production camera and arena-floor review.

## Automated Gates

- `projectile_visual_profile_verifier.gd`
- `shot_tracer_visual_verifier.gd`
- `weapon_shot_tracer_integration_verifier.gd`
- `combat_effect_resource_reuse_verifier.gd`
