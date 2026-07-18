extends "res://scripts/maps/party_shooter_match_presentation.gd"
class_name OpenRingoutMatchPresentation

const INTRO_REVEAL_DURATION := 1.35
const WINNER_FOCUS_DELAY := 0.78
const WINNER_CAMERA_DURATION := 0.64
const READY_COLOR := Color("#fff4d6")
const GO_COLOR := Color("#ffd24a")
const INK_COLOR := Color("#251a35")

func configure(
	arena: Node3D,
	camera_director: Node,
	characters: Array,
	profile: Dictionary = {}
) -> void:
	var open_profile := {
		"profile_id": "open_ringout",
		"intro_reveal_duration": INTRO_REVEAL_DURATION,
		"winner_focus_delay": WINNER_FOCUS_DELAY,
		"winner_camera_duration": WINNER_CAMERA_DURATION,
		"ready_color": READY_COLOR,
		"go_color": GO_COLOR,
		"ink_color": INK_COLOR,
		"hud_root_names": ["HUDRoot"],
	}
	for key: Variant in profile:
		open_profile[key] = profile[key]
	super.configure(arena, camera_director, characters, open_profile)
