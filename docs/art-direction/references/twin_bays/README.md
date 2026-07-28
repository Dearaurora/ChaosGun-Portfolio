# Twin Bays reference freeze

Frozen on 2026-07-16 for **Twin Bays Splash Arena / 双湾水上竞技场**.

## Authority order

1. `res://resources/maps/twin_bays_layout_v1.json` and the current Godot
   production scene are the structural, placement, collision, and camera
   authority.
2. `twin_bays_as_built_reference_v1.png` is the approved human-readable
   structure/composition reference. Its companion JSON binds it to the frozen
   Godot source capture and the canonical layout SHA.
3. `twin_bays_splash_arena_selected_background.png` is **Mood Reference Only**.
   It controls palette, material language, rounded shape language, background
   water, and party-shooter tone only. It must never be used to infer geometry.
4. Earlier whitebox, structure, foreground-style, and dry-floor images remain
   design-history evidence. They cannot override the current as-built contract.
5. `twin_bays_art_v3.json` and `twin_bays_tide_v1.json` override the historical
   dry-floor-only rule. Concept splash shapes still cannot define runtime water.

The complete conflict and retirement rules live in
`res://docs/art-direction/twin-bays-reference-contract.md`.

## Tide-aware floor contract

The gameplay floor is warm cream tile/resin while dry. Water may appear only as
the configured high-tide surface, source-connected retreat network, wet
footprints, projectile/landing feedback, or portal effects. It must not contain:

- static ellipse puddles or painted splash shapes copied from concept art;
- gameplay-floor water unrelated to a Tide V1 phase or runoff source;
- `Decal` nodes projecting water onto platform sides;
- screen-space reflection or refraction water.

All water remains collision-free. Central bays and outer gaps remain lethal at
every tide phase. Tide residue must respect spawn, pickup, portal-exit, cover,
and danger-edge clean zones.

## Frozen visual tokens

| Role | Token | Intent |
| --- | --- | --- |
| Dry floor | `#F4EFE7` | Warm cream, high value, matte |
| Wall/cover | `#4FC5D8` | Aqua cyan, clean tile/plastic |
| Soft cap | `#FF8F82` | Coral, rounded and toy-like |
| Hazard edge | `#FFD54A` | Sunny yellow, readable over water |
| Pickup marker | `#FF8A3D` | Orange, open and unobstructed |
| Portal | `#36D9FF` | Bright cyan, depth-tested glow |

Large clean color fields, rounded low-poly silhouettes, low-noise seams, and clear roughness separation are mandatory. Lab/mechanical clutter, logos, and text are out of scope.

## Frozen files and SHA-256

| File | SHA-256 |
| --- | --- |
| `twin_bays_as_built_reference_v1.png` | `2DB58AB4D246BB8D25F53C9CDAC85D2B2FC12932FD579060256B6F95FC992E0D` |
| `twin_bays_as_built_reference_v1.json` | `2C660F52DDA13A703A2E8DA045BAEC4E1E87CB9256E05C30824F8A7E816AC76F` |
| `twin_bays_as_built_source_empty_v1.png` | `04C8DCA087E62C233225621C0D5F7EEB2FE238FD50257AAED9F480A370DAEF93` |
| `twin_bays_dry_floor_implementation_baseline.png` | `5FB4792C98688BECFEAE6033F3BE3709F3425832592BFE0BD753873ACE594E1A` |
| `twin_bays_splash_arena_foreground_style.png` | `3C190A62909AE6CB780082A46109E1616F21711BACFDB97FB567F23158896C9E` |
| `twin_bays_splash_arena_selected_background.png` | `8E838DB1D12560C106ED40B2986F098A0E3DA2C7E7C9830615A8961EB50D043C` |
| `twin_bays_structure_reference.png` | `2F6192FC3C972BF5BD3DEEE9738B9CBF2F6954E3A279445BEE69A09632441E89` |
| `twin_bays_whitebox_baseline.png` | `2FFB45F866FBCA6A34FE8ED224D65D117051936813DAEDC18628DAACFFE6D5FE` |
