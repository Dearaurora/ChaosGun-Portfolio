extends "res://scripts/maps/battle_arena.gd"
class_name TwinBaysArenaBase

const TwinBaysPortalScript = preload("res://scripts/maps/twin_bays_portal.gd")
const TwinBaysLayoutScript = preload("res://scripts/maps/twin_bays_layout.gd")
const PartyShooterCameraDirectorScript = preload("res://scripts/maps/party_shooter_camera_director.gd")

const ROLE_GAMEPLAY := &"gameplay"
const ROLE_FOREGROUND := &"foreground"
const ROLE_BACKDROP := &"backdrop"
const ROLE_PORTALS := &"portals"
# Twin Bays is bilaterally symmetric and its paired pipe mouths sit on opposite
# sides. A centered horizontal yaw gives both portals equal visual weight.
const TWIN_BAYS_HORIZONTAL_VIEW_OFFSET := Vector2(0.0, 64.0)

var _left_portal: TwinBaysPortal = null
var _right_portal: TwinBaysPortal = null
var _layout: Dictionary = {}
var _twin_bays_layers: Dictionary = {}
var _camera_director: Node = null
var _special_weapon_spawner: WeaponSpawner = null


static func twin_bays_gameplay_view_offset() -> Vector3:
	return PartyShooterCameraDirectorScript.view_offset_with_standard_pitch(
		TWIN_BAYS_HORIZONTAL_VIEW_OFFSET.x,
		TWIN_BAYS_HORIZONTAL_VIEW_OFFSET.y
	)

func _build_map_layout() -> void:
	_clear_twin_bays_nodes()
	_layout = TwinBaysLayoutScript.load_default()
	if _layout.is_empty():
		push_error("Twin Bays arena could not load its authoritative layout")
		return
	_twin_bays_layers = _create_twin_bays_layers()
	var gameplay := _twin_bays_layers[ROLE_GAMEPLAY] as Node3D
	var foreground := _twin_bays_layers[ROLE_FOREGROUND] as Node3D
	var backdrop := _twin_bays_layers[ROLE_BACKDROP] as Node3D
	var portals := _twin_bays_layers[ROLE_PORTALS] as Node3D

	_build_twin_bays_gameplay(gameplay)
	_build_twin_bays_foreground(foreground)
	_build_twin_bays_backdrop(backdrop)
	if foreground != gameplay:
		_verify_foreground_is_visual_only(foreground)
	var portal_materials := _create_twin_bays_portal_materials()
	_build_portal_pair(portals, portal_materials["ring"] as Material, portal_materials["core"] as Material)

func _build_map_dressing() -> void:
	pass

# Production subclasses use these four distinct roots. Development scenes may
# alias foreground to gameplay to preserve a legacy combined whitebox tree.
func _twin_bays_layer_names() -> Dictionary:
	return {
		ROLE_GAMEPLAY: "Gameplay",
		ROLE_FOREGROUND: "ForegroundVisuals",
		ROLE_BACKDROP: "Backdrop",
		ROLE_PORTALS: "Portals",
	}

func _create_twin_bays_layers() -> Dictionary:
	var names := _twin_bays_layer_names()
	var result := {}
	var nodes_by_name := {}
	# Backdrop-first creation preserves the approved whitebox child order while
	# production scenes still receive all four named responsibility layers.
	for role: StringName in [ROLE_BACKDROP, ROLE_GAMEPLAY, ROLE_FOREGROUND, ROLE_PORTALS]:
		var node_name := String(names[role])
		var layer: Node3D = nodes_by_name.get(node_name) as Node3D
		if layer == null:
			layer = Node3D.new()
			layer.name = node_name
			add_child(layer)
			nodes_by_name[node_name] = layer
		result[role] = layer
	return result

# Default production behavior creates authoritative Godot-owned collision only.
# Foreground GLBs remain visual-only and can never become collision authority.
func _build_twin_bays_gameplay(parent: Node3D) -> void:
	_build_collision_only_platform(parent)
	_build_collision_only_walls(parent)
	_build_collision_only_covers(parent)

func _build_twin_bays_foreground(_parent: Node3D) -> void:
	pass

func _build_twin_bays_backdrop(_parent: Node3D) -> void:
	pass

func _create_twin_bays_portal_materials() -> Dictionary:
	var portal_mat := _make_emissive_material(Color("#3ed8ff"), 5.0, true)
	portal_mat.albedo_color.a = 0.94
	portal_mat.render_priority = 2
	portal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var portal_core_mat := _make_emissive_material(Color("#2b769d"), 0.35, true)
	portal_core_mat.albedo_color.a = 0.88
	portal_core_mat.render_priority = 1
	portal_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {"ring": portal_mat, "core": portal_core_mat}

func get_twin_bays_layout() -> Dictionary:
	return _layout.duplicate(true)

func get_twin_bays_layer(role: StringName) -> Node3D:
	return _twin_bays_layers.get(role) as Node3D

