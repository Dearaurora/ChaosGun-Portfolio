# ChaosGun UI System

Selected visual target: central character stage, compact side slots, four-card roster rail, and a single bottom action rail.

## Tokens

- Ink: `#21142F`
- Soft ink: `#3B2548`
- Cream: `#FFF1CF`
- Muted cream: `#DFCCB8`
- Gold: `#F8C84F`
- P1 blue: `#4DA4FF`
- P2 orange: `#FF6248`
- P3 violet: `#D66BDC`
- P4 green: `#77CF6B`
- Panel radius: `12`
- Dialog radius: `18`
- Control radius: `10`
- Base spacing: `8`
- Interaction transitions: `120–220ms`

## Responsive frames

- Primary design: `1920×1080`
- Validation: `1280×720`, `1536×960`, `2560×1440`
- HUD footprint: four `200×72` cards using the existing safe-corner camera contract.

## Component inventory

- Shared screen shell
- Primary, secondary, focused, pressed, and disabled buttons
- Player slot card
- Compact roster status card
- Keybind column and keybind row
- HUD player card
- Match event banner (READY/GO and localized map warnings)
- Pause overlay
- Result grid

The Pencil source remains `docs/ui/chaosgun_ui_system.pen`. It must be authored through the Pencil MCP editor when its application WebSocket is available; this document is the deterministic token/component contract used by the running Godot implementation.
