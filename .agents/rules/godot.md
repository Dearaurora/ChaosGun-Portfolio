---
trigger: always_on
glob:
description:
---

# Godot visual-test window policy

When launching Godot for an interactive or visual test, use a windowed half-screen
viewport by default: `--windowed --resolution 960x540`. Do not use fullscreen.

Headless import, verifier, smoke, and screenshot-capture commands are exempt.
This is an agent test-launch preference only; do not change `project.godot` display
defaults unless the task explicitly asks to change the shipped game configuration.

