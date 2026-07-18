extends SceneTree

## Frozen production contract for Momentum Circuit.
##
## Development runs intentionally do not require the player-facing map pool.
## The release wrapper supplies --require-map-pool=true only after every other
## gate has passed.

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const WHITEBOX_SCENE_PATH := "res://scenes/maps/momentum_circuit_whitebox.tscn"
const LAYOUT_PATH := "res://resources/maps/momentum_circuit_layout_v2.json"
const PRODUCTION_CONFIG_PATH := "res://resources/maps/momentum_circuit_production_v2.json"
const REQUIRED_LAYERS := [&"Gameplay", &"ForegroundVisuals", &"MechanismVFX", &"Backdrop"]
const EXPECTED_WEAPON_IDS := [&"ak_rifle", &"gatling", &"shotgun", &"smg", &"sniper"]
const EXPECTED_CLOUD_SPEED_A := 0.003
const EXPECTED_CLOUD_SPEED_B := -0.008
const FLOAT_EPSILON := 0.015
const CAMERA_PITCH_DEGREES := 37.4771817105026

var _failures: Array[String] = []
var _arena: Node3D = null
var _layout: Dictionary = {}
var _production_config: Dictionary = {}
var _layers: Dictionary = {}


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit Production Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	root.size = Vector2i(1536, 1024)

	_layout = _load_json_dictionary(LAYOUT_PATH)
	_production_config = _load_json_dictionary(PRODUCTION_CONFIG_PATH)
	_verify_frozen_source_contract()
	_verify_map_pool_policy()

	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene is missing: %s" % SCENE_PATH)
		await _finish()
		return
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load production scene: %s" % SCENE_PATH)
		await _finish()
		return

	var match_config := root.get_node_or_null("MatchConfig")
	if match_config != null:
		match_config.set("slots", [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		])

	_arena = packed.instantiate() as Node3D
	if _arena == null:
		_fail("Production scene root must be Node3D")
		await _finish()
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame

	_verify_layer_contract()
	_verify_collision_authority()
	_verify_layout_counts()
	_verify_surface_style()
	_verify_gameplay_collision_samples()
	_verify_gravity_controller()
	_verify_activators_and_anchors()
	_verify_camera_contract()
	_verify_weapon_contract()
	_verify_cloud_vortex()
	_verify_mechanism_vfx()

	await _finish()


func _verify_surface_style() -> void:
	print("\n--- Coverless Dark Deck Surface ---")
	var style := _production_config.get("surface_style", {}) as Dictionary
	var expected_colors := {
		"base_color": "#45445F",
		"inset_color": "#37364D",
		"seam_color": "#716B91",
		"static_rim_color": "#B7A8EA",
		"side_color": "#3C315F",
	}
	for key: String in expected_colors:
		if String(style.get(key, "")).to_upper() != String(expected_colors[key]).to_upper():
			_fail("surface_style.%s differs from locked palette" % key)
	if int(style.get("panel_count", 0)) != 14:
		_fail("Dark deck must define exactly 14 large-scale partitions")
	if float(style.get("metallic_max", 1.0)) > 0.03:
		_fail("Deck metallic maximum exceeds 0.03")
	if float(style.get("roughness_min", 0.0)) < 0.78 or float(style.get("roughness_max", 1.0)) > 0.84:
		_fail("Deck roughness must remain within 0.78-0.84")
	if float(style.get("static_rim_width", 0.0)) > 0.12:
		_fail("Static rim width exceeds 0.12 world units")
	if float(style.get("static_rim_emission", 1.0)) > 0.35:
		_fail("Static rim emission exceeds 0.35")
	var foreground: Node = _layers.get(&"ForegroundVisuals")
	if foreground == null:
		return
	var names: Array[String] = []
	var material_names: Array[String] = []
	for node in _walk(foreground):
		names.append(node.name.to_lower())
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh != null:
				for surface_index in range(mesh.get_surface_count()):
					var material := mesh.surface_get_material(surface_index)
					if material != null:
						material_names.append(material.resource_name.to_lower())
	for token in names + material_names:
		if token.contains("cover"):
			_fail("Foreground GLB contains prohibited cover object/material: %s" % token)
	var joined := " ".join(names + material_names)
	for required_token in ["decktop", "deckside", "deckseam", "staticrim"]:
		if not joined.contains(required_token):
			_fail("Foreground GLB is missing surface token: %s" % required_token)
	print("OK  14-partition matte deck, zero covers, and low-energy static rim")


