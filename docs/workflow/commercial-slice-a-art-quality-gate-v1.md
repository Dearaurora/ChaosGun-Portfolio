# Commercial Slice A Art Quality Gate V1

Last updated: 2026-04-26

## Purpose

Every visual change to `Commercial Slice A` must be judged against an explicit art bar before it is considered done. The old standard was too low: it proved that the map had some reference-inspired elements, but it did not prove that the final image looked close enough to the reference.

This gate separates objective regression checks from human visual judgment. Passing scripts is necessary, but not sufficient.

## Non-Negotiable Target

The map should read as a polished soft toy-board arena in the same broad visual family as the supplied Boomerang Fu reference:

- Soft pastel grass field with low visual noise.
- Lavender-blue rounded maze walls that look intentionally authored, not like scattered primitives.
- Warm wooden bridge/connectors that clearly show routes.
- Readable cliffs and empty gaps between islands.
- Peripheral trees, rocks, and foliage that frame the board without cluttering combat lanes.
- Fixed top-down camera composition that makes the whole arena feel designed as one board.

## Quality Score

Each visual iteration receives a score from 0 to 5 in each category. A visual pass is not accepted unless:

- Total score is at least 32 out of 40.
- No category scores below 3.
- Reference Fidelity, Composition, and Geometry Language are each at least 4.

| Category | 1 | 3 | 5 |
| --- | --- | --- | --- |
| Reference Fidelity | Only borrows colors loosely | Recognizably inspired by the reference | Immediately reads as the same soft toy-board family |
| Composition | Elements feel scattered | Board shape is readable | Whole screen has intentional framing and rhythm |
| Geometry Language | Boxy/prototype primitives dominate | Some rounded low-wall language | Rounded walls, islands, bridges, and props feel cohesive |
| Color And Lighting | Washed out or mismatched | Palette is mostly controlled | Soft pastel contrast matches the reference mood |
| Ground Treatment | Flat grass slab | Some patches and variation | Hand-painted-looking field with subtle readable variation |
| Prop Integration | Props look pasted on | Props frame the arena | Props support silhouette, depth, and edge framing |
| Gameplay Readability | Art hides routes or cliffs | Routes remain understandable | Routes, cliffs, pickups, and cover are clearer because of art |
| Polish Density | Sparse prototype feel or clutter | Acceptable density | Dense enough to feel authored, sparse enough to play |

## Automated Minimum Gates

The whitebox verifier must fail if any of these regress:

- Fixed camera policy changes.
- Main map scale regresses below the enlarged target.
- Grass, bridge, and wall palette leave the accepted pastel ranges.
- Off-style props return.
- Soft wall shells disappear.
- Grouped decorative shell count falls below the current threshold.
- Decorative grouped shells gain collision.
- Ground patches fall below the current threshold.
- AI pickup awareness stops matching the enlarged layout.

These gates only prove the floor. They do not prove art quality.

## Manual Screenshot Review

Every visual change must include a screenshot review note before it is considered complete. The reviewer compares the current map to the supplied reference and records:

- Current total score and per-category scores.
- The three largest visual gaps.
- Whether the change improved or harmed the score.
- A clear pass/fail decision.

## Current Map Assessment

Current score estimate after the wall-cap pass: 28 out of 40. This is below the acceptance bar.

| Category | Score | Current Issue |
| --- | --- | --- |
| Reference Fidelity | 3 | Island edges and ground layering are closer, but wall/corner richness and prop framing still lag. |
| Composition | 3 | Enlarged board reads better, but edge framing and negative space are still crude. |
| Geometry Language | 4 | Island edges and wall caps reduce the primitive read, but the wall network still needs stronger authored composition. |
| Color And Lighting | 3 | Brightness is controlled, but the scene lacks the reference's soft color layering. |
| Ground Treatment | 3 | Island shadows and path-wear layers help, but the field still needs more authored paint and edge softness. |
| Prop Integration | 3 | Nature props are on-theme, but they do not yet create strong foreground/background framing. |
| Gameplay Readability | 4 | Routes, cliffs, and pickups remain readable. |
| Polish Density | 4 | Ground, edge, and cap density improved, but perimeter composition is still weak. |

## Next Art Priorities

1. Replace or mask the biggest whitebox platform reads with softer island edge treatment.
2. Add stronger ground-paint layers: broad shade bands, small grass color islands, and subtle path wear near bridges.
3. Improve wall silhouette with layered caps and rounded corner pieces instead of only straight capsule shells.
4. Add perimeter framing clusters that create depth like the reference without blocking play.
5. Only then tune lighting again; lighting cannot compensate for weak geometry and composition.

## Definition Of Done For Future Visual Changes

A visual change is done only when:

- The changed category score improves or stays the same with a documented reason.
- The total art score moves toward 32 or remains above 32.
- Whitebox verification passes.
- AI smoke passes if the change can affect readability, navigation, or combat tempo.
- The validation log records the before/after assessment.
