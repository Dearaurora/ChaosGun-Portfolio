extends Node3D
class_name MomentumCircuitEnvironmentDressingV8

## Visual-only environment enrichment for Momentum Circuit.
##
## The GLB is a ten-family model library. This controller owns all placement
## and motion, keeping the imported asset free of gameplay logic and authored
## animation. Every instance is placed outside the playable boundary.

const EXPECTED_FAMILY_COUNT := 10
const BACKGROUND_LAYER_COUNT := 3
const MOTION_SYSTEM_COUNT := 3

var _config: Dictionary = {}
var _camera: Camera3D = null
var _camera_origin := Vector3.ZERO
var _library: Node3D = null
var _family_templates: Dictionary = {}
var _layer_roots: Dictionary = {}
var _instances: Array[Node3D] = []
var _ring_instances: Array[Node3D] = []
var _ring_chasers: Array[Dictionary] = []
var _traffic_items: Array[Dictionary] = []
var _scan_visuals: Array[Dictionary] = []
var _elapsed := 0.0
var _motion_enabled := true


func configure(config: Dictionary, camera: Camera3D = null) -> void:
	_config = config.duplicate(true)
	_camera = camera
	if is_instance_valid(_camera):
		_camera_origin = (
			_camera.global_position
			if _camera.is_inside_tree()
			else _camera.position
		)
	rebuild()


func _ready() -> void:
	if get_child_count() == 0 and not _config.is_empty():
		rebuild()


func _process(delta: float) -> void:
	if not _motion_enabled:
		return
	advance_motion(delta)


func rebuild() -> void:
	set_process(false)
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_family_templates.clear()
	_layer_roots.clear()
	_instances.clear()
	_ring_instances.clear()
	_ring_chasers.clear()
	_traffic_items.clear()
	_scan_visuals.clear()
	_elapsed = 0.0

	set_meta("visual_only", true)
	set_meta("collision_owner", "Godot gameplay scene")
	set_meta("environment_version", 8)
	if not is_in_group(&"momentum_circuit_environment_dressing"):
		add_to_group(&"momentum_circuit_environment_dressing")

	_create_layer_roots()
	if not _load_model_library():
		return
	_build_static_instances()
	_build_ring_motion()
	_build_traffic_routes()
	_build_sensor_scans()
	_apply_visual_only_contract(self)
	set_process(true)