func _verify_frozen_source_contract() -> void:
	print("\n--- Frozen Source Contract ---")
	if _layout.is_empty():
		_fail("Authoritative layout JSON is missing or invalid: %s" % LAYOUT_PATH)
		return
	if String(_layout.get("schema", "")) != "chaos_gun.momentum_circuit_layout":
		_fail("Unexpected authoritative layout schema")
	if int(_layout.get("version", -1)) != 2:
		_fail("Authoritative layout version must remain 2")
	_verify_array_count(_layout, "holes", 3)
	_verify_array_count(_layout, "covers", 0)
	_verify_array_count(_layout, "portals", 4)
	_verify_array_count(_layout, "shockwave_nodes", 3)
	_verify_array_count(_layout, "spawns", 4)
	var validation := _layout.get("validation", {}) as Dictionary
	if not bool(validation.get("passed", false)):
		_fail("Whitebox extraction validation is not marked passed")
	if float(validation.get("reconstruction_iou", 0.0)) < 0.95:
		_fail("Whitebox reconstruction IoU regressed below 0.95")
	if float(validation.get("visual_projection_iou", 0.0)) < 0.95:
		_fail("Whitebox visual projection IoU regressed below 0.95")

	if _production_config.is_empty():
		_fail("Production configuration is missing or invalid: %s" % PRODUCTION_CONFIG_PATH)
		return
	var layout_reference := String(_production_config.get("layout", _production_config.get("layout_path", "")))
	if not layout_reference.is_empty() and layout_reference != LAYOUT_PATH:
		_fail("Production config must reference the frozen whitebox layout")
	print("OK  one outer platform, three holes, zero covers, four anchors, three activator locations")


func _verify_map_pool_policy() -> void:
	print("\n--- Map Pool Policy ---")
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		return
	var require_map_pool := _argument_bool("--require-map-pool=", false)
	var maps: Array = match_config.MAPS
	var production_indices: Array[int] = []
	for index in range(maps.size()):
		var entry: Variant = maps[index]
		if entry is Array and (entry as Array).size() >= 2:
			var path := String((entry as Array)[1])
			if path == WHITEBOX_SCENE_PATH:
				_fail("Development whitebox must never be exposed in MatchConfig.MAPS")
			if path == SCENE_PATH:
				production_indices.append(index)
	if require_map_pool:
		if production_indices != [2]:
			_fail("Release mode requires Momentum Circuit exactly once at map index 2")
		elif String((maps[2] as Array)[0]) != "Momentum Circuit":
			_fail("Map index 2 must use display name Momentum Circuit")
		else:
			print("OK  released as map index 2")
	else:
		if not production_indices.is_empty() and production_indices != [2]:
			_fail("If present during development, Momentum Circuit must be unique at map index 2")
		print("OK  DevOnly policy: whitebox absent; production pool entry not required")


func _verify_layer_contract() -> void:
	print("\n--- Four-Layer Scene Contract ---")
	_layers.clear()
	for layer_name in REQUIRED_LAYERS:
		var layer := _arena.get_node_or_null(NodePath(String(layer_name)))
		if layer == null:
			_fail("Production scene root is missing direct child: %s" % layer_name)
		else:
			_layers[layer_name] = layer
			print("OK  direct layer: ", layer_name)


