extends "res://scripts/maps/battle_arena.gd"
class_name MomentumCircuitArenaBase

const MomentumCircuitLayoutScript = preload("res://scripts/maps/momentum_circuit_layout.gd")

const LAYOUT_PATH := "res://resources/maps/momentum_circuit_layout_v2.json"
const PLATFORM_SIDE_COLOR := Color("#3c315f")
const PLATFORM_TOP_COLOR := Color("#45445f")
const TOP_CAP_DEPTH := 0.08
const PICKUP_CANDIDATES := [
	Vector3(7.191700, 1.45, -29.766880),
	Vector3(-4.306064, 1.45, -14.906740),
	Vector3(6.835699, 1.45, 9.692331),
	Vector3(14.364346, 1.45, 14.038998),
]

var _layout: Dictionary = {}


func _ensure_layout() -> bool:
	if not _layout.is_empty():
		return true
	_layout = MomentumCircuitLayoutScript.load_default()
	if _layout.is_empty():
		push_error("Momentum Circuit cannot build without its validated layout")
		return false
	set_meta("layout_source", LAYOUT_PATH)
	set_meta("layout_schema", String(_layout.get("schema", "")))
	set_meta("layout_version", int(_layout.get("version", -1)))
	return true


func _get_spawn_points() -> Array:
	if not _ensure_layout():
		return DEFAULT_SPAWN_POINTS.duplicate()
	var result: Array = []
	for spawn_value: Variant in _layout["spawns"] as Array:
		var spawn := spawn_value as Dictionary
		result.append(
			MomentumCircuitLayoutScript.vector3(spawn["position_world"], "spawn.position_world")
		)
	return result


func get_layout_data() -> Dictionary:
	_ensure_layout()
	return _layout.duplicate(true)


func _configure_map_runtime() -> void:
	if weapon_spawner == null:
		return
	weapon_spawner.initial_delay = 20.0
	weapon_spawner.stay_duration = 30.0
	weapon_spawner.respawn_cooldown = 10.0
	weapon_spawner.custom_spawn_points = PICKUP_CANDIDATES.duplicate()
	weapon_spawner.custom_spawn_clusters = []
	weapon_spawner.fixed_spawn_points = []
	weapon_spawner.random_spawn_points = []
	var no_weapon_overrides: Array[Callable] = []
	weapon_spawner.weapon_factories_override = no_weapon_overrides
	weapon_spawner.max_active_pickups = 1
	weapon_spawner.set_meta("momentum_circuit_candidate_count", PICKUP_CANDIDATES.size())
	weapon_spawner.set_meta("momentum_circuit_candidate_positions", PICKUP_CANDIDATES)


func _build_shared_geometry(parent: Node3D, visuals_visible: bool = true) -> void:
	_build_arena_surface(parent)
	if visuals_visible:
		return
	_set_geometry_visuals_visible(parent, false)


func _set_geometry_visuals_visible(parent: Node, visible_value: bool) -> void:
	if not visible_value:
		_hide_geometry_visuals_preserving_csg_collision(parent)
		return
	var pending: Array[Node] = [parent]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).visible = visible_value
		for child: Node in node.get_children():
			pending.append(child)


func _hide_geometry_visuals_preserving_csg_collision(parent: Node) -> void:
	# Visibility on a collision-enabled CSG tree also controls whether Godot bakes
	# its physics shape.  Keep the authoritative platform CSG active and make it
	# optically transparent; the imported foreground remains the sole visual owner.
	var transparent_collision_material := _make_invisible_collision_material()
	var surface := parent.get_node_or_null("ArenaSurface") as CSGCombiner3D
	if surface:
		surface.visible = true
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surface.material_override = transparent_collision_material
		for child: Node in surface.get_children():
			if child is CSGShape3D:
				var collision_shape := child as CSGShape3D
				collision_shape.visible = true
				collision_shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				collision_shape.material_override = transparent_collision_material
				if collision_shape is CSGPolygon3D:
					(collision_shape as CSGPolygon3D).material = transparent_collision_material

	var top_cap := parent.get_node_or_null("ArenaTopCap") as CSGCombiner3D
	if top_cap:
		top_cap.visible = false

func _make_invisible_collision_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	return material


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
	shape_name: String,
	polygon: PackedVector2Array,
	base_y: float,
	depth: float,
	material: Material,
	operation: CSGShape3D.Operation
) -> CSGPolygon3D:
	var shape := CSGPolygon3D.new()
	shape.name = shape_name
	shape.mode = CSGPolygon3D.MODE_DEPTH
	shape.polygon = polygon
	shape.depth = depth
	shape.position = Vector3(0.0, base_y, 0.0)
	shape.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	shape.operation = operation
	shape.material = material
	shape.use_collision = false
	return shape


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


func _component_radius(data: Dictionary) -> float:
	var bounds := data["component_bounds_xywh_px"] as Array
	var projection := _layout["projection"] as Dictionary
	var diameter_x := float(bounds[2]) * float(projection["world_units_per_pixel_x"])
	var diameter_z := float(bounds[3]) * float(projection["world_units_per_pixel_z"])
	return maxf(0.8, (diameter_x + diameter_z) * 0.25)


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
