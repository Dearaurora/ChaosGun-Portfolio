# AI-guided character production

## Production decision

The approved character now uses a multiview-first hybrid workflow:

1. One approved turnaround defines the front, side, back, and three-quarter silhouette.
2. Hunyuan3D-2mv reconstructs one consistent high-resolution volume from the clean views.
3. Blender converts that volume into a reviewable art base: normalize scale, reduce density, rebuild the face opening, add the face panel and eyes, and assign the suit materials.
4. The reviewed base is retopologized and rigged only after its silhouette is accepted.

Single-view reconstruction and procedural primitive assembly are no longer the primary production route. They remain useful for diagnostics and isolated props, but they did not preserve the approved character silhouette reliably enough.

## Current asset roles

- `assets/source/characters/reference/character_turnaround_v1.png`: approved visual target.
- `assets/source/characters/reference/turnaround_v1_mv/`: clean reconstruction views.
- `assets/source/characters/cloud_reconstruction_mv_v1/hero_multiview_candidate.glb`: untouched multiview reconstruction source.
- `assets/source/characters/hero_character_cloud_v1.blend`: cleaned Blender art base.
- `assets/models/generated/characters/hero_character_cloud_v1.glb`: reviewable Godot import candidate.
- `tools/build_hero_character_cloud_cleanup.py`: reproducible cleanup, export, and preview build.

## Verified result

- Reconstruction source: 272,484 polygons.
- Cleaned body target: 45,000 polygons.
- Exported character total: 45,628 polygons across the body, face panel, and two eyes.
- Blender GLB round-trip: passed.
- Godot 4.6.2 scene import: passed.

## Runtime contract

- The face panel and eyes remain independent named meshes.
- The body keeps distinct suit and rubber material regions.
- Weapon assets remain independent GLBs with authored holder and muzzle anchors.
- The character must expose separate pistol and long-gun hand targets before runtime integration.
- Held weapon bounds must remain in front of the torso depth plane.

## Current limitation

`hero_character_cloud_v1.glb` is an art-base candidate, not the final playable mesh. Its body is still a fused triangulated reconstruction, its material borders need retopology cleanup, and it has no skeleton, deformation loops, hand targets, or weapon sockets. It must not replace the current runtime character until those steps and the combat-pose checks pass.
