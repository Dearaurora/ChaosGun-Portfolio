# ChaosGun Feel Tuning Loop

Goal: make combat tuning repeatable before judging hand feel from live play.

## Workflow

1. Probe one profile:
   `powershell -File scripts/tests/run_feel_tuning_probe.ps1 -GodotPath <Godot.exe> -Profile resources/feel_profiles/default.json -Seed 240429`
2. Batch several profiles:
   `powershell -File scripts/tests/run_feel_tuning_batch.ps1 -GodotPath <Godot.exe> -ProfileDir resources/feel_profiles -Runs 6 -SeedBase 240428`
   To focus a comparison, add `-Profiles ringout_push,candidate_v1`.
3. Score a batch:
   `powershell -File scripts/tests/score_feel_profiles.ps1 -InputPath reports/feel/batch-latest.json -OutPath reports/feel/score-latest.json`

## Profile Shape

Profiles are JSON files with:

- `game_config`: runtime values copied onto `GameConfig`.
- `weapon_feel_overrides`: per-weapon values applied when a `Weapon` is initialized.
- `score_targets`: optional thresholds used by the scorer.

`recoil_force` controls shooter recoil only. `knockback_power` controls projectile hit impulse only.

## Metrics

The probe runs the Commercial Slice A AI match and records:

- AI count that equipped a primary weapon.
- total deaths.
- suspected ring-out deaths.
- max simultaneous pickups and pickup clusters.
- first death timing.
- random seed used for the run.

The scorer intentionally favors stable ranges over single-run highs. A profile should be rerun before promotion if one run looks unusually good or bad.

The score table includes `EngagementRate`, `TimelyFirstDeathRate`, `DeathlessRuns`, and `DeathRange` so unstable profiles are visible even when their averages look strong. Treat any profile with deathless or slow-first-death samples in a small batch as a candidate for more runs, not as a winner.

Batch runs use the same seed for every profile at a given run index. That keeps profile comparisons closer to apples-to-apples while still allowing multiple seeds across `-Runs`.
