# Twin Bays Splash Arena task card

Owner: project owner; implementation by Codex  
Status: P23-P27 implemented; owner art approved; P28 Golden closure in progress  
Last updated: 2026-07-18

| Gate | Deliverable | Exit evidence | Status |
| --- | --- | --- | --- |
| G0 | Stable references, hashes, dry-floor contract, tool versions | Dual-authority as-built sheet/manifest, reference README, and verifier log | Complete |
| G1 | Layout JSON, loader, whitebox migration, production skeleton | `<=0.01` coordinate diff and unchanged ray samples | Complete |
| G2 | Shared party-shooter runtime and gameplay regression | Spawn/pickup/fall/respawn/pistol/result/pause/portal checks | Complete |
| G3 | Deterministic Hero Kit and manifests | Builder exit code, `.blend`, GLB, preview, material list | Complete |
| G4 | One-side integration in production camera | Finalized `34/40`; project-owner approval recorded | Complete |
| G5 | Full production foreground | Full GLB, stable anchors, no collision or duplicate whitebox visuals | Complete |
| G6 | Portals, water backdrop, peripheral props, production light | Portal/background/readability screenshot and no floor marks | Complete |
| G7 | Player map routing and release evidence | Routing, formal AI/performance, and Quick rendered evidence pass; owner approval, first Golden, and clean no-update full rerun remain | In progress |

## P23-P28 implementation status

| Phase | Implemented evidence | Status |
| --- | --- | --- |
| P23 | Layout remains frozen at SHA-256 `ea69b591ae88df766967596a18dacbcaff047c07e65b41fc008330f5e94a0227`; P24-P27 did not change gameplay coordinates or collision | Complete |
| P24 | Deterministic dry PBR: 2K cream floor and 1K cyan/dark-cyan/coral albedo-normal-roughness sets; corrected sRGB payload; all 12 PBR maps use Basis Universal when embedded in the GLBs | Complete; owner approved |
| P25 | Visual-only, out-of-phase motion: floats `<=0.12` units / `<=1.5 degrees`, palms `<=2 degrees`, pipe-entry foam/ripples `<=4%` scale | Complete |
| P26 | Editable `.blend` stays modular; GLB export batches static meshes by material, reducing production foreground `40 -> 7` while preserving 33 semantic anchors | Complete |
| P27 | Shared `PartyShooterMatchPresentation`: `1.35 s` reveal, `READY -> GO!`, `0.78 s` winner focus, HUD at `22%` | Complete |
| P28 | Formal AI `8 x 30 s` PASS; matched D3D12 Forward+ performance PASS; Quick rendered runner PASS with 11/11 captures. Owner art approval, explicit first Golden, then a no-update full rerun remain | Automated pass; release gate pending |

Implementation details and the 11-image candidate set are recorded in
`docs/art-direction/twin-bays-p23-p27-implementation-review.md`. Owner art
approval is recorded; the images remain candidates until the explicit Golden
update run succeeds.

## P28 evidence snapshot

- AI: armed/kills/ring-out rounds are `8/8`, `8/8`, and `8/8`; 21 portal
  events; zero illegal spawn, NaN/Inf, stuck, ping-pong, engine/script error, or
  shutdown leak findings.
- Matched 1080p performance: D3D12 Forward+, Twin Bays average `215.81 FPS`,
  1% low `70.60 FPS`, draw-call ratio `0.521`, primitive ratio `0.235`, render
  memory ratio `0.405`, and final-tail memory drift `1.29 MiB`. Both paired
  processes exited `0` without leak warnings.
- The 12 embedded PBR maps now use Basis Universal. This resolves the earlier
  approximately `1.28x` relative video-memory ratio (about `77 MiB` above Open
  Ring-Out on the prior Vulkan import path); the current Twin Bays
  render-memory proxy is about `457 MiB`.
- Windows now uses Godot 4.6's recommended D3D12 rendering-device driver.
- The Quick rendered runner completed with all `11/11` candidate captures. Its
  recorded result is development PASS, not RELEASE PASS.
- No Golden exists. Formal release still requires owner approval, an explicit
  baseline-creation run, and one complete rerun without the update flag.

## Risk register

| Risk | Early check | Required response |
| --- | --- | --- |
| Art/collision drift | Anchor and footprint verifier | Fix source layout/builder; do not conceal with light/Decal |
| Invisible central shoulder | Ray and visible-deck coverage check | Expand cream visual only; preserve frozen collision |
| Character/gun contrast loss | Four-character production-camera capture | Rebalance arena material values, not shared character skins |
| Portal wall hack | Depth/occlusion screenshot | Keep depth test and place visual within tower opening |
| Wet-floor scope creep | Forbidden-name/resource scan and human veto | Delete the asset/node/mask; background water is separate |
| Performance regression | Matched Open Ring-Out benchmark | Merge static meshes/materials and simplify background first |
| Dirty-worktree collision | Narrow diffs and scoped staging | Preserve unrelated user work; never reset or bulk-format |

## Deferred backlog

Map skins, new weapons/tuning, portal projectiles, swimming/bounce, map-specific animation, full water park, music, water ambience, and map-specific AI navigation remain deferred.
