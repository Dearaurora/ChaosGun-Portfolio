# Twin Bays Art V4 Convergence Review

> **REJECTED BY PROJECT OWNER — 2026-07-24**
>
> The fixed-camera concept comparison shows that Art V4 did not materially
> converge on the approved toy-waterpark reference. The earlier `38/40`
> score and automatic stop decision are withdrawn. This document is retained
> only as historical evidence of the rejected pass; it is not an approval or
> Golden candidate. The reset evidence is
> `reports/twin_bays_art_v5/concept_gap_triptych.png`, and the new
> camera-matched target is
> `docs/art-direction/concepts/twin_bays_art_v5_camera_target.png`.

## Outcome

The following outcome was the superseded automatic assessment and is no longer
accepted. Art V4 remains the current runtime fallback only until a corrected
candidate passes concept-fidelity review. It preserves the
Art V3 rollback assets and all gameplay-owned structure while improving the
full-match camera in three retained passes:

1. warmer key light, cooler fill, contact shadows, tile scale, wall panels,
   padded coral highlights and stronger yellow safety edges;
2. deeper bay water, lower-noise caustics, stronger platform/water separation,
   clearer peripheral islands, palms, rings, buoys and slide silhouettes;
3. thicker segmented portal pipes and a dedicated clear-water material that
   removes the grey paint-like drain residue.

The former **38/40** stop claim is invalid. The missing changes are visible at
normal match scale: padded silhouette thickness, portal staging, platform/water
contact, water depth hierarchy and peripheral waterpark storytelling. Golden
evidence was not created or replaced.

## Frozen authority

| Authority | SHA-256 |
| --- | --- |
| Layout V1 | `211ed22c8b9a3af358ec2058bbabf2a976b7a2158d1f18f887bebd9cd966217a` |
| Tide V1 | `45caaa9ea785b9bd136e0839cae20bf6ba70a662c949119484e04d32c84b7a46` |
| Art V3 profile | `ccbaba05cf471e400f1102318ae44defa886133bf484d8cbf3cbb645db68cd3d` |
| Art V3 foreground | `d6e8602acda03c65cf10358b8a18de0857e0a7c39c72a9de201b46a7a4a0aba7` |
| Art V3 water shader | `5e3329ba02d99bc9d7dccd473a40fcff744857c4d859ddc93c780b991500f6ce` |
| Art V3 backdrop shader | `864c4500b4568555ace675d1c911d7d0dbde2d62672057e191f683c13d6bba07` |

The V4 contract verifier re-hashes every frozen V3 authority before passing.

## Convergence record

| Pass | Highest-value gap | Decision | Evidence |
| --- | --- | --- | --- |
| V4-01 | Overexposure and flat foreground | Rejected | Water caustics competed with players despite improved lighting. Preserved under `reports/twin_bays_art_v4/rejected_pass_01/`. |
| V4-02 | Background water noise and shallow depth | Retained | Reduced caustic dominance while keeping stronger wall, deck and bay depth. Preserved under `reports/twin_bays_art_v4/pass_02_best/`. |
| V4-03 | Grey, opaque-looking drain residue | Retained / final | Separate V4 clear-water shader converts the residue to a thin gloss/aqua layer without changing Tide V1. |

## Score

The historical `37/40` is retained only as an approval record. Both versions
were re-scored from the current fixed production captures.

| Category | Art V3 | Art V4 | Result |
| --- | ---: | ---: | --- |
| Reference fidelity | 4 | 5 | Stronger toy-water-park materials and silhouettes |
| Party-shooter tone | 4 | 5 | Coral, gold, aqua and cream now separate cleanly |
| Background / periphery | 4 | 5 | Deeper bay, clearer islands, props and slide ends |
| Composition / depth | 4 | 5 | Contact shadows and dark structural sides restore layers |
| Geometry finish | 4 | 4 | Pipe bands, collars and insets improve the match camera; close-up sculpt remains P3 |
| Materials / lighting | 4 | 5 | PBR tile/pad response and profile-driven key/fill |
| Gameplay readability | 5 | 5 | Four players, HUD, pickup markers and danger edges remain clear |
| Completion / polish | 4 | 4 | Production-ready at match scale; specialist close-up polish remains |
| **Total** | **33/40** | **38/40** | **Stop gate reached** |

