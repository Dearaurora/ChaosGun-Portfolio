extends Node
class_name TwinBaysArtV3Review

## Review-only material, foreground and lighting bridge. Hero scope blends the
## approved material family into the north-east quadrant. Full-map scope swaps
## only the visual GLB for the isolated full candidate; gameplay stays Godot-owned.

const REVIEW_TEXTURE_ROOT := "res://assets/review/twin_bays_art_v3/textures/"
const FULL_REVIEW_SCENE_PATH := "res://assets/review/twin_bays_art_v3/full_map/twin_bays_art_v3_full_foreground.glb"

var _profile: Dictionary = {}
var _material_cache: Dictionary = {}
var _overridden_surfaces := 0
var _overridden_meshes := 0
var _scope: StringName = &"hero"
var _full_map_foreground_loaded := false
var _replaced_visual_nodes := 0
var _full_review_instance: Node3D = null


func configure(arena: Node3D, art_profile: Dictionary, scope: StringName = &"hero") -> void:
	_profile = art_profile.duplicate(true)
	_scope = scope
	name = "TwinBaysArtV3FullMapReview" if _scope == &"full_map" else "TwinBaysArtV3HeroReview"
	set_meta("review_only", true)
	set_meta("visual_only", true)
	set_meta("review_scope", _scope)
	var foreground := arena.get_node_or_null("ForegroundVisuals")
	if foreground == null:
		push_error("Art V3 review could not find ForegroundVisuals")
		return
	if _scope == &"full_map":
		_replace_with_full_map_candidate(foreground)
	else:
		_apply_material_overrides(foreground)
	_apply_review_lighting(arena)


func get_debug_state() -> Dictionary:
	var hero := _profile.get("hero_review", {}) as Dictionary
	return {
		"configured": not _profile.is_empty(),
		"review_only": true,
		"scope": String(_scope),
		"region": String(hero.get("region", "")),
		"world_x_min": float(hero.get("world_x_min", 10.0)),
		"world_z_max": float(hero.get("world_z_max", 1.5)),
		"blend_softness": float(hero.get("blend_softness", 2.5)),
		"overridden_meshes": _overridden_meshes,
		"overridden_surfaces": _overridden_surfaces,
		"shared_review_materials": _material_cache.size(),
		"full_map_foreground_loaded": _full_map_foreground_loaded,
		"replaced_visual_nodes": _replaced_visual_nodes,
		"collision_nodes": _count_collision_nodes(_full_review_instance if _full_review_instance else self),
	}


func _replace_with_full_map_candidate(foreground: Node) -> void:
	var packed := load(FULL_REVIEW_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Art V3 full-map review foreground is missing: %s" % FULL_REVIEW_SCENE_PATH)
		return
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		push_error("Art V3 full-map review foreground could not be instantiated")
		return
	for child in foreground.get_children():
		foreground.remove_child(child)
		child.free()
		_replaced_visual_nodes += 1
	candidate.name = "TwinBaysArtV3FullReviewForeground"
	candidate.set_meta("visual_only", true)
	candidate.set_meta("review_only", true)
	foreground.add_child(candidate)
	_full_review_instance = candidate
	_full_map_foreground_loaded = true


func _apply_material_overrides(root: Node) -> void:
	for node in _walk(root):
		if not node is MeshInstance3D:
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var touched := false
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface_index)
			if source == null:
				continue
			var role := _material_role(source.resource_name)
			if role.is_empty():
				continue
			mesh_instance.set_surface_override_material(surface_index, _review_material(role, source))
			_overridden_surfaces += 1
			touched = true
		if touched:
			_overridden_meshes += 1


func _material_role(material_name: String) -> String:
	var value := material_name.to_lower()
	if "drycream" in value:
		return "cream"
	if "cyandark" in value:
		return "cyan_shadow"
	if "coralsoft" in value:
		return "coral"
	if "cyan" in value and "portal" not in value:
		return "cyan"
	if "safetyyellow" in value:
		return "safety_yellow"
	if "pickuporange" in value:
		return "pickup_orange"
	if "portalrecess" in value:
		return "portal_recess"
	if "portalcyan" in value:
		return "portal_cyan"
	return ""


