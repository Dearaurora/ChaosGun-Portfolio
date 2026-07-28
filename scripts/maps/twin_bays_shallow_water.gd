extends Node3D
class_name TwinBaysShallowWater

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const ResidueShapes = preload("res://scripts/maps/twin_bays_residue_shapes.gd")
const WaterMaterials = preload("res://scripts/maps/twin_bays_water_materials.gd")

const STEP_SFX_PATHS := [
	"res://assets/audio/generated/maps/twin_bays/shallow_step_01.wav",
	"res://assets/audio/generated/maps/twin_bays/shallow_step_02.wav",
	"res://assets/audio/generated/maps/twin_bays/shallow_step_03.wav",
]
const LAND_SFX_PATH := "res://assets/audio/generated/maps/twin_bays/shallow_land.wav"
const BULLET_SFX_PATH := "res://assets/audio/generated/maps/twin_bays/shallow_bullet.wav"
const RIPPLE_LIFETIME := 0.72
const FOOTPRINT_WIDTH := 0.48
const FOOTPRINT_LENGTH := 0.84
const RESIDUE_BUCKET_COUNT := 12

var _arena: Node3D = null
var _art_profile: Dictionary = {}
var _water_config: Dictionary = {}
var _interaction_config: Dictionary = {}
var _water_polygons: Array[PackedVector2Array] = []
var _runoff_networks: Array = []
var _platform_polygon := PackedVector2Array()
var _characters: Array[BaseCharacter] = []
var _character_states: Dictionary = {}
var _water_y := 1.135
var _tide_mode := false
var _tide_phase: StringName = &"dry_hold"
var _tide_progress := 1.0
var _residue_width_scale := 0.0
var _review_residue_art: Dictionary = {}
var _review_puddle_polygons: Array[PackedVector2Array] = []
var _review_puddle_bucket_cache: Dictionary = {}
var _last_review_puddle_bucket := -1
var _event_serial := 0

var _ripple_multimesh: MultiMeshInstance3D = null
var _ripple_states: Array[Dictionary] = []
var _ripple_cursor := 0
var _footprint_multimesh: MultiMeshInstance3D = null
var _footprint_states: Array[Dictionary] = []
var _footprint_cursor := 0
var _splash_particles: GPUParticles3D = null
var _audio_players: Array[AudioStreamPlayer3D] = []
var _audio_cursor := 0
var _step_streams: Array[AudioStream] = []
var _land_stream: AudioStream = null
var _bullet_stream: AudioStream = null
var _projectile_cell_times: Dictionary = {}
var _projectile_event_times: Array[int] = []

var _debug := {
	"configured": false,
	"visual_layer_count": 0,
	"water_polygon_count": 0,
	"footstep_events": 0,
	"entry_events": 0,
	"exit_events": 0,
	"landing_events": 0,
	"projectile_events": 0,
	"projectile_events_throttled": 0,
	"wet_footprints_spawned": 0,
	"active_ripples": 0,
	"active_footprints": 0,
	"movement_effect": "none",
	"water_master_material_count": 0,
	"water_master_shader_path": WaterMaterials.MASTER_SHADER_PATH,
}


func configure(arena: Node3D, art_profile: Dictionary, characters: Array) -> void:
	_arena = arena
	_art_profile = art_profile.duplicate(true)
	_tide_mode = String(_art_profile.get("schema", "")) == "chaos_gun.twin_bays_tide"
	if _tide_mode:
		_water_config = (_art_profile.get("residue", {}) as Dictionary).duplicate(true)
		_interaction_config = (_art_profile.get("feedback", {}) as Dictionary).duplicate(true)
		_interaction_config["gameplay_effect"] = "none"
		_runoff_networks = (_water_config.get("networks", []) as Array).duplicate(true)
		_build_platform_polygon()
		_water_y = float((_art_profile.get("levels", {}) as Dictionary).get("residue_water_y", 1.014))
	else:
		_water_config = (_art_profile.get("water_marks", {}) as Dictionary).duplicate(true)
		_interaction_config = (_water_config.get("interaction", {}) as Dictionary).duplicate(true)
	_build_polygons()
	_configure_imported_water_meshes()
	_build_effect_pools()
	_load_audio_streams()
	configure_characters(characters)
	_connect_projectiles()
	set_process(true)
	_debug["configured"] = true
	_debug["water_polygon_count"] = _runoff_networks.size() if _tide_mode else _water_polygons.size()


