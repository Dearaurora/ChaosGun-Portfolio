extends Node
class_name TwinBaysArtV4Review

## Isolated full-map Art V4 bridge. It swaps only the collision-free foreground
## and applies profile-driven lighting; gameplay remains owned by the arena.

const FULL_REVIEW_SCENE_PATH := "res://assets/review/twin_bays_art_v4/candidate/twin_bays_art_v4_foreground.glb"

var _profile: Dictionary = {}
var _candidate: Node3D = null
var _replaced_visual_nodes := 0


func configure(arena: Node3D, art_profile: Dictionary) -> void:
	_profile = art_profile.duplicate(true)
	name = "TwinBaysArtV4Review"
	set_meta("review_only", true)
	set_meta("visual_only", true)
	var foreground := arena.get_node_or_null("ForegroundVisuals")
	if foreground == null:
		push_error("Art V4 review could not find ForegroundVisuals")
		return
	_replace_foreground(foreground)
	_apply_lighting(arena)


func get_debug_state() -> Dictionary:
	return {
		"configured": not _profile.is_empty(),
		"review_only": true,
		"full_map_foreground_loaded": _candidate != null,
		"replaced_visual_nodes": _replaced_visual_nodes,
		"collision_nodes": _count_collision_nodes(_candidate if _candidate else self),
		"candidate_id": String((_profile.get("review", {}) as Dictionary).get("candidate_id", "")),
	}


func _replace_foreground(foreground: Node) -> void:
	var packed := load(FULL_REVIEW_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Art V4 review foreground is missing: %s" % FULL_REVIEW_SCENE_PATH)
		return
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		push_error("Art V4 review foreground could not be instantiated")
		return
	for child in foreground.get_children():
		foreground.remove_child(child)
		child.free()
		_replaced_visual_nodes += 1
	candidate.name = "TwinBaysArtV4ReviewForeground"
	candidate.set_meta("visual_only", true)
	candidate.set_meta("review_only", true)
	foreground.add_child(candidate)
	_candidate = candidate


func _apply_lighting(arena: Node3D) -> void:
	var lighting := _profile.get("lighting", {}) as Dictionary
	var key := arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if key:
		var rotation := lighting.get("key_rotation_degrees", [-56.0, -38.0, -4.0]) as Array
		if rotation.size() >= 3:
			key.rotation_degrees = Vector3(float(rotation[0]), float(rotation[1]), float(rotation[2]))
		key.light_color = Color(String(lighting.get("key_color", "#FFE7C8")))
		key.light_energy = float(lighting.get("key_energy", 0.94))
		key.shadow_enabled = true
		key.shadow_blur = float(lighting.get("shadow_blur", 1.55))
		key.shadow_opacity = float(lighting.get("shadow_opacity", 0.72))

	var fill := arena.get_node_or_null("SplashCoolFill") as OmniLight3D
	if fill:
		fill.light_color = Color(String(lighting.get("fill_color", "#79DDF4")))
		fill.light_energy = float(lighting.get("fill_energy", 0.075))

	var environment_node := arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node == null or environment_node.environment == null:
		return
	var environment := environment_node.environment.duplicate(true) as Environment
	var sky := Sky.new()
	if environment.sky:
		sky = environment.sky.duplicate(true) as Sky
	var sky_material := ProceduralSkyMaterial.new()
	if sky.sky_material is ProceduralSkyMaterial:
		sky_material = sky.sky_material.duplicate(true) as ProceduralSkyMaterial
	sky_material.sky_top_color = Color(String(lighting.get("sky_top_color", "#229FC7")))
	sky_material.sky_horizon_color = Color(String(lighting.get("sky_horizon_color", "#8FE5EF")))
	sky_material.ground_bottom_color = Color(String(lighting.get("ground_bottom_color", "#006B89")))
	sky_material.ground_horizon_color = Color(String(lighting.get("ground_horizon_color", "#42BDD0")))
	sky.sky_material = sky_material
	environment.sky = sky
	environment.tonemap_exposure = float(lighting.get("exposure", 0.52))
	environment.adjustment_enabled = true
	environment.adjustment_brightness = float(lighting.get("brightness", 0.98))
	environment.adjustment_contrast = float(lighting.get("contrast", 1.105))
	environment.adjustment_saturation = float(lighting.get("saturation", 1.075))
	environment.ambient_light_color = Color(String(lighting.get("ambient_color", "#8FD8E4")))
	environment.ambient_light_energy = float(lighting.get("ambient_energy", 0.14))
	environment.ssao_enabled = true
	environment.ssao_radius = float(lighting.get("ssao_radius", 1.0))
	environment.ssao_intensity = float(lighting.get("ssao_intensity", 1.08))
	environment.ssao_power = float(lighting.get("ssao_power", 1.38))
	environment.glow_enabled = true
	environment.glow_intensity = float(lighting.get("glow_intensity", 0.14))
	environment.glow_strength = float(lighting.get("glow_strength", 0.46))
	environment.glow_bloom = float(lighting.get("glow_bloom", 0.015))
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