func _verify_collision_authority() -> void:
	print("\n--- Collision Authority ---")
	var gameplay: Node = _layers.get(&"Gameplay")
	if gameplay == null:
		return
	var gameplay_collision_count := _collision_nodes(gameplay).size()
	if gameplay_collision_count == 0:
		_fail("Gameplay must own authoritative platform collision")
	for layer_name in [&"ForegroundVisuals", &"MechanismVFX", &"Backdrop"]:
		var layer: Node = _layers.get(layer_name)
		if layer == null:
			continue
		var collisions := _collision_nodes(layer)
		if not collisions.is_empty():
			_fail("%s must be visual-only; found collision at %s" % [
				layer_name, _arena.get_path_to(collisions[0])
			])
		for node in _walk(layer):
			if node is Camera3D or node is Light3D:
				_fail("%s contains forbidden %s at %s" % [
					layer_name, node.get_class(), _arena.get_path_to(node)
				])
			var script := node.get_script() as Script
			if script != null and (
				script.resource_path.contains("/characters/")
				or script.resource_path.contains("/weapons/")
			):
				_fail("%s contains character/weapon runtime script: %s" % [
					layer_name, script.resource_path
				])
	for node in _walk(_arena):
		if not (node is CollisionObject3D or node is CollisionShape3D):
			continue
		if node == gameplay or gameplay.is_ancestor_of(node):
			continue
		_fail("Collision exists outside Gameplay: %s (%s)" % [
			_arena.get_path_to(node), node.get_class()
		])
	print("OK  Gameplay collision nodes=%d; all three visual layers are collision-free" % gameplay_collision_count)


func _verify_layout_counts() -> void:
	print("\n--- Production Layout Counts ---")
	var covers := _nodes_in_arena_group(&"momentum_circuit_cover")
	var spawns := _nodes_in_arena_group(&"momentum_circuit_spawn")
	if not covers.is_empty():
		_fail("Production Gameplay must expose zero momentum_circuit_cover nodes, got %d" % covers.size())
	if _arena.get_node_or_null("Gameplay/MomentumCircuitGeometry/Covers") != null:
		_fail("Production Gameplay must not create a Covers node")
	if spawns.size() != 4:
		_fail("Production Gameplay must expose exactly four momentum_circuit_spawn nodes, got %d" % spawns.size())
	if _arena.has_method("_get_spawn_points"):
		var runtime_spawns: Variant = _arena.call("_get_spawn_points")
		if not runtime_spawns is Array or (runtime_spawns as Array).size() != 4:
			_fail("Runtime spawn contract must expose four positions")
	else:
		_fail("Production arena does not expose _get_spawn_points")
	print("OK  zero covers and four spawn anchors")


func _verify_gameplay_collision_samples() -> void:
	print("\n--- Walkable Collision Samples ---")
	if _arena.get_world_3d() == null:
		_fail("Production arena has no World3D for collision sampling")
		return
	var gameplay: Node = _layers.get(&"Gameplay")
	var arena_surface := gameplay.find_child("ArenaSurface", true, false) if gameplay != null else null
	if arena_surface == null:
		_fail("Gameplay is missing authoritative ArenaSurface")
	else:
		var subtraction_count := 0
		for child in arena_surface.get_children():
			if child is CSGShape3D and int(child.get("operation")) == int(CSGShape3D.OPERATION_SUBTRACTION):
				subtraction_count += 1
		if subtraction_count != 3:
			_fail("ArenaSurface must preserve exactly three subtraction holes, got %d" % subtraction_count)
	var space := _arena.get_world_3d().direct_space_state
	for spawn_value: Variant in _layout.get("spawns", []):
		var spawn := spawn_value as Dictionary
		var position := _vector3_from_array(spawn.get("position_world", []))
		var query := PhysicsRayQueryParameters3D.create(
			position + Vector3.UP * 7.0,
			position + Vector3.DOWN * 7.0
		)
		query.collision_mask = 1
		query.collide_with_areas = false
		if space.intersect_ray(query).is_empty():
			_fail("Spawn has no authoritative gameplay floor: %s" % spawn.get("id", "?"))
	for hole_value: Variant in _layout.get("holes", []):
		var hole := hole_value as Dictionary
		var center_values := hole.get("center_world_xz", []) as Array
		if center_values.size() < 2:
			_fail("Hole has no center for collision sampling: %s" % hole.get("id", "?"))
			continue
		var center := Vector3(float(center_values[0]), 1.0, float(center_values[1]))
		var query := PhysicsRayQueryParameters3D.create(
			center + Vector3.UP * 7.0,
			center + Vector3.DOWN * 7.0
		)
		query.collision_mask = 1
		query.collide_with_areas = false
		if not space.intersect_ray(query).is_empty():
			_fail("Void center was filled by gameplay collision: %s" % hole.get("id", "?"))
	print("OK  four spawn floors collide and three void centers remain open")


