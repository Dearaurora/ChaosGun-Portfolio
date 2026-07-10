# ChaosGun Live-Play A/B - 2026-04-28

Purpose: decide whether automated benchmark winner `ringout_push` should become the live hand-feel baseline, using `candidate_v1` as the direct challenger.

## Launch Commands

Benchmark profile:

`powershell -ExecutionPolicy Bypass -File scripts/playtest/launch_commercial_slice_playtest.ps1 -GodotPath E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe -Profile ringout_push`

Challenger profile:

`powershell -ExecutionPolicy Bypass -File scripts/playtest/launch_commercial_slice_playtest.ps1 -GodotPath E:\AITools\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe -Profile candidate_v1`

Default launch now uses `ringout_push` if `-Profile` is omitted. Each launch writes a notes template under `reports\feel\live-play`.

The in-game HUD shows the active profile as `FEEL: <PROFILE_ID>` below the center score display. Check this before scoring a run.

## Test Order

1. Play `ringout_push` for 3 short matches.
2. Play `candidate_v1` for 3 short matches.
3. Return to `ringout_push` for 1 match to check whether the preference still holds after contrast.

Use the same map and human-vs-3-AI setup each time.

## Notes To Capture

Score each item from 1 to 5:

| Item | What 1 Means | What 5 Means |
| --- | --- | --- |
| Shooter recoil comfort | fighting the controls | punchy but controllable |
| Hit knockback readability | unclear why targets move | obvious and satisfying |
| Ring-out satisfaction | random or cheap | earned and readable |
| Weapon contrast | guns feel samey | guns have distinct roles |
| Match pacing | dead air or chaos | steady pressure |

Also record one sentence for:

- Most satisfying moment.
- Most frustrating moment.
- Whether the profile should be stronger, softer, or kept.

## Promotion Rule

Promote `ringout_push` if it scores equal or higher than `candidate_v1` on ring-out satisfaction and does not lose by more than 1 point on recoil comfort.

Promote `candidate_v1` if `ringout_push` feels too chaotic, too floaty, or too externally punishing despite the automated score advantage.

If neither profile feels right, tune between them. Do not use `candidate_v2` as the next base unless the product goal shifts toward more chaotic kill output.
