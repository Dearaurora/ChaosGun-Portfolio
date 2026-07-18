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
5. The dry-floor contract below overrides every image. Blue splash shapes on
   concept floors are rejected reference residue.

The complete conflict and retirement rules live in
`res://docs/art-direction/twin-bays-reference-contract.md`.

## Dry-floor contract (veto rule)

Gameplay floor must be dry cream tile/resin. It may have low-contrast seams and broad roughness variation, but it must not contain:

- painted splash shapes, water stains, wet footprints, drips, puddles, or pooled-water meshes;
- `Decal` nodes used as wet marks;
- textures, masks, or shader parameters named for puddles, floor water, wetness, or dampness;
- reflections or gloss patches that imply standing water.

Water is legal only below/outside the playable platform in `Backdrop`, and as short-lived depth-tested portal-ring/transfer effects in `Portals`. Portal effects must not leave a mark on the floor.

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
| `twin_bays_as_built_reference_v1.png` | `6865D5376AE833FE917B5A758D2EF7465B74C11B8F663536349217AF67FCDBA3` |
| `twin_bays_as_built_reference_v1.json` | `FD14D2B338D578F435E38DCF0DCFEC7C7FC4716B8FA09BE16D410F5BC123F4F5` |
| `twin_bays_as_built_source_empty_v1.png` | `04C8DCA087E62C233225621C0D5F7EEB2FE238FD50257AAED9F480A370DAEF93` |
| `twin_bays_dry_floor_implementation_baseline.png` | `5FB4792C98688BECFEAE6033F3BE3709F3425832592BFE0BD753873ACE594E1A` |
| `twin_bays_splash_arena_foreground_style.png` | `3C190A62909AE6CB780082A46109E1616F21711BACFDB97FB567F23158896C9E` |
| `twin_bays_splash_arena_selected_background.png` | `8E838DB1D12560C106ED40B2986F098A0E3DA2C7E7C9830615A8961EB50D043C` |
| `twin_bays_structure_reference.png` | `2F6192FC3C972BF5BD3DEEE9738B9CBF2F6954E3A279445BEE69A09632441E89` |
| `twin_bays_whitebox_baseline.png` | `2FFB45F866FBCA6A34FE8ED224D65D117051936813DAEDC18628DAACFFE6D5FE` |
