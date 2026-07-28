# Twin Bays Art V3 Hero Review

Status: `APPROVED 2026-07-23 — FULL-MAP REVIEW IN PROGRESS`

Scope: north-east runtime quadrant only

Layout authority: `twin_bays_layout_v1.json` SHA `211ed22c8b9a3af358ec2058bbabf2a976b7a2158d1f18f887bebd9cd966217a`

Art profile SHA: `ccbaba05cf471e400f1102318ae44defa886133bf484d8cbf3cbb645db68cd3d`

Tide profile SHA: `45caaa9ea785b9bd136e0839cae20bf6ba70a662c949119484e04d32c84b7a46`

## Candidate evidence

| State | Evidence | SHA-256 |
|---|---|---|
| Dry | `reports/twin_bays_art_v3_hero_dry_1536x1024.png` | `a74cc16c8a742d16e62f7822700229e807f8eb09cd589fb149b9d312ccedf475` |
| High tide | `reports/twin_bays_art_v3_hero_high_1536x1024.png` | `2e13950089358eaab285924dec5b4a3f3e28d681d47741e5de56dccf4d65900d` |
| Drain 0 s | `reports/twin_bays_art_v3_hero_drain_0_1536x1024.png` | `8ff271486dc14f847a6dd8ee94e3a147bb6ef3b20b391caf3673442c8e0e67c3` |
| Drain 9 s | `reports/twin_bays_art_v3_hero_drain_9_1536x1024.png` | `b0f9b45ac2f5155dce903e18ebcf6bfc3f4b64d3440b38763314b16ea3739447` |
| Four-player battle | `reports/twin_bays_art_v3_hero_battle_1920x1080.png` | `fc43dfeb634e2eb0e3ab2cac5ba29de094dd3877478841b9882a140b4cf117f2` |

## Same-camera old/new evidence

| State | Comparison | SHA-256 |
|---|---|---|
| High tide | `reports/twin_bays_art_v3_compare_high_old_new.png` | `c1825f232b56570fdc73ac2d08f6b23934e458f98c1781f218b77ec557b6e6d3` |
| Drain 0 s | `reports/twin_bays_art_v3_compare_drain_0_old_new.png` | `1686b733c182b248ba57005b2dbf4448506fa42b73b2a923739e17daa1162dae` |

## Automated result

- Deterministic Hero Blend and eight-material GLB built successfully.
- Runtime candidate is an explicit review-only material mask; it adds no collision, Area, navigation or gameplay coordinates.
- Production Blend, foreground GLB, manifest and existing previews remain byte-identical.
- Default production tide visuals remain unchanged until the review profile is explicitly enabled.
- Review high tide keeps the Tide V1 `0.90` speed and `1.25` damping values unchanged.
- High tide, drain surface, wet bed and meniscus now use one precompiled lit shader authority: `assets/shaders/twin_bays_water_master.gdshader` SHA `5e3329ba02d99bc9d7dccd473a40fcff744857c4d859ddc93c780b991500f6ce`.
- The shared shader uses a depth prepass, world-space dual-flow normals and PBR roughness/specular response. It no longer replaces the approved floor, wall and pipe materials with an unshaded flat layer.
- Explicit white blob highlights were rejected during visual QA; the final candidate uses weak broad sheen so the water movement does not read as soap spots.
- The rejected constant-width runoff ribbons have been removed. Review residue now uses merged area puddles, secondary pools and droplets with changing topology.
- The visible residue and the footstep, landing and projectile contact query consume the same generated polygons; no invisible legacy ribbon remains interactive.
- Review water remains capped at three shared visual batches. Danger foam is one continuous perimeter batch rather than many overlapping transparent cards.
- Drain coverage is measured from the actual generated polygons at approximately `15% -> 8% -> 0%`; elongated parallel edges and sharp tips are forbidden by contract.
- Strict capture treats engine, script and shader errors as failures even when Godot exits with code zero.
- Golden update and full-map rollout remain locked.

## Human gate

Approved by the project owner on 2026-07-23. The approval is bound to the three SHAs above and unlocks only the isolated full-map review build. Production replacement, release Manifest and Golden updates remain locked until the full-map Godot evidence is approved.
