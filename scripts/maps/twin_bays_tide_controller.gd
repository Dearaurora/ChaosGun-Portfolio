extends Node3D
class_name TwinBaysTideController

signal phase_changed(phase: StringName, duration: float)

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")
const ResidueShapes = preload("res://scripts/maps/twin_bays_residue_shapes.gd")
const WaterMaterials = preload("res://scripts/maps/twin_bays_water_materials.gd")
const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const MATCH_EVENT_BANNER_SCENE = preload("res://scenes/ui/components/match_event_banner.tscn")
const MOTION_SOURCE := &"twin_bays_high_tide"
const RESIDUE_BUCKET_COUNT := 12
const PHASE_ORDER: Array[StringName] = [
	&"initial_dry", &"warning", &"rising", &"high", &"falling", &"draining", &"dry_hold",
]

var _arena: Node3D = null
var _layout: Dictionary = {}
var _profile: Dictionary = {}
var _characters: Array[BaseCharacter] = []
var _backdrop: TwinBaysSplashBackdrop = null
var _shallow_water: TwinBaysShallowWater = null
var _phase: StringName = &"initial_dry"
var _phase_elapsed := 0.0
var _phase_progress := 0.0
var _running := false
var _debug_override := false
var _arrival_fired := false

var _flood_surface: MeshInstance3D = null
var _flood_material: ShaderMaterial = null
var _residue_root: Node3D = null
var _residue_materials: Array[ShaderMaterial] = []
var _residue_mesh_instances: Array[MeshInstance3D] = []
var _residue_bucket_cache: Dictionary = {}
var _danger_foam: Node3D = null
var _danger_foam_material: Material = null
var _danger_foam_base_alpha := 0.0
var _warning_layer: CanvasLayer = null
var _warning_banner = null
var _warning_label: Label = null
var _warning_audio: AudioStreamPlayer = null
var _arrival_audio: AudioStreamPlayer = null
var _last_residue_bucket := -1
var _residue_coverage := 0.0
var _review_tide_art: Dictionary = {}
var _motion_modifier_state: Dictionary = {}


func configure(
	arena: Node3D,
	layout: Dictionary,
	tide_profile: Dictionary,
	characters: Array,
	backdrop: TwinBaysSplashBackdrop,
	shallow_water: TwinBaysShallowWater
) -> void:
	_arena = arena
	_layout = layout.duplicate(true)
	_profile = tide_profile.duplicate(true)
	_backdrop = backdrop
	_shallow_water = shallow_water
	_characters.clear()
	_motion_modifier_state.clear()
	for item: Variant in characters:
		if item is BaseCharacter:
			var character := item as BaseCharacter
			character.clear_environment_motion_modifier(MOTION_SOURCE)
			_characters.append(character)
	_build_flood_surface()
	_build_residue_visuals(1.0)
	_build_danger_foam()
	_build_warning_ui()
	_build_phase_audio()
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	_apply_phase_state()


func start_cycle() -> void:
	_debug_override = false
	_running = true
	_set_phase(&"initial_dry")


func stop_cycle() -> void:
	_running = false
	_clear_motion_modifiers()
	_hide_warning()


func set_debug_phase(phase: StringName, progress: float) -> void:
	if phase not in PHASE_ORDER:
		push_error("Unknown Twin Bays tide phase: %s" % phase)
		return
	_running = false
	_debug_override = true
	_phase = phase
	_phase_progress = clampf(progress, 0.0, 1.0)
	_phase_elapsed = _phase_duration(phase) * _phase_progress
	_apply_phase_state()


func apply_art_profile(art_profile: Dictionary) -> void:
	# Approved visual tuning. Gameplay timing, levels and motion modifiers remain
	# owned by Tide V1 and are deliberately not copied from the art profile.
	_review_tide_art = (art_profile.get("tide_art", {}) as Dictionary).duplicate(true)
	if _flood_material:
		WaterMaterials.apply_shader_variant(_flood_material, _review_tide_art)
		var color := Color(String(_review_tide_art.get("high_water_color", "#83EAF0")))
		color.a = float(_review_tide_art.get("high_water_alpha", 0.36))
		_flood_material.set_shader_parameter("water_color", color)
		_flood_material.set_shader_parameter("water_roughness", float(_review_tide_art.get("high_water_roughness", 0.18)))
		_flood_material.set_shader_parameter("water_specular", float(_review_tide_art.get("high_water_specular", 0.44)))
		_flood_material.set_shader_parameter("normal_strength", float(_review_tide_art.get("high_water_normal_strength", 0.64)))
		_flood_material.set_shader_parameter("highlight_strength", float(_review_tide_art.get("high_water_highlight_strength", 0.26)))
	_build_residue_visuals(1.0)
	_build_danger_foam()
	if _shallow_water and _shallow_water.has_method("apply_art_profile"):
		_shallow_water.call("apply_art_profile", art_profile)
	_last_residue_bucket = -1
	_apply_phase_state()


func apply_art_review_profile(art_profile: Dictionary) -> void:
	apply_art_profile(art_profile)
	set_meta("art_v3_review", true)