func _build_collision_only_platform(parent: Node3D) -> void:
	var platform := _layout["platform"] as Dictionary
	var floor_top_y := float(platform["floor_top_y"])
	var depth := float(platform["depth"])
	var surface := _spawn_extruded_polygon(
		"ArenaSurface",
		TwinBaysLayoutScript.packed_vector2_array(platform["outline"], "platform.outline"),
		depth,
		Vector3(0, floor_top_y - depth, 0),
		parent,
		null,
		true
	)
	surface.visible = false
	var causeway := platform["causeway"] as Dictionary
	surface.set_meta("central_causeway_width", float(causeway["visible_width"]))
	surface.set_meta("safe_causeway_width", float(causeway["safe_width"]))
	_spawn_safety_causeway_collision(parent)

func _build_collision_only_walls(parent: Node3D) -> void:
	var floor_top_y := float((_layout["platform"] as Dictionary)["floor_top_y"])
	for wall_value: Variant in _layout["walls"] as Array:
		var wall := wall_value as Dictionary
		var points := TwinBaysLayoutScript.packed_vector2_array(wall["points"], "wall.points")
		for section_value: Variant in wall["sections"] as Array:
			var section := section_value as Dictionary
			var shifted := PackedVector2Array()
			for point_index in range(int(section["start"]), int(section["end_exclusive"])):
				shifted.append(points[point_index])
			var offsets := TwinBaysLayoutScript.float_array(section["offsets"], "wall.offsets")
			for point_index in range(shifted.size()):
				shifted[point_index].y += offsets[point_index]
			var footprint := _build_variable_width_polyline_footprint(
				shifted,
				TwinBaysLayoutScript.float_array(section["thicknesses"], "wall.thicknesses")
			)
			var wall_node := _spawn_extruded_polygon(
				"%s_%02d" % [wall["node_prefix"], int(section["label"])],
				footprint,
				float(section["height"]),
				Vector3(0, floor_top_y, 0),
				parent,
				null,
				true
			)
			wall_node.visible = false

func _build_collision_only_covers(parent: Node3D) -> void:
	for cover_value: Variant in _layout["covers"] as Array:
		var cover := cover_value as Dictionary
		var cover_root := Node3D.new()
		cover_root.name = String(cover["node_name"])
		cover_root.position = TwinBaysLayoutScript.vector3(cover["position"], "cover.position")
		cover_root.rotation_degrees = Vector3(0, float(cover["yaw_degrees"]), 0)
		parent.add_child(cover_root)
		var static_body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = TwinBaysLayoutScript.vector3(cover["size"], "cover.size")
		collision.shape = box
		collision.position = Vector3(0, box.size.y * 0.5, 0)
		static_body.add_child(collision)
		cover_root.add_child(static_body)

func _verify_foreground_is_visual_only(foreground: Node3D) -> void:
	var pending: Array[Node] = [foreground]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node != foreground and (node is CollisionObject3D or node is CollisionShape3D):
			push_error("Twin Bays ForegroundVisuals must be collision-free: %s" % foreground.get_path_to(node))
		if node is CSGShape3D and (node as CSGShape3D).use_collision:
			push_error("Twin Bays ForegroundVisuals contains collision-enabled CSG: %s" % foreground.get_path_to(node))
		for child: Node in node.get_children():
			pending.append(child)

func _build_curved_arena_surface(parent: Node3D, side_mat: Material, top_mat: Material) -> void:
	var platform := _layout["platform"] as Dictionary
	var polygon := TwinBaysLayoutScript.packed_vector2_array(platform["outline"], "platform.outline")
	var floor_top_y := float(platform["floor_top_y"])
	var platform_depth := float(platform["depth"])
	var surface := _spawn_extruded_polygon(
		"ArenaSurface", polygon, platform_depth, Vector3(0, floor_top_y - platform_depth, 0), parent, side_mat, true
	)
	var causeway := platform["causeway"] as Dictionary
	surface.set_meta("central_causeway_width", float(causeway["visible_width"]))
	surface.set_meta("safe_causeway_width", float(causeway["safe_width"]))

	# Two inset caps make a narrow low-poly chamfer around both the outer rim and
	# the two open bays. Unlike global scaling, polygon offsets move concave edges
	# in the correct direction.
	var bevel_mat := _make_material(Color("#bcc0c7"))
	var bevel_cap := platform["bevel_cap"] as Dictionary
	var top_cap := platform["top_cap"] as Dictionary
	var bevel_offsets := Geometry2D.offset_polygon(polygon, -float(bevel_cap["inset"]), Geometry2D.JOIN_MITER)
	var top_offsets := Geometry2D.offset_polygon(polygon, -float(top_cap["inset"]), Geometry2D.JOIN_MITER)
	if bevel_offsets.size() == 1:
		_spawn_extruded_polygon(
			"ArenaBevelCap", bevel_offsets[0], float(bevel_cap["depth"]), Vector3(0, float(bevel_cap["base_y"]), 0), parent, bevel_mat, false
		)
	if top_offsets.size() == 1:
		_spawn_extruded_polygon(
			"ArenaTopCap", top_offsets[0], float(top_cap["depth"]), Vector3(0, float(top_cap["base_y"]), 0), parent, top_mat, false
		)
	else:
		_spawn_extruded_polygon("ArenaTopCap", polygon, float(top_cap["depth"]), Vector3(0, float(top_cap["base_y"]), 0), parent, top_mat, false)
	_spawn_safety_causeway_collision(parent)

