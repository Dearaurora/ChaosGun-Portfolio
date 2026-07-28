extends SceneTree

const DEFAULT_OUT_PATH := "res://reports/p16_impact_showcase.png"
const VIEWPORT_SIZE := Vector2i(960, 540)
const HitEffectScene: PackedScene = preload("res://scenes/effects/hit_effect.tscn")

var _entries := [
	{"weapon": &"pistol", "label": "PISTOL", "color": Color("#ff6b72"), "position": Vector3(-4.2, 0.0, -1.4)},
	{"weapon": &"smg", "label": "SMG", "color": Color("#8ee63f"), "position": Vector3(0.0, 0.0, -1.4)},
	{"weapon": &"ak_rifle", "label": "AK RIFLE", "color": Color("#ffb13b"), "position": Vector3(4.2, 0.0, -1.4)},
	{"weapon": &"sniper", "label": "SNIPER", "color": Color("#5ce3ff"), "position": Vector3(-4.2, 0.0, 1.5)},
	{"weapon": &"gatling", "label": "GATLING", "color": Color("#ffd34d"), "position": Vector3(0.0, 0.0, 1.5)},
	{"weapon": &"shotgun", "label": "SHOTGUN", "color": Color("#d884ff"), "position": Vector3(4.2, 0.0, 1.5)},
]

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("P16 impact showcase requires a render-capable display driver")
		quit(1)
		return
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var stage := Node3D.new()
	stage.name = "P16ImpactShowcase"
	root.add_child(stage)
	current_scene = stage
	_build_environment(stage)
	_build_floor(stage)
	_build_lighting(stage)
	_build_camera(stage)
	_build_labels(stage)

	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	_spawn_impacts(stage)
	await process_frame
	var image := root.get_texture().get_image()
	var out_path := _resolve_output_path()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("Could not save P16 impact showcase to %s" % out_path)
		quit(1)
		return
	print("Saved P16 impact showcase: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)

func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#7773bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f3d8c8")
	environment.ambient_light_energy = 0.54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

func _build_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(18.0, 0.20, 9.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ef9560")
	material.roughness = 0.78
	mesh.material = material
	floor.mesh = mesh
	floor.position.y = -0.12
	stage.add_child(floor)

func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffd2a8")
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	key.shadow_enabled = false
	stage.add_child(key)

func _build_camera(stage: Node3D) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.2
	camera.current = true
	camera.position = Vector3(0.0, 10.0, 0.0)
	camera.rotation_degrees.x = -90.0
	stage.add_child(camera)

func _spawn_impacts(stage: Node3D) -> void:
	var direction := Vector3(0.88, 0.0, -0.48).normalized()
	for entry in _entries:
		var hit := HitEffectScene.instantiate() as Node3D
		hit.call("configure", entry["color"], entry["weapon"], direction)
		stage.add_child(hit)
		hit.position = entry["position"]

func _build_labels(stage: Node3D) -> void:
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	for index in range(_entries.size()):
		var column := index % 3
		var row := index / 3
		var label := Label.new()
		label.text = _entries[index]["label"]
		label.position = Vector2(128.0 + column * 512.0, 314.0 + row * 360.0)
		label.size = Vector2(256.0, 46.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color("#39263f"))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		canvas.add_child(label)

func _resolve_output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var requested := argument.trim_prefix("--output=").strip_edges()
			if requested.begins_with("res://") and requested.ends_with(".png"):
				return requested
	return DEFAULT_OUT_PATH
