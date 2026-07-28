extends SceneTree

const DEFAULT_OUT_PATH := "res://reports/weapon_spawn_p10_showcase.png"
const VIEWPORT_SIZE := Vector2i(960, 540)

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Weapon spawn showcase requires a render-capable display driver")
		quit(1)
		return
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	_build_environment(stage)
	_build_floor(stage)
	_build_lighting(stage)
	_build_camera(stage)
	_build_spawn_states(stage)
	_build_labels(stage)
	await process_frame
	await process_frame
	await create_timer(0.34).timeout
	var image := root.get_texture().get_image()
	var out_path := _resolve_output_path()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("Could not save weapon spawn showcase to %s" % out_path)
		quit(1)
		return
	print("Saved weapon spawn showcase: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)

func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9293d8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f3d9c5")
	environment.ambient_light_energy = 0.58
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.8
	world_environment.environment = environment
	stage.add_child(world_environment)

func _build_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(16.0, 0.5, 5.4)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ef9360")
	material.roughness = 0.82
	mesh.material = material
	floor.mesh = mesh
	floor.position = Vector3(0.0, -0.32, 0.2)
	stage.add_child(floor)

func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffd0a1")
	key.light_energy = 1.38
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color("#9bc6ff")
	fill.light_energy = 1.8
	fill.omni_range = 13.0
	fill.position = Vector3(-5.0, 4.0, -4.0)
	stage.add_child(fill)

func _build_camera(stage: Node3D) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.8
	camera.current = true
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 4.3, -10.8), Vector3(0.0, 0.55, 0.0), Vector3.UP)

func _build_spawn_states(stage: Node3D) -> void:
	var entries := [
		{"x": 4.75, "premium": true, "state": WeaponSpawnPedestal.VisualState.ACTIVE, "color": Color("#ff9b23"), "weapon": WeaponData.create_ak_rifle(), "kind": "fixed"},
		{"x": 1.58, "premium": false, "state": WeaponSpawnPedestal.VisualState.ACTIVE, "color": Color("#79d946"), "weapon": WeaponData.create_smg(), "kind": "random"},
		{"x": -1.58, "premium": false, "state": WeaponSpawnPedestal.VisualState.PREWARM, "color": Color("#31bde8"), "weapon": null, "kind": "random"},
		{"x": -4.75, "premium": false, "state": WeaponSpawnPedestal.VisualState.COOLING, "color": Color("#6a7382"), "weapon": null, "kind": "random"},
	]
	var pickup_scene := load("res://scenes/weapons/weapon_pickup.tscn") as PackedScene
	for entry in entries:
		var pedestal := WeaponSpawnPedestal.new()
		pedestal.position = Vector3(float(entry["x"]), 0.50, 0.0)
		stage.add_child(pedestal)
		pedestal.configure(bool(entry["premium"]))
		pedestal.set_state(int(entry["state"]), entry["color"])
		if entry["weapon"] != null:
			var pickup := pickup_scene.instantiate() as WeaponPickup
			pickup.position = Vector3(float(entry["x"]), 0.50, 0.0)
			stage.add_child(pickup)
			pickup.setup(entry["weapon"])
			pickup.configure_spawn_presentation(String(entry["kind"]))

func _build_labels(stage: Node3D) -> void:
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	var names := ["CENTER ACTIVE", "OUTER ACTIVE", "PREWARM", "COOLING"]
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