func get_debug_state() -> Dictionary:
	return {
		"configured": _arena != null and not _profile.is_empty(),
		"running": _running,
		"debug_override": _debug_override,
		"phase": String(_phase),
		"phase_elapsed": _phase_elapsed,
		"phase_duration": _phase_duration(_phase),
		"phase_progress": _phase_progress,
		"background_water_y": _background_water_y(),
		"platform_water_visible": _flood_surface != null and _flood_surface.visible,
		"residue_coverage": _residue_coverage,
		"residue_network_count": _networks().size(),
		"residue_topology": String(_residue_root.get_meta("topology", "legacy_ribbons")) if _residue_root else "none",
		"residue_puddle_count": int(_residue_root.get_meta("puddle_count", 0)) if _residue_root else 0,
		"residue_vertex_count": _mesh_vertex_count(_residue_root),
		"motion_modifier_count": _active_motion_modifier_count(),
		"speed_multiplier": _gameplay_float("speed_multiplier", 0.90),
		"damp_multiplier": _gameplay_float("horizontal_damp_multiplier", 1.25),
		"collision_nodes": _count_collision_nodes(self),
		"art_review_active": not _review_tide_art.is_empty(),
		"authored_bay_foam_enabled": bool(
			_review_tide_art.get("authored_bay_foam_enabled", false)
		),
		"danger_foam_visible": _danger_foam != null and _danger_foam.visible,
		"danger_foam_vertex_count": _mesh_vertex_count(_danger_foam),
		"danger_foam_aabb": (
			(_danger_foam.get_child(0) as MeshInstance3D).mesh.get_aabb()
			if _danger_foam != null
				and _danger_foam.get_child_count() > 0
				and _danger_foam.get_child(0) is MeshInstance3D
			else AABB()
		),
		"danger_foam_material_alpha": (
			_danger_foam_base_alpha
		),
		"danger_foam_authored": (
			bool(_danger_foam.get_child(0).get_meta("authored_bay_foam", false))
			if _danger_foam != null and _danger_foam.get_child_count() > 0
			else false
		),
		"water_master_shader_path": WaterMaterials.shader_path_for_material(_flood_material),
		"warning_visible": is_instance_valid(_warning_banner) and _warning_banner.visible,
		"warning_title": _warning_label.text if is_instance_valid(_warning_label) else "",
		"water_master_material_count": _water_master_material_count(),
		"water_materials_unified": _water_materials_unified(),
		"transparent_batch_count": 3,
	}


