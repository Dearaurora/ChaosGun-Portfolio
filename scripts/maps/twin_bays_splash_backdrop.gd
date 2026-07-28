extends Node3D
class_name TwinBaysSplashBackdrop

const TwinBaysLayoutScript = preload("res://scripts/maps/twin_bays_layout.gd")
const LEGACY_BACKDROP_WATER_SHADER: Shader = preload("res://assets/shaders/twin_bays_backdrop_water_legacy.gdshader")
const ART_V3_BACKDROP_WATER_SHADER: Shader = preload("res://assets/shaders/twin_bays_backdrop_water.gdshader")
const ART_V4_BACKDROP_WATER_SHADER: Shader = preload("res://assets/shaders/twin_bays_backdrop_water_v4.gdshader")
const ART_V5_BACKDROP_WATER_SHADER: Shader = preload("res://assets/shaders/twin_bays_backdrop_water_v5.gdshader")
const WATER_Y := -5.85
const WATER_PLANE_SIZE := Vector2(300.0, 300.0)
const FLOAT_BOB_LIMIT := 0.12
const FLOAT_TILT_LIMIT_DEGREES := 1.5
const PALM_SWAY_LIMIT_DEGREES := 2.0
const WATER_ENTRY_SCALE_LIMIT := 0.04

var _cream := Color("#F4EFE7")
var _aqua := Color("#4FC5D8")
var _coral := Color("#FF8F82")
var _yellow := Color("#FFD54A")
var _teal := Color("#2DB9A4")
var _trunk := Color("#B97A52")

var _ambient_motion_time := 0.0
var _float_motion: Array[Dictionary] = []
var _palm_motion: Array[Dictionary] = []
var _water_entry_motion: Array[Dictionary] = []
var _tide_level_y := WATER_Y
var _tide_phase: StringName = &"dry"
var _tide_progress := 0.0
var _water_surface: MeshInstance3D = null
var _water_shader: ShaderMaterial = null
var _art_version := 3
var _art_profile: Dictionary = {}

func _process(delta: float) -> void:
	advance_ambient_motion(delta)

func rebuild() -> void:
	set_process(false)
	for child in get_children():
		child.free()
	_float_motion.clear()
	_palm_motion.clear()
	_water_entry_motion.clear()
	_ambient_motion_time = 0.0
	_tide_level_y = WATER_Y
	_tide_phase = &"dry"
	_tide_progress = 0.0
	set_meta("visual_only", true)
	_build_water_surface()
	if _art_version < 5:
		_build_edge_islets()
		_build_inflatables()
		_build_buoy_lines()
		_build_slide_ends()
	_build_pipe_water_entries()
	_apply_ambient_motion()
	set_process(true)

func _build_water_surface() -> void:
	var water := MeshInstance3D.new()
	water.name = "DynamicBackgroundWater"
	var plane := PlaneMesh.new()
	# The shared toy-island camera has a diagonal ground footprint. A square
	# backdrop prevents its corners from exposing the sky at wide map framing.
	plane.size = WATER_PLANE_SIZE
	plane.subdivide_width = 2
	plane.subdivide_depth = 2
	water.mesh = plane
	water.position = Vector3(0.0, WATER_Y, 0.0)
	_water_shader = _water_material()
	water.material_override = _water_shader
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_water_surface = water

func set_tide_level(world_y: float, phase: StringName, progress: float) -> void:
	_tide_level_y = world_y
	_tide_phase = phase
	_tide_progress = clampf(progress, 0.0, 1.0)
	if _water_surface and is_instance_valid(_water_surface):
		_water_surface.position.y = _tide_level_y
	if _water_shader:
		_water_shader.set_shader_parameter("tide_amount", _tide_visual_amount())
	# Ambient transforms are applied once by _process(). Calling the same loop
	# here doubled all float/palm/foam work on every active tide frame.

