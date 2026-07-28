# Twin Bays Art V5 Camera Convergence Review

## Status

Art V5 is an isolated review candidate aligned to the approved production-camera
target. It has not replaced Art V4, has not updated Golden evidence, and has not
changed layout, collision, camera, tide gameplay, AI, UI, characters, or weapons.

The production-camera capture matrix is complete. Godot used the real Forward+
renderer with a hidden root window; all 1280x720, 1536x1024 and 1920x1080
evidence came from off-screen viewports. No visible game window was shown.

Art V5 is the best retained deterministic candidate. Production promotion and
Golden replacement remain human approval gates because the project owner
previously rejected Art V4 on concept fidelity.

## Visible convergence

- Replaced thin wall-cap strips with continuous rounded coral sweeps and
  camera-readable visual module seams.
- Added a deeper dark-cyan platform skirt and a coral lower bumper at the
  camera-facing platform edge.
- Added broken contact foam and foam clusters at the waterline.
- Enlarged portal shells, collars, throats, and the three-layer water-entry
  footprint; added a profile-driven cascade and emissive droplets without
  changing portal gameplay coordinates or VFX node count.
- Added visual-only palm islets, water towers, slide ends, inflatable rings, and
  buoy lines inside the production camera's peripheral band.
- Increased cream tile definition, warm-key/cool-fill separation, bay depth,
  authored broad caustics, and tide-water color separation.
- Replaced the flat/cracked procedural backdrop pattern with one deterministic
  1024 texture mask sampled by the runtime water shader. This keeps a large,
  camera-readable water language without adding a material batch.
- Replaced opaque portal-entry "foam rope" with broken translucent contact
  rings and a dedicated V5 portal-water shader. The gameplay portal nodes and
  transfer coordinates remain unchanged.
- Preserved the no-static-dry-puddle rule. Residual water remains tide-owned.

## Evidence

- Approved target:
  `docs/art-direction/concepts/twin_bays_art_v5_camera_target.png`
- V4 / approved target / V5 Godot runtime:
  `reports/twin_bays_art_v5/v4_target_v5_runtime.png`
- Final runtime matrix:
  `reports/twin_bays_art_v5/final_contact_sheet.png`
- Accepted/rejected iteration board:
  `reports/twin_bays_art_v5/industrial_iteration_review.png`
- Portal detail:
  `reports/twin_bays_art_v5/candidate/v5_portal_close_1920x1080.png`
- Latest deterministic candidate preview:
  `assets/review/twin_bays_art_v5/candidate/twin_bays_art_v5_foreground.png`
- Editable source:
  `_art_source_review/twin_bays_art_v5/twin_bays_art_v5_review.blend`
- Candidate manifest:
  `assets/review/twin_bays_art_v5/candidate/twin_bays_art_v5_manifest.json`

## Budgets

| Contract | Result |
| --- | ---: |
| Foreground mesh batches | 10 / 12 |
| Candidate material union | 11 / 12 |
| Foreground triangles | 101,580 |
| Editable source meshes | 236 |
| Export mesh reduction | 95.76% |
| Visual-only cap seams | 18 |
| Maximum texture dimension | 2,048 |
| Foreground collision/navigation | 0 |
| Runtime node growth | 0 |

## Determinism and protection

- Hero GLB, foreground GLB, 12 generated PBR maps, the backdrop-caustic
  texture, and manifest are
  byte-identical on the stable-input rebuild gate.
- Art V4 profile, Blender source, hero GLB, foreground GLB, and manifest remain
  byte-identical to the protected hashes recorded by the V5 manifest.
- Current candidate hashes:
  - profile: `0675bbccbf1bbecf28a856c71e4ebd557499912465829ca538454f93d8c943f5`
  - foreground: `132c1ea0627660fc0c91030518bb3ed8fbbf913a4ecc57630024038b4bf0ef39`
  - hero: `110b4046d2451b509f4e1d57dade6bc9b123a21623159dffca4781a589c9a25e`
  - caustics: `8e6306320338dec445dfe0dc0d5d4546fadfa5d8b5cb5154a7d6706861246f6d`
  - manifest: `984bb28eda567aada915f479acb60df70e62851c865702036de34260b29b8860`

## Headless verification

- `TWIN_BAYS_ART_V5_RUNTIME_CONTRACT_PASS`
- `Twin Bays Art V5 Review Verifier PASS`
- `Twin Bays Geometry Integrity Verifier PASS`
- `TWIN_BAYS_TIDE_VERIFY_PASS`
- `TWIN_BAYS_SHALLOW_WATER_VERIFY_PASS`
- `Twin Bays Camera Verifier PASS`
- `Twin Bays Splash Arena Runtime Verifier PASS`
- `Twin Bays Splash Arena Release Verifier PASS`
- `Twin Bays Environment Ambient Motion Verifier PASS`
- 2 x 5-second AI smoke: PASS, one portal event, zero stuck characters
- `TWIN_BAYS_ART_V5_FINAL_DUAL_BUILD_STABLE_PASS`