func configure_characters(characters: Array) -> void:
	_characters.clear()
	_character_states.clear()
	for item in characters:
		if not item is BaseCharacter:
			continue
		var character := item as BaseCharacter
		_characters.append(character)
		_character_states[character.get_instance_id()] = {
			"inside": contains_world_point(character.global_position),
			"wet_steps": 0,
			"last_water_position": character.global_position,
		}
		character.set_surface_feedback_provider(self)


func add_character(character: BaseCharacter) -> void:
	if character == null or not is_instance_valid(character):
		return
	if character not in _characters:
		_characters.append(character)
	_character_states[character.get_instance_id()] = {
		"inside": contains_world_point(character.global_position),
		"wet_steps": 0,
		"last_water_position": character.global_position,
	}
	character.set_surface_feedback_provider(self)


func set_tide_phase(phase: StringName, progress: float, _background_level_y: float) -> void:
	_tide_phase = phase
	_tide_progress = clampf(progress, 0.0, 1.0)
	match _tide_phase:
		&"high", &"rising", &"falling":
			_water_y = float((_art_profile.get("levels", {}) as Dictionary).get("platform_water_y", 1.10))
		&"draining":
			_water_y = float((_art_profile.get("levels", {}) as Dictionary).get("residue_water_y", 1.014))
	_residue_width_scale = 1.0 - _tide_progress if _tide_phase == &"draining" else (1.0 if _tide_phase == &"falling" else 0.0)
	_update_review_puddle_polygons()


func apply_art_profile(art_profile: Dictionary) -> void:
	_review_residue_art = (art_profile.get("tide_art", {}) as Dictionary).duplicate(true)
	_debug["water_master_shader_path"] = WaterMaterials.shader_path_for_config(_review_residue_art)
	_rebuild_review_puddle_cache()
	_update_review_puddle_polygons()


func apply_art_review_profile(art_profile: Dictionary) -> void:
	apply_art_profile(art_profile)
	set_meta("art_v3_review", true)


func contains_world_point(position: Vector3) -> bool:
	var point := Vector2(position.x, position.z)
	if _tide_mode:
		match _tide_phase:
			&"high", &"falling":
				return Geometry2D.is_point_in_polygon(point, _platform_polygon)
			&"rising":
				return _tide_progress >= 0.82 and Geometry2D.is_point_in_polygon(point, _platform_polygon)
			&"draining":
				if not _review_residue_art.is_empty():
					return ResidueShapes.point_in_any(point, _review_puddle_polygons)
				return _point_in_runoff(point, _residue_width_scale)
		return false
	for polygon in _water_polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false


func handle_character_footstep(character: BaseCharacter, contact_data: Dictionary) -> bool:
	if character == null or not is_instance_valid(character) or character.is_dead or character.is_game_over:
		return false
	var position := contact_data.get("position", character.global_position) as Vector3
	var state := _state_for(character)
	if contains_world_point(position):
		state["inside"] = true
		state["wet_steps"] = int(_interaction_config.get("wet_step_budget", 3))
		state["last_water_position"] = position
		_character_states[character.get_instance_id()] = state
		_debug["footstep_events"] = int(_debug["footstep_events"]) + 1
		_spawn_ripple(position, 0.46, 1.45, 0.72)
		_spawn_splash(position, 5, 0.72)
		_play_audio(&"step", position, 1.0)
		return true

	var wet_steps := int(state.get("wet_steps", 0))
	if wet_steps > 0:
		state["wet_steps"] = wet_steps - 1
		_character_states[character.get_instance_id()] = state
		if _can_place_wet_footprint(position):
			var foot_index := int(contact_data.get("foot_index", 0))
			var strength := lerpf(0.48, 1.0, float(wet_steps) / 3.0)
			_spawn_footprint(character, position, foot_index, strength)
			_debug["wet_footprints_spawned"] = int(_debug["wet_footprints_spawned"]) + 1
		_play_audio(&"wet_exit", position, float(wet_steps) / 3.0)
		return true
	return false


