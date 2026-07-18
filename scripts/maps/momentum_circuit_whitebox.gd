extends "res://scripts/maps/momentum_circuit_arena_base.gd"

const MomentumCircuitPortalScript = preload("res://scripts/maps/momentum_circuit_portal.gd")
const MomentumCircuitShockwaveScript = preload("res://scripts/maps/momentum_circuit_shockwave.gd")
const MomentumCircuitActivatorScript = preload("res://scripts/maps/momentum_circuit_activator.gd")

# Render-calibrated albedos. Frozen design tokens remain attached as metadata;
# these compensate for the fixed filmic/lighting response at the reference view.
const PORTAL_COLOR := Color("#72e5f3")
const SHOCKWAVE_COLOR := Color("#ffbb3e")
const BACKDROP_COLOR := Color("#111216")
const PORTAL_EXIT_OFFSET := 4.75

# Linear, closed, and sampled against the JSON outer polygon minus its three
# stored holes. The final six points are the only adjustment to the concept's
# suggested route: they follow the narrow north-west fold without leaving the
# walkable mask.
const SHOCKWAVE_WAYPOINTS_XZ := [
	Vector2(-37.0, -41.0),
	Vector2(-12.0, -36.0),
	Vector2(11.0, -27.0),
	Vector2(17.28, -31.349),
	Vector2(31.92, -30.568),
	Vector2(34.0, -28.0),
	Vector2(39.0, -30.0),
	Vector2(28.0, -14.0),
	Vector2(8.0, -5.0),
	Vector2(11.0, 11.0),
	Vector2(30.0, 22.0),
	Vector2(35.0, 32.0),
	Vector2(12.0, 34.0),
	Vector2(-10.0, 25.0),
	Vector2(-21.0, 13.0),
	Vector2(-40.0, -8.0),
	Vector2(-34.0, -15.0),
	Vector2(-26.0, -16.0),
	Vector2(-12.0, -15.0),
	Vector2(-3.0, -20.0),
	Vector2(-2.16, -27.638),
	Vector2(-2.24, -31.057),
	Vector2(-5.6, -34.963),
	Vector2(-37.0, -41.0),
]

var _portal_nodes_by_id: Dictionary = {}
var _shockwave_controller: Node3D = null


func _build_map_layout() -> void:
	if not _ensure_layout():
		return
	_portal_nodes_by_id.clear()
	_build_whitebox_geometry()
	_build_mechanisms()
	_build_spawn_markers()


func _build_map_dressing() -> void:
	if not _ensure_layout():
		return
	var existing := get_node_or_null("MomentumCircuitBackdrop")
	if existing:
		remove_child(existing)
		existing.free()
	var backdrop_root := Node3D.new()
	backdrop_root.name = "MomentumCircuitBackdrop"
	add_child(backdrop_root)

	var backdrop := MeshInstance3D.new()
	backdrop.name = "VoidBackdrop"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(180.0, 0.3, 170.0)
	backdrop.mesh = mesh
	backdrop.position = Vector3(0.0, -4.35, 0.0)
	backdrop.material_override = _make_material(BACKDROP_COLOR, true)
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.set_meta("color_token", "#111216")
	backdrop_root.add_child(backdrop)


func _apply_map_visual_overrides() -> void:
	_configure_camera()
	_configure_light()
	_configure_environment()


func _uses_fixed_runtime_camera() -> bool:
	return true


func get_shockwave_waypoints() -> PackedVector3Array:
	var result := PackedVector3Array()
	for point: Vector2 in SHOCKWAVE_WAYPOINTS_XZ:
		result.append(Vector3(point.x, 1.25, point.y))
	return result


func _build_whitebox_geometry() -> void:
	var existing := get_node_or_null("MomentumCircuitWhitebox")
	if existing:
		remove_child(existing)
		existing.free()

	var whitebox_root := Node3D.new()
	whitebox_root.name = "MomentumCircuitWhitebox"
	add_child(whitebox_root)
	_build_shared_geometry(whitebox_root, true)


