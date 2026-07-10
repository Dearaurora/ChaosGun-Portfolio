# ChaosGun Feel Top 2 Promotion - 2026-04-28

Command:

`powershell -ExecutionPolicy Bypass -File scripts/tests/run_feel_tuning_batch.ps1 -GodotPath E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe -Profiles ringout_push,candidate_v1 -Runs 6 -Seconds 18 -SeedBase 290000 -OutPath reports\feel\batch-top2-r6.json`

Score command:

`powershell -ExecutionPolicy Bypass -File scripts/tests/score_feel_profiles.ps1 -InputPath reports\feel\batch-top2-r6.json -OutPath reports\feel\score-top2-r6.json`

| Profile | Score | Armed AI | Deaths | Ring-outs | Engagement Rate | Timely First Death Rate | Deathless Runs | Death Range |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ringout_push | 76.39 | 1.33 | 2.83 | 2.83 | 1.0 | 0.83 | 0 | 4 |
| candidate_v1 | 74.72 | 1.33 | 2.33 | 2.33 | 1.0 | 0.83 | 0 | 2 |

Read:

- `ringout_push` remains the automated benchmark leader. It produces more deaths and ring-outs without any deathless seed.
- `candidate_v1` is close enough to keep as the live-play comparison profile. It has lower output but better death range.
- The gap is not large enough to delete either profile. The right next step is a live-play A/B pass, not another blind numerical tweak.

Promotion:

- Automated benchmark: `ringout_push`
- Live-play challenger: `candidate_v1`
- Regression reference: `default`

Next pass:

Run live-play notes against `ringout_push` first. If it feels too chaotic or too externally punishing, compare directly with `candidate_v1`; if `candidate_v1` feels underpowered, tune between these two profiles rather than returning to `candidate_v2`.
