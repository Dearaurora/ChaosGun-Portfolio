# Open Ring-Out A1 Art Upgrade Design

Date: 2026-07-09

## Goal

Upgrade the default `Open Ring-Out Slice` stage into the first high-quality showcase art slice for ChaosGun.

The approved art identity is **A1: premium toy sky-island arena**: warm rounded toy-board platforms, readable bridges, glowing hazard edges, soft purple-blue abyss depth, distant floating islands, and playful peripheral toy props. The target quality bar is a commercial party-game screenshot, in the broad family of Overcooked and Boomerang Fu, without copying either game.

## Confirmed Scope

- Keep the current gameplay layout: collision, bridge positions, spawn points, weapon points, and core camera composition stay stable.
- Allow a medium visual rebuild: island silhouettes, visible bridge shells, cliff massing, edge light language, sky/abyss depth, surface detail, and prop framing can be rebuilt.
- Use the existing Blender Python -> GLB -> Godot layer as the main production path.
- Rebuild `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb` as the hero visual asset.
- Keep Godot runtime logic responsible for collision, spawning, weapons, HUD, character runtime behavior, and validation.

## Non-Goals

- Do not redesign combat topology in this pass.
- Do not change knockback tuning, weapon behavior, AI behavior, or scoring.
- Do not move the project into a hand-authored `.blend` workflow yet.
- Do not build a general-purpose art kit before the first showcase stage looks complete.
- Do not make menu, character, weapon, or HUD overhaul part of this pass unless required to preserve stage readability.

## Scene Architecture

The stage keeps the existing split between invisible/low-level gameplay structure and authored visual presentation.

Godot keeps:

- `OpenRingoutPlayable` collision and runtime platform nodes.
- Existing spawn, weapon pickup, AI, player, and HUD systems.
- Runtime lighting and environment configuration in `scripts/maps/open_ringout_slice.gd`.
- The `OpenRingoutBlenderVisuals` hook that instances the generated GLB.
- Verification scripts for node presence, collision stability, camera framing, and gameplay readability.

Blender GLB owns the primary visible scene:

- platform shells
- visible bridges
- cliff skirts
- edge light strips
- surface panels and grooves
- pickup pad treatment
- distant floating islands
- cloud/abyss depth
- non-colliding toy prop framing

The result should make the generated Blender layer feel like the real stage, while the Godot primitives remain the trusted gameplay layer.

## Asset Groups

### 1. Playable Shells

Central island, side islands, and bridge visual shells should become rounded, thick, toy-like sky-island forms. They must align with current gameplay collision closely enough that players never see themselves standing in empty air or blocked by invisible art.

### 2. Edge Language

Use glowing strips, rim pieces, bridge-mouth warnings, and small marker lights to make lethal edges clearer than the current build. Edge treatment should be beautiful but also function as hazard communication.

### 3. Surface Treatment

Add controlled surface detail: panel seams, subtle tile grooves, gentle wear, center pickup pad treatment, and readable route markings. Surface detail must stay low-noise so bullets, characters, pickups, and bridge exits remain legible.

### 4. Bridge Set

Rebuild bridges with stronger thickness, end caps, attachment hardware, small lights, and a tactile toy-board construction. Bridges must read as safe walkable connectors, not decorative planks or ambiguous scenery.

### 5. Depth Set

Add soft cloud banks, distant toy islands, below-stage shadows, glow motes, and atmospheric layers. These assets should deepen the screenshot without competing with playable shapes.

### 6. Prop Framing

Use windmills, flags, life rings, toy crates, soft rails, rubber posts, barrels, and small scenic toys only around the periphery or safe dead zones. Props should frame the board and create memory points without suggesting new cover or blocking routes.

## Visual Bar

Score the pass on eight categories, each from 1 to 5.

The pass is accepted only if:

- Total score is at least 34 out of 40.
- No category is below 3.
- Composition, Geometry Language, Gameplay Readability, and Screenshot Appeal are each at least 4.

Categories:

1. **A1 Reference Fidelity**: reads immediately as a premium toy sky-island arena.
2. **Composition**: has clear focal structure, edge framing, rhythm, and depth.
3. **Geometry Language**: islands, cliffs, bridges, props, and edges share rounded toy construction.
4. **Color And Lighting**: warm orange platforms, purple-blue abyss, glow accents, and character colors work together.
5. **Surface Detail**: panels, grooves, wear, pickup pads, and markings add polish without noise.
6. **Depth And Backdrop**: cloud sea, distant islands, bottom shadows, and glow motes add real spatial depth.
7. **Gameplay Readability**: routes, bridge mouths, ledges, cover, pickups, characters, weapons, and projectile paths are clearer because of art.
8. **Screenshot Appeal**: the captured stage can serve as a primary demo/Steam/itch promotional screenshot candidate.

## Pipeline

1. Update `tools/build_open_ringout_blender_visuals.py` to generate the A1 hero visual layer.
2. Export to `assets/models/generated/open_ringout_slice/open_ringout_visuals.glb`.
3. Import the GLB through Godot.
4. Run the Open Ring-Out verifier.
5. Capture `reports/open_ringout_slice_screenshot.png`.
6. Record a before/after art review against the 40-point bar.
7. Run a short AI smoke check if any visual change could affect gameplay readability.

## Validation Requirements

Automated checks should prove the minimum floor:

- The GLB is loadable and instanced under `OpenRingoutBlenderVisuals`.
- Existing playable collision nodes remain present.
- Spawn points and weapon pickup points remain stable.
- The fixed camera framing remains stable.
- Bridge connector readability checks still pass.
- Open edge and ring-out checks still pass.
- HUD remains readable over the upgraded scene.

Manual screenshot review proves the quality bar:

- Compare the new screenshot to the current `reports/open_ringout_slice_screenshot.png`.
- Assign all eight category scores.
- Record the three biggest remaining visual gaps.
- Mark the pass accepted only if it meets the score thresholds above.

## Risks And Handling

- **Visual/collision mismatch**: keep gameplay collision unchanged and validate with bridge and edge checks before screenshot review.
- **Overdecorated routes**: keep props out of active lanes and bridge mouths unless they are explicit readable markers.
- **Too much glow/noise**: edge glow must communicate danger without hiding bullets, pickups, or character silhouettes.
- **Generated-asset drift**: use named helper functions and asset groups in the Blender script so future passes can adjust individual systems without rewriting the whole scene.
- **Performance or import cost**: keep meshes low-poly, reuse materials, and avoid excessive alpha layers in the main GLB.

## Decision

Proceed with **Blender hero visual asset rebuild** for `Open Ring-Out Slice`, using A1 premium toy sky-island as the approved direction and medium visual reconstruction as the approved scope.