func _verify_gravity_controller() -> void:
	print("\n--- Gravity Controller Contract ---")
	var controllers := _semantic_nodes(
		&"momentum_circuit_gravity_controller",
		["gravitycontroller"],
		[&"request_toggle", &"get_debug_state", &"get_character_context"]
	)
	if controllers.size() != 1:
		_fail("Production scene must contain exactly one gravity controller, got %d" % controllers.size())
		return
	var controller := controllers[0]
	for method_name in [&"request_toggle", &"get_debug_state", &"get_character_context", &"get_ai_movement_bias"]:
		if not controller.has_method(method_name):
			_fail("Gravity controller is missing public method: %s" % method_name)
	var debug := controller.call("get_debug_state") as Dictionary
	_expect_string(debug, "state", "idle", "initial controller state")
	_expect_int(debug, "direction", 0, "initial field direction")
	_expect_float_alias(debug, ["warning_seconds"], 1.25, "warning seconds")
	_expect_float_alias(debug, ["active_seconds"], 4.0, "active seconds")
	_expect_float_alias(debug, ["reversing_seconds", "reverse_warning_seconds"], 0.65, "reversing seconds")
	_expect_float_alias(debug, ["recovery_seconds"], 0.75, "recovery seconds")
	_expect_float_alias(debug, ["global_guard_seconds"], 0.75, "global guard")
	_expect_float_alias(debug, ["acceleration", "field_acceleration"], 28.0, "field acceleration")
	_expect_float_alias(debug, ["max_field_axis_speed", "max_contribution_speed"], 18.0, "environment contribution cap")
	_expect_float_alias(debug, ["corridor_x_min", "corridor_min_x"], 2.0, "corridor X minimum")
	_expect_float_alias(debug, ["corridor_y_min", "corridor_min_y"], -4.0, "corridor Y minimum")
	_expect_float_alias(debug, ["corridor_y_max", "corridor_max_y"], 7.0, "corridor Y maximum")
	_expect_float_alias(debug, ["anchor_outer_radius"], 5.5, "stabilizer outer radius")
	_expect_float_alias(debug, ["anchor_core_radius"], 2.75, "stabilizer core radius")
	_expect_float_alias(debug, ["anchor_clear_seconds"], 0.45, "stabilizer clear duration")
	print("OK  public API and all frozen gravity parameters")


func _verify_activators_and_anchors() -> void:
	print("\n--- Activators And Stabilizers ---")
	var activators := _semantic_nodes(
		&"momentum_circuit_gravity_activator",
		["gravityactivator", "gravitynode", "activator"],
		[&"apply_hit", &"get_debug_state"]
	)
	var anchors := _semantic_nodes(
		&"momentum_circuit_stabilizer_anchor",
		["stabilizeranchor", "stabilityanchor"],
		[&"get_stabilization_strength", &"contains_core"]
	)
	if activators.size() != 3:
		_fail("Production scene must contain exactly three shootable activators, got %d" % activators.size())
	if anchors.size() != 4:
		_fail("Production scene must contain exactly four stabilizer anchors, got %d" % anchors.size())
	for activator in activators:
		var debug := activator.call("get_debug_state") as Dictionary
		_expect_float_alias(debug, ["cooldown_seconds"], 8.0, "%s cooldown" % activator.name)
		if activator.has_signal(&"body_entered") and activator is Area3D:
			_fail("Shoot-only activator must not be an Area3D contact trigger: %s" % activator.name)
	for anchor in anchors:
		var debug: Dictionary = anchor.call("get_debug_state") if anchor.has_method("get_debug_state") else {}
		_expect_float_alias(debug, ["outer_radius"], 5.5, "%s outer radius" % anchor.name)
		_expect_float_alias(debug, ["core_radius"], 2.75, "%s core radius" % anchor.name)
		if anchor is Area3D:
			_fail("Stabilizer anchor must be sampled spatially, not act as a contact/teleport Area3D")
	print("OK  three shoot-only activators and four non-portal stabilizers")