func _process(delta: float) -> void:
	if not _running:
		return
	_phase_elapsed += maxf(delta, 0.0)
	var duration := _phase_duration(_phase)
	_phase_progress = clampf(_phase_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	_apply_phase_state()
	if _phase_elapsed >= duration:
		_set_phase(_next_phase(_phase))


func _set_phase(value: StringName) -> void:
	_phase = value
	_phase_elapsed = 0.0
	_phase_progress = 0.0
	_arrival_fired = false
	_apply_phase_state()
	phase_changed.emit(_phase, _phase_duration(_phase))
	if _phase == &"warning" and _warning_audio and not RuntimeGlobals.runtime_audio_disabled():
		_warning_audio.play()
	elif _phase == &"high" and _arrival_audio and not RuntimeGlobals.runtime_audio_disabled():
		_arrival_audio.play()


func _next_phase(value: StringName) -> StringName:
	var index := PHASE_ORDER.find(value)
	if index < 0:
		return &"initial_dry"
	return PHASE_ORDER[(index + 1) % PHASE_ORDER.size()]


func _phase_duration(value: StringName) -> float:
	var timing := _profile.get("timing", {}) as Dictionary
	return float(timing.get(String(value), 1.0))


func _apply_phase_state() -> void:
	var level := _background_water_y()
	if _backdrop:
		_backdrop.set_tide_level(level, _phase, _phase_progress)
	var flood_alpha := _flood_alpha()
	if _flood_surface:
		_flood_surface.visible = flood_alpha > 0.002
	if _flood_material:
		_flood_material.set_shader_parameter("alpha_scale", flood_alpha)
	var draining_progress := _phase_progress if _phase == &"draining" else (1.0 if _phase in [&"initial_dry", &"warning", &"rising", &"high", &"falling", &"dry_hold"] else 1.0)
	var residue_visibility := 0.0
	if _phase == &"falling":
		residue_visibility = smoothstep(0.45, 1.0, _phase_progress)
		draining_progress = 0.0
	elif _phase == &"draining":
		residue_visibility = 1.0
	elif _phase == &"dry_hold":
		residue_visibility = 0.0
	_set_residue_progress(draining_progress, residue_visibility)
	if _shallow_water:
		_shallow_water.set_tide_phase(_phase, _phase_progress, level)
	_update_motion_modifiers()
	_update_warning()
	_update_danger_foam(flood_alpha)
	if _phase == &"high" and not _arrival_fired:
		_arrival_fired = true
		var game_feel := RuntimeGlobals.game_feel()
		if game_feel:
			game_feel.screen_shake(float((_profile.get("warning", {}) as Dictionary).get("arrival_camera_kick", 0.08)), 0.12)


func _background_water_y() -> float:
	var levels := _profile.get("levels", {}) as Dictionary
	var low := float(levels.get("background_low_y", -5.85))
	var high := float(levels.get("background_high_y", 1.06))
	match _phase:
		&"rising":
			return lerpf(low, high, smoothstep(0.0, 1.0, _phase_progress))
		&"high":
			return high
		&"falling":
			return lerpf(high, low, smoothstep(0.0, 1.0, _phase_progress))
	return low


func _flood_alpha() -> float:
	var phase_alpha := clampf(
		float(_review_tide_art.get("high_water_phase_alpha", 0.72)),
		0.0,
		1.0
	)
	match _phase:
		&"rising":
			return smoothstep(0.35, 1.0, _phase_progress) * phase_alpha
		&"high":
			return phase_alpha
		&"falling":
			return (1.0 - smoothstep(0.0, 0.48, _phase_progress)) * phase_alpha
	return 0.0


func _update_motion_modifiers() -> void:
	var active := _phase == &"high"
	for character in _characters:
		if not is_instance_valid(character):
			continue
		var should_apply := (
			active
			and not character.is_dead
			and not character.is_game_over
			and not character.is_scripted_traversal_active()
		)
		var key := character.get_instance_id()
		if bool(_motion_modifier_state.get(key, false)) == should_apply:
			continue
		if should_apply:
			character.set_environment_motion_modifier(
				MOTION_SOURCE,
				_gameplay_float("speed_multiplier", 0.90),
				_gameplay_float("horizontal_damp_multiplier", 1.25)
			)
		else:
			character.clear_environment_motion_modifier(MOTION_SOURCE)
		_motion_modifier_state[key] = should_apply


func _clear_motion_modifiers() -> void:
	for character in _characters:
		if is_instance_valid(character):
			character.clear_environment_motion_modifier(MOTION_SOURCE)
	_motion_modifier_state.clear()


func _gameplay_float(key: String, fallback: float) -> float:
	return float((_profile.get("gameplay", {}) as Dictionary).get(key, fallback))


func _all_characters() -> Array[BaseCharacter]:
	var result: Array[BaseCharacter] = []
	for character in _characters:
		if is_instance_valid(character) and character not in result:
			result.append(character)
	for node in get_tree().get_nodes_in_group("player"):
		if node is BaseCharacter and node not in result:
			result.append(node as BaseCharacter)
	return result


func _on_tree_node_added(node: Node) -> void:
	if not node is BaseCharacter:
		return
	call_deferred("_register_character", node)


func _register_character(node: Node) -> void:
	if not is_instance_valid(node) or not node is BaseCharacter:
		return
	var character := node as BaseCharacter
	if character not in _characters:
		_characters.append(character)
	character.clear_environment_motion_modifier(MOTION_SOURCE)
	_motion_modifier_state.erase(character.get_instance_id())
	if _shallow_water:
		_shallow_water.add_character(character)
	_update_motion_modifiers()


func _build_flood_surface() -> void:
	_flood_surface = MeshInstance3D.new()
	_flood_surface.name = "TideFloodPlatformSurface"
	_flood_surface.mesh = _platform_mesh()
	var surface_config := ((_profile.get("residue", {}) as Dictionary).get("surface", {}) as Dictionary).duplicate(true)
	_flood_material = WaterMaterials.create_surface(
		Color("#46D5E5"), 0.82, 0.16,
		float(surface_config.get("highlight_strength", 0.27)),
		float(surface_config.get("normal_strength", 0.68)),
		float(surface_config.get("specular", 0.44)), surface_config)
	_flood_surface.material_override = _flood_material
	_flood_surface.position.y = float((_profile.get("levels", {}) as Dictionary).get("visual_platform_water_y", 1.155))
	_flood_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flood_surface.set_meta("visual_only", true)
	add_child(_flood_surface)


func _platform_mesh() -> ArrayMesh:
	var points := PackedVector2Array()
	for pair: Variant in (_layout.get("platform", {}) as Dictionary).get("outline", []):
		var values := pair as Array
		points.append(Vector2(float(values[0]), float(values[1])))
	var triangles := Geometry2D.triangulate_polygon(points)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	for point in points:
		vertices.append(Vector3(point.x, 0.0, point.y))
		uvs.append(point * 0.025 + Vector2(0.5, 0.5))
		normals.append(Vector3.UP)
		tangents.append_array([1.0, 0.0, 0.0, 1.0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_INDEX] = triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_residue_visuals(width_scale: float) -> void:
	if _residue_root and is_instance_valid(_residue_root):
		_residue_root.free()
	_residue_root = Node3D.new()
	_residue_root.name = "TideResidueVisuals"
	_residue_root.set_meta("visual_only", true)
	add_child(_residue_root)
	_residue_materials.clear()
	_residue_mesh_instances.clear()
	_residue_bucket_cache.clear()
	var residue := _profile.get("residue", {}) as Dictionary
	var surface := residue.get("surface", {}) as Dictionary
	var wet_mat := WaterMaterials.create_wet_bed(
		Color(String(_review_tide_art.get("wet_bed_color", surface.get("wet_bed_color", "#4EB5C6")))),
		float(_review_tide_art.get("wet_bed_alpha", surface.get("wet_bed_alpha", 0.20))),
		float(_review_tide_art.get("wet_bed_roughness", surface.get("wet_bed_roughness", 0.42))), _review_tide_art)
	var water_mat := WaterMaterials.create_surface(
		Color(String(_review_tide_art.get("runoff_water_color", surface.get("water_color", "#78E0EC")))),
		float(_review_tide_art.get("runoff_water_alpha", surface.get("water_alpha", 0.27))),
		float(_review_tide_art.get("runoff_water_roughness", surface.get("water_roughness", 0.20))),
		float(_review_tide_art.get("runoff_highlight_strength", surface.get("highlight_strength", 0.27))),
		float(_review_tide_art.get("runoff_normal_strength", surface.get("normal_strength", 0.72))),
		float(_review_tide_art.get("runoff_specular", surface.get("specular", 0.42))), _review_tide_art)
	var rim_mat := WaterMaterials.create_meniscus(
		Color(String(_review_tide_art.get("meniscus_color", surface.get("meniscus_color", "#D2FBFC")))),
		float(_review_tide_art.get("meniscus_alpha", surface.get("meniscus_alpha", 0.62))),
		float(_review_tide_art.get("meniscus_roughness", 0.14)), _review_tide_art)
	_residue_materials.assign([wet_mat, water_mat, rim_mat])
	var wet := _residue_mesh_instance("TideResidueWetBed", wet_mat)
	var water := _residue_mesh_instance("TideResidueSurface", water_mat)
	var rim := _residue_mesh_instance("TideResidueMeniscus", rim_mat)
	_residue_mesh_instances.assign([wet, water, rim])
	_residue_root.add_child(wet)
	_residue_root.add_child(water)
	_residue_root.add_child(rim)
	# Drainage previously rebuilt geometry and materials in 36 runtime buckets,
	# causing 40-110 ms spikes. Build every deterministic shape once while the
	# map is loading; the live tide now swaps three cached Mesh resources only.
	for bucket in range(RESIDUE_BUCKET_COUNT + 1):
		_residue_bucket_cache[bucket] = _build_residue_bucket_data(bucket)
	_apply_residue_bucket(roundi(
		clampf(1.0 - width_scale, 0.0, 1.0) * float(RESIDUE_BUCKET_COUNT)
	))


func _residue_mesh_instance(node_name: String, material: ShaderMaterial) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta("visual_only", true)
	return instance


func _build_residue_bucket_data(bucket: int) -> Dictionary:
	var progress := clampf(float(bucket) / float(RESIDUE_BUCKET_COUNT), 0.0, 1.0)
	var width_scale := 1.0 - progress
	var visual_deck_y := float((_profile.get("levels", {}) as Dictionary).get("visual_deck_top_y", 1.12))
	var visual_residue_y := float((_profile.get("levels", {}) as Dictionary).get("visual_residue_water_y", 1.136))
	var residue_style := String(
		(_review_tide_art.get("residue_topology", {}) as Dictionary).get("style", "")
	)
	var review_puddles := (
		not _review_tide_art.is_empty()
		and residue_style in [
			"concept_aligned_area_puddles",
			"source_connected_clear_water",
		]
	)
	if review_puddles:
		var polygons: Array[PackedVector2Array] = ResidueShapes.build_puddle_polygons(
			_networks(), progress, _platform_polygon(), _residue_exclusions(), _review_tide_art)
		return {
			"wet": _mesh_from_temporary_layer(_puddle_layer("WetCache", polygons, 0.006, false)),
			"water": _mesh_from_temporary_layer(_puddle_layer(
				"WaterCache", polygons, visual_residue_y - visual_deck_y, false)),
			"rim": _mesh_from_temporary_layer(_puddle_layer(
				"RimCache", polygons, visual_residue_y - visual_deck_y + 0.006, true)),
			"coverage": ResidueShapes.coverage(polygons, _platform_polygon()),
			"topology": residue_style,
			"puddle_count": polygons.size(),
		}
	return {
		"wet": _mesh_from_temporary_layer(_residue_layer("WetCache", width_scale * 1.08, 0.006, false)),
		"water": _mesh_from_temporary_layer(_residue_layer(
			"WaterCache", width_scale, visual_residue_y - visual_deck_y, false)),
		"rim": _mesh_from_temporary_layer(_residue_layer(
			"RimCache", width_scale, visual_residue_y - visual_deck_y + 0.006, true)),
		"coverage": _estimate_residue_coverage(width_scale),
		"topology": "legacy_ribbons",
		"puddle_count": 0,
	}


func _mesh_from_temporary_layer(instance: MeshInstance3D) -> Mesh:
	var mesh := instance.mesh
	instance.free()
	return mesh


func _apply_residue_bucket(bucket: int) -> void:
	var clamped_bucket := clampi(bucket, 0, RESIDUE_BUCKET_COUNT)
	var data := _residue_bucket_cache.get(clamped_bucket, {}) as Dictionary
	if data.is_empty() or _residue_mesh_instances.size() != 3:
		return
	_residue_mesh_instances[0].mesh = data.get("wet") as Mesh
	_residue_mesh_instances[1].mesh = data.get("water") as Mesh
	_residue_mesh_instances[2].mesh = data.get("rim") as Mesh
	_residue_coverage = float(data.get("coverage", 0.0))
	_residue_root.set_meta("topology", String(data.get("topology", "legacy_ribbons")))
	_residue_root.set_meta("puddle_count", int(data.get("puddle_count", 0)))


func _puddle_layer(node_name: String, polygons: Array[PackedVector2Array], height: float, rim_only: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in polygons:
		if polygon.size() < 3:
			continue
		if rim_only:
			var center := ResidueShapes.centroid(polygon)
			var rim_width := float(_review_tide_art.get("meniscus_width", 0.065))
			for index in range(polygon.size()):
				var a := polygon[index]
				var b := polygon[(index + 1) % polygon.size()]
				var inset_a := a.move_toward(center, minf(rim_width, a.distance_to(center) * 0.10))
				var inset_b := b.move_toward(center, minf(rim_width, b.distance_to(center) * 0.10))
				_append_quad(st, a, b, inset_b, inset_a, height)
			continue
		var indices := Geometry2D.triangulate_polygon(polygon)
		for index_value in indices:
			var point := polygon[int(index_value)]
			st.set_normal(Vector3.UP)
			st.set_uv(point * 0.05)
			st.set_tangent(Plane(Vector3.RIGHT, 1.0))
			var deck_y := float((_profile.get("levels", {}) as Dictionary).get("visual_deck_top_y", 1.12))
			st.add_vertex(Vector3(point.x, deck_y + height, point.y))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = st.commit()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta("visual_only", true)
	return mesh_instance


func _residue_exclusions() -> Array:
	var clean := (_profile.get("residue", {}) as Dictionary).get("clean_zones", {}) as Dictionary
	return ResidueShapes.build_exclusions(_layout, clean)


func _residue_layer(node_name: String, width_scale: float, height: float, rim_only: bool) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for network_value: Variant in _networks():
		var network := network_value as Dictionary
		var points := network.get("points", []) as Array
		var samples := _sample_runoff_curve(points)
		var width_start := float(network.get("width_start", 4.0)) * width_scale
		var width_end := float(network.get("width_end", 1.5)) * width_scale
		var previous: Dictionary = {}
		for index in range(samples.size()):
			var point := samples[index]
			var t := float(index) / maxf(float(samples.size() - 1), 1.0)
			var before := samples[maxi(0, index - 1)]
			var after := samples[mini(samples.size() - 1, index + 1)]
			var tangent := (after - before).normalized()
			if tangent.length_squared() < 0.001:
				continue
			var normal := Vector2(-tangent.y, tangent.x)
			var seed := float(abs(String(network.get("id", "")).hash()) % 37)
			var width_noise := float(_review_tide_art.get("runoff_width_noise", 0.055))
			var irregularity := (
				1.0
				+ sin(t * 11.0 + seed * 0.31) * width_noise * 0.58
				+ sin(t * 27.0 + seed * 0.67) * width_noise * 0.42
			)
			var taper_start := clampf(float(_review_tide_art.get("runoff_branch_taper", 0.84)), 0.55, 0.94)
			var end_taper := 1.0 - smoothstep(taper_start, 1.0, t)
			var width := lerpf(width_start, width_end, t) * irregularity * end_taper * _clean_zone_factor(point)
			if width <= 0.05 or not Geometry2D.is_point_in_polygon(point, _platform_polygon()):
				previous.clear()
				continue
			var left := point - normal * width * 0.5
			var right := point + normal * width * 0.5
			if not previous.is_empty():
				if rim_only:
					_append_quad(st, previous["left"] - previous["normal"] * 0.09, previous["left"] + previous["normal"] * 0.09, left + normal * 0.09, left - normal * 0.09, height)
					_append_quad(st, previous["right"] - previous["normal"] * 0.09, previous["right"] + previous["normal"] * 0.09, right + normal * 0.09, right - normal * 0.09, height)
				else:
					_append_quad(st, previous["left"], previous["right"], right, left, height)
			previous = {"left": left, "right": right, "normal": normal}
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = st.commit()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.set_meta("visual_only", true)
	return mesh_instance


func _sample_runoff_curve(values: Array) -> PackedVector2Array:
	var controls := PackedVector2Array()
	for value: Variant in values:
		controls.append(_xz2(value as Array))
	var result := PackedVector2Array()
	if controls.size() < 2:
		return result
	for segment in range(controls.size() - 1):
		var p0 := controls[maxi(segment - 1, 0)]
		var p1 := controls[segment]
		var p2 := controls[segment + 1]
		var p3 := controls[mini(segment + 2, controls.size() - 1)]
		var subdivisions := maxi(4, ceili(p1.distance_to(p2) / 0.55))
		for step in range(subdivisions):
			var t := float(step) / float(subdivisions)
			result.append(_catmull_rom(p0, p1, p2, p3, t))
	result.append(controls[-1])
	return result


func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _append_ribbon_quad(st: SurfaceTool, a: Vector2, b: Vector2, width_a: float, width_b: float, height: float, rim_only: bool) -> void:
	var direction := (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x)
	if rim_only:
		for sign_variant: Variant in [-1.0, 1.0]:
			var sign_value := float(sign_variant)
			var edge_a: Vector2 = a + normal * width_a * 0.5 * sign_value
			var edge_b: Vector2 = b + normal * width_b * 0.5 * sign_value
			_append_quad(st, edge_a - normal * 0.09, edge_a + normal * 0.09, edge_b + normal * 0.09, edge_b - normal * 0.09, height)
		return
	_append_quad(st, a - normal * width_a * 0.5, a + normal * width_a * 0.5, b + normal * width_b * 0.5, b - normal * width_b * 0.5, height)


func _append_quad(st: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2, height: float) -> void:
	for point in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.set_uv(point * 0.05)
		st.set_tangent(Plane(Vector3.RIGHT, 1.0))
		var deck_y := float((_profile.get("levels", {}) as Dictionary).get("visual_deck_top_y", 1.12))
		st.add_vertex(Vector3(point.x, deck_y + height, point.y))


func _residue_point_allowed(point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(point, _platform_polygon()):
		return false
	var clean := (_profile.get("residue", {}) as Dictionary).get("clean_zones", {}) as Dictionary
	for marker_value: Variant in _layout.get("pickup_markers", []):
		if point.distance_to(_xz((marker_value as Dictionary).get("position", []) as Array)) < float(clean.get("ordinary_pickup_radius", 2.5)):
			return false
	var special := _layout.get("special_pickup_marker", {}) as Dictionary
	if point.distance_to(_xz(special.get("position", []) as Array)) < float(clean.get("special_pickup_radius", 3.5)):
		return false
	for spawn_value: Variant in _layout.get("spawns", []):
		if point.distance_to(_xz((spawn_value as Dictionary).get("position", []) as Array)) < float(clean.get("spawn_radius", 2.5)):
			return false
	for cover_value: Variant in _layout.get("covers", []):
		var cover := cover_value as Dictionary
		var size := cover.get("size", []) as Array
		var radius := maxf(float(size[0]), float(size[2])) * 0.5 + float(clean.get("cover_margin", 0.5))
		if point.distance_to(_xz(cover.get("position", []) as Array)) < radius:
			return false
	return true


func _clean_zone_factor(point: Vector2) -> float:
	var clean := (_profile.get("residue", {}) as Dictionary).get("clean_zones", {}) as Dictionary
	var factor := 1.0
	for marker_value: Variant in _layout.get("pickup_markers", []):
		factor = minf(factor, _distance_mask(point, _xz((marker_value as Dictionary).get("position", []) as Array), float(clean.get("ordinary_pickup_radius", 2.5))))
	var special := _layout.get("special_pickup_marker", {}) as Dictionary
	factor = minf(factor, _distance_mask(point, _xz(special.get("position", []) as Array), float(clean.get("special_pickup_radius", 3.5))))
	for spawn_value: Variant in _layout.get("spawns", []):
		factor = minf(factor, _distance_mask(point, _xz((spawn_value as Dictionary).get("position", []) as Array), float(clean.get("spawn_radius", 2.5))))
	for cover_value: Variant in _layout.get("covers", []):
		var cover := cover_value as Dictionary
		var size := cover.get("size", []) as Array
		var radius := maxf(float(size[0]), float(size[2])) * 0.5 + float(clean.get("cover_margin", 0.5))
		factor = minf(factor, _distance_mask(point, _xz(cover.get("position", []) as Array), radius))
	return factor


func _distance_mask(point: Vector2, center: Vector2, radius: float) -> float:
	return smoothstep(radius, radius + 1.1, point.distance_to(center))


func _set_residue_progress(progress: float, visibility: float) -> void:
	var clamped := clampf(progress, 0.0, 1.0)
	var bucket := roundi(clamped * float(RESIDUE_BUCKET_COUNT))
	if bucket != _last_residue_bucket:
		_last_residue_bucket = bucket
		_apply_residue_bucket(bucket)
	if _residue_root:
		_residue_root.visible = visibility > 0.002 and clamped < 0.999
		for material in _residue_materials:
			material.set_shader_parameter("alpha_scale", visibility)


func _estimate_residue_coverage(width_scale: float) -> float:
	var area := 0.0
	for value: Variant in _networks():
		var network := value as Dictionary
		var points := network.get("points", []) as Array
		var length := 0.0
		for index in range(points.size() - 1):
			length += _xz2(points[index] as Array).distance_to(_xz2(points[index + 1] as Array))
		area += length * (float(network.get("width_start", 4.0)) + float(network.get("width_end", 1.5))) * 0.5 * width_scale
	return area / maxf(absf(_polygon_area(_platform_polygon())), 1.0)


func _build_danger_foam() -> void:
	if _danger_foam and is_instance_valid(_danger_foam):
		_danger_foam.free()
	_danger_foam_material = null
	_danger_foam_base_alpha = 0.0
	_danger_foam = Node3D.new()
	_danger_foam.name = "HighTideDangerFoam"
	_danger_foam.set_meta("visual_only", true)
	add_child(_danger_foam)
	if _review_tide_art.is_empty():
		_build_legacy_danger_foam()
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foam_stride := maxi(
		2, int(_review_tide_art.get("danger_foam_stride", 7))
	)
	var foam_width := float(_review_tide_art.get("danger_foam_width", 0.22))
	var foam_material_scale := float(
		_review_tide_art.get("danger_foam_material_scale", 0.46)
	)
	var authored_paths_added := _append_authored_bay_foam(st, foam_width)
	if not authored_paths_added:
		_append_legacy_review_foam(st, foam_stride, foam_width)
	var foam := MeshInstance3D.new()
	foam.name = "HighTideDangerFoamBatch"
	foam.mesh = st.commit()
	var foam_color := Color(String(_review_tide_art.get("danger_foam_color", "#E8FEFF")))
	_danger_foam_base_alpha = (
		float(_review_tide_art.get("danger_foam_alpha", 0.82))
		* foam_material_scale
	)
	if authored_paths_added:
		var authored_material := StandardMaterial3D.new()
		authored_material.albedo_color = Color(foam_color, _danger_foam_base_alpha)
		authored_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		authored_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		authored_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		authored_material.roughness = 0.18
		authored_material.emission_enabled = true
		authored_material.emission = foam_color
		authored_material.emission_energy_multiplier = 0.12
		_danger_foam_material = authored_material
	else:
		_danger_foam_material = WaterMaterials.create_meniscus(
			foam_color,
			_danger_foam_base_alpha,
			0.16,
			_review_tide_art)
	_danger_foam_material.render_priority = 2
	foam.material_override = _danger_foam_material
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.set_meta("visual_only", true)
	foam.set_meta("authored_bay_foam", authored_paths_added)
	_danger_foam.add_child(foam)


func _append_authored_bay_foam(st: SurfaceTool, fallback_width: float) -> bool:
	if not bool(_review_tide_art.get("authored_bay_foam_enabled", false)):
		return false
	var path_values := _review_tide_art.get("authored_bay_foam_paths", []) as Array
	if path_values.is_empty():
		return false
	var subdivisions := maxi(
		2,
		int(_review_tide_art.get("authored_bay_foam_subdivisions", 5))
	)
	var base_width := float(
		_review_tide_art.get("authored_bay_foam_width", fallback_width)
	)
	var width_variation := float(
		_review_tide_art.get("authored_bay_foam_width_variation", 0.18)
	)
	var gap_period := maxi(
		0,
		int(_review_tide_art.get("authored_bay_foam_gap_period", 13))
	)
	var double_band := bool(
		_review_tide_art.get("authored_bay_foam_double_band", true)
	)
	var foam_height := float(
		_review_tide_art.get("authored_bay_foam_height", 0.08)
	)
	var global_segment := 0
	var any_segment := false
	for path_value: Variant in path_values:
		var raw_points := path_value as Array
		if raw_points.size() < 2:
			continue
		var points: Array[Vector2] = []
		for point_value: Variant in raw_points:
			var point_array := point_value as Array
			if point_array.size() >= 2:
				points.append(Vector2(float(point_array[0]), float(point_array[1])))
		if points.size() < 2:
			continue
		for section in range(points.size() - 1):
			var p0 := points[maxi(section - 1, 0)]
			var p1 := points[section]
			var p2 := points[section + 1]
			var p3 := points[mini(section + 2, points.size() - 1)]
			for subdivision in range(subdivisions):
				var t0 := float(subdivision) / float(subdivisions)
				var t1 := float(subdivision + 1) / float(subdivisions)
				var a := _catmull_rom(p0, p1, p2, p3, t0)
				var b := _catmull_rom(p0, p1, p2, p3, t1)
				var phase0 := float(global_segment) * 0.79 + float(section) * 1.31
				var phase1 := phase0 + 0.79
				var width0 := base_width * (
					1.0 + sin(phase0) * width_variation
				)
				var width1 := base_width * (
					1.0 + sin(phase1) * width_variation
				)
				var gap := gap_period > 0 and global_segment % gap_period == gap_period - 2
				if not gap:
					_append_ribbon_quad(st, a, b, width0, width1, foam_height, false)
					if double_band:
						var direction := (b - a).normalized()
						var normal := Vector2(-direction.y, direction.x)
						var offset := normal * (
							0.34 + sin(phase0 * 0.71) * 0.08
						)
						_append_ribbon_quad(
							st,
							a + offset,
							b + offset,
							width0 * 0.34,
							width1 * 0.34,
							foam_height + 0.006,
							false
						)
					any_segment = true
				global_segment += 1
	return any_segment


func _append_legacy_review_foam(
	st: SurfaceTool,
	foam_stride: int,
	foam_width: float
) -> void:
	for edge_value: Variant in [
		# The fourth value seats the foam on the water side of the yellow
		# boundary. Keeping it off the deck prevents a grey "paint stripe"
		# across the combat lane in the full-map camera.
		[Vector2(-21.5, -10.45), Vector2(21.5, -10.45), 34, -0.62],
		[Vector2(-20.5, 1.95), Vector2(20.5, 1.95), 32, 0.62],
		[Vector2(-52.0, 24.0), Vector2(-45.0, 24.0), 8, 0.58],
		[Vector2(45.0, 24.0), Vector2(52.0, 24.0), 8, 0.58],
	]:
		var edge := edge_value as Array
		var start := edge[0] as Vector2
		var finish := edge[1] as Vector2
		var segment_count := int(edge[2])
		var direction := (finish - start).normalized()
		var normal := Vector2(-direction.y, direction.x)
		for index in range(segment_count):
			# Sparse crests keep the yellow danger edge dominant. A dashed line
			# across the whole bay reads as floor paint, not foam.
			if index % foam_stride != mini(1, foam_stride - 1):
				continue
			var t0 := float(index) / float(segment_count)
			var t1 := float(index + 1) / float(segment_count)
			var wave0 := sin(t0 * TAU * 3.0 + start.x * 0.07) * 0.15 + sin(t0 * TAU * 7.0) * 0.05
			var wave1 := sin(t1 * TAU * 3.0 + start.x * 0.07) * 0.15 + sin(t1 * TAU * 7.0) * 0.05
			var water_side_offset := float(edge[3])
			var p0 := start.lerp(finish, t0) + normal * (water_side_offset + wave0)
			var p1 := start.lerp(finish, t1) + normal * (water_side_offset + wave1)
			var width0 := foam_width + sin(t0 * TAU * 5.0 + 0.8) * foam_width * 0.22
			var width1 := foam_width + sin(t1 * TAU * 5.0 + 0.8) * foam_width * 0.22
			_append_ribbon_quad(st, p0, p1, width0, width1, 0.052, false)


func _build_legacy_danger_foam() -> void:
	var foam_points: Array[Vector3] = []
	for edge_value: Variant in [
		[Vector3(-21.5, 1.16, -10.45), Vector3(21.5, 1.16, -10.45), 9],
		[Vector3(-20.5, 1.16, 1.95), Vector3(20.5, 1.16, 1.95), 9],
		[Vector3(-52.0, 1.16, 24.0), Vector3(-45.0, 1.16, 24.0), 3],
		[Vector3(45.0, 1.16, 24.0), Vector3(52.0, 1.16, 24.0), 3],
	]:
		var edge := edge_value as Array
		var start := edge[0] as Vector3
		var finish := edge[1] as Vector3
		var count := int(edge[2])
		for index in range(count):
			var t := (float(index) + 0.5) / float(count)
			var point := start.lerp(finish, t)
			point.x += sin(float(index) * 2.17 + start.x * 0.04) * 0.34
			point.z += sin(float(index) * 1.71 + start.x * 0.07) * 0.24
			foam_points.append(point)
	var foam_mesh := SphereMesh.new()
	foam_mesh.radius = 0.72
	foam_mesh.height = 0.14
	foam_mesh.radial_segments = 8
	foam_mesh.rings = 4
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = foam_points.size()
	for index in range(foam_points.size()):
		var scale_value := 0.72 + float(index % 5) * 0.11
		multimesh.set_instance_transform(index, Transform3D(Basis().scaled(Vector3(scale_value, 1.0, 0.48 + float(index % 3) * 0.10)), foam_points[index]))
	var foam := MultiMeshInstance3D.new()
	foam.name = "HighTideDangerFoamPuffs"
	foam.multimesh = multimesh
	foam.multimesh.mesh = foam_mesh
	foam.material_override = _legacy_foam_material(Color("#E8FEFF"), 0.86, 0.16)
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.set_meta("visual_only", true)
	_danger_foam.add_child(foam)


func _update_danger_foam(flood_alpha: float) -> void:
	if _danger_foam:
		_danger_foam.visible = flood_alpha > 0.12
	if _danger_foam_material:
		var visibility := smoothstep(0.12, 0.72, flood_alpha)
		if _danger_foam_material is ShaderMaterial:
			(_danger_foam_material as ShaderMaterial).set_shader_parameter(
				"alpha_scale",
				visibility
			)
		elif _danger_foam_material is StandardMaterial3D:
			var standard := _danger_foam_material as StandardMaterial3D
			var color := standard.albedo_color
			color.a = _danger_foam_base_alpha * visibility
			standard.albedo_color = color


func _legacy_foam_material(color: Color, alpha: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	color.a = alpha
	material.albedo_color = color
	material.roughness = roughness
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_warning_ui() -> void:
	_warning_layer = CanvasLayer.new()
	_warning_layer.name = "HighTideWarning"
	_warning_layer.layer = 42
	add_child(_warning_layer)
	_warning_banner = MATCH_EVENT_BANNER_SCENE.instantiate()
	_warning_banner.name = "HighTideCountdown"
	_warning_layer.add_child(_warning_banner)
	_warning_banner.call("set_placement", 1)
	_warning_banner.call("set_event", "涨潮", "离开低洼区", "TWIN BAYS", TOY_UI.GOLD, [], false)
	_warning_label = _warning_banner.call("get_title_label") as Label
	_warning_banner.call("hide_event", false)


func _build_phase_audio() -> void:
	_warning_audio = AudioStreamPlayer.new()
	_warning_audio.name = "TideWarningAudio"
	_warning_audio.stream = load("res://assets/audio/generated/maps/twin_bays/tide_warning.wav") as AudioStream
	_warning_audio.volume_db = -8.5
	add_child(_warning_audio)
	_arrival_audio = AudioStreamPlayer.new()
	_arrival_audio.name = "TideArrivalAudio"
	_arrival_audio.stream = load("res://assets/audio/generated/maps/twin_bays/tide_arrival.wav") as AudioStream
	_arrival_audio.volume_db = -6.0
	add_child(_arrival_audio)


func _update_warning() -> void:
	if _warning_banner == null:
		return
	if _phase != &"warning":
		_hide_warning()
		return
	var remaining := maxi(1, ceili(_phase_duration(&"warning") - _phase_elapsed))
	_warning_banner.call(
		"set_event",
		"涨潮  %d" % remaining,
		"离开低洼区",
		"TWIN BAYS",
		TOY_UI.GOLD,
		[],
		true
	)


func _hide_warning() -> void:
	if _warning_banner:
		_warning_banner.call("hide_event", true)


func _networks() -> Array:
	return (_profile.get("residue", {}) as Dictionary).get("networks", []) as Array


func _platform_polygon() -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Variant in (_layout.get("platform", {}) as Dictionary).get("outline", []):
		result.append(_xz2(value as Array))
	return result


func _xz(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[2])) if values.size() >= 3 else Vector2.INF


func _xz2(values: Array) -> Vector2:
	return Vector2(float(values[0]), float(values[1])) if values.size() >= 2 else Vector2.INF


func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(points.size()):
		var current := points[index]
		var next := points[(index + 1) % points.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5


func _active_motion_modifier_count() -> int:
	var count := 0
	for character in _all_characters():
		var debug := character.get_environment_motion_debug()
		if debug.get("sources", {}).has(MOTION_SOURCE):
			count += 1
	return count


func _water_master_material_count() -> int:
	var count := 1 if WaterMaterials.is_master_material(_flood_material) else 0
	for material in _residue_materials:
		if WaterMaterials.is_master_material(material):
			count += 1
	return count


func _water_materials_unified() -> bool:
	if not WaterMaterials.is_master_material(_flood_material):
		return false
	for material in _residue_materials:
		if not WaterMaterials.is_master_material(material):
			return false
	return not _residue_materials.is_empty()


func _count_collision_nodes(root: Node) -> int:
	var count := 1 if root is CollisionObject3D or root is CollisionShape3D or root is NavigationRegion3D or root is NavigationObstacle3D else 0
	for child in root.get_children():
		count += _count_collision_nodes(child)
	return count


func _mesh_vertex_count(root: Node) -> int:
	if root == null:
		return 0
	var count := 0
	if root is MeshInstance3D:
		var mesh := (root as MeshInstance3D).mesh
		if mesh:
			for surface_index in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(surface_index)
				count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for child in root.get_children():
		count += _mesh_vertex_count(child)
	return count


func _exit_tree() -> void:
	_clear_motion_modifiers()