func _build_arena_surface(parent: Node3D) -> void:
	var platform := _layout["platform"] as Dictionary
	var source_projection_outline := MomentumCircuitLayoutScript.packed_vector2_array(
		platform["outline_world_xz"],
		"platform.outline_world_xz"
	)
	var outer_outline := MomentumCircuitLayoutScript.packed_vector2_array(
		platform.get("visual_top_outline_world_xz", platform["outline_world_xz"]),
		"platform.visual_top_outline_world_xz"
	)
	var top_y := float(platform["top_y"])
	var bottom_y := float(platform["bottom_y"])
	var depth := float(platform["depth"])

	var surface := CSGCombiner3D.new()
	surface.name = "ArenaSurface"
	surface.use_collision = true
	surface.add_to_group(&"momentum_circuit_geometry")
	surface.set_meta("layout_source", LAYOUT_PATH)
	surface.set_meta("platform_top_y", top_y)
	surface.set_meta("platform_bottom_y", bottom_y)
	surface.set_meta("platform_depth", depth)
	surface.set_meta("outer_point_count", outer_outline.size())
	surface.set_meta("source_projection_outer_point_count", source_projection_outline.size())
	surface.set_meta("source_projection_outline_world_xz", source_projection_outline)
	surface.set_meta("visual_top_outline_world_xz", outer_outline)
	surface.set_meta("subtraction_hole_count", 3)
	parent.add_child(surface)

	var side_material := _make_material(PLATFORM_SIDE_COLOR)
	side_material.emission_enabled = true
	side_material.emission = PLATFORM_SIDE_COLOR
	side_material.emission_energy_multiplier = 0.12
	var platform_body := _new_extruded_polygon(
		"PlatformBody",
		outer_outline,
		bottom_y,
		depth,
		side_material,
		CSGShape3D.OPERATION_UNION
	)
	platform_body.set_meta("color_token", "#3C315F")
	platform_body.set_meta("layout_outline_world_xz", outer_outline)
	platform_body.set_meta("source_projection_outline_world_xz", source_projection_outline)
	surface.add_child(platform_body)

	for index in range((_layout["holes"] as Array).size()):
		var hole := (_layout["holes"] as Array)[index] as Dictionary
		var source_hole_outline := MomentumCircuitLayoutScript.packed_vector2_array(
			hole["outline_world_xz"],
			"holes[%d].outline_world_xz" % index
		)
		var hole_outline := MomentumCircuitLayoutScript.packed_vector2_array(
			hole.get("visual_top_outline_world_xz", hole["outline_world_xz"]),
			"holes[%d].visual_top_outline_world_xz" % index
		)
		var hole_node := _new_extruded_polygon(
			"VoidHole%02d" % (index + 1),
			hole_outline,
			bottom_y - 0.2,
			depth + 0.4,
			side_material,
			CSGShape3D.OPERATION_SUBTRACTION
		)
		hole_node.set_meta("layout_id", String(hole["id"]))
		hole_node.set_meta("layout_outline_world_xz", hole_outline)
		hole_node.set_meta("source_projection_outline_world_xz", source_hole_outline)
		surface.add_child(hole_node)

	# A second, collision-free boolean shell supplies the white top plane while
	# leaving the gameplay collider as one unambiguous CSGCombiner3D.
	var top_cap := CSGCombiner3D.new()
	top_cap.name = "ArenaTopCap"
	top_cap.use_collision = false
	top_cap.set_meta("same_topology_as", surface.get_path())
	top_cap.set_meta("platform_top_y", top_y)
	parent.add_child(top_cap)
	var top_material := _make_material(PLATFORM_TOP_COLOR)
	var cap_body := _new_extruded_polygon(
		"TopCapBody",
		outer_outline,
		top_y,
		TOP_CAP_DEPTH,
		top_material,
		CSGShape3D.OPERATION_UNION
	)
	cap_body.set_meta("color_token", "#45445F")
	top_cap.add_child(cap_body)
	for index in range((_layout["holes"] as Array).size()):
		var hole := (_layout["holes"] as Array)[index] as Dictionary
		var hole_outline := MomentumCircuitLayoutScript.packed_vector2_array(
			hole.get("visual_top_outline_world_xz", hole["outline_world_xz"]),
			"holes[%d].visual_top_outline_world_xz" % index
		)
		var cap_hole := _new_extruded_polygon(
			"TopCapHole%02d" % (index + 1),
			hole_outline,
			top_y - 0.04,
			TOP_CAP_DEPTH + 0.12,
			top_material,
			CSGShape3D.OPERATION_SUBTRACTION
		)
		cap_hole.set_meta("layout_id", String(hole["id"]))
		top_cap.add_child(cap_hole)


