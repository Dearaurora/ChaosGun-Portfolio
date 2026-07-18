# Twin Bays Splash Arena human review

Review date: `2026-07-18`  
Reviewer: `Project-owner approval recorded; Codex automated evidence closure`  
Build/revision: `codex/art-vertical-slice-v2 working tree`  
Production capture: `reports/twin_bays_splash_arena_battle_1920x1080.png`  
Portal/background capture: `reports/twin_bays_splash_arena_portal_1920x1080.png`  
1280x720 framing capture: `reports/twin_bays_splash_arena_mobile_1280x720.png`  
Automated validation log: `reports/twin_bays_release_validation.log` (Quick rendered development PASS)  
Formal AI evidence: `reports/twin_bays_splash_arena_ai_batch.json` (PASS)  
Formal performance evidence: `reports/twin_bays_splash_arena_performance.json` (PASS)

The project owner approved the current visual result on `2026-07-18`. The
existing implementation-side score is therefore finalized at `34/40`: no item
is below 3, and fidelity, party-shooter tone, background, and gameplay
readability are each at least 4.

## Current owner-review package

P23-P28 implementation and validation details are recorded in
`docs/art-direction/twin-bays-p23-p27-implementation-review.md`. Its 11 listed
captures cover empty, battle, general portal, left/right portal close-ups,
1280x720, ambient-motion start/end, intro READY/GO, and winner focus.

The owner-approved dual-authority package adds
`docs/art-direction/references/twin_bays/twin_bays_as_built_reference_v1.png`.
It uses the frozen Godot empty capture for structure/camera and labels the old
concept as Mood Reference Only. The canonical layout and production scene win
every conflict; retired concept geometry must not return.

All 11 files are review candidates. No Twin Bays Golden baseline has been
created. Formal AI and matched D3D12 performance have passed, and the Quick
rendered runner produced all 11 candidates; final RELEASE PASS still requires
explicit first-Golden creation and a complete no-update rerun.

Technical closure notes: all 12 embedded PBR maps now use Basis Universal,
resolving the earlier approximately `1.28x` relative video-memory ratio (about
`77 MiB` above Open Ring-Out on the prior Vulkan import path). The formal
Twin Bays performance result is `215.81 FPS` average, `70.60 FPS` 1% low,
`0.521/0.235/0.405` draw-call/primitive/render-memory ratios, `1.29 MiB`
drift, and process exit `0` without leak warnings.

| Category | Score | Evidence / correction |
| --- | ---: | --- |
| Reference fidelity | 4 | Approved H silhouette, holes, safe middle, revised 10-cover layout, four ordinary pads, center-special pad, perimeter walls, and vertical portals are retained. |
| Party-shooter tone | 5 | Large toy-like color fields, rounded cover language, readable hazards, and playful peripheral props. |
| Background design | 4 | Dynamic cyan water, deeper bay water, palm islets, rings, buoys, and slide ends support the water-park venue without cluttering combat. |
| Composition/framing | 4 | Four spawn regions and both portals remain in frame at 1920x1080 and 1280x720. |
| Geometry quality | 4 | Curved 116-point deck, safe 16-unit middle, six clean wall sections, open south fall routes, and 10 cover anchors pass structural/collision verification. |
| Materials/lighting | 4 | Dry cream floor, aqua/coral/yellow/orange hierarchy and contact shadows are clear; lighting remains deliberately simple and low-noise. |
| Gameplay readability | 5 | Characters, held guns, holes, yellow edges, covers, pickup points, and portals remain distinct under the runtime camera. |
| Completion/polish | 4 | Production GLB, portal VFX/SFX, dynamic backdrop, captures, deterministic builder, and release automation are present. |
| **Total / 40** | **34** | Meets the numeric gate; project-owner sign-off recorded on 2026-07-18. |

## Veto review

- [x] Gameplay floor is visibly dry: no splash paint, wet stain, puddle, wet Decal, wetness mask, or standing-water gloss.
- [x] Portal is depth-tested and does not show through its tower/wall.
- [x] No false visible edge exists over the safe central collision.
- [x] Four characters and current gun silhouettes remain readable at the production camera.
- [x] No doubled whitebox/production surface or z-fighting is visible.

## Decision

- [x] Implementation is ready for owner art review and playtest.
- [x] P23-P27 implementation evidence and the 11-image review package are present.
- [x] Formal AI `8 x 30 s` passes at `8/8` armed, `8/8` kill, `8/8` ring-out rounds, with 21 portal events and zero invalid-state/leak findings.
- [x] Formal D3D12 Forward+ performance passes, and the Quick rendered runner completes all 11/11 candidates.
- [x] Project owner has approved the subjective art gate.
- [ ] Owner-approved candidates have been explicitly promoted to the first Golden baseline.
- [ ] A complete no-update full runner has proved the Golden remains unchanged and produced final RELEASE PASS.

Known limitations: background scenery is intentionally low-poly and peripheral; portal use by AI is observational; there is no map music, water ambience, swimming, bullet teleport, or floor wetness in this scope.  
Follow-up skin hook: characters and guns continue to use `party_shooter_v1`; map-themed skins remain a separate future task.  
Reviewer signature: `Project-owner approval recorded; Codex evidence closure`