func _review_material(role: String, source: Material) -> ShaderMaterial:
	if _material_cache.has(role):
		return _material_cache[role] as ShaderMaterial
	var standard := source as StandardMaterial3D
	var material := ShaderMaterial.new()
	material.resource_name = "TBSA_ArtV3Review_%s" % role
	material.shader = _hero_blend_shader()
	var old_color := standard.albedo_color if standard else Color.WHITE
	var old_roughness := standard.roughness if standard else 0.65
	var old_albedo := standard.albedo_texture if standard and standard.albedo_texture else _solid_texture(Color.WHITE)
	var old_normal := standard.normal_texture if standard and standard.normal_texture else _solid_texture(Color(0.5, 0.5, 1.0, 1.0))
	var old_roughness_map := standard.roughness_texture if standard and standard.roughness_texture else _solid_texture(Color(old_roughness, old_roughness, old_roughness, 1.0))
	var new_albedo := _profile_texture(role, "albedo", _palette_color(role))
	var new_normal := _profile_texture(role, "normal", Color(0.5, 0.5, 1.0, 1.0))
	var new_roughness := _profile_texture(role, "roughness", Color(_profile_roughness(role), _profile_roughness(role), _profile_roughness(role), 1.0))
	var hero := _profile.get("hero_review", {}) as Dictionary
	material.set_shader_parameter("old_albedo_tex", old_albedo)
	material.set_shader_parameter("old_normal_tex", old_normal)
	material.set_shader_parameter("old_roughness_tex", old_roughness_map)
	material.set_shader_parameter("old_tint", old_color)
	material.set_shader_parameter("new_albedo_tex", new_albedo)
	material.set_shader_parameter("new_normal_tex", new_normal)
	material.set_shader_parameter("new_roughness_tex", new_roughness)
	material.set_shader_parameter("new_tint", Color.WHITE)
	material.set_shader_parameter("world_x_min", float(hero.get("world_x_min", 10.0)))
	material.set_shader_parameter("world_z_max", float(hero.get("world_z_max", 1.5)))
	material.set_shader_parameter("blend_softness", maxf(float(hero.get("blend_softness", 2.5)), 0.1))
	_material_cache[role] = material
	return material


func _hero_blend_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

uniform sampler2D old_albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D old_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D old_roughness_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 old_tint : source_color = vec4(1.0);
uniform sampler2D new_albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D new_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D new_roughness_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 new_tint : source_color = vec4(1.0);
uniform float world_x_min = 10.0;
uniform float world_z_max = 1.5;
uniform float blend_softness = 2.5;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x_mask = smoothstep(world_x_min - blend_softness, world_x_min + blend_softness, world_position.x);
	float z_mask = 1.0 - smoothstep(world_z_max - blend_softness, world_z_max + blend_softness, world_position.z);
	float hero_mask = x_mask * z_mask;
	vec3 old_albedo = texture(old_albedo_tex, UV).rgb * old_tint.rgb;
	vec3 new_albedo = texture(new_albedo_tex, UV).rgb * new_tint.rgb;
	ALBEDO = mix(old_albedo, new_albedo, hero_mask);
	NORMAL_MAP = mix(texture(old_normal_tex, UV).rgb, texture(new_normal_tex, UV).rgb, hero_mask);
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(texture(old_roughness_tex, UV).r, texture(new_roughness_tex, UV).r, hero_mask);
}
"""
	return shader


func _profile_texture(role: String, map_name: String, fallback: Color) -> Texture2D:
	if role in ["cream", "cyan", "cyan_shadow", "coral"]:
		var path := "%stbsa_%s_%s.png" % [REVIEW_TEXTURE_ROOT, _texture_role(role), map_name]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return _solid_texture(fallback)


func _texture_role(role: String) -> String:
	match role:
		"cream": return "dry_cream"
		"cyan_shadow": return "cyan_dark"
	return role


func _palette_color(role: String) -> Color:
	var palette := _profile.get("palette", {}) as Dictionary
	var key := role
	if role == "safety_yellow": key = "safety_yellow"
	if role == "pickup_orange": key = "pickup_orange"
	return Color(String(palette.get(key, "#FFFFFF")))


func _profile_roughness(role: String) -> float:
	var surfaces := _profile.get("surface_families", {}) as Dictionary
	if surfaces.has(role):
		return float((surfaces[role] as Dictionary).get("roughness", 0.55))
	return 0.46 if role in ["portal_cyan", "safety_yellow", "pickup_orange"] else 0.58


func _solid_texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _apply_review_lighting(arena: Node3D) -> void:
	var lighting := _profile.get("lighting", {}) as Dictionary
	var key := arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		key.light_color = Color(String(lighting.get("key_color", "#FFF0D7")))
		key.light_energy = float(lighting.get("key_energy", 0.82))
	var environment_node := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node and environment_node.environment:
		var environment := environment_node.environment.duplicate(true) as Environment
		environment.tonemap_exposure = float(lighting.get("exposure", 0.68))
		environment.adjustment_contrast = float(lighting.get("contrast", 1.055))
		environment.adjustment_saturation = float(lighting.get("saturation", 1.075))
		environment.ambient_light_color = Color(String(lighting.get("ambient_color", "#BDECF2")))
		environment.ambient_light_energy = float(lighting.get("ambient_energy", 0.22))
		environment.ssao_radius = float(lighting.get("ssao_radius", 0.82))
		environment.ssao_intensity = float(lighting.get("ssao_intensity", 0.78))
		environment_node.environment = environment


func _walk(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child in root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _count_collision_nodes(root: Node) -> int:
	var count := 0
	for node in _walk(root):
		if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D:
			count += 1
	return count
