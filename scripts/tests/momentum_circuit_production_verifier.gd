extends SceneTree

## Frozen production contract for Momentum Circuit.
##
## Development runs intentionally do not require the player-facing map pool.
## The release wrapper supplies --require-map-pool=true only after every other
## gate has passed.

const SCENE_PATH := "res://scenes/maps/momentum_circuit_arena.tscn"
const WHITEBOX_SCENE_PATH := "res://scenes/maps/momentum_circuit_whitebox.tscn"
const LAYOUT_PATH := "res://resources/maps/momentum_circuit_layout_v2.json"
const PRODUCTION_CONFIG_PATH := "res://resources/maps/momentum_circuit_production_v9.json"
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
	_verify_no_wind_controller()
	_verify_light_bridges()
	_verify_teleporters()
	_verify_camera_contract()
	_verify_weapon_contract()
	_verify_cloud_vortex()
	_verify_environment_dressing()
	_verify_hole_depth()
	_verify_mechanism_vfx()

	await _finish()


func _verify_surface_style() -> void:
	print("\n--- Coverless Dark Deck Surface ---")
	var style := _production_config.get("surface_style", {}) as Dictionary
	var expected_colors := {
		"base_color": "#3B3A52",
		"inset_color": "#211F32",
		"seam_color": "#252337",
		"static_rim_color": "#A998E3",
		"side_color": "#271C45",
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
	for token_group in [["decktop", "panelunit"], ["deckside", "sidewall"], ["deckseam", "seam"], ["staticrim"]]:
		var found := false
		for required_token in token_group:
			if joined.contains(required_token):
				found = true
		if not found:
			_fail("Foreground GLB is missing surface token: %s" % "/".join(token_group))
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
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var collider := hit.get("collider") as Node
			if collider == null or not collider.is_in_group(&"momentum_circuit_light_bridge_collision"):
				_fail("Void center was filled by non-bridge gameplay collision: %s" % hole.get("id", "?"))
	print("OK  four spawn floors collide; voids remain open except for the current light bridge")


func _verify_no_wind_controller() -> void:
	print("\n--- Standard Hole Fall Contract ---")
	var controllers := _nodes_in_arena_group(&"momentum_circuit_wind_controller")
	if not controllers.is_empty():
		_fail("Formal production scene must not contain a wind controller")
	for node in _walk(_arena):
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with("momentum_circuit_wind_field.gd"):
			_fail("Formal production scene must not instantiate momentum_circuit_wind_field.gd")
	print("OK  holes use the standard fall/respawn rule; no wind rescue")


func _verify_light_bridges() -> void:
	print("\n--- Rotating Light Bridge Contract ---")
	var controllers := _nodes_in_arena_group(&"momentum_circuit_light_bridge_controller")
	if controllers.size() != 1:
		_fail("Production scene must contain exactly one light-bridge controller, got %d" % controllers.size())
		return
	var controller := controllers[0]
	for method_name in [&"get_debug_state", &"test_step", &"test_scan_for_traversals", &"test_traversal_step", &"get_ai_movement_bias"]:
		if not controller.has_method(method_name):
			_fail("Light-bridge controller is missing %s" % method_name)
	var debug := controller.call("get_debug_state") as Dictionary
	if String(debug.get("state", "")) != "ACTIVE":
		_fail("Light bridges must start in ACTIVE")
	if String(debug.get("active_bridge_id", "")) != "bridge_hole_02":
		_fail("Opening bridge must be hole 2")
	if String(debug.get("next_bridge_id", "")) != "bridge_hole_01":
		_fail("Bridge order must begin hole 2 -> hole 1")
	if int(debug.get("bridge_count", 0)) != 3:
		_fail("Light-bridge controller must own three bridge specs")
	if (debug.get("collision_enabled_ids", []) as Array).size() != 1:
		_fail("Exactly one bridge must collide during ACTIVE")
	if not bool(debug.get("forced_traversal_enabled", false)):
		_fail("Light bridges must force safe centerline traversal")
	if absf(float(debug.get("traversal_speed", 0.0)) - 13.0) > FLOAT_EPSILON:
		_fail("Forced bridge traversal speed must be 13u/s")
	if absf(float(debug.get("bounce_speed", 0.0)) - 15.0) > FLOAT_EPSILON:
		_fail("Two-character bridge bounce speed must be 15u/s")
	var collision_bodies := _nodes_in_arena_group(&"momentum_circuit_light_bridge_collision")
	if collision_bodies.size() != 3:
		_fail("Gameplay must own exactly three light-bridge collision bodies, got %d" % collision_bodies.size())
	var bridge_config := _production_config.get("light_bridges", {}) as Dictionary
	if absf(float(bridge_config.get("active_seconds", 0.0)) - 8.0) > FLOAT_EPSILON:
		_fail("Light bridge stable duration must be 8 seconds")
	if absf(float(bridge_config.get("warning_seconds", 0.0)) - 2.0) > FLOAT_EPSILON:
		_fail("Light bridge warning duration must be 2 seconds")
	if absf(float(bridge_config.get("switching_seconds", 0.0)) - 0.45) > FLOAT_EPSILON:
		_fail("Light bridge switching duration must be 0.45 seconds")
	if not bool(bridge_config.get("forced_traversal_enabled", false)):
		_fail("Production bridge config must enable forced safe traversal")
	print("OK  three Gameplay bridges; fixed 8/2/0.45 cadence; safe forced crossing and two-player return")


func _verify_teleporters() -> void:
	print("\n--- Random Teleporter Contract ---")
	var teleporters := _nodes_in_arena_group(&"momentum_circuit_random_teleporter")
	if teleporters.size() != 4:
		_fail("Production scene must contain exactly four random teleporters, got %d" % teleporters.size())
	for teleporter in teleporters:
		if not teleporter.has_method("get_debug_state") or not teleporter.has_method("set_destinations") or not teleporter.has_method("test_step"):
			_fail("Teleporter missing random destination contract: %s" % teleporter.name)
		var debug := teleporter.call("get_debug_state") as Dictionary
		if absf(float(debug.get("landing_cooldown_seconds", 0.0)) - 3.0) > 0.001:
			_fail("Teleporter %s must use a 3-second landing-pad cooldown" % teleporter.name)
	print("OK  four cyan discs use random destinations and 3-second landing-pad cooldowns")


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


func _verify_environment_dressing() -> void:
	print("\n--- v9 Environment Dressing ---")
	var nodes := _nodes_in_arena_group(&"momentum_circuit_environment_dressing")
	if nodes.size() != 1:
		_fail("Backdrop must contain exactly one v9 environment dressing controller, got %d" % nodes.size())
		return
	var dressing := nodes[0]
	var backdrop: Node = _layers.get(&"Backdrop")
	if backdrop != null and not backdrop.is_ancestor_of(dressing):
		_fail("Environment dressing must live under Backdrop")
	if not dressing.has_method("get_debug_state"):
		_fail("Environment dressing must expose get_debug_state")
		return
	var debug := dressing.call("get_debug_state") as Dictionary
	if not bool(debug.get("configured", false)):
		_fail("Environment dressing did not configure its complete model library")
	if int(debug.get("version", 0)) != 9:
		_fail("Environment dressing must report version 9")
	if int(debug.get("background_layer_count", 0)) != 3:
		_fail("Environment dressing must expose far, mid, and ambient layers")
	if int(debug.get("model_family_count", 0)) != 10:
		_fail("Environment dressing must expose exactly ten low-poly model families")
	if int(debug.get("active_motion_system_count", 0)) != 1:
		_fail("Environment dressing must expose the low-poly ambient traffic motion system")
	if int(debug.get("ring_instance_count", -1)) != 0:
		_fail("Painted energy rings must not be duplicated by low-poly runtime stand-ins")
	if int(debug.get("traffic_route_count", 0)) != 3:
		_fail("Environment dressing must expose three ambient traffic loops")
	if int(debug.get("sensor_scan_count", -1)) != 0:
		_fail("Painted energy towers must not be covered by teleporter-like sensor scans")
	if int(debug.get("collision_node_count", -1)) != 0:
		_fail("Environment dressing must contain no collision")
	if int(debug.get("shadow_caster_count", -1)) != 0:
		_fail("Environment dressing must cast no shadows")
	if int(debug.get("camera_node_count", -1)) != 0:
		_fail("Environment dressing GLB/runtime must contain no cameras")
	if int(debug.get("light_node_count", -1)) != 0:
		_fail("Environment dressing GLB/runtime must contain no lights")
	var environment_config := _production_config.get("environment_dressing", {}) as Dictionary
	if int(environment_config.get("max_materials", 99)) > 5:
		_fail("Environment dressing exceeds its five-material budget")
	if int(environment_config.get("max_added_draw_calls", 999)) > 55:
		_fail("Environment dressing exceeds its added draw-call budget")
	print("OK  approved energy-array matte plus low-poly traffic, no collision/shadows")


func _verify_mechanism_vfx() -> void:
	print("\n--- Mechanism VFX Contract ---")
	var nodes := _semantic_nodes(
		&"momentum_circuit_mechanism_vfx",
		["rotatinglightbridgeandteleportvfx"],
		[&"get_debug_state"]
	)
	if nodes.size() != 1:
		_fail("MechanismVFX must expose exactly one controller, got %d" % nodes.size())
		return
	if not bool(nodes[0].get_meta("visual_only", false)):
		_fail("MechanismVFX controller must declare visual_only=true")
	var debug := nodes[0].call("get_debug_state") as Dictionary
	if int(debug.get("bridge_visual_count", 0)) != 3:
		_fail("MechanismVFX must render exactly three bridge surfaces")
	if int(debug.get("endpoint_socket_count", 0)) != 6:
		_fail("MechanismVFX must render exactly six embedded endpoint sockets")
	if int(debug.get("teleporter_visual_count", 0)) != 4:
		_fail("MechanismVFX must retain four teleporter pulse visuals")
	if int(debug.get("visual_version", 0)) != 7:
		_fail("MechanismVFX must use the v7 presentation")
	if int(debug.get("bridge_visual_layers", 0)) != 3:
		_fail("Every bridge must expose frame, energy core, and scan layers")
	if int(debug.get("cooldown_ring_segments", 0)) != 8:
		_fail("Teleporter cooldown presentation must use eight segments")
	if not bool(debug.get("teleport_trail_enabled", false)):
		_fail("Teleporter source-to-destination trail must be enabled")
	if int(debug.get("audio_player_count", 0)) != 3:
		_fail("MechanismVFX must expose bridge, event, and teleport spatial audio players")
	if int(debug.get("literal_arrow_count", -1)) != 0 or int(debug.get("text_node_count", -1)) != 0:
		_fail("Light-bridge presentation must contain no arrows or text")
	print("OK  v7 three-layer bridges, eight-segment pads, trails/audio, no arrows/text")


func _verify_hole_depth() -> void:
	print("\n--- Hole Depth Parallax ---")
	var node := _arena.get_node_or_null("Backdrop/HoleDepthParallax")
	if node == null or not node.has_method("get_debug_state"):
		_fail("Backdrop is missing the visual-only hole depth controller")
		return
	var debug := node.call("get_debug_state") as Dictionary
	if int(debug.get("hole_count", 0)) != 3:
		_fail("Hole depth presentation must cover all three holes")
	if int(debug.get("cloud_layer_count", 0)) != 6:
		_fail("Hole depth presentation must use two parallax layers per hole")
	if int(debug.get("inner_wall_layers", 0)) != 3:
		_fail("Hole depth contract must retain three inner-wall layers")
	if bool(debug.get("platform_plane_fall_effect", true)):
		_fail("No fall effect may exist at platform height")
	if int(debug.get("collision_node_count", -1)) != 0:
		_fail("Hole depth presentation must be collision-free")
	print("OK  three deep holes, six sub-deck cloud layers, no platform-plane fall effect")


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