func handle_character_landing(character: BaseCharacter, position: Vector3, fall_speed: float) -> void:
	if character == null or character.is_dead or not contains_world_point(position):
		return
	var strength := clampf(remap(fall_speed, 2.0, 16.0, 0.65, 1.35), 0.65, 1.35)
	_debug["landing_events"] = int(_debug["landing_events"]) + 1
	_spawn_ripple(position, 0.70, 2.25 * strength, strength)
	_spawn_splash(position, 8 if strength >= 1.0 else 6, strength)
	_play_audio(&"land", position, strength)


func get_debug_state() -> Dictionary:
	var result := _debug.duplicate(true)
	result["active_ripples"] = _count_active(_ripple_states)
	result["active_footprints"] = _count_active(_footprint_states)
	result["ripple_pool_size"] = _ripple_states.size()
	result["footprint_pool_size"] = _footprint_states.size()
	result["audio_pool_size"] = _audio_players.size()
	result["water_y"] = _water_y
	result["character_state_count"] = _character_states.size()
	result["projectile_rate_limit"] = int(_interaction_config.get("projectile_global_rate_limit", 24))
	result["gameplay_effect"] = String(_interaction_config.get("gameplay_effect", "invalid"))
	result["tide_mode"] = _tide_mode
	result["tide_phase"] = String(_tide_phase)
	result["tide_progress"] = _tide_progress
	result["residue_width_scale"] = _residue_width_scale
	result["residue_topology"] = String(
		(_review_residue_art.get("residue_topology", {}) as Dictionary).get(
			"style", "legacy_ribbons"
		)
	) if not _review_residue_art.is_empty() else "legacy_ribbons"
	result["residue_puddle_count"] = _review_puddle_polygons.size()
	result["residue_visual_query_coverage"] = ResidueShapes.coverage(_review_puddle_polygons, _platform_polygon) if not _review_residue_art.is_empty() else 0.0
	var footprint_positions: Array[Vector3] = []
	for state in _footprint_states:
		if bool(state.get("active", false)):
			footprint_positions.append(state.get("position", Vector3.ZERO) as Vector3)
	result["active_footprint_positions"] = footprint_positions
	var footprint_transforms: Array[Vector3] = []
	if _footprint_multimesh and _footprint_multimesh.multimesh:
		for index in range(mini(3, _footprint_multimesh.multimesh.instance_count)):
			footprint_transforms.append(_footprint_multimesh.multimesh.get_instance_transform(index).origin)
	result["footprint_transform_origins"] = footprint_transforms
	return result


func _update_review_puddle_polygons() -> void:
	if _review_residue_art.is_empty() or not _tide_mode or _tide_phase != &"draining":
		_review_puddle_polygons.clear()
		_last_review_puddle_bucket = -1
		return
	var bucket := roundi(
		clampf(_tide_progress, 0.0, 1.0) * float(RESIDUE_BUCKET_COUNT)
	)
	if bucket == _last_review_puddle_bucket:
		return
	_last_review_puddle_bucket = bucket
	_review_puddle_polygons.clear()
	var cached := _review_puddle_bucket_cache.get(bucket, []) as Array
	for polygon_value: Variant in cached:
		_review_puddle_polygons.append(polygon_value as PackedVector2Array)


