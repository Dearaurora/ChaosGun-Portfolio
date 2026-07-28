# Momentum Circuit Design QA

## Comparison basis

- Approved concept: `docs/art-direction/references/momentum_circuit/momentum_circuit_gravity_side_swap_cloud_vortex.png`
- Corrected active-state capture: `reports/momentum_circuit_semantic_fix_active_plus_1536x1024.png`
- Battle capture: `reports/momentum_circuit_semantic_fix_battle_1920x1080.png`
- HUD-safe capture: `reports/momentum_circuit_semantic_fix_hud_warning_1280x720.png`
- State captures: `reports/momentum_circuit_semantic_fix_{idle,warning,active_plus,reversing,active_minus,recovery}_1536x1024.png`
- Viewports checked: `1536x1024`, `1920x1080`, and `1280x720`.

The concept and corrected capture were reviewed together at the same 1536x1024 viewport. The concept is treated as two semantic layers: the approved arena/cloud art direction and gameplay objects are source truth; the broad warm corridor overlay, repeated yellow arrows, illustrative yellow falling character, projectiles, and shell casings are explanatory annotations and are not production assets.

## Iteration history

1. The first production pass incorrectly converted the broad warm corridor overlay and repeated arrows into literal runtime geometry. This was a P1 semantic mismatch: it copied the concept's explanation layer instead of implementing the mechanic.
2. The correction removed the full-surface corridor fill and every literal direction arrow.
3. Direction is now communicated through a thin right-side perimeter chase, sparse cyan motion streaks, a short boundary warning pulse, activator/anchor response, and state audio. `REVERSING` extinguishes the streaks before the direction changes; `RECOVERY` fades them out.
4. Production, mechanics, runtime, map-route, and Twin Bays regression verifiers passed after the correction.

## Findings

- No actionable P0, P1, or P2 issue remains in the corrected mechanism presentation.
- [P3] The runtime ceramic platform is cleaner and flatter than the painterly concept.
  - Impact: reduced close-up material richness, but silhouettes, covers, holes, anchors, activators, and characters remain readable.
  - Optional follow-up: subtle roughness variation and sparse panel seams without changing collision or reintroducing painted guidance graphics.
- [P3] A still frame intentionally does not encode `+X` versus `-X` with an arrow shape.
  - Impact: direction is clearest in motion and through stereo/positional audio, which is the desired diegetic behavior.
  - Guardrail: never solve this by restoring a filled lane or large floor arrows; improve chase timing, flow streak motion, or node/audio response instead.

## Required fidelity surfaces

- Layout: one outer silhouette, three holes, nine cover groups, four cyan stabilizer anchors, and three orange shootable activators remain unchanged from the validated whitebox.
- Visual hierarchy: neutral matte floor stays gameplay-readable against the cloud vortex; no yellow/orange corridor carpet competes with characters or pickups.
- Mechanism language: `surface_fill_present=false`, `literal_arrow_count=0`, one boundary cue, perimeter chase segments, sparse flow streaks, and three real audio channels are enforced by the production verifier.
- State coverage: IDLE, WARNING, ACTIVE(+X), REVERSING, ACTIVE(-X), and RECOVERY all have captured evidence. Reversal has an explicit visual blackout before the flow resumes.
- Responsive framing: the 1920x1080 battle capture keeps all four characters and the arena visible; the 1280x720 capture preserves HUD safe areas without clipping primary information.
- Accessibility: direction uses motion plus sound rather than color alone. Warm edge light identifies the active danger region while cyan streak motion conveys flow.
- Asset boundaries: foreground and cloud visual layers contain no collision, camera, light, character, or weapon authority.

## Human visual acceptance score

- Party-game feel: `4.5/5`
- Cloud-vortex background: `5/5`
- Battle readability: `4.5/5`
- Silhouette and layout: `4.5/5`
- Mechanism readability in motion: `4/5`
- Palette fidelity: `4.5/5`
- Material depth: `3.5/5`
- Overall polish: `3.5/5`
- Total: `34/40`

## Gate result

- [x] Concept annotation layer is documented and excluded from production geometry.
- [x] Full corridor fill removed.
- [x] Literal arrows removed.
- [x] Six mechanism states, battle framing, and HUD-safe framing visually checked.
- [x] Production, mechanics, runtime, player-facing route, and neighboring-map regression checks passed.

final result: passed

---

# Twin Bays Art V4 Production Design QA

## Comparison basis

