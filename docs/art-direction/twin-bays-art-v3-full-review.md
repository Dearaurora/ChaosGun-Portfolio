# Twin Bays Art V3 Full-Map Review

Status: `APPROVED 2026-07-23 — PRODUCTION REPLACEMENT IN PROGRESS`

Hero gate: `APPROVED 2026-07-23`

Layout SHA: `211ed22c8b9a3af358ec2058bbabf2a976b7a2158d1f18f887bebd9cd966217a`

Art V3 SHA: `ccbaba05cf471e400f1102318ae44defa886133bf484d8cbf3cbb645db68cd3d`

Tide V1 SHA: `45caaa9ea785b9bd136e0839cae20bf6ba70a662c949119484e04d32c84b7a46`

## Isolated candidate assets

| Asset | Path | SHA-256 |
|---|---|---|
| Editable Blend | `_art_source_review/twin_bays_art_v3_full/twin_bays_art_v3_full_review.blend` | `18436eaeb6e50bd953aa3a51394cd72f9460cc5bf3e02d6f12d100f8ff8c73be` |
| Full foreground GLB | `assets/review/twin_bays_art_v3/full_map/twin_bays_art_v3_full_foreground.glb` | `fd2e41a75263973cdfcfc446ded480af9d6c48606b697dd4420061b0070851f8` |
| Review manifest | `assets/review/twin_bays_art_v3/full_map/twin_bays_art_v3_full_manifest.json` | `4570ffeb03e9d2c74c5d239aa0ae98736b2e9a30f0c2c12eeb6de9f46688d9d6` |

The candidate has seven material-batched foreground meshes, eight primary materials, 33 foreground semantic anchors and 26,692 triangles. It contains no collision, navigation, camera, light, character, weapon or dynamic portal effect. The project owner approved this exact candidate and its bound Layout/Art/Tide fingerprint on 2026-07-23.

## Runtime evidence

| State | Evidence | SHA-256 |
|---|---|---|
| Dry overview | `reports/twin_bays_art_v3_full_dry_1536x1024.png` | `91bc70963c07dec6f44cd600c449bc52486fca10e4403d18275f48d8a54a34eb` |
| High tide | `reports/twin_bays_art_v3_full_high_1536x1024.png` | `67f87e1805aeb4f215bd7849af7571eae757cb064da45093f473b7dc3db0d00b` |
| Drain 0 s | `reports/twin_bays_art_v3_full_drain_0_1536x1024.png` | `88a442705c6afb784e8d7030b69434e26a63e04db07ac7ad4267c7c656128eb7` |
| Drain 9 s | `reports/twin_bays_art_v3_full_drain_9_1536x1024.png` | `ad7c6b1910ad72d95386e6b06f411a29e0adff7ea226e2dd5162404f9820c928` |
| Four-player high-tide battle | `reports/twin_bays_art_v3_full_battle_1920x1080.png` | `68a66fa841455749852d921053b6a3a9fc028f78a50facf1c9832a89a618c328` |
| HUD-safe 1280×720 | `reports/twin_bays_art_v3_full_mobile_1280x720.png` | `ca40b7062683fa8f8f7e65ddb91678cf6031070f79c6324873205ede75034df2` |
| Production isolation guard | `reports/twin_bays_art_v3_production_guard_empty.png` | `526c301667e700720d24924fddf2f858eeb579b2c93d0f8616fbe94cea7a2886` |

## Comparison evidence

| Comparison | Path | SHA-256 |
|---|---|---|
| Old production vs new full candidate | `reports/twin_bays_art_v3_full_compare_old_new_dry.png` | `9122839e81b1c6cd86d946be7e51c093a7c4c6a13468e47958e2611af55020d4` |
| Mood reference vs as-built candidate | `reports/twin_bays_art_v3_full_compare_concept_mood.png` | `3415765b781f863b310f5c51c6761030797fa21cb044a6102703efa7ac7e5554` |

## Review iterations

1. Full-map expansion initially exposed the old flat cyan backdrop. It was rejected because it did not carry the selected concept's water-park atmosphere.
2. Background water now uses a precompiled dual-scale caustic shader with a deeper central bay and restrained moving light lines.
3. The first full-map high-tide pass exposed a continuous grey foam strip across the central deck. It was rejected as floor-paint language.
4. Danger foam is now one batched mesh containing sparse, low-alpha crests seated on the water side. Yellow geometry remains the primary danger boundary.
5. The final strict runner captured all six required states and passed the full-candidate runtime, geometry, material, shader, collision and production-protection checks.

## Locked boundaries

- Production Blend, GLBs, manifest, previews and Golden remain byte-identical.
- Full-map approval does not authorize layout, collision, camera, portal, pickup, character or weapon changes.
- Golden update remains prohibited until production replacement, AI, performance and release validation pass.