func _rebuild_review_puddle_cache() -> void:
	_review_puddle_bucket_cache.clear()
	_last_review_puddle_bucket = -1
	if _review_residue_art.is_empty() or not _tide_mode:
		return
	var layout := (_arena.call("get_twin_bays_layout") as Dictionary) if _arena and _arena.has_method("get_twin_bays_layout") else {}
	var clean := _water_config.get("clean_zones", {}) as Dictionary
	var exclusions := ResidueShapes.build_exclusions(layout, clean)
	for bucket in range(RESIDUE_BUCKET_COUNT + 1):
		var progress := float(bucket) / float(RESIDUE_BUCKET_COUNT)
		_review_puddle_bucket_cache[bucket] = ResidueShapes.build_puddle_polygons(
			_runoff_networks, progress, _platform_polygon, exclusions, _review_residue_art)


func _process(delta: float) -> void:
	_update_character_transitions()
	_update_ripples(delta)
	_update_footprints(delta)


func _build_polygons() -> void:
	_water_polygons.clear()
	if _tide_mode:
		return
	var source := _water_config.get("active_profile", _water_config) as Dictionary
	var vertex_count := int(_water_config.get("polygon_vertices", 32))
	for entry_value in source.get("clusters", []):
		_water_polygons.append(_water_polygon(entry_value as Dictionary, vertex_count, true))
	for entry_value in source.get("droplets", []):
		_water_polygons.append(_water_polygon(entry_value as Dictionary, 20, false))


func _water_polygon(entry: Dictionary, vertex_count: int, irregular: bool) -> PackedVector2Array:
	var center_values := entry.get("center", []) as Array
	var radii_values := entry.get("radii", []) as Array
	var center := Vector2(float(center_values[0]), float(center_values[1]))
	var radii := Vector2(float(radii_values[0]), float(radii_values[1]))
	var rotation := deg_to_rad(float(entry.get("rotation_degrees", 0.0)))
	var seed_value := float(entry.get("seed", 0))
	var polygon := PackedVector2Array()
	for index in range(vertex_count):
		var angle := TAU * float(index) / float(vertex_count)
		var modulation := 1.0
		if irregular:
			var phase := seed_value * 0.61803398875
			modulation += 0.105 * sin(angle * 3.0 + phase)
			modulation += 0.052 * sin(angle * 5.0 + phase * 1.73)
			modulation += 0.028 * sin(angle * 7.0 - phase * 0.61)
		var local := Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * modulation
		polygon.append(center + local.rotated(rotation))
	return polygon


func _build_platform_polygon() -> void:
	_platform_polygon.clear()
	if _arena == null or not _arena.has_method("get_twin_bays_layout"):
		return
	var layout := _arena.call("get_twin_bays_layout") as Dictionary
	for value: Variant in (layout.get("platform", {}) as Dictionary).get("outline", []):
		var pair := value as Array
		_platform_polygon.append(Vector2(float(pair[0]), float(pair[1])))