No category regressed, no category is below 4, and Gameplay Readability remains
5. The next deterministic changes would be close-up-only, so both the score gate
and diminishing-return gate are satisfied.

## Production assets and budgets

- Art profile: `resources/maps/twin_bays_art_v4.json`
- Editable Blender source:
  `assets/source/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4.blend`
- Production foreground:
  `assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_foreground.glb`
- Production manifest:
  `assets/models/generated/twin_bays_splash_arena_v4/twin_bays_splash_arena_v4_manifest.json`
- V4 clear-water shader: `assets/shaders/twin_bays_water_master_v4.gdshader`
- V4 backdrop shader: `assets/shaders/twin_bays_backdrop_water_v4.gdshader`

Measured production budgets:

| Budget | Result |
| --- | ---: |
| Primary materials | 8 / 12 |
| Foreground mesh batches | 7 / 12 |
| Transparent water batches | 3 / 3 |
| Foreground triangles | 33,820 |
| Maximum texture dimension | 2,048 |
| Runtime node growth | 0 |
| Foreground collision/navigation | 0 |

The Blender pipeline produced byte-identical hero GLB, foreground GLB, 24 PBR
texture files and manifest on the repeated-build gate. GPU previews and Blender
container metadata are review/source artifacts and are explicitly outside that
byte-determinism scope.

## Runtime invariants

The following remain unchanged:

- `TwinBaysSplashArena`, `apply_art_profile(Dictionary)` and
  `set_tide_level(...)` interfaces;
- Layout V1, collision, camera rules, portal gameplay, AI, player/weapon data,
  UI and Tide V1 timing/levels/motion modifiers;
- 0.90 high-tide speed multiplier and 1.25 horizontal damping multiplier;
- no static puddles on dry ground;
- all new scenery is visual-only and outside the combat collision contract.

## Evidence

- Four-player Before/After:
  `reports/twin_bays_art_v4/comparisons/v3_v4_battle_comparison.png`
- Tide-state Before/After:
  `reports/twin_bays_art_v4/comparisons/v3_v4_tide_state_matrix.png`
- Production contact sheet:
  `reports/twin_bays_art_v4/comparisons/v4_production_contact_sheet.png`
- Frozen V3 matrix: `reports/twin_bays_art_v4/before/`
- Final production matrix: `reports/twin_bays_art_v4/production/`

The production matrix includes dry, warning, rising, high, falling, drain
0/9/18 seconds, 1920×1080 four-player gameplay, 1920×1080 portal and 1280×720
HUD-safe captures.

## Verification

- `TWIN_BAYS_ART_V4_DOUBLE_BUILD_IDENTICAL_PASS files=27`
- `TWIN_BAYS_ART_V4_PROMOTION_PASS`
- `TWIN_BAYS_ART_V4_CONTRACT_PASS`
- Twin Bays quick release suite:
  `DEVELOPMENT PASS (release gates skipped)`
- AI 8×30-second batch: PASS — 8 armed rounds, 8 kill rounds, 8 ring-out
  rounds, 16 portal events, 0 stuck characters and 0 invalid frames
- D3D12 Forward+ 1920×1080 matched performance gate: **ENVIRONMENT FAIL**.
  The required retry again lost/minimized the host window, so it is not recorded
  as a formal PASS. The offscreen Twin Bays diagnostic itself measured
  239.12 average FPS, 116.27 1% low, 1.08 MiB memory drift and relative
  draw/primitive/render-memory costs of 0.767 / 0.366 / 0.410. Those values
  clear every art budget, but remain diagnostic because focus evidence failed.

## Stop reason and specialist handoff

Automatic upgrading stops because the required total score has been reached and
all remaining gaps are P3:

- unique hand-painted wear/roughness variation for portal collars;
- a bespoke sculpted foam seat and pipe throat for close-up marketing shots;
- additional authored prop storytelling beyond the existing islands, rings,
  buoys and palms.

Those changes are not reliably visible in the normal four-player camera and
would require specialist sculpting or hand-painted texture art. They are not
worth adding to the deterministic runtime pipeline in this pass.

Golden remains unchanged and must be confirmed separately by a human reviewer.
