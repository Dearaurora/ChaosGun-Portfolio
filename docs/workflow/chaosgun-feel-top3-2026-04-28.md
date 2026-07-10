# ChaosGun Feel Top 3 Comparison - 2026-04-28

Command:

`powershell -ExecutionPolicy Bypass -File scripts/tests/run_feel_tuning_batch.ps1 -GodotPath E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe -Profiles candidate_v1,ringout_push,candidate_v2 -Runs 4 -Seconds 18 -SeedBase 280000 -OutPath reports\feel\batch-top3-r4.json`

Score command:

`powershell -ExecutionPolicy Bypass -File scripts/tests/score_feel_profiles.ps1 -InputPath reports\feel\batch-top3-r4.json`

| Profile | Score | Armed AI | Deaths | Ring-outs | Engagement Rate | Timely First Death Rate | Deathless Runs | Death Range |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ringout_push | 82.08 | 1.5 | 2.5 | 2.5 | 1.0 | 1.0 | 0 | 1 |
| candidate_v1 | 80.00 | 1.25 | 2.5 | 2.5 | 1.0 | 1.0 | 0 | 1 |
| candidate_v2 | 76.67 | 1.5 | 2.75 | 2.75 | 1.0 | 0.75 | 0 | 3 |

Read:

- `ringout_push` is the best current profile for automated comparison. It keeps every seed engaged, every first death in the target window, and has low death variance.
- `candidate_v1` remains close and should stay in live-play comparison because its recoil is slightly closer to the original baseline.
- `candidate_v2` is not a promotion candidate yet. It increased average kills, but its death range widened and one seed had a late first death.

Next pass:

Use `ringout_push` as the automated benchmark and compare it against `candidate_v1` in live play. If live play says `ringout_push` feels too floaty or too externally punishing, move back toward `candidate_v1` rather than toward `candidate_v2`.
