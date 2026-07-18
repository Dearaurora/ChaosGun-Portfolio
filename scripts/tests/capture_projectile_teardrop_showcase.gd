extends SceneTree

const VIEWPORT_SIZE := Vector2i(1536, 820)
const DEFAULT_OUTPUT := "res://reports/projectile_teardrop_showcase.png"
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/pistol_projectile.tscn")

var _entries := [
	{"weapon": &"pistol", "label": "PISTOL", "position": Vector3(-3.6, 0.0, -1.25), "scale": 3.8},
	{"weapon": &"ak_rifle", "label": "AK RIFLE", "position": Vector3(0.0, 0.0, -1.25), "scale": 3.5},
	{"weapon": &"sniper", "label": "SNIPER", "position": Vector3(3.6, 0.0, -1.25), "scale": 3.2},
	{"weapon": &"smg", "label": "SMG", "position": Vector3(-3.6, 0.0, 1.45), "scale": 4.0},
	{"weapon": &"gatling", "label": "GATLING", "position": Vector3(0.0, 0.0, 1.45), "scale": 4.2},
	{"weapon": &"shotgun", "label": "SHOTGUN", "position": Vector3(3.6, 0.0, 1.45), "scale": 3.9},
]


func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Projectile teardrop capture requires a render-capable display driver")
		quit(1)
		return
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var stage := Node3D.new()
	stage.name = "ProjectileTeardropShowcase"
	root.add_child(stage)
	current_scene = stage
	_build_environment(stage)
	_build_floor(stage)
	_build_camera(stage)
	_build_projectiles(stage)
	_build_labels(stage)

	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	var output := _resolve_output_path()
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save projectile showcase to %s" % output)
		quit(1)
		return
	print("Saved projectile teardrop showcase: %s" % ProjectSettings.globalize_path(output))
	quit(0)


func _build_environment(stage: Node3D) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#6661a4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#fff1db")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	stage.add_child(world)


func _build_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(13.5, 0.22, 7.1)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d86f52")
	material.roughness = 0.82
	mesh.material = material
	floor.mesh = mesh
	floor.position.y = -0.20
	stage.add_child(floor)
	var divider := MeshInstance3D.new()
	var divider_mesh := BoxMesh.new()
	divider_mesh.size = Vector3(12.8, 0.025, 0.035)
	divider.mesh = divider_mesh
	divider.position = Vector3(0.0, -0.04, 0.10)
	var divider_material := StandardMaterial3D.new()
	divider_material.albedo_color = Color("#6f3650")
	divider.material_override = divider_material
	stage.add_child(divider)


func _build_camera(stage: Node3D) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.0
	camera.position = Vector3(0.0, 12.0, 0.0)
	camera.rotation_degrees.x = -90.0
	camera.current = true
	stage.add_child(camera)


func _build_projectiles(stage: Node3D) -> void:
	for entry in _entries:
		var projectile := PROJECTILE_SCENE.instantiate() as Projectile
		projectile.name = "%sTeardrop" % String(entry["weapon"])
		projectile.direction = Vector3.RIGHT
		projectile.speed = 0.0
		projectile.lifetime = 5.0
		projectile.configure_visual_profile(entry["weapon"], Color("#e96525"))
		stage.add_child(projectile)
		projectile.position = entry["position"]
		projectile.look_at_from_position(projectile.position, projectile.position + Vector3.RIGHT, Vector3.UP)
		projectile.scale = Vector3.ONE * float(entry["scale"])
		projectile.process_mode = Node.PROCESS_MODE_DISABLED


func _build_labels(stage: Node3D) -> void:
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	for index in range(_entries.size()):
		var column := index % 3
		var row := index / 3
		var label := Label.new()
		label.text = _entries[index]["label"]
		label.position = Vector2(110.0 + column * 512.0, 28.0 + row * 388.0)
		label.size = Vector2(300.0, 44.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color("#3a2340"))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		canvas.add_child(label)


func _resolve_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested := argument.trim_prefix("--output=").strip_edges()
			if requested.begins_with("res://reports/") and requested.ends_with(".png"):
				return requested
	return DEFAULT_OUTPUT
