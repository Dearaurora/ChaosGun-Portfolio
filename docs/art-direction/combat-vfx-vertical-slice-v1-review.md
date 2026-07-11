# Combat VFX Vertical Slice V1 Review

## Goals

- Start every shot at the authored weapon muzzle instead of one shared character marker.
- Keep pistol, SMG, AK, and sniper fire visually distinct.
- Remove detached dots, black rings, stacked ribbons, and persistent particle residue.
- Preserve projectile dodge readability and all gameplay values.

## Implemented

- Added per-weapon muzzle anchors derived from the generated GLB dimensions.
- Synced `WeaponPoint` whenever the active weapon changes.
- Replaced the spherical muzzle flash with one colored core and two short controlled petals.
- Reduced the instant shot tracer to a dark edge and colored core only.
- Removed the tracer lead dot and the projectile hot-center/lead-spark dots.
- Removed the duplicate projectile trajectory underlay/core ribbons.
- Kept one colored projectile core, one dark rim, and one short translucent tail.
- Replaced the spherical hit flash with one diamond core and four deterministic shards.
- Shifted high-exposure projectile colors to deeper coral, green, orange, and cyan values.

## Timing Limits

- Muzzle flash: `0.040-0.080s` by weapon.
- Shot tracer: `0.040-0.070s` by weapon.
- Hit effect: `0.105-0.180s` by weapon.
- No decals, particle emitters, or persistent motes are created.

## Evidence

- `reports/combat_vfx_vertical_slice_final_v2.png`: first combat frame.
- `reports/combat_vfx_gameplay_settle_final_v2.png`: settled projectile read.

## Verification

- Combat effect visual verifier: PASS.
- Shot tracer visual verifier: PASS.
- Projectile visual profile verifier: PASS.
- Weapon shot tracer integration verifier: PASS.
- Per-weapon muzzle progression verifier: PASS.
- Character motion, Open Ring-Out, sunset integration, and HUD verifiers: PASS.