func _spawn_extruded_polygon(
	shape_name: String,
	polygon: PackedVector2Array,
	depth: float,
	pos: Vector3,
	parent: Node3D,
	mat: Material,
	collision_enabled: bool
) -> CSGPolygon3D:
	var shape := CSGPolygon3D.new()
	shape.name = shape_name
	shape.polygon = polygon
	shape.mode = CSGPolygon3D.MODE_DEPTH
	shape.depth = depth
	shape.position = pos
	shape.rotation_degrees = Vector3(90, 0, 0)
	shape.material = mat
	shape.use_collision = collision_enabled
	parent.add_child(shape)
	return shape

func _spawn_polygonal_pillar(
	shape_name: String,
	center: Vector3,
	footprint: PackedVector2Array,
	height: float,
	parent: Node3D,
	body_mat: Material,
	top_mat: Material,
	body_expand: float = 0.0,
	cap_inset: float = 0.16,
	cap_height: float = 0.15,
	collision_enabled: bool = true
) -> Node3D:
	var root := Node3D.new()
	root.name = shape_name
	root.position = center
	parent.add_child(root)

	var body_height := height - cap_height
	var body_footprint := footprint
	if body_expand > 0.0:
		var body_polygons := Geometry2D.offset_polygon(footprint, body_expand, Geometry2D.JOIN_MITER)
		if body_polygons.size() == 1:
			body_footprint = body_polygons[0]
	_spawn_extruded_polygon("Body", body_footprint, body_height, Vector3.ZERO, root, body_mat, collision_enabled)
	var cap_polygons := Geometry2D.offset_polygon(footprint, -cap_inset, Geometry2D.JOIN_MITER)
	var cap_footprint := cap_polygons[0] if cap_polygons.size() == 1 else footprint
	_spawn_extruded_polygon(
		"TopCap", cap_footprint, cap_height, Vector3(0, body_height, 0), root, top_mat, false
	)
	return root

func _spawn_safety_causeway_collision(parent: Node3D) -> void:
	var causeway := (_layout["platform"] as Dictionary)["causeway"] as Dictionary
	var body := StaticBody3D.new()
	body.name = "CausewaySafetyCollision"
	body.position = TwinBaysLayoutScript.vector3(causeway["collision_position"], "platform.causeway.collision_position")
	parent.add_child(body)

	var collision_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = TwinBaysLayoutScript.vector3(causeway["collision_size"], "platform.causeway.collision_size")
	collision_shape.shape = box
	body.add_child(collision_shape)

func _spawn_beveled_block(
	shape_name: String,
	pos: Vector3,
	size: Vector3,
	parent: Node3D,
	mat: Material,
	collision_enabled: bool = true,
	yaw_deg: float = 0.0,
	bevel: float = 0.32,
	side_lightness: float = 0.82
) -> Node3D:
	var root := Node3D.new()
	root.name = shape_name
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "BeveledMesh"
	mesh_instance.mesh = _build_chamfered_box_mesh(size, bevel, side_lightness)
	mesh_instance.position = Vector3(0, size.y * 0.5, 0)
	mesh_instance.material_override = mat
	root.add_child(mesh_instance)

	if collision_enabled:
		var static_body := StaticBody3D.new()
		var collision_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision_shape.shape = box
		collision_shape.position = Vector3(0, size.y * 0.5, 0)
		static_body.add_child(collision_shape)
		root.add_child(static_body)

	return root