func apply_art_profile(art_profile: Dictionary) -> void:
	var palette := art_profile.get("palette", {}) as Dictionary
	var next_version := int(art_profile.get("version", 3))
	var needs_profile_rebuild := next_version >= 4 and next_version != _art_version
	_art_version = next_version
	_art_profile = art_profile.duplicate(true)
	_aqua = Color(String(palette.get("cyan", "#63D5E4")))
	_coral = Color(String(palette.get("coral", "#FF9B8C")))
	_yellow = Color(String(palette.get("safety_yellow", "#FFDA4F")))
	if needs_profile_rebuild:
		rebuild()
	if _water_shader:
		var backdrop := art_profile.get("backdrop", {}) as Dictionary
		if _art_version >= 5:
			_water_shader.shader = ART_V5_BACKDROP_WATER_SHADER
		elif _art_version >= 4:
			_water_shader.shader = ART_V4_BACKDROP_WATER_SHADER
		else:
			_water_shader.shader = ART_V3_BACKDROP_WATER_SHADER
		_water_shader.set_shader_parameter(
			"shallow_color",
			Color(String(backdrop.get("shallow_color", palette.get("cyan", "#63D5E4"))))
		)
		_water_shader.set_shader_parameter(
			"light_color",
			Color(String(backdrop.get("light_color", palette.get("portal_cyan", "#3FE7FF"))))
		)
		_water_shader.set_shader_parameter(
			"deep_color",
			Color(String(backdrop.get("deep_color", palette.get("deep_water", "#087F9E"))))
		)
		_water_shader.set_shader_parameter("caustic_strength", float(backdrop.get("caustic_strength", 0.20)))
		if _art_version >= 4:
			_water_shader.set_shader_parameter("perimeter_depth", float(backdrop.get("perimeter_depth", 0.20)))
			_water_shader.set_shader_parameter("bay_depth_strength", float(backdrop.get("bay_depth", 0.78)))
		if _art_version >= 5:
			var caustic_texture_path := String(
				backdrop.get(
					"caustic_texture",
					"res://assets/textures/generated/twin_bays_v5_caustics.png"
				)
			)
			if ResourceLoader.exists(caustic_texture_path):
				_water_shader.set_shader_parameter(
					"caustic_texture",
					load(caustic_texture_path) as Texture2D
				)
			_water_shader.set_shader_parameter(
				"caustic_world_scale",
				float(backdrop.get("caustic_world_scale", 0.30))
			)
			_water_shader.set_shader_parameter(
				"caustic_softness",
				float(backdrop.get("caustic_softness", 0.105))
			)
			_water_shader.set_shader_parameter(
				"caustic_detail_mix",
				float(backdrop.get("caustic_detail_mix", 0.38))
			)
			_water_shader.set_shader_parameter(
				"macro_swell_strength",
				float(backdrop.get("macro_swell_strength", 0.055))
			)
			_water_shader.set_shader_parameter(
				"caustic_tile_world_size",
				float(backdrop.get("caustic_tile_world_size", 64.0))
			)
			_water_shader.set_shader_parameter(
				"caustic_light_mix",
				float(backdrop.get("caustic_light_mix", 0.24))
			)
			_water_shader.set_shader_parameter(
				"outer_darkening",
				float(backdrop.get("outer_darkening", 0.018))
			)
			_water_shader.set_shader_parameter(
				"glint_strength",
				float(backdrop.get("glint_strength", 0.012))
			)
			_water_shader.set_shader_parameter(
				"caustic_scroll_a",
				_vector2(backdrop.get("caustic_scroll_a", [0.0016, -0.0011]) as Array)
			)
			_water_shader.set_shader_parameter(
				"caustic_scroll_b",
				_vector2(backdrop.get("caustic_scroll_b", [-0.0010, 0.0014]) as Array)
			)
	set_meta(
		"art_v5_active" if _art_version >= 5 else (
			"art_v4_active" if _art_version >= 4 else "art_v3_active"
		),
		true
	)


func apply_art_review_profile(art_profile: Dictionary) -> void:
	apply_art_profile(art_profile)
	set_meta(
		"art_v5_review" if _art_version >= 5 else (
			"art_v4_review" if _art_version >= 4 else "art_v3_review"
		),
		true
	)


func _vector2(values: Array) -> Vector2:
	if values.size() < 2:
		return Vector2.ZERO
	return Vector2(float(values[0]), float(values[1]))