func _point_in_runoff(point: Vector2, width_scale: float) -> bool:
	if width_scale <= 0.001 or not Geometry2D.is_point_in_polygon(point, _platform_polygon):
		return false
	for value: Variant in _runoff_networks:
		var network := value as Dictionary
		var points := network.get("points", []) as Array
		for index in range(points.size() - 1):
			var a := _vector2(points[index] as Array)
			var b := _vector2(points[index + 1] as Array)
			var segment_count := maxf(float(points.size() - 1), 1.0)
			var t := (float(index) + 0.5) / segment_count
			var width := lerpf(float(network.get("width_start", 4.0)), float(network.get("width_end", 1.5)), t) * width_scale
			if _distance_to_segment(point, a, b) <= width * 0.5:
				return true
	return false


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var delta := b - a
	if delta.length_squared() <= 0.0001:
		return point.distance_to(a)
	var ratio := clampf((point - a).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return point.distance_to(a + delta * ratio)


func _configure_imported_water_meshes() -> void:
	if _arena == null:
		return
	var surface_config := _water_config.get("surface", {}) as Dictionary
	var layer_count := 0
	var master_material_count := 0
	for node in _walk(_arena):
		if not node is MeshInstance3D:
			continue
		var mesh_instance := node as MeshInstance3D
		var lower_name := String(mesh_instance.name).to_lower()
		if not lower_name.contains("shallowwater"):
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if lower_name.contains("wetbed"):
			mesh_instance.material_override = _wet_bed_material(surface_config)
			layer_count += 1
		elif lower_name.contains("meniscus"):
			mesh_instance.material_override = _meniscus_material(surface_config)
			layer_count += 1
		elif lower_name.contains("surface"):
			mesh_instance.material_override = _water_surface_material(surface_config)
			_water_y = _mesh_world_top(mesh_instance)
			layer_count += 1
		if WaterMaterials.is_master_material(mesh_instance.material_override):
			master_material_count += 1
	_debug["visual_layer_count"] = layer_count
	_debug["water_master_material_count"] = master_material_count


func _wet_bed_material(config: Dictionary) -> ShaderMaterial:
	return WaterMaterials.wet_bed_from_config(config)


func _water_surface_material(config: Dictionary) -> ShaderMaterial:
	return WaterMaterials.surface_from_config(config)


func _meniscus_material(config: Dictionary) -> ShaderMaterial:
	return WaterMaterials.meniscus_from_config(config)


func _build_effect_pools() -> void:
	var ripple_count := int(_interaction_config.get("ripple_pool_size", 32))
	_ripple_multimesh = _build_multimesh("ShallowWaterRipples", ripple_count, _ripple_material())
	_ripple_states = _empty_states(ripple_count)
	var footprint_count := int(_interaction_config.get("footprint_pool_size", 24))
	_footprint_multimesh = _build_footprint_multimesh(footprint_count)
	_footprint_states = _empty_states(footprint_count)
	_build_splash_particles()
	var audio_count := int(_interaction_config.get("audio_pool_size", 12))
	for index in range(audio_count):
		var player := AudioStreamPlayer3D.new()
		player.name = "ShallowWaterAudio_%02d" % index
		player.unit_size = 13.0
		player.max_distance = 110.0
		add_child(player)
		_audio_players.append(player)


func _build_multimesh(node_name: String, count: int, material: Material) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	quad.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = count
	multimesh.visible_instance_count = count
	for index in range(count):
		multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3(0.001, 0.001, 0.001)), Vector3.ZERO))
		multimesh.set_instance_custom_data(index, Color(1.0, 0.0, 0.0, 0.0))
	instance.multimesh = multimesh
	instance.custom_aabb = AABB(Vector3(-100.0, -2.0, -60.0), Vector3(200.0, 12.0, 120.0))
	add_child(instance)
	return instance