func _new_extruded_polygon(
	node_name: String,
	polygon: PackedVector2Array,
	base_y: float,
	depth: float,
	material: Material,
	operation: CSGShape3D.Operation
) -> CSGPolygon3D:
	var shape := CSGPolygon3D.new()
	shape.name = node_name
	shape.mode = CSGPolygon3D.MODE_DEPTH
	shape.polygon = polygon
	shape.depth = depth
	shape.position = Vector3(0.0, base_y, 0.0)
	shape.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	shape.operation = operation
	shape.material = material
	shape.use_collision = false
	return shape


func _build_mechanisms() -> void:
	var existing := get_node_or_null("MomentumCircuitMechanisms")
	if existing:
		remove_child(existing)
		existing.free()

	var mechanism_root := Node3D.new()
	mechanism_root.name = "MomentumCircuitMechanisms"
	add_child(mechanism_root)
	_build_portals(mechanism_root)
	_build_shockwave(mechanism_root)


func _build_portals(parent: Node3D) -> void:
	var portals_root := Node3D.new()
	portals_root.name = "Portals"
	parent.add_child(portals_root)
	var portal_material := _make_emissive_material(PORTAL_COLOR, 0.34)

	for index in range((_layout["portals"] as Array).size()):
		var portal_data := (_layout["portals"] as Array)[index] as Dictionary
		var portal := MomentumCircuitPortalScript.new() as Area3D
		portal.name = "Portal%02d" % (index + 1)
		portal.position = MomentumCircuitLayoutScript.vector3(
			portal_data["position_world"],
			"portals[%d].position_world" % index
		)
		portal.add_to_group(&"portal")
		portal.add_to_group(&"momentum_circuit_portal")
		var portal_id := String(portal_data["id"])
		var pair_id := String(portal_data["paired_portal_id"])
		var inward := _portal_inward_direction(portal_id)
		var outer_radius := _component_radius(portal_data)
		portal.set_meta("layout_id", portal_id)
		portal.set_meta("paired_portal_id", pair_id)
		portal.set_meta("layout_position_world", portal.position)
		portal.set_meta("component_bounds_xywh_px", portal_data["component_bounds_xywh_px"])
		portal.set_meta("outer_radius_world", outer_radius)
		portal.set_meta("inward_tangent_world", inward)
		portal.set_meta("source_tangent_world", -inward)
		portal.set_meta("exit_offset_world", PORTAL_EXIT_OFFSET)
		portal.set_meta("color_token", "#72e5f3")
		portals_root.add_child(portal)
		_portal_nodes_by_id[portal_id] = portal

		var trigger := CollisionShape3D.new()
		trigger.name = "TriggerShape"
		var trigger_shape := CylinderShape3D.new()
		trigger_shape.radius = outer_radius * 0.84
		trigger_shape.height = 1.2
		trigger.shape = trigger_shape
		trigger.position = Vector3(0.0, 0.6, 0.0)
		portal.add_child(trigger)

		var exit_marker := Marker3D.new()
		exit_marker.name = "ExitMarker"
		exit_marker.position = inward * PORTAL_EXIT_OFFSET + Vector3(0.0, 0.1, 0.0)
		exit_marker.set_meta("inward_offset_world", PORTAL_EXIT_OFFSET)
		exit_marker.set_meta("inward_tangent_world", inward)
		portal.add_child(exit_marker)

		var ring := MeshInstance3D.new()
		ring.name = "PortalRing"
		var torus := TorusMesh.new()
		torus.inner_radius = outer_radius * 0.72
		torus.outer_radius = outer_radius * 0.96
		torus.rings = 40
		torus.ring_segments = 10
		ring.mesh = torus
		ring.position = Vector3(0.0, 0.16, 0.0)
		ring.material_override = portal_material
		portal.add_child(ring)

		var core := MeshInstance3D.new()
		core.name = "PortalCore"
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = outer_radius * 0.69
		core_mesh.bottom_radius = outer_radius * 0.72
		core_mesh.height = 0.12
		core_mesh.radial_segments = 40
		core.mesh = core_mesh
		core.position = Vector3(0.0, 0.08, 0.0)
		core.material_override = portal_material
		portal.add_child(core)

	for portal_data_value: Variant in _layout["portals"] as Array:
		var portal_data := portal_data_value as Dictionary
		var portal_id := String(portal_data["id"])
		var pair_id := String(portal_data["paired_portal_id"])
		var source := _portal_nodes_by_id.get(portal_id) as Area3D
		var destination := _portal_nodes_by_id.get(pair_id) as Area3D
		if source == null or destination == null:
			push_error("Momentum Circuit portal pairing is incomplete: %s -> %s" % [portal_id, pair_id])
			continue
		var destination_exit := destination.get_node("ExitMarker") as Marker3D
		var source_inward := _portal_inward_direction(portal_id)
		var destination_inward := _portal_inward_direction(pair_id)
		source.call(
			"configure_pair",
			destination_exit,
			-source_inward,
			destination_inward
		)
		source.set_meta("destination_exit_path", source.get_path_to(destination_exit))
		source.set_meta("destination_tangent_world", destination_inward)


