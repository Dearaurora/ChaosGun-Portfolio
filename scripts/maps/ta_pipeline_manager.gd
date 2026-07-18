extends Node

const DEFAULT_MAP_HALF_EXTENT := 24.0
const CAMERA_HEIGHT := 52.0
const CAMERA_BACK_OFFSET := 52.0
const CAMERA_FOLLOW_SPEED := 4.0
const CAMERA_MIN_SIZE := 28.0
const CAMERA_MAX_SIZE := 56.0
const CAMERA_PADDING := 1.10

func apply_pipeline(arena: Node3D) -> void:
	_apply_lighting(arena)
	_apply_environment(arena)
	if arena.has_method("_update_map_runtime_camera"):
		_keep_authored_camera(arena)
		print("TA Pipeline: map camera director + art pass active")
		return
	if _arena_uses_fixed_runtime_camera(arena):
		_keep_authored_camera(arena)
		print("TA Pipeline: art pass active, runtime camera locked")
		return
	# Immediate camera fit for first frame.
	update_runtime_camera(arena, [], 0.0)
	print("TA Pipeline: camera + art pass active")

func update_runtime_camera(arena: Node3D, characters: Array, delta: float) -> void:
	if _arena_uses_fixed_runtime_camera(arena):
		return

	var camera = arena.get_node_or_null("GlobalCamera") as Camera3D
	if not camera:
		return

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL

	var bounds = _compute_scene_bounds(arena)
	var min_x: float = bounds[0]
	var max_x: float = bounds[1]
	var min_z: float = bounds[2]
	var max_z: float = bounds[3]

	for c in characters:
		if not is_instance_valid(c):
			continue
		if c is BaseCharacter and (c as BaseCharacter).is_game_over:
			continue
		var p: Vector3 = c.global_position
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.z)
		max_z = maxf(max_z, p.z)

	var center := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
	var span_x := max_x - min_x
	var span_z := max_z - min_z
	var span := maxf(span_x, span_z)
	var target_size := clampf(span * CAMERA_PADDING, CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)

	camera.size = _smooth(camera.size, target_size, delta)
	camera.position.x = _smooth(camera.position.x, center.x, delta)
	camera.position.y = _smooth(camera.position.y, CAMERA_HEIGHT, delta)
	camera.position.z = _smooth(camera.position.z, center.z + CAMERA_BACK_OFFSET, delta)
	camera.look_at(center + Vector3(0, 2.0, 0), Vector3.UP)

func _compute_scene_bounds(arena: Node3D) -> Array:
	var min_x := -DEFAULT_MAP_HALF_EXTENT
	var max_x := DEFAULT_MAP_HALF_EXTENT
	var min_z := -DEFAULT_MAP_HALF_EXTENT
	var max_z := DEFAULT_MAP_HALF_EXTENT

	var stack: Array = [arena]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)

			if not (c is Node3D):
				continue
			var n3d := c as Node3D
			var name_l := String(n3d.name).to_lower()
			if name_l.contains("camera") or name_l.contains("light") or name_l.contains("pause") or name_l.contains("hud"):
				continue
			if name_l.contains("externalart") or name_l.contains("commercialdressing") or name_l.contains("kenneydressing"):
				continue

			if n3d is CSGBox3D:
				var csg = n3d as CSGBox3D
				var half = csg.size * 0.5
				var p = csg.global_position
				min_x = minf(min_x, p.x - half.x)
				max_x = maxf(max_x, p.x + half.x)
				min_z = minf(min_z, p.z - half.z)
				max_z = maxf(max_z, p.z + half.z)
			elif n3d is StaticBody3D:
				var body = n3d as StaticBody3D
				for shape_node in body.get_children():
					if not (shape_node is CollisionShape3D):
						continue
					var col = shape_node as CollisionShape3D
					if col.shape is BoxShape3D:
						var box = col.shape as BoxShape3D
						var center = col.global_position
						var half = box.size * 0.5
						min_x = minf(min_x, center.x - half.x)
						max_x = maxf(max_x, center.x + half.x)
						min_z = minf(min_z, center.z - half.z)
						max_z = maxf(max_z, center.z + half.z)
			elif n3d is MeshInstance3D:
				var p = n3d.global_position
				min_x = minf(min_x, p.x)
				max_x = maxf(max_x, p.x)
				min_z = minf(min_z, p.z)
				max_z = maxf(max_z, p.z)

	return [min_x, max_x, min_z, max_z]

func _smooth(current: float, target: float, delta: float) -> float:
	if delta <= 0.0:
		return target
	var t := clampf(delta * CAMERA_FOLLOW_SPEED, 0.0, 1.0)
	return lerpf(current, target, t)

func _apply_lighting(arena: Node3D) -> void:
	var d_light = arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if not d_light:
		return
	d_light.light_color = Color("#f8edd7")
	d_light.light_energy = 0.82
	d_light.shadow_enabled = true
	d_light.shadow_blur = 1.5
	d_light.rotation_degrees = Vector3(-55, 45, 0)

func _apply_environment(arena: Node3D) -> void:
	var env_node = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not env_node:
		env_node = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		arena.add_child(env_node)

	var env = Environment.new()
	var sky = Sky.new()
	var psky = ProceduralSkyMaterial.new()
	psky.sky_top_color = Color("#12365f")
	psky.sky_horizon_color = Color("#22639a")
	psky.ground_bottom_color = Color("#0a2442")
	psky.ground_horizon_color = Color("#1b4d7f")
	sky.sky_material = psky
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.72
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.02
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bfd6eb")
	env.ambient_light_energy = 0.30
	env.fog_enabled = true
	env.fog_light_color = Color("#b2cde0")
	env.fog_density = 0.0025
	env.fog_sun_scatter = 0.22
	env.fog_aerial_perspective = 0.04
	env.ssao_enabled = false
	env.glow_enabled = false
	env_node.environment = env

func _arena_uses_fixed_runtime_camera(arena: Node) -> bool:
	return arena != null and arena.has_method("_uses_fixed_runtime_camera") and bool(arena.call("_uses_fixed_runtime_camera"))

func _keep_authored_camera(arena: Node3D) -> void:
	var camera = arena.get_node_or_null("GlobalCamera") as Camera3D
	if not camera:
		return
	camera.current = true