func _build_footprint_multimesh(count: int) -> MultiMeshInstance3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 3
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	_append_footprint_ellipse(vertices, indices, Vector2(0.0, 0.08), Vector2(0.42, 0.46), 16)
	_append_footprint_ellipse(vertices, indices, Vector2(0.0, -0.34), Vector2(0.23, 0.17), 12)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = count
	for index in range(count):
		multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3.ZERO))
		multimesh.set_instance_color(index, Color(0.14, 0.53, 0.60, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.name = "ShallowWaterWetFootprints"
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.multimesh = multimesh
	instance.custom_aabb = AABB(Vector3(-100.0, -2.0, -60.0), Vector3(200.0, 12.0, 120.0))
	add_child(instance)
	return instance


func _append_footprint_ellipse(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	center: Vector2,
	radii: Vector2,
	segments: int
) -> void:
	var center_index := vertices.size()
	vertices.append(Vector3(center.x, 0.0, center.y))
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		vertices.append(Vector3(center.x + cos(angle) * radii.x, 0.0, center.y + sin(angle) * radii.y))
	for index in range(segments):
		indices.append(center_index)
		indices.append(center_index + 1 + index)
		indices.append(center_index + 1 + ((index + 1) % segments))


func _ripple_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;
varying vec4 instance_data;
void vertex() { instance_data = INSTANCE_CUSTOM; }
void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float band = 1.0 - smoothstep(0.035, 0.15, abs(radius - 0.72));
	float fade = clamp(1.0 - instance_data.x, 0.0, 1.0);
	ALBEDO = mix(vec3(0.29, 0.82, 0.91), vec3(0.86, 0.99, 1.0), instance_data.y);
	ALPHA = band * fade * 0.88 * instance_data.y;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _build_splash_particles() -> void:
	_splash_particles = GPUParticles3D.new()
	_splash_particles.name = "ShallowWaterSplashDroplets"
	_splash_particles.amount = 256
	_splash_particles.lifetime = 0.62
	_splash_particles.one_shot = false
	_splash_particles.emitting = false
	_splash_particles.fixed_fps = 30
	_splash_particles.visibility_aabb = AABB(Vector3(-90.0, -2.0, -50.0), Vector3(180.0, 12.0, 100.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0.0, -15.0, 0.0)
	process_material.damping_min = 0.35
	process_material.damping_max = 0.75
	_splash_particles.process_material = process_material
	var droplet := SphereMesh.new()
	droplet.radius = 0.068
	droplet.height = 0.136
	droplet.radial_segments = 8
	droplet.rings = 4
	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color("#B9F5FA")
	droplet_material.roughness = 0.20
	droplet_material.metallic_specular = 0.28
	droplet.material = droplet_material
	_splash_particles.draw_pass_1 = droplet
	_splash_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_splash_particles)


func _update_character_transitions() -> void:
	for character in _characters:
		if not is_instance_valid(character):
			continue
		var state := _state_for(character)
		if character.is_dead or character.is_game_over or not character.visible:
			state["inside"] = false
			state["wet_steps"] = 0
			state["last_water_position"] = character.global_position
			_character_states[character.get_instance_id()] = state
			continue
		var inside := contains_world_point(character.global_position)
		var was_inside := bool(state.get("inside", false))
		if inside:
			state["last_water_position"] = character.global_position
		if inside and not was_inside:
			_debug["entry_events"] = int(_debug["entry_events"]) + 1
			_spawn_ripple(character.global_position, 0.72, 1.85, 0.90)
			_spawn_splash(character.global_position, 6, 0.85)
		elif was_inside and not inside:
			_debug["exit_events"] = int(_debug["exit_events"]) + 1
			state["wet_steps"] = int(_interaction_config.get("wet_step_budget", 3))
			_spawn_ripple(state.get("last_water_position", character.global_position) as Vector3, 0.55, 1.55, 0.72)
		state["inside"] = inside
		_character_states[character.get_instance_id()] = state


func _spawn_ripple(position: Vector3, start_scale: float, end_scale: float, strength: float) -> void:
	if _ripple_states.is_empty() or _ripple_multimesh == null:
		return
	var index := _ripple_cursor % _ripple_states.size()
	_ripple_cursor += 1
	_ripple_states[index] = {
		"active": true, "age": 0.0, "lifetime": RIPPLE_LIFETIME,
		"position": Vector3(position.x, _water_y + 0.018, position.z),
		"start_scale": start_scale, "end_scale": end_scale, "strength": strength,
	}


func _spawn_footprint(character: BaseCharacter, position: Vector3, foot_index: int, strength: float) -> void:
	if _footprint_states.is_empty() or _footprint_multimesh == null:
		return
	var index := _footprint_cursor % _footprint_states.size()
	_footprint_cursor += 1
	var forward := -character.global_basis.z.normalized()
	var yaw := atan2(forward.x, forward.z)
	_footprint_states[index] = {
		"active": true, "age": 0.0,
		"lifetime": float(_interaction_config.get("wet_footprint_lifetime", 1.2)),
		"position": Vector3(position.x, _water_y + 0.035, position.z),
		"yaw": yaw, "strength": strength,
		"foot_index": foot_index,
	}


func _spawn_splash(position: Vector3, count: int, strength: float) -> void:
	if _splash_particles == null:
		return
	_event_serial += 1
	for index in range(count):
		var angle := TAU * float(index) / float(maxi(count, 1)) + float(_event_serial % 7) * 0.31
		var speed := (1.4 + float((index + _event_serial) % 3) * 0.36) * strength
		var velocity := Vector3(cos(angle) * speed, (2.4 + float(index % 2) * 0.55) * strength, sin(angle) * speed)
		var transform := Transform3D(Basis().scaled(Vector3.ONE * lerpf(0.70, 1.20, strength / 1.35)), Vector3(position.x, _water_y + 0.08, position.z))
		_splash_particles.emit_particle(
			transform, velocity, Color("#C6FAFC"), Color(0.0, 0.0, 0.0, 0.0),
			GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR
		)


func _update_ripples(delta: float) -> void:
	if _ripple_multimesh == null:
		return
	var multimesh := _ripple_multimesh.multimesh
	for index in range(_ripple_states.size()):
		var state := _ripple_states[index]
		if not bool(state.get("active", false)):
			continue
		var age := float(state["age"]) + delta
		var lifetime := float(state["lifetime"])
		if age >= lifetime:
			state["active"] = false
			_ripple_states[index] = state
			multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3.ZERO))
			continue
		state["age"] = age
		_ripple_states[index] = state
		var ratio := age / lifetime
		var scale_value := lerpf(float(state["start_scale"]), float(state["end_scale"]), ease(ratio, -1.2))
		multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3(scale_value, 1.0, scale_value)), state["position"] as Vector3))
		multimesh.set_instance_custom_data(index, Color(ratio, float(state["strength"]), 0.0, 1.0))


