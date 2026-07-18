extends "res://scripts/maps/party_shooter_camera_director.gd"


func configure(camera: Camera3D, profile: Dictionary = {}) -> void:
	var open_profile := {
		"profile_id": "open_ringout",
		"map_focus": Vector3(2.0, 1.0, 2.0),
		"view_offset": STANDARD_GAMEPLAY_VIEW_OFFSET,
		"initial_size": 50.0,
		"idle_overview_size": 58.5,
		"min_size": 36.0,
		"max_size": 92.0,
		"playable_min": Vector2(-48.0, -39.0),
		"playable_max": Vector2(48.0, 39.0),
		"focus_min": Vector2(-43.0, -33.0),
		"focus_max": Vector2(44.0, 34.0),
		"track_min_y": -2.0,
		"world_frame_padding": 4.5,
		"character_screen_radius": 3.2,
		"screen_edge_gutter": 20.0,
		"min_layout_viewport": Vector2(640.0, 360.0),
		"fallback_layout_viewport": Vector2(1152.0, 648.0),
		"reserve_corner_hud": true,
		"reveal_focus": Vector3(-4.5, 1.0, -6.5),
		"reveal_size": 76.0,
		"reveal_duration": 1.35,
		"winner_focus_size": 29.5,
		"winner_focus_duration": 0.72,
	}
	for key in profile:
		open_profile[key] = profile[key]
	super.configure(camera, open_profile)
