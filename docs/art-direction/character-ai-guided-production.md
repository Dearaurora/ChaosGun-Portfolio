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
- `assets/source/characters/hero_character_rig_v1.blend`: editable armature, IK controls, and topology-aware skin weights.
- `assets/models/generated/characters/hero_character_rig_v1.glb`: neutral-pose skinned runtime candidate.
- `tools/build_hero_character_rig_v1.py`: reproducible rig, export, and pistol/AK/sniper pose preview build.
- `tools/verify_hero_character_rig.py`: Blender GLB round-trip verifier.
- `scripts/tests/hero_character_rig_asset_verifier.gd`: Godot skeleton and skin verifier.

## Verified result

- Reconstruction source: 272,484 polygons.
- Cleaned body target: 45,000 polygons.
- Exported character total: 45,628 polygons across the body, face panel, and two eyes.
- Blender GLB round-trip: passed.
- Godot 4.6.2 scene import: passed.
- Rig candidate: 15 bones and 41,365 imported Blender polygons.
- Rig topology: the non-manifold reconstructed sleeves are removed; each replacement sleeve uses a continuous 15-ring, 16-segment deformation mesh with an integrated rounded shoulder cap.
- Rig weighting: the torso and hidden shoulder sockets remain on `Spine`, gloves and boots use rigid weights, and replacement sleeves blend only between their upper-arm and forearm bones.
- Blender rig round-trip: passed with one armature, nine imported mesh objects, and five skinned meshes.
- Godot 4.6.2 rig import: passed with one `Skeleton3D`, eight visible mesh nodes, and five imported `Skin` resources.
- Pistol, AK, and sniper two-hand inspection poses: rendered without torso penetration, torso wrinkles, or automatic-weight spikes.

## Runtime contract

- The face panel and eyes remain independent named meshes.
- The body keeps distinct suit and rubber material regions.
- Weapon assets remain independent GLBs with authored holder and muzzle anchors.
- The character must expose separate pistol and long-gun hand targets before runtime integration.
- Held weapon bounds must remain in front of the torso depth plane.

## Current limitation

`hero_character_cloud_v1.glb` remains the unrigged art base. `hero_character_rig_v1.glb` is the first validated deformation candidate, but it is not yet the final playable mesh: reconstructed material borders and the subtle shoulder-socket seam still need visual cleanup, the inspection poses are Blender IK poses rather than baked runtime animations, and weapon sockets have not yet been authored into the exported skeleton contract. It must not replace the current runtime character until those steps and an isolated in-engine combat-pose check pass.
