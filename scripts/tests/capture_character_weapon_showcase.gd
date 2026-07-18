extends SceneTree

const DEFAULT_OUT_PATH := "res://reports/character_weapon_p9_showcase.png"
const VIEWPORT_SIZE := Vector2i(1536, 800)
const MuzzleFlashScene: PackedScene = preload("res://scenes/effects/muzzle_flash.tscn")

var _showcase_entries: Array = []

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
	if OS.get_cmdline_user_args().has("--fire-poses"):
		_stage_fire_poses(stage)
		await process_frame
	elif OS.get_cmdline_user_args().has("--authored-motion"):
		await _stage_authored_motion_states(stage)
	elif OS.get_cmdline_user_args().has("--motion"):
		_stage_motion_states(stage)
		await process_frame
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
	_showcase_entries = [
		{"x": 5.05, "weapon": &"pistol", "color": Color("#ef4d53")},
		{"x": 1.68, "weapon": &"smg", "color": Color("#75ca3e")},
		{"x": -1.68, "weapon": &"ak_rifle", "color": Color("#f2bd31")},
		{"x": -5.05, "weapon": &"sniper", "color": Color("#28a8df")},
	]
	if OS.get_cmdline_user_args().has("--authored-motion"):
		_showcase_entries = [
			{"x": 4.70, "weapon": &"pistol", "color": Color("#ef4d53"), "state": "START"},
			{"x": 1.55, "weapon": &"smg", "color": Color("#75ca3e"), "state": "RUN"},
			{"x": -1.55, "weapon": &"ak_rifle", "color": Color("#f2bd31"), "state": "STOP"},
			{"x": -4.55, "weapon": &"shotgun", "color": Color("#28a8df"), "state": "HIT"},
		]
	if OS.get_cmdline_user_args().has("--heavy"):
		_showcase_entries = [
			{"x": 3.35, "weapon": &"gatling", "color": Color("#ef4d53")},
			{"x": -3.35, "weapon": &"shotgun", "color": Color("#28a8df")},
		]
	for entry in _showcase_entries:
		var visual := CharacterVisual.new()
		visual.body_color = entry["color"]
		visual.position = Vector3(float(entry["x"]), 0.0, 0.0)
		visual.rotation_degrees.y = 52.0 if OS.get_cmdline_user_args().has("--authored-motion") else 25.0
		visual.set_meta("showcase_weapon", String(entry["weapon"]))
		visual.set_meta("showcase_state", String(entry.get("state", "")))
		stage.add_child(visual)
		visual.call_deferred("set_weapon_visual", entry["weapon"])

func _stage_fire_poses(stage: Node3D) -> void:
	for child in stage.get_children():
		if not (child is CharacterVisual):
			continue
		var visual := child as CharacterVisual
		var weapon_id := StringName(String(visual.get_meta("showcase_weapon", "pistol")))
		visual.animate_fire(weapon_id)
		visual.call("_process", 0.0)
		var flash := MuzzleFlashScene.instantiate() as Node3D
		if flash == null:
			continue
		var fire_direction := -visual.global_basis.z.normalized()
		flash.call("configure", fire_direction, _effect_color_for_weapon(weapon_id), weapon_id)
		stage.add_child(flash)
		flash.global_position = visual.to_global(visual.get_weapon_muzzle_local_position(weapon_id))

func _effect_color_for_weapon(weapon_id: StringName) -> Color:
	match weapon_id:
		&"smg":
			return Color("#8ee63f")
		&"ak_rifle":
			return Color("#ffb13b")
		&"sniper":
			return Color("#5ce3ff")
		&"gatling":
			return Color("#ffd34d")
		&"shotgun":
			return Color("#d884ff")
		_:
			return Color("#ff6b72")

func _stage_motion_states(stage: Node3D) -> void:
	for child in stage.get_children():
		if not (child is CharacterVisual):
			continue
		var visual := child as CharacterVisual
		match String(visual.get_meta("showcase_weapon", "")):
			"pistol":
				visual.animate_fire(&"pistol")
			"smg":
				for _step in range(12):
					visual.animate_locomotion(Vector3.RIGHT, Vector3.FORWARD, 1.0, 1.0 / 60.0)
			"ak_rifle":
				visual.animate_hit(Vector3.RIGHT, 1.0)
				visual.animate_locomotion(Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0 / 60.0)
			"sniper":
				visual.animate_fire(&"sniper")
				visual.animate_locomotion(Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0 / 60.0)

func _stage_authored_motion_states(stage: Node3D) -> void:
	var hit_triggered := false
	for frame in range(60):
		var elapsed := float(frame) / 60.0
		for child in stage.get_children():
			if not (child is CharacterVisual):
				continue
			var visual := child as CharacterVisual
			match String(visual.get_meta("showcase_state", "")):
				"START":
					var starts_now := elapsed >= 0.80
					visual.animate_locomotion(Vector3.FORWARD if starts_now else Vector3.ZERO, Vector3.FORWARD, 1.0 if starts_now else 0.0, 1.0 / 60.0)
				"RUN":
					visual.animate_locomotion(Vector3.FORWARD, Vector3.FORWARD, 1.0, 1.0 / 60.0)
				"STOP":
					var still_running := elapsed < 0.80
					visual.animate_locomotion(Vector3.FORWARD if still_running else Vector3.ZERO, Vector3.FORWARD, 1.0 if still_running else 0.0, 1.0 / 60.0)
				"HIT":
					visual.animate_locomotion(Vector3.ZERO, Vector3.FORWARD, 0.0, 1.0 / 60.0)
					if elapsed >= 0.90 and not hit_triggered:
						visual.animate_hit(Vector3.RIGHT, 1.0)
						hit_triggered = true
		await create_timer(1.0 / 60.0).timeout
	for child in stage.get_children():
		if child is CharacterVisual:
			(child as CharacterVisual).rotation_degrees.y = 52.0
	await process_frame

func _build_camera(stage: Node3D) -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.3 if OS.get_cmdline_user_args().has("--heavy") else 7.0
	camera.current = true
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 3.1, -10.0), Vector3(0.0, 1.25, -0.2), Vector3.UP)

func _build_labels(stage: Node3D) -> void:
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	var names: Array[String] = []
	for entry in _showcase_entries:
		var weapon_label := String(entry["weapon"]).replace("_", " ").to_upper()
		if entry.has("state"):
			names.append("%s  /  %s" % [String(entry["state"]), weapon_label])
		else:
			names.append(weapon_label)
	for i in range(names.size()):
		var label := Label.new()
		label.text = names[i]
		if names.size() == 2:
			label.position = Vector2(180.0 + i * 768.0, 714.0)
			label.size = Vector2(408.0, 54.0)
		else:
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
