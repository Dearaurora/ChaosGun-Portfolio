# ChaosGun Unity Migration

This is a first playable Unity migration of the Godot prototype.

Open `Assets/ChaosGun/Scenes/ChaosGunArena.unity` and press Play.

Controls:
- Move: WASD
- Jump: Space
- Aim/fire: mouse
- Reset to pistol: 1
- Pick up yellow weapon boxes to switch to SMG, AK Rifle, or Sniper

Migrated core behavior:
- Knockback-first combat
- Lives, death, respawn, temporary invincibility
- Pistol, SMG, AK Rifle, Sniper tuning inspired by the Godot `WeaponData`
- Simple AI opponent
- Ring-out arena and HUD

Still to migrate:
- Godot scenes and authored map layouts
- Commercial Slice A glTF dressing pass
- Original audio hookups
- Full UI menu flow and character select
- Weapon spawner timings and detailed visual feedback