- Structural authority: `resources/maps/twin_bays_layout_v1.json`
- Mood authority: `docs/art-direction/references/twin_bays/twin_bays_splash_arena_selected_background.png`
- Same-camera battle comparison: `reports/twin_bays_art_v4/comparisons/v3_v4_battle_comparison.png`
- Tide-state comparison: `reports/twin_bays_art_v4/comparisons/v3_v4_tide_state_matrix.png`
- Production contact sheet: `reports/twin_bays_art_v4/comparisons/v4_production_contact_sheet.png`
- Final runtime evidence: `reports/twin_bays_art_v4/production/`

The current Godot scene and Layout V1 remain the geometry and camera source of
truth. The concept is used only for palette, material response, rounded
water-park language, background depth and party-shooter tone.

## Findings

- No actionable P0, P1 or P2 visual issue remains.
- The prior tentacle/ribbon runoff has been removed. Drain water now reads as a
  thin clear aqua layer and never restores static opening puddles.
- Warm cream, aqua tile, coral pads, yellow danger trim and orange pickup marks
  separate clearly in dry, high-tide and drain states.
- Portal pipes are visibly seated on the platform and retain readable mouth,
  collar, recess, foam and travel direction at gameplay scale.
- Four players, all six weapon silhouettes, ordinary pickup markers, the
  central special pickup and lethal water edges remain legible at 1920x1080
  and 1280x720.
- Remaining P3 opportunities are close-up-only hand-painted collar wear,
  bespoke foam/throat sculpting and extra peripheral storytelling. They do not
  justify more deterministic runtime complexity.

## Score and gate result

- Reference fidelity: 5/5
- Party-shooter tone: 5/5
- Background/periphery: 5/5
- Composition/depth: 5/5
- Geometry finish: 4/5
- Materials/lighting: 5/5
- Gameplay readability: 5/5
- Completion/polish: 4/5
- Total: 38/40

- [x] V3 and V4 reviewed at matched camera and state.
- [x] Full-map V4 approved by the project owner.
- [x] Production foreground is locked to V4; V3 remains rollback evidence only.
- [x] Eight materials, seven foreground batches and three water batches remain within budget.
- [x] Layout, collision, portals, camera, tide, characters, weapons and map routing show no visual regression.
- [x] Visual QA passes independently of the outstanding desktop-focus performance-environment gate.

final result: passed

---

# Twin Bays Unified Water Material Design QA

## Comparison basis

- Mood and material source truth: `docs/art-direction/references/twin_bays/twin_bays_splash_arena_selected_background.png`
- Same-camera old/new high-tide comparison: `reports/twin_bays_art_v3_compare_high_old_new.png`
- Same-camera old/new drain-start comparison: `reports/twin_bays_art_v3_compare_drain_0_old_new.png`
- Final native Godot captures: `reports/twin_bays_art_v3_hero_{dry,high,drain_0,drain_9}_1536x1024.png`
- Four-player runtime capture: `reports/twin_bays_art_v3_hero_battle_1920x1080.png`

The concept, old captures and final captures were inspected together. The old/new evidence uses the same Godot camera, resolution, geometry and tide state; the only intended differences are the approved Art V3 static materials and the unified water rendering path. Browser viewport and density checks do not apply to this native 3D scene.

## Iteration history

1. The old tide and residue controllers each owned replacement water shaders. Their unshaded transparent surfaces flattened or hid the floor, wall, pipe and cover materials whenever tide visuals were active. This was a P1 material-authority regression.
2. High tide, residue surface, wet bed and meniscus were moved to one precompiled lit shader and one material factory. The shared shader uses depth prepass, world-space dual-flow normals, PBR roughness and specular response while preserving the underlying approved materials.
3. The first unified candidate added repeated bright oval glints. In the fixed gameplay camera these read as soap spots rather than flowing water, a P2 visual defect.
4. Explicit color glints were reduced to a broad weak sheen. Flow is now carried primarily by normals and roughness in motion; the final still no longer contains repeated white blobs.
5. Final same-camera comparison confirms that the new tide states retain tile scale, panel seams, rounded-cover highlights, pipe surfacing and floor roughness instead of reverting the map to flat color.

## Required fidelity surfaces

- Single authority: tide flood and all three residue layers use `assets/shaders/twin_bays_water_master.gdshader` through `scripts/maps/twin_bays_water_materials.gd`.
- Material continuity: the approved cream floor, cyan wall, coral cap, cover and pipe materials remain visible during high tide and drain states.
- Water language: shallow cyan tint, restrained wet edge, subtle flow response and no repeated oval highlights, tentacle ribbons or white sticker outlines.
- Rendering discipline: lit transparent material, depth prepass, fixed shared batches, no runtime shader-source compilation and no screen reflection/refraction.
- Gameplay isolation: water rendering adds no collision, Area, navigation or layout coordinates and keeps Tide V1 movement parameters unchanged.
- Responsive framing: 1536x1024 state evidence and 1920x1080 battle evidence retain the reviewed portal, covers and playable area.
- Typography, copy and icons: not applicable to this environment-material review.

