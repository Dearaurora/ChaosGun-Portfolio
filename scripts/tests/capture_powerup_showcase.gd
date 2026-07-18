extends SceneTree

const VIEWPORT_SIZE := Vector2i(1536, 960)

var _stage: Node3D = null

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Powerup showcase capture needs a render-capable display driver")
		quit(1)
		return
	root.set_meta("disable_runtime_audio", true)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	_stage = Node3D.new()
	_stage.name = "PowerupShowcase"
	root.add_child(_stage)
	current_scene = _stage
	_build_environment()
	_build_stage()

	var speed_character := _spawn_ai("SpeedCharacter", Vector3(-5.2, 0.08, -1.0), Color("#39a9f2"))
	var fury_character := _spawn_ai("FuryCharacter", Vector3(5.2, 0.08, -1.0), Color("#ef5b45"))
	var clone_owner := _spawn_ai("CloneOwner", Vector3(-1.1, 0.08, -3.6), Color("#9b63e8"))
	speed_character.combat_owner = clone_owner
	fury_character.combat_owner = clone_owner
	await process_frame
	speed_character.apply_powerup(PowerupCatalog.SPEED)
	fury_character.apply_powerup(PowerupCatalog.FURY)
	clone_owner.apply_powerup(PowerupCatalog.CLONE)

	_spawn_pickup(PowerupCatalog.SPEED, Vector3(-4.2, 1.50, 4.0))
	_spawn_pickup(PowerupCatalog.CLONE, Vector3(0.0, 1.50, 4.0))
	_spawn_pickup(PowerupCatalog.FURY, Vector3(4.2, 1.50, 4.0))

	await create_timer(0.38).timeout
	var clone := _first_clone()
	if clone:
		clone.freeze = true
		clone.set_process(false)
		clone.set_physics_process(false)
	if OS.get_cmdline_user_args().has("--mist") and clone:
		clone.dismiss()
		await create_timer(0.14).timeout
	else:
		await create_timer(0.22).timeout

	var image := root.get_texture().get_image()
	var output := _output_path()
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save powerup showcase: %d" % error)
		quit(1)
		return
	print("Saved screenshot: %s" % ProjectSettings.globalize_path(output))
	quit(0)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#7777bd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d7d9ff")
	environment.ambient_light_energy = 0.64
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	_stage.add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key.light_color = Color("#fff1d8")
	key.light_energy = 1.15
	key.shadow_enabled = true
	_stage.add_child(key)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 10.6, 19.2)
	camera.fov = 47.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.15, 0.4), Vector3.UP)
	camera.current = true
	_stage.add_child(camera)

func _build_stage() -> void:
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(19.0, 0.7, 14.0)
	collision.shape = shape
	collision.position.y = -0.35
	floor_body.add_child(collision)
	_stage.add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(19.0, 0.7, 14.0)
	floor_mesh.mesh = mesh
	floor_mesh.position.y = -0.35
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#ee884b")
	material.roughness = 0.74
	floor_mesh.material_override = material
	_stage.add_child(floor_mesh)

func _spawn_ai(node_name: String, position: Vector3, color: Color) -> AICharacter:
	var packed := load("res://scenes/characters/ai_character.tscn") as PackedScene
	var character := packed.instantiate() as AICharacter
	character.name = node_name
	character.position = position
	character.add_to_group("player")
	_stage.add_child(character)
	character.get_visual().set_body_color(color)
	character.freeze = true
	character.set_process(false)
	character.set_physics_process(false)
	return character

func _spawn_pickup(powerup_id: StringName, position: Vector3) -> void:
	var packed := load("res://scenes/powerups/powerup_pickup.tscn") as PackedScene
	var pickup := packed.instantiate() as PowerupPickup
	_stage.add_child(pickup)
	pickup.position = position
	pickup.setup(powerup_id)

func _first_clone() -> CloneCharacter:
	for node in get_nodes_in_group("temporary_clone"):
		if node is CloneCharacter:
			return node as CloneCharacter
	return null

func _output_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			return argument.trim_prefix("--output=")
	return "res://reports/powerup_showcase.png"
