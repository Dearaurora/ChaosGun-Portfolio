# ChaosGun Feel Baseline - 2026-04-28

Command:

`powershell -ExecutionPolicy Bypass -File scripts/tests/run_feel_tuning_batch.ps1 -GodotPath E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe -ProfileDir resources\feel_profiles -Runs 2 -Seconds 18 -SeedBase 260428 -OutPath reports\feel\batch-latest.json`

Score command:

`powershell -ExecutionPolicy Bypass -File scripts/tests/score_feel_profiles.ps1 -InputPath reports\feel\batch-latest.json`

| Profile | Score | Armed AI | Deaths | Ring-outs | Engagement Rate | Deathless Runs | Death Range | First Death |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| candidate_v1 | 86.25 | 2.0 | 2.5 | 2.5 | 1.0 | 0 | 1 | 8.57s |
| ringout_push | 83.33 | 2.0 | 2.0 | 2.0 | 1.0 | 0 | 0 | 9.73s |
| shooter_kick | 77.92 | 1.0 | 2.5 | 2.5 | 1.0 | 0 | 1 | 8.07s |
| default | 61.67 | 2.0 | 1.5 | 1.5 | 0.5 | 1 | 3 | 6.73s |

Read:

- `candidate_v1` is the best current candidate on the seeded two-run sample.
- `ringout_push` is the most stable of the strong candidates, with no deathless run and zero death range across this sample.
- `shooter_kick` still produces kills, but lower armed AI suggests the stronger self-kick profile may be less reliable for weapon participation.
- `default` remains viable but had one deathless run under the second seed, so it is weaker as a baseline for the next hand-feel pass.

Next tuning pass:

Use `candidate_v1` and `ringout_push` as the two live-play candidates. Keep `default` as the regression reference. Do not promote a profile from a two-seed sample alone; rerun with at least `-Runs 6` after live-play notes identify the preferred direction.