func _verify_camera_contract() -> void:
	print("\n--- Shared Party Camera ---")
	var camera := _arena.find_child("GlobalCamera", true, false) as Camera3D
	if camera == null:
		_fail("Production scene is missing GlobalCamera")
		return
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_fail("GlobalCamera must use orthographic projection")
	var forward := -camera.global_basis.z.normalized()
	var horizontal := Vector2(forward.x, forward.z).length()
	var downward_pitch := rad_to_deg(atan2(-forward.y, horizontal))
	if absf(downward_pitch - CAMERA_PITCH_DEGREES) > 0.08:
		_fail("GlobalCamera downward pitch %.4f differs from %.4f" % [downward_pitch, CAMERA_PITCH_DEGREES])
	var director := _find_camera_director()
	if director == null:
		_fail("Production scene is missing shared party camera director")
		return
	var state: Dictionary = {}
	if _arena.has_method("get_runtime_camera_debug"):
		state = _arena.call("get_runtime_camera_debug") as Dictionary
	elif director.has_method("get_debug_state"):
		state = director.call("get_debug_state") as Dictionary
	_expect_node_float(director, state, ["initial_size", "_initial_size"], 84.0, "camera initial size")
	_expect_node_float(director, state, ["idle_overview_size", "_idle_overview_size"], 88.0, "camera idle size")
	_expect_node_float(director, state, ["min_size", "_min_size"], 56.0, "camera minimum size")
	_expect_node_float(director, state, ["max_size", "_max_size"], 104.0, "camera maximum size")
	print("OK  orthographic shared camera, standard pitch, 84/88/56/104 profile")


func _verify_weapon_contract() -> void:
	print("\n--- Weapon Spawn Contract ---")
	var spawner := _arena.find_child("WeaponSpawner", true, false)
	if spawner == null:
		_fail("Production scene is missing WeaponSpawner")
		return
	_expect_property_float(spawner, "initial_delay", 20.0)
	_expect_property_float(spawner, "stay_duration", 30.0)
	_expect_property_float(spawner, "respawn_cooldown", 10.0)
	if int(spawner.get("max_active_pickups")) != 1:
		_fail("WeaponSpawner max_active_pickups must be 1")
	var candidate_count := 0
	for key in ["custom_spawn_points", "random_spawn_points", "fixed_spawn_points"]:
		var value: Variant = spawner.get(key)
		if value is Array:
			candidate_count += (value as Array).size()
	if candidate_count != 4:
		_fail("WeaponSpawner must expose exactly four candidate points, got %d" % candidate_count)
	if spawner.has_method("get_spawn_pool_ids_debug"):
		var ids: Array[StringName] = []
		for raw_id: Variant in spawner.call("get_spawn_pool_ids_debug", "pooled"):
			ids.append(StringName(raw_id))
		var actual_set: Dictionary = {}
		var expected_set: Dictionary = {}
		for id in ids:
			actual_set[id] = true
		for id in EXPECTED_WEAPON_IDS:
			expected_set[id] = true
		if actual_set != expected_set:
			_fail("Weapon pool differs from the five normal weapons: %s" % str(ids))
	else:
		_fail("WeaponSpawner does not expose get_spawn_pool_ids_debug")
	print("OK  four candidates, max one pickup, 20/30/10 timing, five normal weapons")


