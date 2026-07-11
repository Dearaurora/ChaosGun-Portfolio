extends SceneTree

const DEFAULT_OUT_PATH := "res://reports/character_combat_feedback_showcase.png"
const VIEWPORT_SIZE := Vector2i(1536, 800)

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Character combat feedback showcase requires a render-capable display driver")
		quit(1)
		return
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var stage := Node3D.new()
	stage.name = "CharacterCombatFeedbackShowcase"
	root.add_child(stage)
	current_scene = stage
	_build_environment(stage)
	_build_floor(stage)
	_build_lighting(stage)
	_build_camera(stage)
	_build_states(stage)
	_build_labels(stage)

	await process_frame
	await process_frame
	await create_timer(0.025).timeout
	_spawn_transition(stage, -1.7, &"ringout")
	_spawn_transition(stage, -5.1, &"respawn")
	var hit_visual := stage.get_node_or_null("Visual_hit") as CharacterVisual
	var hit_feedback := stage.get_node_or_null("Feedback_hit") as CharacterCombatFeedback
	var showcase_impact := Vector3(0.8, 0.0, 1.0).normalized()
	if hit_visual:
		hit_visual.animate_hit(showcase_impact, 1.1)
	if hit_feedback:
		hit_feedback.play_hit(showcase_impact, 1.1)
	await process_frame
	var image := root.get_texture().get_image()
	var out_path := _resolve_output_path()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("Could not save feedback showcase to %s" % out_path)
		quit(1)
		return
	print("Saved character combat feedback showcase: %s" % ProjectSettings.globalize_path(out_path))
	quit(0)

func _build_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8f8fd6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f2d8c4")
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
	mesh.size = Vector3(15.5, 0.5, 5.4)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#f29a61")
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
	camera.size = 6.5
	camera.current = true
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 4.0, -10.5), Vector3(0.0, 1.18, 0.0), Vector3.UP)

func _build_states(stage: Node3D) -> void:
	var entries := [
		{"x": 5.1, "color": Color("#ef4d53"), "mode": &"hit"},
		{"x": 1.7, "color": Color("#75ca3e"), "mode": &"shield"},
		{"x": -1.7, "color": Color("#f2bd31"), "mode": &"ringout"},
		{"x": -5.1, "color": Color("#28a8df"), "mode": &"respawn"},
	]
	for entry in entries:
		var mode := entry["mode"] as StringName
		var x := float(entry["x"])
		if mode != &"ringout":
			var visual := CharacterVisual.new()
			visual.name = "Visual_%s" % String(mode)
			visual.body_color = entry["color"]
			visual.position = Vector3(x, 0.0, 0.0)
			visual.rotation_degrees.y = 18.0
			stage.add_child(visual)
			visual.call_deferred("set_weapon_visual", &"pistol")
			var feedback := CharacterCombatFeedback.new()
			feedback.name = "Feedback_%s" % String(mode)
			feedback.position = Vector3(x, 0.0, 0.0)
			stage.add_child(feedback)
			if mode == &"shield":
				feedback.call_deferred("set_shield_active", true)

func _spawn_transition(stage: Node3D, x: float, mode: StringName) -> void:
	var transition_scene := load("res://scenes/effects/character_transition_burst.tscn") as PackedScene
	if transition_scene == null:
		return
	var transition := transition_scene.instantiate() as Node3D
	var effect_color := Color("#ff4d62") if mode == &"ringout" else Color("#6ee7ff")
	transition.call("configure", mode, effect_color, 1.45 if mode == &"ringout" else 1.15)
	transition.position = Vector3(x, 0.0, 0.0)
	stage.add_child(transition)

func _build_labels(stage: Node3D) -> void:
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	var names := ["HIT", "RESPAWN SHIELD", "RING-OUT", "RESPAWN"]
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