func _update_footprints(delta: float) -> void:
	if _footprint_multimesh == null:
		return
	var multimesh := _footprint_multimesh.multimesh
	for index in range(_footprint_states.size()):
		var state := _footprint_states[index]
		if not bool(state.get("active", false)):
			continue
		var age := float(state["age"]) + delta
		var lifetime := float(state["lifetime"])
		if age >= lifetime:
			state["active"] = false
			_footprint_states[index] = state
			multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3.ZERO))
			multimesh.set_instance_color(index, Color(0.14, 0.53, 0.60, 0.0))
			continue
		state["age"] = age
		_footprint_states[index] = state
		var ratio := age / lifetime
		var basis := Basis(Vector3.UP, float(state["yaw"])).scaled(Vector3(FOOTPRINT_WIDTH, 1.0, FOOTPRINT_LENGTH))
		multimesh.set_instance_transform(index, Transform3D(basis, state["position"] as Vector3))
		var alpha := (1.0 - ratio) * 0.72 * float(state["strength"])
		multimesh.set_instance_color(index, Color(0.14, 0.53, 0.60, alpha))


func _connect_projectiles() -> void:
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	for node in get_tree().get_nodes_in_group("projectile"):
		_connect_projectile(node)


func _on_tree_node_added(node: Node) -> void:
	if node is Projectile:
		_connect_projectile(node)


func _connect_projectile(node: Node) -> void:
	if not node is Projectile:
		return
	var projectile := node as Projectile
	if not projectile.impact_resolved.is_connected(_on_projectile_impact):
		projectile.impact_resolved.connect(_on_projectile_impact)


func _on_projectile_impact(position: Vector3, _direction: Vector3, weapon_id: StringName) -> void:
	var tolerance := float(_interaction_config.get("surface_height_tolerance", 1.25))
	if absf(position.y - _water_y) > tolerance or not contains_world_point(position):
		return
	var now := Time.get_ticks_msec()
	var throttle_msec := int(float(_interaction_config.get("projectile_cell_throttle_seconds", 0.06)) * 1000.0)
	var cell := Vector2i(floori(position.x * 1.4), floori(position.z * 1.4))
	if now - int(_projectile_cell_times.get(cell, -100000)) < throttle_msec:
		_debug["projectile_events_throttled"] = int(_debug["projectile_events_throttled"]) + 1
		return
	while not _projectile_event_times.is_empty() and now - _projectile_event_times[0] >= 1000:
		_projectile_event_times.pop_front()
	if _projectile_event_times.size() >= int(_interaction_config.get("projectile_global_rate_limit", 24)):
		_debug["projectile_events_throttled"] = int(_debug["projectile_events_throttled"]) + 1
		return
	_projectile_cell_times[cell] = now
	_projectile_event_times.append(now)
	var strength := 1.0 if weapon_id == &"sniper" else 0.62
	_spawn_ripple(position, 0.24, 0.92 + strength * 0.30, strength)
	_spawn_splash(position, 4 if weapon_id == &"sniper" else 2, strength)
	_play_audio(&"bullet", position, strength)
	_debug["projectile_events"] = int(_debug["projectile_events"]) + 1