func _verify_cloud_vortex() -> void:
	print("\n--- Counter-Rotating Cloud Vortex ---")
	var nodes := _semantic_nodes(
		&"momentum_circuit_cloud_vortex",
		["cloudvortex"],
		[&"get_debug_state"]
	)
	if nodes.size() != 1:
		_fail("Backdrop must contain exactly one cloud-vortex controller, got %d" % nodes.size())
		return
	var vortex := nodes[0]
	var backdrop: Node = _layers.get(&"Backdrop")
	if backdrop != null and not (vortex == backdrop or backdrop.is_ancestor_of(vortex)):
		_fail("Cloud vortex must live under Backdrop")
	var debug := vortex.call("get_debug_state") as Dictionary
	if int(debug.get("layer_count", -1)) != 2:
		_fail("Cloud vortex must expose exactly two rotating layers")
	_expect_float_alias(debug, ["layer_a_speed"], EXPECTED_CLOUD_SPEED_A, "cloud layer A angular speed", 0.00001)
	_expect_float_alias(debug, ["layer_b_speed"], EXPECTED_CLOUD_SPEED_B, "cloud layer B angular speed", 0.00001)
	if float(debug.get("layer_a_speed", 0.0)) * float(debug.get("layer_b_speed", 0.0)) >= 0.0:
		_fail("Cloud-vortex layers must rotate in opposing directions")
	if int(debug.get("collision_node_count", _collision_nodes(vortex).size())) != 0:
		_fail("Cloud vortex must contain no collision")
	if int(debug.get("shadow_caster_count", 0)) != 0:
		_fail("Cloud vortex must not cast shadows onto gameplay")
	if not bool(vortex.get_meta("visual_only", false)) and not bool(debug.get("visual_only", false)):
		_fail("Cloud vortex must declare visual_only=true")
	print("OK  two collision-free, shadow-free layers at +0.003 / -0.008 rad/s")


func _verify_mechanism_vfx() -> void:
	print("\n--- Mechanism VFX Contract ---")
	var nodes := _semantic_nodes(
		&"momentum_circuit_mechanism_vfx",
		["mechanismvfx"],
		[&"get_debug_state"]
	)
	if nodes.size() != 1:
		_fail("MechanismVFX must expose exactly one controller, got %d" % nodes.size())
		return
	var debug := nodes[0].call("get_debug_state") as Dictionary
	if not bool(debug.get("visual_only", nodes[0].get_meta("visual_only", false))):
		_fail("MechanismVFX controller must declare visual_only=true")
	if int(debug.get("activator_visual_count", -1)) != 3:
		_fail("MechanismVFX must render three activator visuals")
	if int(debug.get("anchor_visual_count", -1)) != 4:
		_fail("MechanismVFX must render four stabilizer visuals")
	if bool(debug.get("surface_fill_present", true)):
		_fail("Gravity presentation must not tint or fill the full right-side floor")
	if int(debug.get("literal_arrow_count", -1)) != 0:
		_fail("Gravity presentation must contain no literal floor-arrow meshes")
	if not bool(debug.get("static_deck_rim_present", false)):
		_fail("VFX debug state must report the independent static deck rim")
	if not bool(debug.get("dynamic_gravity_rim_separate", false)):
		_fail("Static deck rim and dynamic gravity chase must remain separate")
	if int(debug.get("boundary_cue_count", 0)) != 1:
		_fail("Gravity presentation must expose one thin corridor-boundary cue")
	if int(debug.get("flow_streak_count", 0)) <= 0:
		_fail("Gravity presentation must expose sparse directional flow streaks")
	if int(debug.get("rim_segment_count", 0)) <= 0:
		_fail("Gravity presentation must expose a right-side rim chase")
	if int(debug.get("audio_player_count", 0)) < 3:
		_fail("Gravity presentation must expose state, interaction, and stabilizer audio channels")
	print("OK  diegetic boundary/rim/flow cues, three activators, four stabilizers, no floor fill or arrows")


func _semantic_nodes(
	group_name: StringName,
	name_tokens: Array[String],
	required_methods: Array[StringName]
) -> Array[Node]:
	var result: Array[Node] = _nodes_in_arena_group(group_name)
	if not result.is_empty():
		return result
	for node in _walk(_arena):
		var has_methods := true
		for method_name in required_methods:
			if not node.has_method(method_name):
				has_methods = false
				break
		if not has_methods:
			continue
		var normalized := _normalize(String(node.name))
		var script := node.get_script() as Script
		if script != null:
			normalized += _normalize(script.resource_path)
		var matched := name_tokens.is_empty()
		for token in name_tokens:
			if normalized.contains(_normalize(token)):
				matched = true
				break
		if matched:
			result.append(node)
	return result