The geometry audit retains a 0.305177 portal inset, 1.963492 wall/pipe
clearance, 0.220999 portal aperture clearance, 9.894314 minimum pipe bend
radius, and zero causeway overlap.

The corrected hidden D3D12 Forward+ diagnostic used a real 1920x1080
`UPDATE_ALWAYS` off-screen viewport, a 10-second warmup and a 60-second sample.
It measured 144.92 average FPS, 101.58 1% low, 8.79 ms p99 and 0.00 MiB memory
drift, with no focus loss, minimization, or orphan-node growth. The earlier
960x540 report is retained as superseded evidence rather than mislabeled as
1080p.

A headless Windows host exposes zero GPU draw/primitive/video-memory counters,
so the formal relative-render-cost ratio is not claimed from this run. Absolute
performance passes; relative cost remains an explicit evidence limitation:

- `reports/twin_bays_art_v5/performance_industrial_pass_v5_1080p.json`

## Industrial iteration record

| Pass | Decision | Production lesson |
| --- | --- | --- |
| Frozen before | Baseline | Judge every change at the production camera, not in a material preview |
| Large procedural cells | Rejected | More contrast produced a cracked-ice language, not pool caustics |
| Long flowing lines | Rejected | Motion direction alone produced noodle-like graphics |
| Deterministic authored caustic mask | Retained | Offline shape control plus low-cost runtime motion reads at match scale |
| Portal contact / water material | Retained | Correct material semantics beat more prop count; translucent broken contact reads as water |
| Global soft-light pass | Rejected | Softer shadows flattened covers, platform mass, and character contact |

The iteration method follows the same high-level priorities described in
Riot's official environment-art production notes: protect gameplay clarity,
control value and contrast, review through regular playtests, spend detail
outside the core gameplay read, and measure performance. Their Ascent
retrospective also stresses failing fast and keeping the gameplay zone clean
while composition supports navigation.

- https://playvalorant.com/en-gb/news/dev/the-art-of-valorant-map-environments/
- https://playvalorant.com/en-gb/news/dev/the-birth-of-ascent/

Compared with a top-tier environment-art team, this candidate now has the
right production controls—frozen gameplay authority, deterministic source,
isolated candidates, same-camera evidence, rejected-version retention, and
runtime budgets—but it still lacks specialist-authored finish: bespoke
waterline masks, sculpted portal throats/foam, hand-shaped slide ends, and
high-density peripheral storytelling.

## Score and stop decision

| Category | Art V4 rejected capture | Art V5 | Result |
| --- | ---: | ---: | --- |
| Reference fidelity | 3 | 4 | Rounded cap mass, wet retreat state and waterpark periphery now follow the approved target |
| Party-shooter tone | 4 | 5 | Coral, aqua, cream and yellow read as one toy-waterpark kit |
| Background / periphery | 3 | 4 | Islands, palms, towers, slides and buoy lines frame the production camera |
| Composition / depth | 4 | 5 | Dark skirt, bay walls, bumper and contact foam restore foreground/midground separation |
| Geometry finish | 3 | 4 | Continuous swept caps and thicker portal assemblies hold at match scale |
| Materials / lighting | 4 | 5 | Authored caustics, water-depth hierarchy and translucent contact materials now hold at match scale |
| Gameplay readability | 5 | 5 | Four characters, HUD, covers, pickups and danger edges remain clear |
| Completion / polish | 3 | 4 | Full tide/runtime matrix is coherent; close-up sculpt remains specialist work |
| **Total** | **29/40** | **36/40** | **Professional-finish stop** |

Automatic iteration stops at **36/40**, not because the 38-point score gate was
reached, but because the remaining normal-camera gap is no longer a safe
parameter or procedural-geometry adjustment:

- the target's hero foam/splash motifs need hand-painted masks or decals;
- portal collars, throat foam, slide ends and peripheral props need bespoke
  sculpting and authored breakup;
- matching the target's portal staging more closely would require changing the
  frozen layout or portal mouth placement;
- the rejected global-soft-light candidate shows that the remaining lighting
  difference cannot be fixed with a single global parameter pass without
  flattening gameplay contact;
- the formal relative GPU-cost gate needs valid GPU counters, which the
  requested headless host does not expose.

Further automatic edits would either be visible only in close-up, violate a
frozen interface, trade gameplay readability for decorative noise, or require
specialist hand-authored assets. Art V5, all rejected passes, the rejected Art
V4 capture and the approved target are preserved for a professional
environment-art handoff. Golden remains unchanged.
