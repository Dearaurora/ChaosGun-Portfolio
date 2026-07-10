# Map Validation Checklist

**Verification status**
- Runtime execution completed on 2026-04-24 with Godot 4.6.2 headless verification.
- Runtime camera lock verification completed on 2026-04-25 with Godot 4.6.2 headless verification.
- Curated dressing and darker presentation profile verification completed on 2026-04-25 with Godot 4.6.2 headless verification.
- Reference-style visual translation verification completed on 2026-04-25 with Godot 4.6.2 headless verification.
- Soft-geometry refinement verification completed on 2026-04-25 with Godot 4.6.2 headless verification.
- Grouped shell refinement verification completed on 2026-04-25 with Godot 4.6.2 headless verification.
- Side-link shell refinement verification completed on 2026-04-26 with Godot 4.6.2 headless verification.
- Large-map scale verification completed on 2026-04-26 with Godot 4.6.2 headless verification.
- Art quality gate V1 added on 2026-04-26. Current map estimate is 22/40, below the 32/40 acceptance bar.
- Ground-layer art pass completed on 2026-04-26. Current map estimate is 24/40, still below the 32/40 acceptance bar.
- Island-edge art pass completed on 2026-04-26. Current map estimate is 26/40, still below the 32/40 acceptance bar.
- Wall-cap art pass completed on 2026-04-26. Current map estimate is 28/40, still below the 32/40 acceptance bar.
- Reusable command: `powershell -File scripts/tests/run_commercial_slice_whitebox_verifier.ps1 -GodotPath <path-to-Godot.exe>`
- Reusable AI smoke command: `powershell -File scripts/tests/run_commercial_slice_ai_smoke.ps1 -GodotPath <path-to-Godot.exe>`
- Reusable AI smoke batch command: `powershell -File scripts/tests/run_commercial_slice_ai_smoke_batch.ps1 -GodotPath <path-to-Godot.exe> -Runs 6`
- Latest result: whitebox verifier now also proves that the enlarged arena target is met (`CenterIsland` 35x35, side island offset 35, backdrop 130x130, respawn radius 38.75), AI pickup range is scaled to 35, `CommercialSliceBackdrop/GrassField` exists, the material palette follows the reference-style grass/bridge/wall targets, dressing uses only tree/rock/foliage families, 19 art-quality ground layers are present, 36 grouped decorative shell segments frame routes, 24 island-edge overlays soften island slabs, 28 rounded wall caps mark bridge mouths and turns, and the authored `GlobalCamera` stays locked during scene setup and forced runtime follow updates. A two-run AI smoke batch still passes after the wall-cap pass.

## Connectivity
- [ ] `C` can reach `N`, `S`, `W`, and `E` through the main bridges.
- [ ] `N`, `S`, `W`, and `E` can rotate into neighboring islands through the secondary links.
- [ ] No island forces a single-route escape.

## Fall Risk
- [ ] All island gaps read as true lethal drop zones.
- [ ] Main bridges have exposed edges on both sides.
- [ ] Secondary links are visibly riskier than the main bridges.
- [ ] Main island corners and cuts preserve ring-out threat.

## Spawn And Tempo
- [ ] Each spawn area has one faster route to center and one safer route to a neighboring island.
- [ ] Spawn exits are not covered by a single hard choke.
- [x] Runtime respawn points match the `Commercial Slice A` spawn plan.
- [x] Respawn points land on valid whitebox surfaces.
- [ ] First contact happens quickly enough for arcade pacing.
- [ ] Pressured players can rotate instead of only retreating backward.

## Readability
- [x] Default camera framing clearly shows `C` as the anchor zone.
- [x] Runtime camera behavior matches the map's fixed-camera policy.
- [ ] The main and secondary bridge hierarchy is obvious without extra UI.
- [ ] Bridge mouths stay free of oversized blockers.
- [ ] Lethal edges remain readable from normal combat camera height.

## Combat Value
- [ ] Center is valuable without becoming the only worthwhile fight zone.
- [ ] Side islands meaningfully support flanks and resets.
- [ ] Bridge and ledge fights create regular ring-out finishes.
- [ ] No side island becomes a low-risk bunker.

## Resource Spawns
- [ ] Weapon pickups spawn on the center island, side islands, or other valid whitebox surfaces.
- [ ] No weapon pickup can appear in a lethal gap between islands.
- [ ] Pickup placement reinforces movement between center and side routes.

## Runtime Smoke
- [x] Automated AI smoke has been run against `Commercial Slice A`.
- [x] Current sample runs show meaningful eliminations and ring-out pressure inside the 18s smoke window.
- [x] Map-specific live runtime now uses faster pickup cadence: `initial_delay=3.5`, `stay_duration=10.0`, `respawn_cooldown=4.0`.
- [x] Current map runtime now sustains `max_active_pickups=2`, and the smoke harness fails if fewer than two simultaneous pickups appear.
- [x] Current map runtime now sustains two simultaneous pickup clusters, and the smoke harness fails if simultaneous pickups do not span both route groups.

