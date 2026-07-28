# ChaosGun workspace rules

## Godot test-window safety

- Prefer `--headless` for every automated verification that does not require rendered pixels.
- Do not launch a visible Godot game or test window without the user's explicit approval.
- Any approved visible Godot test window must be normal windowed mode, decorated, not always-on-top, and no larger than 960x540.
- Never call `DisplayServer.window_move_to_foreground()`.
- Never set `WINDOW_FLAG_ALWAYS_ON_TOP` or `WINDOW_FLAG_BORDERLESS` to `true`.
- Never use fullscreen or exclusive-fullscreen modes.
- Never force a window position or move it between monitors, including `--position 0,0`.
- Do not disable or bypass `TestWindowPolicy`.
- High-resolution screenshots and videos must render through an off-screen viewport or offline pipeline; the physical host window must remain at or below 960x540.
