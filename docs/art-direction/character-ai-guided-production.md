# AI-guided character production

## Production decision

The approved character is produced with a hybrid workflow:

1. A clean neutral reference image defines the silhouette and proportions.
2. TripoSR creates a local, open-source 3D reconstruction used only as a volume reference.
3. Blender generates the production character as clean, named, multipart geometry.
4. Godot switches authored pistol and long-gun pose sets at runtime.

The AI reconstruction is not shipped as the playable mesh. Its fused topology is unsuitable for reliable posing, hand placement, material control, and later animation.

## Runtime contract

- The body, helmet shell, helmet collar, inset face, visor frame, legs, and boots remain independent named parts.
- Pistol and long-gun arms and gloves are separate visibility sets.
- Pistol, SMG, AK rifle, and sniper rifle remain independent GLB assets.
- Each weapon has an authored holder position and muzzle anchor.
- Held weapon bounds must remain in front of the torso depth plane.

## Source assets

- `assets/source/characters/reference/character_ai_input_v1.png`: neutral reconstruction input.
- `assets/source/characters/ai_reconstruction_v1/0/mesh.obj`: TripoSR volume reference.
- `assets/source/characters/ai_reconstruction_v1/character_ai_candidate_v1.blend`: reviewed AI candidate.
- `assets/source/characters/bean_character.blend`: clean production source.
- `assets/models/generated/characters/bean_character.glb`: runtime export.

## Current scope

This pass establishes the production silhouette, character part hierarchy, weapon separation, and plausible two-point long-gun handling. Finger articulation, deformation rigging, and weapon-specific animation are later polish work and should build on this asset contract rather than replace it.