func _build_chamfered_box_mesh(size: Vector3, requested_bevel: float, side_lightness: float = 0.82) -> ArrayMesh:
	var half := size * 0.5
	var bevel: float = min(requested_bevel, min(half.x, min(half.y, half.z)) * 0.72)
	bevel = max(bevel, 0.001)

	var ix := half.x - bevel
	var iy := half.y - bevel
	var iz := half.z - bevel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_meta("side_lightness", side_lightness)

	# Six inset faces.
	_add_mesh_face(st, [Vector3(-ix, half.y, -iz), Vector3(ix, half.y, -iz), Vector3(ix, half.y, iz), Vector3(-ix, half.y, iz)], Vector3.UP)
	_add_mesh_face(st, [Vector3(-ix, -half.y, -iz), Vector3(-ix, -half.y, iz), Vector3(ix, -half.y, iz), Vector3(ix, -half.y, -iz)], Vector3.DOWN)
	_add_mesh_face(st, [Vector3(-ix, -iy, -half.z), Vector3(ix, -iy, -half.z), Vector3(ix, iy, -half.z), Vector3(-ix, iy, -half.z)], Vector3.FORWARD)
	_add_mesh_face(st, [Vector3(-ix, -iy, half.z), Vector3(-ix, iy, half.z), Vector3(ix, iy, half.z), Vector3(ix, -iy, half.z)], Vector3.BACK)
	_add_mesh_face(st, [Vector3(half.x, -iy, -iz), Vector3(half.x, -iy, iz), Vector3(half.x, iy, iz), Vector3(half.x, iy, -iz)], Vector3.RIGHT)
	_add_mesh_face(st, [Vector3(-half.x, -iy, -iz), Vector3(-half.x, iy, -iz), Vector3(-half.x, iy, iz), Vector3(-half.x, -iy, iz)], Vector3.LEFT)

	# Twelve edge chamfers.
	_add_mesh_face(st, [Vector3(-ix, half.y, -iz), Vector3(ix, half.y, -iz), Vector3(ix, iy, -half.z), Vector3(-ix, iy, -half.z)], Vector3(0, 1, -1).normalized())
	_add_mesh_face(st, [Vector3(-ix, half.y, iz), Vector3(-ix, iy, half.z), Vector3(ix, iy, half.z), Vector3(ix, half.y, iz)], Vector3(0, 1, 1).normalized())
	_add_mesh_face(st, [Vector3(-ix, -half.y, -iz), Vector3(-ix, -iy, -half.z), Vector3(ix, -iy, -half.z), Vector3(ix, -half.y, -iz)], Vector3(0, -1, -1).normalized())
	_add_mesh_face(st, [Vector3(-ix, -half.y, iz), Vector3(ix, -half.y, iz), Vector3(ix, -iy, half.z), Vector3(-ix, -iy, half.z)], Vector3(0, -1, 1).normalized())
	_add_mesh_face(st, [Vector3(ix, half.y, -iz), Vector3(ix, half.y, iz), Vector3(half.x, iy, iz), Vector3(half.x, iy, -iz)], Vector3(1, 1, 0).normalized())
	_add_mesh_face(st, [Vector3(-ix, half.y, -iz), Vector3(-half.x, iy, -iz), Vector3(-half.x, iy, iz), Vector3(-ix, half.y, iz)], Vector3(-1, 1, 0).normalized())
	_add_mesh_face(st, [Vector3(ix, -half.y, -iz), Vector3(half.x, -iy, -iz), Vector3(half.x, -iy, iz), Vector3(ix, -half.y, iz)], Vector3(1, -1, 0).normalized())
	_add_mesh_face(st, [Vector3(-ix, -half.y, -iz), Vector3(-ix, -half.y, iz), Vector3(-half.x, -iy, iz), Vector3(-half.x, -iy, -iz)], Vector3(-1, -1, 0).normalized())
	_add_mesh_face(st, [Vector3(ix, -iy, -half.z), Vector3(half.x, -iy, -iz), Vector3(half.x, iy, -iz), Vector3(ix, iy, -half.z)], Vector3(1, 0, -1).normalized())
	_add_mesh_face(st, [Vector3(-ix, -iy, -half.z), Vector3(-ix, iy, -half.z), Vector3(-half.x, iy, -iz), Vector3(-half.x, -iy, -iz)], Vector3(-1, 0, -1).normalized())
	_add_mesh_face(st, [Vector3(ix, -iy, half.z), Vector3(ix, iy, half.z), Vector3(half.x, iy, iz), Vector3(half.x, -iy, iz)], Vector3(1, 0, 1).normalized())
	_add_mesh_face(st, [Vector3(-ix, -iy, half.z), Vector3(-half.x, -iy, iz), Vector3(-half.x, iy, iz), Vector3(-ix, iy, half.z)], Vector3(-1, 0, 1).normalized())

	# Eight triangular corner cuts.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_add_mesh_face(st, [
					Vector3(sx * ix, sy * half.y, sz * iz),
					Vector3(sx * ix, sy * iy, sz * half.z),
					Vector3(sx * half.x, sy * iy, sz * iz),
				], Vector3(sx, sy, sz).normalized())

	return st.commit()

func _add_mesh_face(st: SurfaceTool, vertices: Array, normal: Vector3) -> void:
	if vertices.size() < 3:
		return
	var ordered: Array = vertices.duplicate()
	var cross: Vector3 = (ordered[1] - ordered[0]).cross(ordered[2] - ordered[0])
	# Godot treats clockwise triangles as front-facing.
	if cross.dot(normal) > 0.0:
		ordered.reverse()
	for index in range(1, ordered.size() - 1):
		for vertex in [ordered[0], ordered[index], ordered[index + 1]]:
			st.set_normal(normal)
			var side_lightness: float = float(st.get_meta("side_lightness", 0.82))
			var face_lightness: float = lerpf(side_lightness, 1.0, clampf(normal.y, 0.0, 1.0))
			st.set_color(Color(face_lightness, face_lightness, face_lightness, 1.0))
			st.add_vertex(vertex)

