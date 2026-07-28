extends SceneTree

const DEFAULT_OUT_PATH := "res://reports/p21_combat_language.png"
const VIEWPORT_SIZE := Vector2i(960, 540)
const MuzzleFlashScene: PackedScene = preload("res://scenes/effects/muzzle_flash.tscn")
const HitEffectScene: PackedScene = preload("res://scenes/effects/hit_effect.tscn")
const ShotTracerScript = preload("res://scripts/effects/shot_tracer.gd")

var _entries := [
	{"weapon": &"pistol", "label": "PISTOL", "color": Color("#ff5d66"), "position": Vector3(-3.0, 0.0, -2.30)},
	{"weapon": &"smg", "label": "SMG", "color": Color("#75e05b"), "position": Vector3(3.0, 0.0, -2.30)},
	{"weapon": &"ak_rifle", "label": "AK RIFLE", "color": Color("#ff9f43"), "position": Vector3(-3.0, 0.0, 0.0)},
	{"weapon": &"sniper", "label": "SNIPER", "color": Color("#55d9f4"), "position": Vector3(3.0, 0.0, 0.0)},
	{"weapon": &"gatling", "label": "GATLING", "color": Color("#ffd34d"), "position": Vector3(-3.0, 0.0, 2.30)},
	{"weapon": &"shotgun", "label": "SHOTGUN", "color": Color("#d884ff"), "position": Vector3(3.0, 0.0, 2.30)},
]

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("P21 combat language capture requires a render-capable display driver")
		quit(1)
		return
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var stage := Node3D.new()
	stage.name = "P21CombatLanguage"
	root.add_child(stage)
	current_scene = stage
	_build_environment(stage)
	_build_floor(stage)
	_build_lighting(stage)
	_build_camera(stage)
	_build_labels(stage)
	_build_effect_chains(stage)

	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	var image := root.get_texture().get_image()
	var out_path := _resolve_output_path()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("Could not save P21 combat language capture to %s" % out_path)
		quit(1)
		return
	print("Saved P21 combat language capture: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)

func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#5d5796")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f2d5c4")
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

func _build_floor(stage: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(13.0, 0.18, 7.8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#d86f52")
	material.roughness = 0.82
	mesh.material = material
	floor.mesh = mesh
	floor.position.y = -0.12
	stage.add_child(floor)
	_add_divider(stage, Vector3(0.0, 0.015, 0.0), Vector3(0.035, 0.020, 7.3))
	for z in [-1.15, 1.15]:
		_add_divider(stage, Vector3(0.0, 0.015, z), Vector3(12.4, 0.020, 0.035))

func _add_divider(stage: Node3D, pos: Vector3, size: Vector3) -> void:
	var divider := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	divider.mesh = mesh
	divider.position = pos
	divider.scale = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.12, 0.24, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	divider.material_override = material
	divider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.add_child(divider)

func _build_lighting(stage: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("#ffd3a5")
	key.light_energy = 1.05
	key.rotation_degrees = Vector3(-54.0, -28.0, 0.0)
	key.shadow_enabled = false
	stage.add_child(key)

func _build_camera(stage: Node3D) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.2
	camera.current = true
	camera.position = Vector3(0.0, 15.0, 0.0)
	camera.rotation_degrees.x = -90.0
	stage.add_child(camera)

func _build_effect_chains(stage: Node3D) -> void:
	for entry in _entries:
		var center: Vector3 = entry["position"]
		var weapon_id: StringName = entry["weapon"]
		var color: Color = entry["color"]
		var flash := MuzzleFlashScene.instantiate() as Node3D
		flash.call("configure", Vector3.RIGHT, color, weapon_id)
		stage.add_child(flash)
		flash.position = center + Vector3(-2.05, 0.12, 0.0)
		flash.scale = Vector3.ONE * 1.28
		flash.process_mode = Node.PROCESS_MODE_DISABLED

		var tracer := ShotTracerScript.new() as Node3D
		tracer.call("setup", center + Vector3(-1.25, 0.10, 0.0), Vector3.RIGHT, color, _tracer_profile(weapon_id))
		stage.add_child(tracer)
		tracer.process_mode = Node.PROCESS_MODE_DISABLED

		var hit := HitEffectScene.instantiate() as Node3D
		hit.call("configure", color, weapon_id, Vector3.RIGHT)
		stage.add_child(hit)
		hit.position = center + Vector3(2.02, 0.11, 0.0)
		hit.scale = Vector3.ONE * 1.48
		hit.process_mode = Node.PROCESS_MODE_DISABLED

func _tracer_profile(weapon_id: StringName) -> Dictionary:
	match weapon_id:
		&"smg":
			return {"length": 1.20, "width": 0.10, "lifetime": 0.040, "style": &"tapered_streak"}
		&"ak_rifle":
			return {"length": 2.00, "width": 0.17, "lifetime": 0.055, "style": &"fork"}
		&"sniper":
			return {"length": 2.80, "width": 0.14, "lifetime": 0.070, "style": &"lance"}
		&"gatling":
			return {"length": 1.10, "width": 0.09, "lifetime": 0.036, "style": &"tapered_streak"}
		&"shotgun":
			return {"length": 1.45, "width": 0.11, "lifetime": 0.050, "style": &"pellet"}
		_:
			return {"length": 1.55, "width": 0.15, "lifetime": 0.052, "style": &"bolt"}

func _build_labels(stage: Node3D) -> void:
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	for index in range(_entries.size()):
		var column := index % 2
		var row := index / 2
		var label := Label.new()
		label.text = _entries[index]["label"]
		label.position = Vector2(180.0 + column * 768.0, 24.0 + row * 300.0)
		label.size = Vector2(408.0, 44.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 23)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color("#2a1b32"))
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
