# Environment Ambient Motion P25 Review

Decision: PASS

## Goal

Make the approved P24 arena feel alive at gameplay distance without adding
visual clutter, changing collision, or competing with characters, projectiles,
pickups, and combat feedback.

## Implemented

- Added runtime visual pivots for the north hero windmill and the distant
  north-west windmill. Their authored meshes remain intact and rotate around
  their actual hubs at restrained, different speeds.
- Grouped the complete hot-air balloon assembly under one motion pivot, so the
  envelope, seams, ropes, rim, and basket share the same slow drift and tilt.
- Added independent low-frequency drift to all ten approved single-layer P14
  cloud banks while preserving the existing camera parallax offset.
- Added phased scale pulses to all 22 arena edge gems. The pulse remains a
  peripheral rhythm rather than a gameplay target marker.
- Added state-dependent status-light orbits to weapon spawn pedestals: fast in
  prewarm, slower while active, and static while cooling.
- Kept every P25 animation in visual-only nodes. No collision object, spawn
  point, camera rule, weapon value, or movement rule changed.

## Motion Budget

- Hero windmill: `0.48 rad/s`.
- Distant windmill: `0.30 rad/s`.
- Balloon translation envelope: `0.22 x / 0.34 y / 0.14 z` world units.
- Balloon tilt envelope: below `0.012 rad`.
- Cloud drift envelope: `0.52 x / 0.09 y / 0.30 z` world units at very low
  frequencies.
- Edge-gem pulse: `+/-5.5%` scale with distributed phase.
- Pedestal light orbit: `1.25 rad/s` prewarm, `0.48 rad/s` active, zero cooling.

## Evidence

- Start frame: `reports/p25_ambient_motion_start.png`.
- Three-second frame: `reports/p25_ambient_motion_end.png`.
- Automated transform evidence: hero rotor advanced `0.480 rad` in one
  controlled second; balloon, cloud, and edge-light deltas were all nonzero.

## Verification

- P25 ambient-motion contract: PASS.
- Weapon spawn visual and orbit contract: PASS.
- Sunset V2 / P24 integration contract: PASS.
- Map topology, bridge surfaces, collision, respawn, and pickup flow: PASS.
- P14 cloud, distant-island, balloon, and grade contract: PASS.
- Runtime camera framing and smoothing: PASS.
- Character locomotion and authored weapon motion: PASS.
- Combat audio and camera feedback: PASS.
- 18-second four-AI gameplay smoke: PASS.
- P25 regression: 10/10 PASS.
- The paired 60-second render sampler completed without engine errors and
  measured `124.77 FPS` average on Open Ring-Out. It also exposed a frame-pacing
  risk: `20.88 FPS` one-percent low with roughly `1,661` average draw calls.

## Visual Judgment

The start/end frames show useful life without changing the arena silhouette.
The windmill has readable rotation, the balloon stays structurally connected,
and cloud motion remains subordinate to combat. Increasing these amplitudes or
adding more ambient particles would reduce clarity and has low marginal value.

## Next

P26 should first consolidate the technical-art render cost and isolate the
one-percent-low spikes without changing the approved image. After that gate is
stable, upgrade match presentation with a short arena reveal, cleaner spawn and
round-end choreography, and one coherent HUD visual language. Static map prop
density and ambient-motion amplitude are no longer high-value targets.