func _build_shockwave(parent: Node3D) -> void:
	var shockwave_root := Node3D.new()
	shockwave_root.name = "Shockwave"
	parent.add_child(shockwave_root)

	var controller := MomentumCircuitShockwaveScript.new() as Node3D
	controller.name = "CircuitShockwave"
	shockwave_root.add_child(controller)
	_shockwave_controller = controller

	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var waypoint_positions := PackedVector3Array()
	for point: Vector2 in SHOCKWAVE_WAYPOINTS_XZ:
		var waypoint := Vector3(point.x, 1.25, point.y)
		curve.add_point(waypoint)
		waypoint_positions.append(waypoint)
	var path_is_walkable := _validate_shockwave_path()
	if not path_is_walkable:
		push_error("Momentum Circuit shockwave path leaves the visual walkable surface")
	controller.call("configure_path", curve)
	controller.set_meta("layout_source", LAYOUT_PATH)
	controller.set_meta("closed_path", true)
	controller.set_meta("path_validated_against_walkable_mask", path_is_walkable)
	controller.set_meta("path_waypoints_world", waypoint_positions)
	controller.set_meta("path_waypoint_count", waypoint_positions.size())

	var activators_root := Node3D.new()
	activators_root.name = "Activators"
	shockwave_root.add_child(activators_root)
	var activator_material := _make_emissive_material(SHOCKWAVE_COLOR, 0.25)

	for index in range((_layout["shockwave_nodes"] as Array).size()):
		var node_data := (_layout["shockwave_nodes"] as Array)[index] as Dictionary
		var activator := MomentumCircuitActivatorScript.new() as StaticBody3D
		activator.name = "ShockwaveNode%02d" % (index + 1)
		activator.position = MomentumCircuitLayoutScript.vector3(
			node_data["position_world"],
			"shockwave_nodes[%d].position_world" % index
		)
		activator.add_to_group(&"shockwave_activator")
		activator.add_to_group(&"momentum_circuit_shockwave_activator")
		var radius := _component_radius(node_data)
		var tangent := _curve_tangent_near(curve, activator.position)
		var side_axis := tangent.cross(Vector3.UP).normalized()
		activator.call("configure", controller, tangent, side_axis)
		activator.set_meta("layout_id", String(node_data["id"]))
		activator.set_meta("layout_position_world", activator.position)
		activator.set_meta("component_bounds_xywh_px", node_data["component_bounds_xywh_px"])
		activator.set_meta("outer_radius_world", radius)
		activator.set_meta("path_tangent_world", tangent)
		activator.set_meta("side_axis_world", side_axis)
		activator.set_meta("color_token", "#ffbb3e")
		activators_root.add_child(activator)

		var hit_shape := CollisionShape3D.new()
		hit_shape.name = "HitShape"
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius * 0.82
		cylinder_shape.height = 1.0
		hit_shape.shape = cylinder_shape
		hit_shape.position = Vector3(0.0, 0.5, 0.0)
		activator.add_child(hit_shape)

		var ring := MeshInstance3D.new()
		ring.name = "NodeRing"
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.65
		torus.outer_radius = radius * 0.92
		torus.rings = 32
		torus.ring_segments = 9
		ring.mesh = torus
		ring.position = Vector3(0.0, 0.16, 0.0)
		ring.material_override = activator_material
		activator.add_child(ring)

		var core := MeshInstance3D.new()
		core.name = "NodeCore"
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = radius * 0.61
		core_mesh.bottom_radius = radius * 0.66
		core_mesh.height = 0.12
		core_mesh.radial_segments = 32
		core.mesh = core_mesh
		core.position = Vector3(0.0, 0.08, 0.0)
		core.material_override = activator_material
		activator.add_child(core)