func advance_motion(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_elapsed = fmod(_elapsed + safe_delta, 7200.0)
	_update_parallax()
	_update_camera_lod_visibility()
	_update_rings(safe_delta)
	_update_traffic()
	_update_sensor_scans()


func set_capture_time(seconds: float) -> void:
	_elapsed = maxf(seconds, 0.0)
	_update_parallax()
	_update_traffic()
	_update_sensor_scans()


func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	set_process(enabled)


func get_debug_state() -> Dictionary:
	return {
		"configured": not _config.is_empty() and _family_templates.size() == EXPECTED_FAMILY_COUNT,
		"visual_only": bool(get_meta("visual_only", false)),
		"version": 8,
		"background_layer_count": BACKGROUND_LAYER_COUNT,
		"background_layers": _layer_roots.keys(),
		"model_family_count": _family_templates.size(),
		"model_family_ids": _family_templates.keys(),
		"instance_count": _instances.size(),
		"ring_instance_count": _ring_instances.size(),
		"traffic_route_count": _traffic_items.size(),
		"sensor_scan_count": _scan_visuals.size(),
		"active_motion_system_count": MOTION_SYSTEM_COUNT,
		"elapsed": _elapsed,
		"motion_enabled": _motion_enabled,
		"collision_node_count": _count_collision_nodes(self),
		"shadow_caster_count": _count_shadow_casters(self),
		"camera_node_count": _count_type_nodes(self, "Camera3D"),
		"light_node_count": _count_type_nodes(self, "Light3D"),
		"visible_mesh_instance_count": _count_visible_meshes(self),
		"estimated_visible_draw_calls": _count_visible_surface_draws(self),
		"max_materials": int(_config.get("max_materials", 5)),
		"max_added_draw_calls": int(_config.get("max_added_draw_calls", 55)),
		"close_view_hidden": _environment_hidden_for_close_view(),
	}


func _create_layer_roots() -> void:
	for layer_data: Variant in _config.get("layers", []):
		var spec := layer_data as Dictionary
		var layer_id := String(spec.get("id", ""))
		if layer_id.is_empty():
			continue
		var root := Node3D.new()
		root.name = String(spec.get("node_name", layer_id.to_pascal_case()))
		root.set_meta("environment_layer_id", layer_id)
		root.set_meta("parallax", float(spec.get("parallax", 0.0)))
		root.set_meta("visual_only", true)
		add_child(root)
		_layer_roots[layer_id] = root


func _load_model_library() -> bool:
	var scene_path := String(_config.get("model_scene_path", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Momentum Circuit v8 environment model library is missing: %s" % scene_path)
		return false
	_library = packed.instantiate() as Node3D
	if _library == null:
		push_error("Momentum Circuit v8 environment model library could not instantiate")
		return false
	_library.name = "EnvironmentModelLibrary"
	_library.visible = false
	add_child(_library)
	for node: Node in _walk(_library):
		if not node is Node3D:
			continue
		var node_name := String(node.name)
		if not node_name.begins_with("EnvFamily"):
			continue
		if node_name.count("_") != 1:
			continue
		var separator := node_name.find("_")
		if separator < 0:
			continue
		var family_id := node_name.substr(separator + 1)
		_family_templates[family_id] = node
	if _family_templates.size() != EXPECTED_FAMILY_COUNT:
		push_error(
			"Momentum Circuit v8 expected %d model families, found %d"
			% [EXPECTED_FAMILY_COUNT, _family_templates.size()]
		)
		return false
	return true


func _build_static_instances() -> void:
	for raw_value: Variant in _config.get("instances", []):
		var spec := raw_value as Dictionary
		if bool(spec.get("motion_owned", false)):
			continue
		_instantiate_family(spec)


func _build_ring_motion() -> void:
	var speeds := _config.get("ring_angular_speeds", [0.018, -0.025]) as Array
	var ring_specs := _config.get("ring_instances", []) as Array
	for index in range(ring_specs.size()):
		var spec := ring_specs[index] as Dictionary
		var instance := _instantiate_family(spec)
		if instance == null:
			continue
		instance.set_meta("ring_speed", float(speeds[index % maxi(speeds.size(), 1)]))
		instance.set_meta("rotate_geometry", bool(spec.get("rotate_geometry", true)))
		_ring_instances.append(instance)
		var chaser := MeshInstance3D.new()
		chaser.name = "EmissiveChaser"
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		chaser.mesh = sphere
		chaser.material_override = _unshaded_material(Color("#7AF4FF"), 2.8)
		chaser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_child(chaser)
		_ring_chasers.append({
			"node": chaser,
			"radius": float(spec.get("chaser_radius", 4.1)),
			"phase": float(index) * PI,
			"arc_half_angle": deg_to_rad(float(spec.get("chaser_arc_degrees", 180.0))),
			"speed": float(spec.get("chaser_speed", 0.9)),
		})


func _build_traffic_routes() -> void:
	var routes := _config.get("traffic_routes", []) as Array
	for route_value: Variant in routes:
		var spec := route_value as Dictionary
		var instance := _instantiate_family(spec)
		if instance == null:
			continue
		var curve := Curve3D.new()
		curve.bake_interval = 1.0
		for point_value: Variant in spec.get("points", []):
			var point := _vector3(point_value)
			curve.add_point(point)
		curve.closed = true
		_traffic_items.append({
			"node": instance,
			"curve": curve,
			"period": maxf(float(spec.get("period", 24.0)), 1.0),
			"phase": float(spec.get("phase", 0.0)),
		})


func _build_sensor_scans() -> void:
	var scan_config := _config.get("sensor_scan", {}) as Dictionary
	var period := maxf(float(scan_config.get("period", 7.0)), 1.0)
	var max_alpha := clampf(float(scan_config.get("max_alpha", 0.18)), 0.0, 0.18)
	for scan_value: Variant in scan_config.get("origins", []):
		var origin := _vector3(scan_value)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "SensorScan"
		mesh_instance.position = origin
		var torus := TorusMesh.new()
		torus.inner_radius = 0.92
		torus.outer_radius = 1.08
		torus.rings = 24
		torus.ring_segments = 6
		mesh_instance.mesh = torus
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.32, 0.90, 1.0, 0.0)
		material.emission_enabled = true
		material.emission = Color("#52E5F5")
		material.emission_energy_multiplier = 1.4
		mesh_instance.material_override = material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ambient_root := _layer_roots.get("ambient") as Node3D
		if ambient_root == null:
			add_child(mesh_instance)
		else:
			ambient_root.add_child(mesh_instance)
		_scan_visuals.append({
			"node": mesh_instance,
			"material": material,
			"period": period,
			"max_alpha": max_alpha,
			"phase": float(_scan_visuals.size()) * 0.43,
		})


func _instantiate_family(spec: Dictionary) -> Node3D:
	var family_id := String(spec.get("family", ""))
	var template := _family_templates.get(family_id) as Node3D
	if template == null:
		push_error("Momentum Circuit v8 environment family not found: %s" % family_id)
		return null
	var layer_id := String(spec.get("layer", "mid"))
	var layer := _layer_roots.get(layer_id) as Node3D
	if layer == null:
		push_error("Momentum Circuit v8 environment layer not found: %s" % layer_id)
		return null
	var duplicate := template.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	if duplicate == null:
		return null
	duplicate.name = "%s_%02d" % [family_id, _instances.size() + 1]
	duplicate.visible = true
	duplicate.position = _vector3(spec.get("position", [0.0, -5.0, 0.0]))
	duplicate.rotation_degrees.y = float(spec.get("rotation_y", 0.0))
	var scale_value := float(spec.get("scale", 1.0))
	duplicate.scale = Vector3.ONE * scale_value
	duplicate.set_meta("environment_family", family_id)
	duplicate.set_meta("visual_only", true)
	layer.add_child(duplicate)
	_instances.append(duplicate)
	_apply_visual_only_contract(duplicate)
	return duplicate


func _update_parallax() -> void:
	if not is_instance_valid(_camera):
		return
	var delta := _camera.global_position - _camera_origin
	for layer_id_value: Variant in _layer_roots:
		var layer_id := String(layer_id_value)
		var layer := _layer_roots[layer_id] as Node3D
		var coefficient := float(layer.get_meta("parallax", 0.0))
		layer.position.x = delta.x * coefficient
		layer.position.z = delta.z * coefficient


func _update_camera_lod_visibility() -> void:
	var hidden := _environment_hidden_for_close_view()
	for layer_value: Variant in _layer_roots.values():
		var layer := layer_value as Node3D
		if is_instance_valid(layer):
			layer.visible = not hidden


func _environment_hidden_for_close_view() -> bool:
	if not is_instance_valid(_camera) or _camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return false
	var threshold := float(_config.get("close_view_hide_below_size", 0.0))
	return threshold > 0.0 and _camera.size < threshold


func _update_rings(delta: float) -> void:
	for index in range(_ring_instances.size()):
		var ring := _ring_instances[index]
		if bool(ring.get_meta("rotate_geometry", true)):
			ring.rotation.y = fposmod(
				ring.rotation.y + float(ring.get_meta("ring_speed", 0.0)) * delta,
				TAU
			)
		if index >= _ring_chasers.size():
			continue
		var data := _ring_chasers[index]
		var chaser := data.get("node") as Node3D
		var radius := float(data.get("radius", 4.1))
		var phase := float(data.get("phase", 0.0))
		var half_angle := float(data.get("arc_half_angle", PI))
		var speed := float(data.get("speed", 0.9))
		var angle := sin(_elapsed * speed + phase) * half_angle
		chaser.position = Vector3(sin(angle) * radius, 0.42, cos(angle) * radius)


func _update_traffic() -> void:
	for data: Dictionary in _traffic_items:
		var node := data.get("node") as Node3D
		var curve := data.get("curve") as Curve3D
		var period := float(data.get("period", 24.0))
		var phase := float(data.get("phase", 0.0))
		if node == null or curve == null:
			continue
		var length := curve.get_baked_length()
		if length <= 0.01:
			continue
		var ratio := fposmod(_elapsed / period + phase, 1.0)
		var offset := ratio * length
		var next_offset := fposmod(offset + 0.5, length)
		var position := curve.sample_baked(offset, true)
		var next_position := curve.sample_baked(next_offset, true)
		node.position = position
		var direction := next_position - position
		if direction.length_squared() > 0.0001:
			node.look_at(position + direction, Vector3.UP)


func _update_sensor_scans() -> void:
	for data: Dictionary in _scan_visuals:
		var node := data.get("node") as MeshInstance3D
		var material := data.get("material") as StandardMaterial3D
		var period := float(data.get("period", 7.0))
		var max_alpha := float(data.get("max_alpha", 0.18))
		var phase := fposmod(_elapsed / period + float(data.get("phase", 0.0)), 1.0)
		var active := phase < 0.42
		var normalized := phase / 0.42 if active else 1.0
		var alpha := sin(normalized * PI) * max_alpha if active else 0.0
		var size := lerpf(0.8, 7.2, normalized) if active else 0.8
		node.scale = Vector3(size, 1.0, size)
		var color := material.albedo_color
		color.a = alpha
		material.albedo_color = color
		node.visible = active


func _apply_visual_only_contract(root: Node) -> void:
	for node: Node in _walk(root):
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("visual_only", true)


func _unshaded_material(color: Color, energy: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = energy
	return result


func _vector3(value: Variant) -> Vector3:
	if not value is Array or (value as Array).size() < 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _walk(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children():
		result.append_array(_walk(child))
	return result


func _count_collision_nodes(root: Node) -> int:
	var count := 0
	for node: Node in _walk(root):
		if node is CollisionObject3D or node is CollisionShape3D:
			count += 1
	return count


func _count_shadow_casters(root: Node) -> int:
	var count := 0
	for node: Node in _walk(root):
		if node is GeometryInstance3D:
			var geometry := node as GeometryInstance3D
			if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				count += 1
	return count


func _count_type_nodes(root: Node, type_name: String) -> int:
	var count := 0
	for node: Node in _walk(root):
		if node.is_class(type_name):
			count += 1
	return count


func _count_visible_meshes(root: Node) -> int:
	var count := 0
	for node: Node in _walk(root):
		if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
			count += 1
	return count


func _count_visible_surface_draws(root: Node) -> int:
	var count := 0
	for node: Node in _walk(root):
		if not node is MeshInstance3D:
			continue
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		count += mesh_instance.mesh.get_surface_count()
	return count