func _build_outer_walls(
	parent: Node3D,
	north_wall_body_mat: Material,
	south_wall_body_mat: Material,
	mat: Material
) -> void:
	for wall_value: Variant in _layout["walls"] as Array:
		var wall := wall_value as Dictionary
		var body_mat := north_wall_body_mat if wall["material_role"] == "north" else south_wall_body_mat
		_spawn_wall_polyline(wall, parent, body_mat, mat)

func _spawn_wall_polyline(
	wall: Dictionary,
	parent: Node3D,
	body_mat: Material,
	top_mat: Material
) -> void:
	var prefix := String(wall["node_prefix"])
	var points := TwinBaysLayoutScript.packed_vector2_array(wall["points"], "%s.points" % wall["id"])
	var floor_top_y := float((_layout["platform"] as Dictionary)["floor_top_y"])
	for section_value: Variant in wall["sections"] as Array:
		var section := section_value as Dictionary
		var shifted_group := PackedVector2Array()
		for point_index in range(int(section["start"]), int(section["end_exclusive"])):
			shifted_group.append(points[point_index])
		var point_offsets := TwinBaysLayoutScript.float_array(section["offsets"], "%s.offsets" % wall["id"])
		var point_thicknesses := TwinBaysLayoutScript.float_array(section["thicknesses"], "%s.thicknesses" % wall["id"])
		var wall_height := float(section["height"])
		for point_index in range(shifted_group.size()):
			shifted_group[point_index].y += point_offsets[point_index]
		var footprint := _build_variable_width_polyline_footprint(shifted_group, point_thicknesses)
		if footprint.size() < 3:
			continue
		var label := int(section["label"])
		var wall_name := "%s_%02d" % [prefix, label]
		_spawn_extruded_polygon(
			wall_name,
			footprint,
			wall_height,
			Vector3(0, floor_top_y, 0),
			parent,
			body_mat,
			true
		)
		var cap_polygons := Geometry2D.offset_polygon(footprint, -float(wall["cap_inset"]), Geometry2D.JOIN_MITER)
		if cap_polygons.size() == 1:
			_spawn_extruded_polygon(
				wall_name + "Cap",
				cap_polygons[0],
				float(wall["cap_depth"]),
				Vector3(0, floor_top_y + wall_height, 0),
				parent,
				top_mat,
				false
			)

func _build_variable_width_polyline_footprint(
	points: PackedVector2Array,
	thicknesses: Array[float]
) -> PackedVector2Array:
	if points.size() < 2 or points.size() != thicknesses.size():
		return PackedVector2Array()
	var left_edge := PackedVector2Array()
	var right_edge := PackedVector2Array()
	for index in range(points.size()):
		var previous := points[maxi(index - 1, 0)]
		var following := points[mini(index + 1, points.size() - 1)]
		var tangent := (following - previous).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width := thicknesses[index] * 0.5
		left_edge.append(points[index] + normal * half_width)
		right_edge.append(points[index] - normal * half_width)
	var polygon := PackedVector2Array(left_edge)
	for index in range(right_edge.size() - 1, -1, -1):
		polygon.append(right_edge[index])
	return polygon

func _build_cover_layout(parent: Node3D, mat: Material) -> void:
	for cover_value: Variant in _layout["covers"] as Array:
		var cover := cover_value as Dictionary
		_spawn_beveled_block(
			String(cover["node_name"]),
			TwinBaysLayoutScript.vector3(cover["position"], "cover.position"),
			TwinBaysLayoutScript.vector3(cover["size"], "cover.size"),
			parent,
			mat,
			true,
			float(cover["yaw_degrees"]),
			float(cover["bevel"]),
			float(cover["side_lightness"])
		)

func _build_pickup_markers(parent: Node3D, mat: Material) -> void:
	for marker_value: Variant in _layout["pickup_markers"] as Array:
		_build_pickup_marker(marker_value as Dictionary, parent, mat)
	var special_marker := _layout.get("special_pickup_marker", {}) as Dictionary
	if not special_marker.is_empty():
		_build_pickup_marker(special_marker, parent, mat)

func _build_pickup_marker(marker: Dictionary, parent: Node3D, mat: Material) -> void:
	_spawn_beveled_block(
		String(marker["node_name"]),
		TwinBaysLayoutScript.vector3(marker["position"], "pickup_marker.position"),
		TwinBaysLayoutScript.vector3(marker["size"], "pickup_marker.size"),
		parent,
		mat,
		false,
		float(marker["yaw_degrees"]),
		float(marker["bevel"])
	)

