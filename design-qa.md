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
