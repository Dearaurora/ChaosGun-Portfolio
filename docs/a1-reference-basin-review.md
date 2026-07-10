# A1 Reference Basin Review

## Purpose

A1 Reference Basin is the first topology-checked whitebox based on the supplied reference image. It is not final art. It exists to test whether the reference-style layout can support ChaosGun's knockback, bridge fighting, and control-mode experiments.

## Structure

- West island: large garden island and the safest first spawn side.
- East island: landmark island with a crescent cover object.
- South island: recovery and flank loop that reduces single-bridge deadlocks.
- Main bridge: wide west-east combat bridge crossing the central void.
- Side bridges: two diagonal bridges connecting west/south and east/south.
- Void: real empty space between landmasses, used for ring-out kills.

## What To Judge In Play

1. Main bridge comfort
   - Can you dodge and fire on it without constantly falling?
   - Does knockback create danger without feeling unfair?

2. Crescent landmark
   - Does it help orientation?
   - Does it create interesting cover, or does it block the fight?

3. South loop
   - Does it prevent the whole match from collapsing into one bridge?
   - Do players and AI naturally use it?

4. Weapon pickup flow
   - Do pickups pull players toward bridge mouths and side routes?
   - Are there too many pickups now that A1 starts with four active weapon clusters?

5. Control modes
   - 2D Gunline: does the main bridge give a readable left-right fight?
   - Twin Stick: does 360 aiming make the open islands too chaotic?
   - Lock On: does lock-on make bridge fights readable, or too automatic?

## Current Known Tradeoffs

- A1 is intentionally generous with weapon pickups so AI and players enter combat quickly.
- The islands are built from overlapping whitebox blocks, so the final outline is still more angular than the SVG concept.
- The crescent landmark is represented by three collidable blocks, not final curved art.
- Pickup radius is currently 5.5 to avoid near-miss pickup frustration.

## Verification

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\tests\run_a1_reference_basin_verifier.ps1 -GodotPath 'E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File scripts\tests\run_a1_reference_basin_ai_smoke.ps1 -GodotPath 'E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe'
```

Expected:

- A1 geometry verifier passes.
- A1 AI smoke passes.
- Commercial Slice A smoke still passes after shared AI/pickup changes.