func _load_audio_streams() -> void:
	_step_streams.clear()
	for path in STEP_SFX_PATHS:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				_step_streams.append(stream)
	if ResourceLoader.exists(LAND_SFX_PATH):
		_land_stream = load(LAND_SFX_PATH) as AudioStream
	if ResourceLoader.exists(BULLET_SFX_PATH):
		_bullet_stream = load(BULLET_SFX_PATH) as AudioStream


func _play_audio(kind: StringName, position: Vector3, strength: float) -> void:
	if RuntimeGlobals.runtime_audio_disabled() or _audio_players.is_empty():
		return
	var stream: AudioStream = null
	match kind:
		&"step", &"wet_exit":
			if not _step_streams.is_empty():
				stream = _step_streams[_event_serial % _step_streams.size()]
		&"land":
			stream = _land_stream
		&"bullet":
			stream = _bullet_stream
	if stream == null:
		return
	var player := _audio_players[_audio_cursor % _audio_players.size()]
	_audio_cursor += 1
	player.stop()
	player.stream = stream
	player.global_position = position
	player.volume_db = lerpf(-19.0, -12.5, clampf(strength, 0.0, 1.35) / 1.35)
	player.pitch_scale = 0.96 + float(_event_serial % 3) * 0.035
	player.play()


func _can_place_wet_footprint(position: Vector3) -> bool:
	if contains_world_point(position):
		return false
	if _arena == null or not _arena.has_method("get_twin_bays_layout"):
		return true
	var layout := _arena.call("get_twin_bays_layout") as Dictionary
	for marker_value in layout.get("pickup_markers", []):
		var marker := marker_value as Dictionary
		var marker_pos := _position_xz(marker.get("position", []) as Array)
		if marker_pos.distance_to(Vector2(position.x, position.z)) < 2.5:
			return false
	var special := layout.get("special_pickup_marker", {}) as Dictionary
	if not special.is_empty() and _position_xz(special.get("position", []) as Array).distance_to(Vector2(position.x, position.z)) < 3.5:
		return false
	return true


func _state_for(character: BaseCharacter) -> Dictionary:
	var key := character.get_instance_id()
	if not _character_states.has(key):
		_character_states[key] = {"inside": false, "wet_steps": 0, "last_water_position": character.global_position}
	return (_character_states[key] as Dictionary).duplicate(true)


func _empty_states(count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for _index in range(count):
		result.append({"active": false})
	return result


func _count_active(states: Array[Dictionary]) -> int:
	var count := 0
	for state in states:
		if bool(state.get("active", false)):
			count += 1
	return count


func _mesh_world_top(mesh_instance: MeshInstance3D) -> float:
	var bounds := mesh_instance.get_aabb()
	var top := mesh_instance.global_transform * (bounds.position + Vector3(0.0, bounds.size.y, 0.0))
	return top.y


func _color_with_alpha(config: Dictionary, color_key: String, alpha_key: String) -> Color:
	var color := Color(String(config.get(color_key, "#72D9EA")))
	color.a = float(config.get(alpha_key, 0.35))
	return color


func _vector2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1])) if values.size() >= 2 else Vector2.ZERO


func _position_xz(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[2])) if values.size() >= 3 else Vector2.INF


func _walk(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child in root.get_children():
		result.append_array(_walk(child))
	return result