func _validate_shockwave_path() -> bool:
	if SHOCKWAVE_WAYPOINTS_XZ.size() < 4:
		return false
	if SHOCKWAVE_WAYPOINTS_XZ[0].distance_to(SHOCKWAVE_WAYPOINTS_XZ[-1]) > 0.001:
		return false
	var platform := _layout["platform"] as Dictionary
	var outer := MomentumCircuitLayoutScript.packed_vector2_array(
		platform["visual_top_outline_world_xz"],
		"platform.visual_top_outline_world_xz"
	)
	var holes: Array[PackedVector2Array] = []
	for index in range((_layout["holes"] as Array).size()):
		var hole := (_layout["holes"] as Array)[index] as Dictionary
		holes.append(
			MomentumCircuitLayoutScript.packed_vector2_array(
				hole["visual_top_outline_world_xz"],
				"holes[%d].visual_top_outline_world_xz" % index
			)
		)
	for segment_index in range(SHOCKWAVE_WAYPOINTS_XZ.size() - 1):
		var start: Vector2 = SHOCKWAVE_WAYPOINTS_XZ[segment_index]
		var finish: Vector2 = SHOCKWAVE_WAYPOINTS_XZ[segment_index + 1]
		var sample_count := maxi(1, int(ceil(start.distance_to(finish) / 0.25)))
		for sample_index in range(sample_count + 1):
			var sample := start.lerp(finish, float(sample_index) / float(sample_count))
			if not Geometry2D.is_point_in_polygon(sample, outer):
				return false
			for hole: PackedVector2Array in holes:
				if Geometry2D.is_point_in_polygon(sample, hole):
					return false
	return true