func _build_portal_pair(
	portal_parent: Node3D,
	portal_mat: Material,
	portal_core_mat: Material
) -> void:
	var portals_by_id := {}
	for portal_value: Variant in _layout["portals"] as Array:
		var portal_data := portal_value as Dictionary
		var portal := _spawn_portal(portal_data, portal_parent, portal_mat, portal_core_mat)
		portals_by_id[String(portal_data["id"])] = portal
		if portal_data["id"] == "left_portal":
			_left_portal = portal
		elif portal_data["id"] == "right_portal":
			_right_portal = portal
	for portal_value: Variant in _layout["portals"] as Array:
		var portal_data := portal_value as Dictionary
		var portal := portals_by_id[String(portal_data["id"])] as TwinBaysPortal
		var destination := portals_by_id[String(portal_data["paired_portal_id"])] as TwinBaysPortal
		portal.configure_pair(destination, destination.exit_marker)

func _spawn_portal(
	portal_data: Dictionary,
	portal_parent: Node3D,
	portal_mat: Material,
	portal_core_mat: Material
) -> TwinBaysPortal:
	var portal := TwinBaysPortalScript.new() as TwinBaysPortal
	portal.name = String(portal_data["node_name"])
	portal.position = TwinBaysLayoutScript.vector3(portal_data["position"], "portal.position")
	portal.cooldown_seconds = float(portal_data["cooldown_seconds"])
	portal_parent.add_child(portal)
	portal.character_teleported.connect(_on_twin_bays_character_teleported)

	var trigger_data := portal_data["trigger"] as Dictionary
	var trigger_shape := CollisionShape3D.new()
	trigger_shape.name = "TriggerShape"
	var trigger_box := BoxShape3D.new()
	trigger_box.size = TwinBaysLayoutScript.vector3(trigger_data["size"], "portal.trigger.size")
	trigger_shape.shape = trigger_box
	trigger_shape.position = TwinBaysLayoutScript.vector3(trigger_data["local_position"], "portal.trigger.local_position")
	portal.add_child(trigger_shape)

	var exit_data := portal_data["exit"] as Dictionary
	var exit := Marker3D.new()
	exit.name = String(exit_data["node_name"])
	exit.position = TwinBaysLayoutScript.vector3(exit_data["local_position"], "portal.exit.local_position")
	portal.add_child(exit)
	portal.exit_marker = exit

	var portal_normal := TwinBaysLayoutScript.vector3(portal_data["normal"], "portal.normal").normalized()
	_build_twin_bays_portal_visuals(portal, portal_data, portal_normal, portal_mat, portal_core_mat)

	var light_data := portal_data["light"] as Dictionary
	var light := OmniLight3D.new()
	light.name = "PortalLight"
	light.position = TwinBaysLayoutScript.vector3(light_data["local_position"], "portal.light.local_position")
	light.light_color = Color("#5de7ff")
	light.light_energy = float(light_data["energy"])
	light.omni_range = float(light_data["range"])
	light.shadow_enabled = false
	portal.add_child(light)

	return portal

func _build_twin_bays_portal_visuals(
	portal: TwinBaysPortal,
	portal_data: Dictionary,
	portal_normal: Vector3,
	portal_mat: Material,
	portal_core_mat: Material
) -> void:
	_add_portal_ring(portal, "PortalGlow", portal_data["ring"] as Dictionary, portal_normal, portal_mat)
	_add_portal_fill(portal, "PortalCore", portal_data["core"] as Dictionary, portal_normal, portal_core_mat)

func _portal_basis(normal: Vector3) -> Basis:
	var y_axis := normal.normalized()
	var z_axis := Vector3.UP
	var x_axis := y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)

func _add_portal_ring(
	parent: Node3D,
	mesh_name: String,
	ring_data: Dictionary,
	normal: Vector3,
	mat: Material
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = _build_portal_ring_mesh(float(ring_data["inner_radius"]), float(ring_data["outer_radius"]), int(ring_data["segments"]))
	mesh_instance.position = TwinBaysLayoutScript.vector3(ring_data["local_position"], "portal.ring.local_position")
	mesh_instance.basis = _portal_basis(normal)
	mesh_instance.scale = TwinBaysLayoutScript.vector3(ring_data["scale"], "portal.ring.scale")
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)

func _add_portal_fill(
	parent: Node3D,
	mesh_name: String,
	core_data: Dictionary,
	normal: Vector3,
	mat: Material
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = _build_portal_disc_mesh(float(core_data["radius"]), int(core_data["segments"]))
	mesh_instance.position = TwinBaysLayoutScript.vector3(core_data["local_position"], "portal.core.local_position")
	mesh_instance.basis = _portal_basis(normal)
	mesh_instance.scale = TwinBaysLayoutScript.vector3(core_data["scale"], "portal.core.scale")
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)