## Findings

- No actionable P0, P1 or P2 mismatch remains in the unified material candidate.
- [P3] Water movement is intentionally understated in a still frame.
  - Impact: the surface may look calmer than the painted concept in a single image.
  - Reason: the fixed camera reads animated normal/specular flow at runtime; increasing static white contrast recreated the rejected soap-spot defect and reduced combat readability.

## Gate result

- [x] Concept, old implementation and new implementation reviewed together.
- [x] High tide and drain states use one precompiled water authority.
- [x] Static Art V3 materials remain visible under active water.
- [x] Repeated white glints removed after visual iteration.
- [x] Strict five-state capture and runtime verifier pass.
- [x] Human A2 Hero approval recorded; full-map production replacement remains separately locked.

final result: passed

---

# Twin Bays Art V3 Full-Map Design QA

## Comparison basis

- Mood source truth: `docs/art-direction/references/twin_bays/twin_bays_splash_arena_selected_background.png`
- Structural source truth: `resources/maps/twin_bays_layout_v1.json`
- Source/implementation comparison: `reports/twin_bays_art_v3_full_compare_concept_mood.png`
- Same-camera old/new comparison: `reports/twin_bays_art_v3_full_compare_old_new_dry.png`
- Final state captures: `reports/twin_bays_art_v3_full_{dry,high,drain_0,drain_9}_1536x1024.png`
- Battle capture: `reports/twin_bays_art_v3_full_battle_1920x1080.png`
- HUD-safe capture: `reports/twin_bays_art_v3_full_mobile_1280x720.png`

The mood reference and final dry implementation were combined on one 3072×1092 comparison canvas. The old production and new implementation were combined on a second same-camera, same-state canvas. Native Godot captures use 1536×1024, 1920×1080 and 1280×720 at density 1; browser and CSS normalization do not apply.

## Comparison history

1. The first full-map expansion preserved the approved foreground but left the background as a nearly solid cyan plane. Against the concept this was a P1 atmosphere and image-quality mismatch.
2. A precompiled two-scale caustic shader added moving, restrained water-light structure and a deeper central bay. The first shader pass was too coarse and produced oversized cell lines, a P2 visual-noise issue.
3. Caustic scale was increased and strength reduced. The final background now reads as water at full view without competing with characters or yellow danger edges.
4. Full-map high tide exposed a continuous grey ribbon across the two central bay boundaries, a P1 floor-paint/shape-language defect.
5. The foam batch was moved toward the water side, reduced to sparse low-alpha crests and re-captured. The final battle and overview no longer contain a continuous grey line.

## Required fidelity surfaces

- Layout and spacing: the current 116-point platform authority, two bays, causeway, two pipes, four wall groups, ten covers, four ordinary points and one special point remain unchanged. Geometry audit confirms visible floor coverage, mounted pipe mouths and flush south walls.
- Colors and tokens: warm cream, aqua tile, coral soft caps, saturated yellow trim, orange pickup points and portal cyan follow the approved palette across the whole map.
- Image and material quality: 2K cream and 1K cyan/coral PBR families remain visible during dry, high-tide and drain states. Background water uses a real shader resource rather than a flat placeholder.
- Shape language: rounded covers, padded coral caps, thick pipes and continuous safety trim preserve the toy water-park language without restoring deleted concept geometry.
- Combat readability: four characters, six weapon silhouettes, ordinary pickup points, the central special point, both portals and all danger edges remain distinguishable at 1920×1080 and 1280×720.
- Tide states: high tide applies a subtle whole-deck tint and animated material response; drain water remains irregular area puddles, not ribbons. Sparse danger foam never becomes a floor line.
- Fonts and typography: map art has no authored typography. Existing HUD type remains unchanged and is checked only for framing.
- Copy and content: no new player-facing copy was introduced.

## Findings

- No actionable P0, P1 or P2 visual issue remains in the full-map candidate.
- [P3] Peripheral islets and slide ends remain deliberately low-poly.
  - Impact: they are simpler than the painted mood reference when enlarged.
  - Reason: they sit outside the combat focus and preserve the fixed performance and draw-call budget.