func _build_edge_islets() -> void:
	var scale_boost := 1.12 if _art_version >= 4 else 1.0
	_create_islet("NorthWestPalmIslet", Vector3(-54.0, WATER_Y + 0.35, -43.0), 0.66 * scale_boost, -16.0)
	_create_islet("NorthEastPalmIslet", Vector3(55.0, WATER_Y + 0.35, -42.0), 0.62 * scale_boost, 21.0)
	_create_islet("SouthWestPalmIslet", Vector3(-56.0, WATER_Y + 0.30, 39.0), 0.56 * scale_boost, 12.0)
	_create_islet("SouthEastPalmIslet", Vector3(57.0, WATER_Y + 0.30, 38.0), 0.56 * scale_boost, -17.0)

func _create_islet(node_name: String, position_value: Vector3, scale_value: float, yaw: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position_value
	root.scale = Vector3.ONE * scale_value
	root.rotation_degrees.y = yaw
	add_child(root)

	var sand := MeshInstance3D.new()
	sand.name = "DrySandBase"
	var sand_mesh := CylinderMesh.new()
	sand_mesh.top_radius = 8.0
	sand_mesh.bottom_radius = 9.2
	sand_mesh.height = 1.15
	sand_mesh.radial_segments = 20 if _art_version >= 4 else 12
	sand.mesh = sand_mesh
	sand.material_override = _material(_cream, 0.96)
	root.add_child(sand)

	var grass := MeshInstance3D.new()
	grass.name = "IslandTurf"
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 6.8
	grass_mesh.bottom_radius = 7.5
	grass_mesh.height = 0.32
	grass_mesh.radial_segments = 20 if _art_version >= 4 else 12
	grass.mesh = grass_mesh
	grass.position.y = 0.68
	grass.material_override = _material(_teal, 0.9)
	root.add_child(grass)

	_add_palm(root, Vector3(-1.7, 0.9, 0.8), 0.95, -12.0)
	_add_palm(root, Vector3(2.5, 0.9, -1.1), 0.72, 18.0)

func _add_palm(parent: Node3D, local_position: Vector3, scale_value: float, yaw: float) -> void:
	var palm := Node3D.new()
	palm.name = "LowPolyPalm"
	palm.position = local_position
	palm.scale = Vector3.ONE * scale_value
	palm.rotation_degrees.y = yaw
	parent.add_child(palm)
	_register_palm_motion(palm)

	var trunk := MeshInstance3D.new()
	trunk.name = "PalmTrunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.28
	trunk_mesh.bottom_radius = 0.48
	trunk_mesh.height = 5.2
	trunk_mesh.radial_segments = 10 if _art_version >= 4 else 7
	trunk.mesh = trunk_mesh
	trunk.position.y = 2.6
	trunk.rotation_degrees.z = -5.0
	trunk.material_override = _material(_trunk, 0.91)
	palm.add_child(trunk)

	for index in range(7):
		var leaf := MeshInstance3D.new()
		leaf.name = "PalmLeaf%02d" % index
		var leaf_mesh := BoxMesh.new()
		leaf_mesh.size = Vector3(0.46, 0.11, 4.35) if _art_version >= 4 else Vector3(0.55, 0.13, 4.0)
		leaf.mesh = leaf_mesh
		leaf.position = Vector3(0.0, 5.25, 0.0)
		leaf.rotation_degrees = Vector3(15.0 + float(index % 2) * 6.0, float(index) * 360.0 / 7.0, 0.0)
		leaf.material_override = _material(_teal.lightened(0.04 * float(index % 3)), 0.92)
		palm.add_child(leaf)

func _build_inflatables() -> void:
	_add_inflatable_ring("CoralFloatNorthWest", Vector3(-43.0, WATER_Y + 0.16, -43.0), 2.3, _coral, 22.0)
	_add_inflatable_ring("YellowFloatNorthEast", Vector3(45.0, WATER_Y + 0.16, -42.0), 2.0, _yellow, -31.0)
	_add_inflatable_ring("AquaFloatSouthWest", Vector3(-53.0, WATER_Y + 0.16, 35.0), 1.8, _aqua, -8.0)
	_add_inflatable_ring("CoralFloatSouthEast", Vector3(52.0, WATER_Y + 0.16, 35.0), 2.1, _coral, 13.0)

func _add_inflatable_ring(node_name: String, position_value: Vector3, radius: float, color: Color, yaw: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	ring.mesh = _torus_mesh(radius * 0.55, radius, 18 if _art_version >= 4 else 12, 48 if _art_version >= 4 else 32)
	ring.position = position_value
	ring.rotation_degrees.y = yaw
	ring.material_override = _material(color, 0.56)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var index := _float_motion.size()
	_register_float_motion(
		ring,
		0.090 + float(index % 3) * 0.009,
		1.10 + float(index % 2) * 0.22,
		0.41 + float(index) * 1.47,
		0.56 + float(index % 2) * 0.07
	)

func _build_buoy_lines() -> void:
	_add_buoy_line("NorthBuoyLine", Vector3(-32.0, WATER_Y + 0.18, -51.0), Vector3(32.0, WATER_Y + 0.18, -51.0), 11)
	_add_buoy_line("SouthBuoyLine", Vector3(-28.0, WATER_Y + 0.18, 49.0), Vector3(28.0, WATER_Y + 0.18, 49.0), 9)

func _add_buoy_line(node_name: String, start: Vector3, finish: Vector3, count: int) -> void:
	var root := Node3D.new()
	root.name = node_name
	add_child(root)
	for index in range(count):
		var buoy := MeshInstance3D.new()
		buoy.name = "Buoy%02d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 0.48
		sphere.height = 0.82
		sphere.radial_segments = 14 if _art_version >= 4 else 10
		sphere.rings = 7 if _art_version >= 4 else 5
		buoy.mesh = sphere
		buoy.position = start.lerp(finish, float(index) / float(maxi(count - 1, 1)))
		buoy.material_override = _material(_yellow if index % 2 == 0 else _coral, 0.62)
		buoy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(buoy)
		var motion_index := _float_motion.size()
		_register_float_motion(
			buoy,
			0.052 + float(index % 4) * 0.006,
			0.72 + float(index % 3) * 0.14,
			0.83 + float(motion_index) * 0.79,
			0.43 + float(index % 3) * 0.035
		)

func _build_slide_ends() -> void:
	_add_slide_end("NorthWestSlideEnd", Vector3(-45.0, WATER_Y + 2.0, -46.0), 23.0, _aqua)
	_add_slide_end("NorthEastSlideEnd", Vector3(45.0, WATER_Y + 2.0, -45.0), -23.0, _coral)

func _build_pipe_water_entries() -> void:
	var layout := TwinBaysLayoutScript.load_default()
	var portal_art := _art_profile.get("portal_art", {}) as Dictionary
	var radius_multiplier := float(
		portal_art.get("water_entry_foam_radius_multiplier", 1.0)
	)
	for pipe_value: Variant in layout.get("portal_pipes", []):
		var pipe := pipe_value as Dictionary
		var entry := TwinBaysLayoutScript.vector3(pipe["water_entry_position"], "portal_pipe.water_entry_position")
		entry.y = WATER_Y + 0.16
		var radius := float(pipe["water_entry_foam_radius"]) * radius_multiplier

		var foam := MeshInstance3D.new()
		foam.name = String(pipe["node_name"]) + "WaterFoam"
		foam.mesh = (
			_broken_annulus_mesh(radius * 0.72, radius, 64, 0)
			if _art_version >= 5
			else _torus_mesh(radius - 0.72, radius, 14, 40)
		)
		foam.position = entry
		foam.material_override = (
			_water_detail_material(
				Color(String(portal_art.get("water_entry_foam_color", "#DDF8F5"))),
				float(portal_art.get("water_entry_foam_alpha", 0.68)),
				0.24
			)
			if _art_version >= 5
			else _material(Color("#EAFDFF"), 0.44)
		)
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(foam)
		_register_water_entry_motion(foam, 0.027, 0.37 + float(_water_entry_motion.size()) * 1.91, 0.58)

		var ripple := MeshInstance3D.new()
		ripple.name = String(pipe["node_name"]) + "CyanRipple"
		ripple.mesh = (
			_broken_annulus_mesh(radius * 0.48, radius * 0.67, 64, 5)
			if _art_version >= 5
			else _torus_mesh(radius - 1.12, radius - 0.82, 12, 36)
		)
		ripple.position = entry + Vector3(0.0, 0.05, 0.0)
		ripple.material_override = (
			_water_detail_material(
				Color(String(portal_art.get("ripple_color", "#8EF6FF"))),
				float(portal_art.get("water_entry_ripple_alpha", 0.34)),
				0.18
			)
			if _art_version >= 5
			else _material(Color("#7CEAFF"), 0.38)
		)
		ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ripple)
		_register_water_entry_motion(ripple, 0.036, 1.24 + float(_water_entry_motion.size()) * 1.53, 0.49)

		if _art_version >= 5:
			# A second, softer broken-water ring gives the pipe a seated
			# outflow footprint at the gameplay camera distance. It remains
			# visual-only and follows the same bounded tide motion.
			var outer_eddy := MeshInstance3D.new()
			outer_eddy.name = String(pipe["node_name"]) + "OuterWaterEddy"
			outer_eddy.mesh = _broken_annulus_mesh(
				radius * 1.05, radius * 1.13, 72, 9
			)
			outer_eddy.position = entry - Vector3(0.0, 0.025, 0.0)
			outer_eddy.scale = Vector3(1.18, 1.0, 0.78)
			outer_eddy.material_override = _water_detail_material(
				Color(String(portal_art.get("water_entry_foam_color", "#DDF8F5"))),
				float(portal_art.get("water_entry_outer_alpha", 0.36)),
				0.30
			)
			outer_eddy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(outer_eddy)
			_register_water_entry_motion(
				outer_eddy, 0.022,
				2.06 + float(_water_entry_motion.size()) * 1.17, 0.42
			)

func _register_float_motion(
	node: Node3D,
	bob_amplitude: float,
	tilt_amplitude_degrees: float,
	phase: float,
	speed: float
) -> void:
	node.set_meta("visual_only", true)
	node.set_meta("ambient_motion", "float")
	var tilt_axis := Vector3(cos(phase), 0.0, sin(phase)).normalized()
	_float_motion.append({
		"node": node,
		"origin": node.position,
		"base_rotation": node.rotation,
		"bob_amplitude": minf(absf(bob_amplitude), FLOAT_BOB_LIMIT),
		"tilt_amplitude_degrees": minf(absf(tilt_amplitude_degrees), FLOAT_TILT_LIMIT_DEGREES),
		"tilt_axis": tilt_axis,
		"phase": phase,
		"speed": speed,
	})

func _register_palm_motion(palm: Node3D) -> void:
	var index := _palm_motion.size()
	var phase := 0.62 + float(index) * 1.19
	palm.set_meta("visual_only", true)
	palm.set_meta("ambient_motion", "palm")
	_palm_motion.append({
		"node": palm,
		"base_rotation": palm.rotation,
		"sway_amplitude_degrees": minf(1.62 + float(index % 3) * 0.12, PALM_SWAY_LIMIT_DEGREES),
		"sway_axis": Vector3(cos(phase), 0.0, sin(phase)).normalized(),
		"phase": phase,
		"speed": 0.25 + float(index % 2) * 0.035,
	})

func _register_water_entry_motion(node: Node3D, scale_amplitude: float, phase: float, speed: float) -> void:
	node.set_meta("visual_only", true)
	node.set_meta("ambient_motion", "water_entry")
	_water_entry_motion.append({
		"node": node,
		"origin": node.position,
		"base_scale": node.scale,
		"scale_amplitude": minf(absf(scale_amplitude), WATER_ENTRY_SCALE_LIMIT),
		"phase": phase,
		"speed": speed,
	})

func advance_ambient_motion(delta: float) -> void:
	_ambient_motion_time = fmod(_ambient_motion_time + maxf(delta, 0.0), 3600.0)
	_apply_ambient_motion()

func _apply_ambient_motion() -> void:
	for entry in _float_motion:
		var node := entry.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var phase := float(entry["phase"])
		var speed := float(entry["speed"])
		var wave := sin(_ambient_motion_time * speed + phase)
		var tilt_wave := sin(_ambient_motion_time * speed * 0.79 + phase + 0.57)
		node.position = (entry["origin"] as Vector3) + Vector3.UP * (
			_tide_level_y - WATER_Y + wave * float(entry["bob_amplitude"])
		)
		node.rotation = (entry["base_rotation"] as Vector3) + (entry["tilt_axis"] as Vector3) * deg_to_rad(
			tilt_wave * float(entry["tilt_amplitude_degrees"])
		)

	for entry in _palm_motion:
		var palm := entry.get("node") as Node3D
		if not is_instance_valid(palm):
			continue
		var sway := sin(
			_ambient_motion_time * float(entry["speed"]) + float(entry["phase"])
		) * float(entry["sway_amplitude_degrees"])
		palm.rotation = (entry["base_rotation"] as Vector3) + (entry["sway_axis"] as Vector3) * deg_to_rad(sway)

	for entry in _water_entry_motion:
		var water_entry := entry.get("node") as Node3D
		if not is_instance_valid(water_entry):
			continue
		var pulse := 1.0 + sin(
			_ambient_motion_time * float(entry["speed"]) + float(entry["phase"])
		) * float(entry["scale_amplitude"])
		water_entry.position.y = (entry["origin"] as Vector3).y + (_tide_level_y - WATER_Y)
		water_entry.scale = (entry["base_scale"] as Vector3) * pulse

func get_ambient_motion_debug() -> Dictionary:
	var float_samples: Array[Dictionary] = []
	for entry in _float_motion:
		var node := entry.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var rotation_delta := node.rotation - (entry["base_rotation"] as Vector3)
		float_samples.append({
			"path": _ambient_debug_path(node),
			"bob_offset": node.position.y - (entry["origin"] as Vector3).y,
			"tilt_degrees": rad_to_deg(Vector2(rotation_delta.x, rotation_delta.z).length()),
			"bob_limit": FLOAT_BOB_LIMIT,
			"tilt_limit_degrees": FLOAT_TILT_LIMIT_DEGREES,
		})

	var palm_samples: Array[Dictionary] = []
	for entry in _palm_motion:
		var palm := entry.get("node") as Node3D
		if not is_instance_valid(palm):
			continue
		var rotation_delta := palm.rotation - (entry["base_rotation"] as Vector3)
		palm_samples.append({
			"path": _ambient_debug_path(palm),
			"sway_degrees": rad_to_deg(Vector2(rotation_delta.x, rotation_delta.z).length()),
			"sway_limit_degrees": PALM_SWAY_LIMIT_DEGREES,
		})

	var water_entry_samples: Array[Dictionary] = []
	for entry in _water_entry_motion:
		var water_entry := entry.get("node") as Node3D
		if not is_instance_valid(water_entry):
			continue
		var base_scale := entry["base_scale"] as Vector3
		water_entry_samples.append({
			"path": _ambient_debug_path(water_entry),
			"scale_ratio": water_entry.scale.x / maxf(base_scale.x, 0.0001),
			"scale_limit": WATER_ENTRY_SCALE_LIMIT,
		})

	return {
		"ready": not _float_motion.is_empty() and not _palm_motion.is_empty() and not _water_entry_motion.is_empty(),
		"time": _ambient_motion_time,
		"float_count": _float_motion.size(),
		"palm_count": _palm_motion.size(),
		"water_entry_count": _water_entry_motion.size(),
		"water_y": _tide_level_y,
		"tide_phase": String(_tide_phase),
		"tide_progress": _tide_progress,
		"water_plane_size": WATER_PLANE_SIZE,
		"float_samples": float_samples,
		"palm_samples": palm_samples,
		"water_entry_samples": water_entry_samples,
	}

func _ambient_debug_path(node: Node) -> String:
	if node.is_inside_tree():
		return String(node.get_path())
	return "%s#%d" % [node.name, node.get_instance_id()]

func _add_slide_end(node_name: String, position_value: Vector3, yaw: float, color: Color) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position_value
	root.rotation_degrees = Vector3(-12.0, yaw, 0.0)
	add_child(root)
	var chute := MeshInstance3D.new()
	chute.name = "SlideChute"
	var chute_mesh := BoxMesh.new()
	chute_mesh.size = Vector3(5.0, 0.45, 12.0)
	chute.mesh = chute_mesh
	chute.material_override = _material(color, 0.48)
	root.add_child(chute)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = "YellowRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.45, 1.05, 12.3)
		rail.mesh = rail_mesh
		rail.position = Vector3(2.45 * side, 0.48, 0.0)
		rail.material_override = _material(_yellow, 0.55)
		root.add_child(rail)

func _water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LEGACY_BACKDROP_WATER_SHADER
	return material

func _tide_visual_amount() -> float:
	match _tide_phase:
		&"warning":
			return 0.18 + _tide_progress * 0.22
		&"rising", &"high":
			return 1.0
		&"falling":
			return 1.0 - _tide_progress * 0.45
	return 0.0

func _torus_mesh(inner_radius: float, outer_radius: float, ring_segments: int, radial_segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center_radius := (inner_radius + outer_radius) * 0.5
	var tube_radius := (outer_radius - inner_radius) * 0.5
	for ring_index in range(ring_segments):
		var theta_a := TAU * float(ring_index) / float(ring_segments)
		var theta_b := TAU * float(ring_index + 1) / float(ring_segments)
		for radial_index in range(radial_segments):
			var phi_a := TAU * float(radial_index) / float(radial_segments)
			var phi_b := TAU * float(radial_index + 1) / float(radial_segments)
			_add_torus_triangle(st, center_radius, tube_radius, theta_a, phi_a, theta_b, phi_a, theta_b, phi_b)
			_add_torus_triangle(st, center_radius, tube_radius, theta_a, phi_a, theta_b, phi_b, theta_a, phi_b)
	return st.commit()


func _broken_annulus_mesh(
	inner_radius: float,
	outer_radius: float,
	segments: int,
	phase: int
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		# Two non-matching rhythms avoid a stamped dashed circle while keeping
		# generation deterministic and the contact silhouette visibly open.
		var cadence_a := (index + phase) % 13
		var cadence_b := (index * 3 + phase * 2) % 17
		if cadence_a in [8, 9, 10] or cadence_b in [13, 14]:
			continue
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var inner_a := Vector3(
			cos(angle_a) * inner_radius, 0.0, sin(angle_a) * inner_radius
		)
		var inner_b := Vector3(
			cos(angle_b) * inner_radius, 0.0, sin(angle_b) * inner_radius
		)
		var outer_a := Vector3(
			cos(angle_a) * outer_radius, 0.0, sin(angle_a) * outer_radius
		)
		var outer_b := Vector3(
			cos(angle_b) * outer_radius, 0.0, sin(angle_b) * outer_radius
		)
		for vertex in [
			outer_a, outer_b, inner_b,
			outer_a, inner_b, inner_a,
		]:
			st.set_normal(Vector3.UP)
			st.add_vertex(vertex)
	return st.commit()


func _add_torus_triangle(st: SurfaceTool, center_radius: float, tube_radius: float, theta_a: float, phi_a: float, theta_b: float, phi_b: float, theta_c: float, phi_c: float) -> void:
	for pair in [[theta_a, phi_a], [theta_b, phi_b], [theta_c, phi_c]]:
		var theta := float(pair[0])
		var phi := float(pair[1])
		var radial := center_radius + tube_radius * cos(phi)
		var normal := Vector3(cos(theta) * cos(phi), sin(phi), sin(theta) * cos(phi)).normalized()
		st.set_normal(normal)
		st.add_vertex(Vector3(cos(theta) * radial, tube_radius * sin(phi), sin(theta) * radial))


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.0
	material.roughness = roughness
	material.metallic_specular = 0.12
	return material


func _water_detail_material(
	color: Color,
	alpha: float,
	roughness: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, clampf(alpha, 0.0, 1.0))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = roughness
	material.metallic_specular = 0.46
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.18
	material.render_priority = 1
	return material