func _build_portal_ring_mesh(inner_radius: float, outer_radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var outer_a := Vector3(cos(angle_a) * outer_radius, 0.0, sin(angle_a) * outer_radius)
		var outer_b := Vector3(cos(angle_b) * outer_radius, 0.0, sin(angle_b) * outer_radius)
		var inner_a := Vector3(cos(angle_a) * inner_radius, 0.0, sin(angle_a) * inner_radius)
		var inner_b := Vector3(cos(angle_b) * inner_radius, 0.0, sin(angle_b) * inner_radius)
		for vertex in [outer_a, inner_b, inner_a, outer_a, outer_b, inner_b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()

func _build_portal_disc_mesh(radius: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		for vertex in [
			Vector3.ZERO,
			Vector3(cos(angle_b) * radius, 0.0, sin(angle_b) * radius),
			Vector3(cos(angle_a) * radius, 0.0, sin(angle_a) * radius),
		]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()

func _get_spawn_points() -> Array:
	if _layout.is_empty():
		_layout = TwinBaysLayoutScript.load_default()
	var result: Array[Vector3] = []
	for spawn_value: Variant in _layout.get("spawns", []) as Array:
		var spawn := spawn_value as Dictionary
		result.append(TwinBaysLayoutScript.vector3(spawn["position"], "spawn.position"))
	return result

func _configure_map_runtime() -> void:
	var runtime := _layout["runtime"] as Dictionary
	var config = RuntimeGlobals.game_config()
	if config:
		config.set("default_lives", int(runtime["default_lives"]))
		config.set("respawn_delay", float(runtime["respawn_delay"]))
		config.set("invincible_duration", float(runtime["invincible_duration"]))
		config.set("fall_threshold", float(runtime["fall_threshold"]))

	if weapon_spawner:
		var pickup_points: Array[Vector3] = []
		for marker_value: Variant in _layout["pickup_markers"] as Array:
			var marker := marker_value as Dictionary
			pickup_points.append(TwinBaysLayoutScript.vector3(marker["spawn_position"], "pickup_marker.spawn_position"))
		weapon_spawner.initial_delay = float(runtime["pickup_initial_delay"])
		weapon_spawner.stay_duration = float(runtime["pickup_stay_duration"])
		weapon_spawner.respawn_cooldown = float(runtime["pickup_respawn_cooldown"])
		weapon_spawner.max_active_pickups = int(runtime["pickup_max_active"])
		weapon_spawner.fixed_spawn_points = []
		weapon_spawner.random_spawn_points = []
		weapon_spawner.custom_spawn_clusters = [pickup_points]
		weapon_spawner.custom_spawn_points = pickup_points
		weapon_spawner.weapon_factories_override = WeaponData.get_center_spawnable_weapons()

	_configure_special_weapon_spawner(runtime)

func _configure_special_weapon_spawner(runtime: Dictionary) -> void:
	var marker := _layout.get("special_pickup_marker", {}) as Dictionary
	if marker.is_empty():
		return
	var special_spawner := WeaponSpawner.new()
	special_spawner.name = "TwinBaysSpecialWeaponSpawner"
	special_spawner.initial_delay = float(runtime["special_pickup_initial_delay"])
	special_spawner.stay_duration = float(runtime["special_pickup_stay_duration"])
	special_spawner.fixed_spawn_interval = float(runtime["special_pickup_interval"])
	special_spawner.max_active_pickups = int(runtime["special_pickup_max_active"])
	special_spawner.center_powerups_enabled = false
	special_spawner.fixed_spawn_points = [
		TwinBaysLayoutScript.vector3(marker["spawn_position"], "special_pickup_marker.spawn_position"),
	]
	special_spawner.random_spawn_points = []
	special_spawner.custom_spawn_clusters = []
	special_spawner.custom_spawn_points = []
	special_spawner.weapon_factories_override = WeaponData.get_special_spawnable_weapons()
	add_child(special_spawner)
	_special_weapon_spawner = special_spawner

func get_twin_bays_special_weapon_spawner() -> WeaponSpawner:
	return _special_weapon_spawner

func _apply_map_visual_overrides() -> void:
	var camera_profile := _twin_bays_camera_profile()
	var camera := get_node_or_null("GlobalCamera") as Camera3D
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.position = camera_profile["position"] as Vector3
		camera.look_at(camera_profile["look_at"] as Vector3, Vector3.UP)
		camera.size = float(camera_profile["size"])
		camera.current = true
		_setup_runtime_camera_director(camera)
	_apply_twin_bays_environment_overrides()

func _twin_bays_camera_profile() -> Dictionary:
	var look_at := Vector3(0.34, 1.0, 0.0)
	var view_offset := twin_bays_gameplay_view_offset()
	return {
		"position": look_at + view_offset,
		"look_at": look_at,
		"size": 90.0,
	}

func _twin_bays_runtime_camera_profile() -> Dictionary:
	var overview := _twin_bays_camera_profile()
	var map_focus := overview["look_at"] as Vector3
	var view_offset := (overview["position"] as Vector3) - map_focus
	var playable_min := Vector2(INF, INF)
	var playable_max := Vector2(-INF, -INF)
	var platform := _layout.get("platform", {}) as Dictionary
	for point_value: Variant in platform.get("outline", []):
		var point := TwinBaysLayoutScript.vector2(point_value, "platform.outline")
		playable_min.x = minf(playable_min.x, point.x)
		playable_min.y = minf(playable_min.y, point.y)
		playable_max.x = maxf(playable_max.x, point.x)
		playable_max.y = maxf(playable_max.y, point.y)
	return {
		"profile_id": "twin_bays_splash_arena",
		"map_focus": map_focus,
		"view_offset": view_offset,
		"initial_size": float(overview["size"]),
		"idle_overview_size": float(overview["size"]),
		"min_size": 40.0,
		"max_size": maxf(96.0, float(overview["size"]) + 6.0),
		"discontinuity_max_size": 132.0,
		"playable_min": playable_min,
		"playable_max": playable_max,
		"focus_min": Vector2(playable_min.x + 9.0, playable_min.y + 7.0),
		"focus_max": Vector2(playable_max.x - 9.0, playable_max.y - 7.0),
		"track_min_y": -2.0,
		# The paired portal mouths sit just outside the four spawn columns. Keep
		# enough contextual margin that a four-way fight still teaches the pairing;
		# clustered fights continue to use the normal close follow camera.
		"world_frame_padding": 20.0,
		"character_screen_radius": 3.2,
		"screen_edge_gutter": 20.0,
		"min_layout_viewport": Vector2(640.0, 360.0),
		"fallback_layout_viewport": Vector2(1280.0, 720.0),
		"reserve_corner_hud": true,
		# Read the shared responsive HUD's real visible player cards. This remains
		# correct after a resolution change and reserves nothing for an all-AI match.
		"hud_occlusion_group": &"party_shooter_camera_occluder",
		"hud_occlusion_gutter": 12.0,
	}

func _setup_runtime_camera_director(camera: Camera3D) -> void:
	if _camera_director == null or not is_instance_valid(_camera_director):
		_camera_director = PartyShooterCameraDirectorScript.new() as Node
		_camera_director.name = "TwinBaysCameraDirector"
		add_child(_camera_director)
	_camera_director.call("configure", camera, _twin_bays_runtime_camera_profile())

func _update_map_runtime_camera(delta: float) -> void:
	if _camera_director and is_instance_valid(_camera_director):
		_camera_director.call("update_camera", _characters, delta)


func _on_twin_bays_character_teleported(
	character: BaseCharacter,
	from_portal: TwinBaysPortal,
	to_portal: TwinBaysPortal
) -> void:
	if _camera_director and is_instance_valid(_camera_director):
		_camera_director.call(
			"notify_spatial_discontinuity",
			character,
			from_portal.global_position,
			to_portal.global_position
		)

func set_runtime_camera_enabled(enabled: bool) -> void:
	if _camera_director and is_instance_valid(_camera_director):
		_camera_director.call("set_enabled", enabled)

func get_runtime_camera_debug() -> Dictionary:
	if _camera_director and is_instance_valid(_camera_director):
		return _camera_director.call("get_debug_state") as Dictionary
	return {}

func _apply_twin_bays_environment_overrides() -> void:
	pass

func _uses_fixed_runtime_camera() -> bool:
	return true

func _clear_twin_bays_nodes() -> void:
	var removable_names := [
		"Floor",
		"Obstacles",
		"KaykitMap",
		"ExternalArt",
		"TwinBaysWhitebox",
		"TwinBaysBackdrop",
		"TwinBaysPortals",
		"Gameplay",
		"ForegroundVisuals",
		"Backdrop",
		"Portals",
	]
	for layer_name: Variant in _twin_bays_layer_names().values():
		if String(layer_name) not in removable_names:
			removable_names.append(String(layer_name))
	for child in get_children():
		if String(child.name) in removable_names:
			child.queue_free()

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.94
	mat.metallic_specular = 0.08
	return mat

func _make_unshaded_material(color: Color) -> StandardMaterial3D:
	var mat := _make_material(color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _make_noise_backdrop_material() -> StandardMaterial3D:
	var mat := _make_unshaded_material(Color.WHITE)
	var noise := FastNoiseLite.new()
	noise.seed = 7319
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.034
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.44

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color("#363636"), Color("#3b3b3b"), Color("#404040"), Color("#464646")
	])

	var texture := NoiseTexture2D.new()
	texture.width = 768
	texture.height = 512
	texture.seamless = true
	texture.normalize = true
	texture.color_ramp = gradient
	texture.noise = noise
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return mat

func _make_emissive_material(color: Color, energy: float, transparent: bool) -> StandardMaterial3D:
	var mat := _make_material(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	if transparent:
		mat.albedo_color.a = 0.78
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 1
	return mat
