extends "res://scripts/maps/twin_bays_arena_base.gd"

# The development whitebox intentionally aliases foreground and gameplay so its
# long-standing node paths and approved render stay stable. Production subclasses
# inherit the base's four distinct Gameplay/ForegroundVisuals/Backdrop/Portals roots.
func _twin_bays_layer_names() -> Dictionary:
	return {
		ROLE_GAMEPLAY: "TwinBaysWhitebox",
		ROLE_FOREGROUND: "TwinBaysWhitebox",
		ROLE_BACKDROP: "TwinBaysBackdrop",
		ROLE_PORTALS: "TwinBaysPortals",
	}

func _build_twin_bays_gameplay(parent: Node3D) -> void:
	var floor_mat := _make_unshaded_material(Color("#6f6a68"))
	var top_mat := _make_material(Color("#fffafe"))
	var cover_mat := _make_material(Color("#fffafe"))
	var wall_mat := _make_material(Color("#fffafe"))
	var north_wall_body_mat := _make_unshaded_material(Color("#7d7b7d"))
	var south_wall_body_mat := _make_material(Color("#807d83"))
	cover_mat.vertex_color_use_as_albedo = true
	wall_mat.vertex_color_use_as_albedo = true
	var pickup_mat := _make_emissive_material(Color("#fbaa7f"), 0.12, false)

	_build_curved_arena_surface(parent, floor_mat, top_mat)
	_build_outer_walls(parent, north_wall_body_mat, south_wall_body_mat, wall_mat)
	_build_cover_layout(parent, cover_mat)
	_build_pickup_markers(parent, pickup_mat)

func _build_twin_bays_foreground(_parent: Node3D) -> void:
	pass

func _build_twin_bays_backdrop(parent: Node3D) -> void:
	_spawn_whitebox_block(
		"VoidBackdrop",
		Vector3(0, -6.2, 0),
		Vector3(180, 0.35, 150),
		parent,
		_make_noise_backdrop_material(),
		false
	)

func _apply_twin_bays_environment_overrides() -> void:
	var light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light:
		light.rotation_degrees = Vector3(-52, -28, 0)
		light.light_color = Color("#f4f2ed")
		light.light_energy = 0.31
		light.shadow_enabled = true
		light.shadow_blur = 4.0
		light.shadow_opacity = 0.48

	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		env.tonemap_exposure = 0.78
		env.adjustment_contrast = 1.06
		env.adjustment_saturation = 0.92
		env.ambient_light_color = Color("#b8b8bc")
		env.ambient_light_energy = 0.55
		env.fog_enabled = false
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color("#505050")
		env.ssao_enabled = true
		env.ssao_radius = 0.85
		env.ssao_intensity = 0.70
		env.ssao_power = 1.0
		env.glow_enabled = true
		env.glow_intensity = 0.34
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = Color("#494949")
			sky_mat.sky_horizon_color = Color("#555555")
			sky_mat.ground_bottom_color = Color("#444444")
			sky_mat.ground_horizon_color = Color("#4d4d4d")
