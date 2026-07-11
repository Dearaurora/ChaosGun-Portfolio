extends SceneTree

const DEFAULT_OUT_PATH := "res://reports/character_weapon_p9_showcase.png"
const VIEWPORT_SIZE := Vector2i(1536, 800)

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Character weapon showcase requires a render-capable display driver")
		quit(1)
		return

	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var stage := Node3D.new()
	stage.name = "CharacterWeaponShowcase"
	root.add_child(stage)
	current_scene = stage
	_build_environment(stage)
	_build_floor(stage)
	_build_lighting(stage)
	_build_roster(stage)
	_build_camera(stage)
	_build_labels(stage)

	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	var image := root.get_texture().get_image()
	var out_path := _resolve_output_path()
	var err := image.save_png(out_path)
	if err != OK:
		push_error("Could not save showcase to %s, error %d" % [out_path, err])
		quit(1)
		return
	print("Saved character weapon showcase: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)

func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#e8ddd5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f3dfd2")
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 2.1
	world_environment.environment = environment
	stage.add_child(world_environment)

func _build_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(15.5, 0.5, 5.4)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d7b29d")
	material.roughness = 0.82
	mesh.material = material
	floor.mesh = mesh
	floor.position = Vector3(0.0, -0.32, 0.2)
	stage.add_child(floor)

func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffd0a1")
	key.light_energy = 1.45
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.shadow_enabled = true
	stage.add_child(key)

	var fill := OmniLight3D.new()
	fill.light_color = Color("#9bc6ff")
	fill.light_energy = 2.2
	fill.omni_range = 13.0
	fill.position = Vector3(-5.0, 4.0, -4.0)
	stage.add_child(fill)

func _build_roster(stage: Node3D) -> void:
	var entries := [
		{"x": 5.05, "weapon": &"pistol", "color": Color("#ef4d53")},
		{"x": 1.68, "weapon": &"smg", "color": Color("#75ca3e")},
		{"x": -1.68, "weapon": &"ak_rifle", "color": Color("#f2bd31")},
		{"x": -5.05, "weapon": &"sniper", "color": Color("#28a8df")},
	]
	for entry in entries:
		var visual := CharacterVisual.new()
		visual.body_color = entry["color"]
		visual.position = Vector3(float(entry["x"]), 0.0, 0.0)
		visual.rotation_degrees.y = 25.0
		stage.add_child(visual)
		visual.call_deferred("set_weapon_visual", entry["weapon"])

func _build_camera(stage: Node3D) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 3.1, -10.0), Vector3(0.0, 1.25, -0.2), Vector3.UP)

func _build_labels(stage: Node3D) -> void:
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	var names := ["PISTOL", "SMG", "AK RIFLE", "SNIPER"]
	for i in range(names.size()):
		var label := Label.new()
		label.text = names[i]
		label.position = Vector2(116.0 + i * 384.0, 714.0)
		label.size = Vector2(280.0, 54.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color("#39263f"))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 3)
		canvas.add_child(label)

func _resolve_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested := argument.trim_prefix("--output=").strip_edges()
			if requested.begins_with("res://") and requested.ends_with(".png"):
				return requested
	return DEFAULT_OUT_PATH