func _build_spawn_markers() -> void:
	var existing := get_node_or_null("MomentumCircuitSpawns")
	if existing:
		remove_child(existing)
		existing.free()
	var spawns_root := Node3D.new()
	spawns_root.name = "MomentumCircuitSpawns"
	add_child(spawns_root)

	for index in range((_layout["spawns"] as Array).size()):
		var spawn_data := (_layout["spawns"] as Array)[index] as Dictionary
		var marker := Marker3D.new()
		marker.name = "Spawn%02d" % (index + 1)
		marker.position = MomentumCircuitLayoutScript.vector3(
			spawn_data["position_world"],
			"spawns[%d].position_world" % index
		)
		marker.add_to_group(&"spawn")
		marker.add_to_group(&"momentum_circuit_spawn")
		marker.set_meta("layout_id", String(spawn_data["id"]))
		marker.set_meta("source_portal_id", String(spawn_data["source_portal_id"]))
		marker.set_meta(
			"inward_direction_world_xz",
			MomentumCircuitLayoutScript.vector2(
				spawn_data["inward_direction_world_xz"],
				"spawn.inward_direction_world_xz"
			)
		)
		marker.set_meta("inward_offset_world", float(spawn_data["inward_offset_world"]))
		spawns_root.add_child(marker)


func _portal_inward_direction(portal_id: String) -> Vector3:
	for spawn_value: Variant in _layout["spawns"] as Array:
		var spawn := spawn_value as Dictionary
		if String(spawn["source_portal_id"]) != portal_id:
			continue
		var direction_xz := MomentumCircuitLayoutScript.vector2(
			spawn["inward_direction_world_xz"],
			"spawn.inward_direction_world_xz"
		)
		var direction := Vector3(direction_xz.x, 0.0, direction_xz.y)
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	return Vector3.FORWARD


func _component_radius(data: Dictionary) -> float:
	var bounds := data["component_bounds_xywh_px"] as Array
	var projection := _layout["projection"] as Dictionary
	var diameter_x := float(bounds[2]) * float(projection["world_units_per_pixel_x"])
	var diameter_z := float(bounds[3]) * float(projection["world_units_per_pixel_z"])
	return maxf(0.8, (diameter_x + diameter_z) * 0.25)


func _curve_tangent_near(curve: Curve3D, world_position: Vector3) -> Vector3:
	var length := curve.get_baked_length()
	if length <= 0.1:
		return Vector3.FORWARD
	var offset := curve.get_closest_offset(world_position)
	var before := curve.sample_baked(fposmod(offset - 0.5, length), true)
	var after := curve.sample_baked(fposmod(offset + 0.5, length), true)
	var tangent := after - before
	tangent.y = 0.0
	return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector3.FORWARD


func _configure_camera() -> void:
	var camera := get_node_or_null("GlobalCamera") as Camera3D
	if camera == null:
		return
	# Exact 100-unit, 55-degree top-plane-centered framing from the extraction.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 81.92
	camera.position = Vector3(0.0, 82.915204, 57.357644)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.current = true
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.set_meta("framing_target_world", Vector3(0.0, 1.0, 0.0))
	camera.set_meta("yaw_degrees", 0.0)
	camera.set_meta("elevation_degrees", 55.0)
	camera.set_meta("reference_viewport_size_px", Vector2i(1536, 1024))


func _configure_light() -> void:
	var light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light == null:
		return
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_color = Color("#f7f5f2")
	light.light_energy = 0.51
	light.shadow_enabled = true
	light.shadow_blur = 3.0
	light.shadow_opacity = 0.42


func _configure_environment() -> void:
	# TA runs before map overrides and authors this root node. Reuse it so the
	# viewport never has two competing WorldEnvironment instances.
	var environment_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null:
		environment_node = get_node_or_null("MomentumCircuitEnvironment") as WorldEnvironment
	if environment_node == null:
		environment_node = WorldEnvironment.new()
		environment_node.name = "WorldEnvironment"
		add_child(environment_node)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKDROP_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d7d7d9")
	environment.ambient_light_energy = 0.35
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment


func _make_material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = 0.78
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _make_emissive_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := _make_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	return material