func _find_camera_director() -> Node:
	for node in _walk(_arena):
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with("party_shooter_camera_director.gd"):
			return node
		if _normalize(String(node.name)).contains("cameradirector") and node.has_method("configure"):
			return node
	return null


func _nodes_in_arena_group(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_nodes_in_group(group_name):
		if node == _arena or _arena.is_ancestor_of(node):
			result.append(node)
	return result


func _collision_nodes(search_root: Node) -> Array[Node]:
	var result: Array[Node] = []
	for node in _walk(search_root):
		if node is CollisionObject3D or node is CollisionShape3D:
			result.append(node)
	return result


func _walk(search_root: Node) -> Array[Node]:
	var result: Array[Node] = [search_root]
	for child in search_root.get_children():
		result.append_array(_walk(child))
	return result


func _expect_node_float(
	node: Node,
	debug: Dictionary,
	keys: Array[String],
	expected: float,
	label: String
) -> void:
	for key in keys:
		if debug.has(key):
			_compare_float(float(debug[key]), expected, label)
			return
		if _has_property(node, key):
			_compare_float(float(node.get(key)), expected, label)
			return
	_fail("Missing %s in camera director debug/property contract" % label)


func _expect_float_alias(
	dictionary: Dictionary,
	keys: Array[String],
	expected: float,
	label: String,
	tolerance: float = FLOAT_EPSILON
) -> void:
	for key in keys:
		if dictionary.has(key):
			_compare_float(float(dictionary[key]), expected, label, tolerance)
			return
	_fail("Missing debug key for %s (accepted keys: %s)" % [label, ", ".join(keys)])


func _expect_property_float(node: Node, key: String, expected: float) -> void:
	if not _has_property(node, key):
		_fail("%s is missing property %s" % [node.name, key])
		return
	_compare_float(float(node.get(key)), expected, "%s.%s" % [node.name, key])


func _expect_string(dictionary: Dictionary, key: String, expected: String, label: String) -> void:
	if String(dictionary.get(key, "")) != expected:
		_fail("%s differs: %s != %s" % [label, dictionary.get(key, "<missing>"), expected])


func _expect_int(dictionary: Dictionary, key: String, expected: int, label: String) -> void:
	if int(dictionary.get(key, -2147483648)) != expected:
		_fail("%s differs: %s != %d" % [label, dictionary.get(key, "<missing>"), expected])


func _compare_float(
	actual: float,
	expected: float,
	label: String,
	tolerance: float = FLOAT_EPSILON
) -> void:
	if not is_finite(actual) or absf(actual - expected) > tolerance:
		_fail("%s differs: %.6f != %.6f (tolerance %.6f)" % [label, actual, expected, tolerance])


func _has_property(node: Object, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _verify_array_count(dictionary: Dictionary, key: String, expected: int) -> void:
	var value: Variant = dictionary.get(key, null)
	if not value is Array or (value as Array).size() != expected:
		_fail("Authoritative layout %s count must remain %d" % [key, expected])


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _vector3_from_array(value: Variant) -> Vector3:
	if not value is Array or (value as Array).size() < 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


func _argument_bool(prefix: String, fallback: bool) -> bool:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with(prefix):
			continue
		var value := argument.trim_prefix(prefix).strip_edges().to_lower()
		if value in ["true", "1", "yes"]:
			return true
		if value in ["false", "0", "no"]:
			return false
	return fallback


func _normalize(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "")


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _arena != null and is_instance_valid(_arena):
		for node in _walk(_arena):
			if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
				node.stop()
		current_scene = null
		_arena.queue_free()
		await process_frame
		await process_frame
	root.set_meta("disable_runtime_audio", false)
	print("==================================================")
	if _failures.is_empty():
		print("RESULT momentum_circuit_production passed=true failures=0")
		print("[Momentum Circuit Production Verifier] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_production passed=false failures=%d" % _failures.size())
	print("[Momentum Circuit Production Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