- [P3] High-tide movement reads more strongly in motion than in a still.
  - Impact: the static high-tide frame shows tint and sparse crests but not the full dual-flow normal animation.
  - Guardrail: do not add opaque blue overlays or continuous white foam bands to improve a still image.

## Gate result

- [x] Mood reference and final implementation reviewed together.
- [x] Old production and new candidate compared at the same camera and state.
- [x] P1 flat-background mismatch fixed.
- [x] P2 coarse-caustic mismatch fixed.
- [x] P1 grey danger-foam ribbon fixed.
- [x] Six final runtime states and full-candidate verifier pass.
- [x] Production assets and Golden remain protected.
- [ ] Project-owner full-map approval remains required before production replacement.

final result: passed

---

# Twin Bays Art V3 Residue Design QA

## Comparison basis

- Mood and material source truth: `docs/art-direction/references/twin_bays/twin_bays_splash_arena_selected_background.png`
- Rejected ribbon crop: `docs/art-direction/references/twin_bays/twin_bays_art_v3_rejected_ribbon_crop.png`
- Drain start implementation: `reports/twin_bays_art_v3_hero_drain_0_1536x1024.png`
- Drain midpoint implementation: `reports/twin_bays_art_v3_hero_drain_9_1536x1024.png`
- Dry, high-tide and four-player evidence: `reports/twin_bays_art_v3_hero_{dry,high}_1536x1024.png` and `reports/twin_bays_art_v3_hero_battle_1920x1080.png`

The concept and both final drain captures were inspected together at 1536x1024, a one-to-one native Godot screenshot comparison. Browser density and CSS viewport checks do not apply to this native 3D scene. The current layout and camera remain structural authority; the concept is compared only for water-park palette, puddle shape language, softness and material hierarchy.

## Iteration history

1. The first drain implementation rendered source paths as near-constant-width spline ribbons. Parallel edges, pointed ends and long directional silhouettes created the rejected tentacle appearance. This was a P1 shape-language mismatch.
2. The renderer and interaction query were moved to one deterministic polygon generator. It produces merged multi-lobed area puddles, smaller secondary pools and droplets, and changes topology as the platform dries.
3. A second comparison found the water too grey and its meniscus too outline-like. Cyan saturation and shallow-water alpha were increased, the rim was reduced, and overlapping lobes were polygon-merged to prevent doubled transparency.
4. Final drain-start and drain-midpoint captures were compared with the concept again. No actionable P0, P1 or P2 residue-shape mismatch remains.

## Required fidelity surfaces

- Shape language: water reads as broad irregular puddles and droplets, never a path, stripe, arrow or tentacle. Maximum aspect ratio is `2.2`; parallel ribbon edges and sharp tips are forbidden.
- Temporal behavior: actual generated coverage changes from approximately `15%` to `8%` and then `0%`; secondary pools and droplets disappear rather than every shape merely shrinking in place.
- Interaction fidelity: visible polygons are also the authoritative point-in-water query for footsteps, landings and projectile impacts. There is no invisible legacy runoff interaction.
- Color and material: shallow cyan remains distinct from the warm cream floor; the subtle meniscus does not become a white sticker outline. Flowing highlight remains a runtime shader effect.
- Layout and spacing: current Godot layout, clean zones, cover footprints, pickups, portal exits and danger borders stay authoritative and unchanged.
- Typography, copy and icons: not applicable; this review covers an environment material with no map text or iconography.
- Asset fidelity: the concept image is not embedded or traced as a runtime asset. It constrains art direction only, while implementation geometry is native and deterministic.
- Responsive framing: 1536x1024 state evidence and 1920x1080 battle evidence retain the reviewed quadrant, portal and gameplay silhouettes.

## Remaining non-blocking note

- [P3] A still capture appears flatter than the painted concept because slow normal flow, specular motion, footsteps and projectile ripples require runtime motion. The dynamic implementation and pooled interactions are retained; adding more static contrast would reduce combat readability.

## Gate result

- [x] Rejected tentacle ribbons removed from rendering and interaction queries.
- [x] Concept and final implementation compared at matched resolution.
- [x] Drain-start and drain-midpoint topology checked.
- [x] Visual and interaction geometry share one source.
- [x] Strict runtime capture and Art V3 contract checks passed.
- [x] Default production capture remains on the legacy backdrop and foreground; Art V3 only loads in review scope.
- [x] Legacy Art V2 review GLB import contract now uses Basis Universal, so the frozen release verifier passes again.
- [x] Human A2 Hero approval recorded; full-map production replacement remains separately locked.

final result: passed