## Iteration Notes
**Effective changes**
- Shared runtime now pushes map-specific spawn points into `GameConfig.respawn_points`, so respawns and AI patrol routing match the active map instead of stale global defaults.
- Headless whitebox verification now checks respawn-point synchronization in addition to geometry and weapon spawn validity.
- Added a reusable AI smoke harness and used it to validate that the map already produces repeated ring-out deaths under bot pressure.
- Increased AI pickup awareness from `15.0` to `28.0`, which improved primary-weapon pickup participation in smoke samples.
- `WeaponSpawner` now supports controlled concurrent live pickups, so map-specific runtime can raise fight pressure without adding duplicate spawner nodes.
- `WeaponSpawner` now also supports grouped pickup spawn clusters, so maps can keep simultaneous pickups distributed across intended combat lanes instead of bunching in one area.
- `Commercial Slice A` pickup points are now stricter: center-cluster points sit on bridge mouths, while side-cluster points sit on off-center side-island entry lanes instead of dead-center island positions.
- The latest five-run smoke sample after this point retune averaged `2.20` armed AI, `2.80` deaths, `2.80` suspected ring-outs, `2.00` simultaneous pickups, `2.00` simultaneous pickup clusters, and `6.09s` to first death.
- Added a reusable batch smoke runner so variance-sensitive tuning can use per-run range plus averages instead of overfitting to one five-run sample.
- Latest six-run batch smoke summary after rolling back unsuccessful AI pickup-targeting tweaks: `Armed AI avg 1.67 (min 1, max 3)`, `Deaths avg 3.17 (min 2, max 5)`, `Ring-outs avg 3.17 (min 2, max 5)`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, `First death avg 6.83s (min 5.58, max 9.12)`.
- `Commercial Slice A` now opts into a fixed runtime camera, so TA lighting/environment still apply but the authored scene camera no longer gets recentered, rescaled, or rotated by character movement or falls.
- Whitebox verification now explicitly fails if `GlobalCamera` drifts during scene setup or during a forced off-map runtime camera update.
- A short post-fix smoke batch still ran cleanly with `Armed AI avg 1.00`, `Deaths avg 2.50`, `Ring-outs avg 2.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 7.64s`.
- `Commercial Slice A` now rebuilds a curated `CommercialSliceDressing` layer from the Kenney dojo kit instead of shipping as pure whitebox, so the map regains gates, banners, lightposts, trees, and rocks without reviving the old `ExternalArt` path.
- `Commercial Slice A` now applies its own darker presentation override after the shared TA pipeline, reducing directional light energy, tonemap exposure, ambient fill, and fog density so the scene no longer reads washed out.
- Whitebox verification now explicitly fails if the curated dressing layer is missing or if the light/exposure/fog profile drifts back above the current brightness thresholds.
- A short post-art-pass smoke batch still ran cleanly with `Armed AI avg 0.50`, `Deaths avg 2.50`, `Ring-outs avg 2.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 10.04s`.
- `Commercial Slice A` now includes a unified `CommercialSliceBackdrop` grass field, so the map reads more like a toy board and less like isolated whitebox chunks floating in space.
- Ground, bridge, and cover materials now follow the reference-inspired palette: light grass islands, muted warm bridges, and pastel lavender walls.
- Curated dressing now removes gates, banners, lightposts, and altar props in favor of only trees, rocks, and foliage clusters.
- Whitebox verification now explicitly fails if the map drifts away from the reference-style palette, loses the backdrop field, or reintroduces off-style props.
- A short post-reference-pass smoke batch still ran cleanly with `Armed AI avg 2.00`, `Deaths avg 3.50`, `Ring-outs avg 3.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 7.62s`.
- Main low-cover and spawn-cover shapes now use softened `CapsuleMesh` wall shells over the existing gameplay collision, bringing the most visible arena geometry closer to the rounded toy-wall look of the reference.
- The grass backdrop now includes multiple soft ground patches, which break up the flat green field and push the board-game look closer to the reference image.
- Whitebox verification now explicitly fails if softened wall shells or soft ground patches disappear.
- A short post-soft-geometry smoke batch still ran cleanly with `Armed AI avg 1.00`, `Deaths avg 2.50`, `Ring-outs avg 2.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 10.40s`.
- `Commercial Slice A` now adds grouped decorative shell segments around bridge mouths, outer island rims, and center corners, which makes the map read less like isolated platforms and more like a deliberately arranged toy maze.
- Whitebox verification now explicitly fails if those grouped decorative shell anchors disappear or if they accidentally gain collision bodies.
- A short post-grouped-shell smoke batch still ran cleanly with `Armed AI avg 1.00`, `Deaths avg 1.50`, `Ring-outs avg 1.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 5.53s`.
- The grouped-shell layer now also marks side-link entries and center-to-side turns with 16 additional collision-free `CapsuleMesh` segments, raising the decorative shell count from 20 to 36.
- Whitebox verification now requires at least 32 grouped decorative shell segments and explicitly checks the eight side-link entry anchors.
- A short post-side-link-shell smoke batch still ran cleanly with `Armed AI avg 1.50`, `Deaths avg 1.50`, `Ring-outs avg 1.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 6.04s`.
- `Commercial Slice A` now uses a 1.25x horizontal arena scale. Center island size increased from 28x28 to 35x35, side island offset increased from 28 to 35, and the grass backdrop increased from 104x104 to 130x130.
- Spawn points, bridge points, pickup clusters, ground patches, dressing props, and decorative grouped shells now scale with the enlarged layout instead of keeping the old compact coordinates.
- Whitebox verification now explicitly fails if the center island, side-island offset, grass backdrop, respawn radius, or AI pickup range regress below the enlarged-map target.
- AI pickup awareness increased from `28.0` to `35.0` so the larger side-route pickup positions remain contestable.
- A four-run post-large-map smoke batch still ran cleanly with `Armed AI avg 1.25`, `Deaths avg 1.50`, `Ring-outs avg 1.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 8.40s`.
- `Commercial Slice A` now includes island shadow pads and path-wear overlays at main bridge mouths and diagonal side links, raising art-quality ground layers from 6 to 19.
- Whitebox verification now explicitly fails if art-quality ground treatment drops below 18 soft ground layers or loses key island-shadow and bridge-wear anchors.
- The stricter art review score improved from 22/40 to 24/40, but the visual pass is still not accepted.
- A two-run post-ground-layer smoke batch still ran cleanly with `Armed AI avg 1.00`, `Deaths avg 2.50`, `Ring-outs avg 2.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 6.72s`.
- `Commercial Slice A` now includes 24 collision-free island-edge overlays that soften center and side island top edges.
- Whitebox verification now explicitly fails if the `CommercialSliceIslandEdges` layer is missing, drops below 24 segments, loses key center/side anchors, uses the wrong mesh type, or gains collision.
- The stricter art review score improved from 24/40 to 26/40, but the visual pass is still not accepted.
- A two-run post-island-edge smoke batch still ran cleanly with `Armed AI avg 2.00`, `Deaths avg 3.00`, `Ring-outs avg 3.00`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 8.24s`.
- `Commercial Slice A` now includes 28 collision-free `SphereMesh` wall caps that add rounded terminals to bridge mouths, side-link entries, center turns, and side-island outer shells.
- Whitebox verification now explicitly fails if the `CommercialSliceWallCaps` layer is missing, drops below 24 caps, loses key bridge/center anchors, uses the wrong mesh type, or gains collision.
- The stricter art review score improved from 26/40 to 28/40, but the visual pass is still not accepted.
- A two-run post-wall-cap smoke batch still ran cleanly with `Armed AI avg 1.00`, `Deaths avg 2.50`, `Ring-outs avg 2.50`, `Max pickups avg 2.00`, `Max pickup clusters avg 2.00`, and `First death avg 7.91s`.

**Problems found**
- Primary-weapon engagement is materially better overall, but smoke variance is still large enough that single five-run samples can mislead tuning decisions.
- AI pickup-targeting experiments that looked promising in deterministic checks did not improve batch smoke metrics, so they were not retained.
- First-contact timing, bridge pressure, and overall combat pacing still benefit from live play validation rather than static verification alone.
- The visual pass did not break runtime behavior, but the latest two-run smoke sample still showed large pickup-engagement variance, so human play is still the right next source of truth.
- The map is now much closer to the supplied reference direction in color and prop language, but it still lacks the same level of soft geometry and bespoke wall shapes because the current asset pool is limited to the curated dojo kit plus whitebox primitives.
- The map is now noticeably closer in color, dressing, and soft wall feel, but it still does not match the reference's bespoke maze-wall silhouettes or fully handcrafted ground painting because those shapes would require either custom meshes or a richer art kit than the current curated dojo assets.
- The grouped shell pass improves the "authored maze edge" feeling, but the wall network is still a visual shell over the existing gameplay topology, not a bespoke one-to-one recreation of the reference map's handcrafted wall layout.
- The larger map restores spatial breathing room, but average first death is slower than the compact-map samples, so hands-on play should decide whether to tune spawn placement, bridge width, or AI pursuit priority next.
- Current art quality is explicitly not accepted yet under `commercial-slice-a-art-quality-gate-v1.md`: estimated score is 28/40, with the weakest areas now being perimeter composition, broader board-level framing, and color layering.

**Next priority**
- Improve perimeter framing and board-level composition before claiming any future visual pass is complete.
- Re-score every future art change against the art quality gate and record before/after scores.
- Run live matches after the next visual pass to decide whether the larger map has the right balance between ring-out dominance and weapon contest pressure.
