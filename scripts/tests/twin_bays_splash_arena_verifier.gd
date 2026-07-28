extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const WHITEBOX_SCENE_PATH := "res://scenes/maps/twin_bays_whitebox.tscn"
const OPEN_RINGOUT_SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"
const LAYOUT_PATH := "res://resources/maps/twin_bays_layout_v1.json"
const ART_PROFILE_PATH := "res://resources/maps/twin_bays_art_v4.json"
const ARENA_SCRIPT_PATH := "res://scripts/maps/twin_bays_splash_arena.gd"
const GENERATED_ASSET_DIR := "res://assets/models/generated/twin_bays_splash_arena_v4"
const GENERATED_MANIFEST_PATH := GENERATED_ASSET_DIR + "/twin_bays_splash_arena_v4_manifest.json"
const PRODUCTION_FOREGROUND_PATH := GENERATED_ASSET_DIR + "/twin_bays_splash_arena_v4_foreground.glb"
const PLAYER_SCENE_PATH := "res://scenes/characters/player.tscn"
const AI_SCENE_PATH := "res://scenes/characters/ai_character.tscn"
const HERO_ASSET_NAME := "HeroCharacterAsset"
const REQUIRED_LAYERS := [&"Gameplay", &"ForegroundVisuals", &"Backdrop", &"Portals"]
const REMOVED_CORNER_PILLARS := [
	&"WestBackCornerPillar",
	&"EastBackCornerPillar",
	&"WestFrontCornerPillar",
	&"EastFrontCornerPillar",
]
const RETIRED_PORTAL_TOWERS := [&"LeftPortalTower", &"RightPortalTower"]
const REMOVED_INNER_COVERS := [
	&"WestNorthCoverInner",
	&"EastNorthCoverInner",
	&"WestSouthCoverInner",
	&"EastSouthCoverInner",
]
const REMOVED_SOUTH_WALL_SECTIONS := [
	&"WestSouthOuterWall_00",
	&"EastSouthOuterWall_00",
]
const FORBIDDEN_FLOOR_TOKENS := [
	"floorwetmarks",
	"floorpuddles",
	"waterstain",
	"wetstain",
	"wetness",
	"puddle",
	"floorwater",
	"dampmask",
]

var _failures: Array[String] = []
var _layout: Dictionary = {}
var _arena: Node3D = null
var _layers: Dictionary = {}


func _initialize() -> void:
	print("==================================================")
	print("[Twin Bays Splash Arena Release Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	_layout = _load_json_dictionary(LAYOUT_PATH)
	_verify_layout_contract()
	_verify_art_v4_production_authority()
	_verify_player_map_policy()
	await _verify_shared_character_and_weapon_identity()
	_verify_generated_glbs()

	if not ResourceLoader.exists(SCENE_PATH):
		_fail("Production scene is missing: %s" % SCENE_PATH)
		await _finish()
		return

	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Could not load production scene: %s" % SCENE_PATH)
		await _finish()
		return

	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]

	_arena = packed_scene.instantiate() as Node3D
	if _arena == null:
		_fail("Production scene root must be Node3D")
		await _finish()
		return
	root.add_child(_arena)
	current_scene = _arena
	await process_frame
	await process_frame
	await physics_frame

	_verify_four_layer_contract()
	_verify_visual_layers_have_no_collision()
	_verify_scene_semantic_anchors()
	_verify_spawns_and_voids()
	_verify_corner_fall_openings()
	_verify_cover_visual_collision_alignment()
	_verify_dry_floor_contract()
	_verify_backdrop_contract()
	_verify_portal_visual_contract()
	_verify_portal_pair_contract()
	await _verify_runtime_teleport()

	await _finish()


func _verify_layout_contract() -> void:
	print("\n--- Frozen Layout Contract ---")
	if _layout.is_empty():
		_fail("Layout JSON is missing or invalid: %s" % LAYOUT_PATH)
		return
	if String(_layout.get("schema", "")) != "chaos_gun.twin_bays_layout":
		_fail("Unexpected layout schema")
	if int(_layout.get("version", -1)) != 1:
		_fail("Layout version must be 1")

	var platform: Dictionary = _layout.get("platform", {})
	var expected_counts := {
		"platform outline": [platform.get("outline", []), 116],
		"wall polylines": [_layout.get("walls", []), 4],
		"portal pipes": [_layout.get("portal_pipes", []), 2],
		"covers": [_layout.get("covers", []), 10],
		"spawns": [_layout.get("spawns", []), 4],
		"pickup markers": [_layout.get("pickup_markers", []), 4],
		"special pickup marker": [[_layout.get("special_pickup_marker", {})], 1],
		"portals": [_layout.get("portals", []), 2],
	}
	for label in expected_counts:
		var pair: Array = expected_counts[label]
		var entries: Array = pair[0]
		var expected: int = pair[1]
		if entries.size() != expected:
			_fail("Expected %d %s in layout, got %d" % [expected, label, entries.size()])
		else:
			print("OK  ", label, ": ", entries.size())

	for collection_name in ["walls", "portal_pipes", "covers", "spawns", "pickup_markers", "portals"]:
		var ids: Dictionary = {}
		for raw_entry in _layout.get(collection_name, []):
			var entry := raw_entry as Dictionary
			var id := String(entry.get("id", ""))
			if id.is_empty():
				_fail("Layout %s entry has no id" % collection_name)
			elif ids.has(id):
				_fail("Duplicate layout id %s in %s" % [id, collection_name])
			ids[id] = true
	if _layout.has("towers"):
		_fail("Retired portal tower collection must not remain in the layout")
	var pipe_ids: Array[String] = []
	var pipes_by_id: Dictionary = {}
	for raw_pipe in _layout.get("portal_pipes", []):
		var pipe := raw_pipe as Dictionary
		var pipe_id := String(pipe.get("id", ""))
		pipe_ids.append(pipe_id)
		pipes_by_id[pipe_id] = pipe
	pipe_ids.sort()
	if pipe_ids != ["left_portal_pipe", "right_portal_pipe"]:
		_fail("Layout must contain only the paired left and right portal pipes")
	for raw_portal in _layout.get("portals", []):
		var portal := raw_portal as Dictionary
		var pipe: Dictionary = pipes_by_id.get(String(portal.get("pipe_id", "")), {})
		if pipe.is_empty() or String(pipe.get("portal_id", "")) != String(portal.get("id", "")):
			_fail("Portal and pipe must reference each other: %s" % portal.get("id", "?"))
	_verify_mirrored_pipe_layout(pipes_by_id)

	var causeway: Dictionary = platform.get("causeway", {})
	if float(causeway.get("visible_width", 0.0)) < 12.0:
		_fail("Visible central route regressed below 12 world units")
	if float(causeway.get("safe_width", 0.0)) < 16.0:
		_fail("Safe central route regressed below 16 world units")


func _verify_mirrored_pipe_layout(pipes_by_id: Dictionary) -> void:
	var left: Dictionary = pipes_by_id.get("left_portal_pipe", {})
	var right: Dictionary = pipes_by_id.get("right_portal_pipe", {})
	if left.is_empty() or right.is_empty():
		return
	var left_path: Array = left.get("path", [])
	var right_path: Array = right.get("path", [])
	if left_path.size() != right_path.size():
		_fail("Portal pipe paths must have matching point counts")
		return
	for index in range(left_path.size()):
		var left_point := _vector3_from_array(left_path[index] as Array)
		var right_point := _vector3_from_array(right_path[index] as Array)
		var mirrored := Vector3(-left_point.x, left_point.y, left_point.z)
		if right_point.distance_to(mirrored) > 0.01:
			_fail("Portal pipe paths are not mirrored at point %d" % index)
	for key in ["outer_radius", "inner_radius", "collar_outer_radius", "collar_depth", "radial_segments", "water_entry_foam_radius"]:
		if left.get(key) != right.get(key):
			_fail("Portal pipe style parameter differs across sides: %s" % key)
	var left_entry := _vector3_from_array(left.get("water_entry_position", []) as Array)
	var right_entry := _vector3_from_array(right.get("water_entry_position", []) as Array)
	if right_entry.distance_to(Vector3(-left_entry.x, left_entry.y, left_entry.z)) > 0.01:
		_fail("Portal pipe water entry positions must be mirrored")
	if left_path.is_empty() or float((left_path[-1] as Array)[1]) >= left_entry.y:
		_fail("Portal pipe tail must continue below the background water surface")


func _verify_player_map_policy() -> void:
	print("\n--- Player Map Routing ---")
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config == null:
		_fail("MatchConfig autoload is missing")
		return
	var maps: Array = match_config.MAPS
	for entry in maps:
		if entry is Array and entry.size() >= 2 and String(entry[1]) == WHITEBOX_SCENE_PATH:
			_fail("Development whitebox is exposed in the player map list")
	if maps.is_empty() or maps[0].size() < 2 or String(maps[0][1]) != OPEN_RINGOUT_SCENE_PATH:
		_fail("Open Ring-Out must remain map index 0")
	else:
		print("OK  Open Ring-Out remains index 0")
	if maps.size() < 2 or maps[1].size() < 2 or String(maps[1][1]) != SCENE_PATH:
		_fail("Twin Bays Splash Arena must be map index 1 after release gates pass")
	else:
		print("OK  production Twin Bays is index 1")
	if int(match_config.selected_map_index) != 0:
		_fail("Initial local selector index must remain 0")
	match_config.select_default_playable_map()
	if String(match_config.get_selected_map_path()) != OPEN_RINGOUT_SCENE_PATH:
		_fail("Explicit index-0 selection no longer resolves to Open Ring-Out")
	else:
		print("OK  local selector index 0 remains Open Ring-Out")
	match_config.select_random_playable_map(1)
	if String(match_config.get_selected_map_path()) != SCENE_PATH:
		_fail("Quick AI random map pool no longer includes Twin Bays")
	else:
		print("OK  Quick AI random map pool includes Twin Bays")
	match_config.select_default_playable_map()


func _verify_shared_character_and_weapon_identity() -> void:
	print("\n--- Shared Character And Weapon Identity ---")
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var ai_scene := load(AI_SCENE_PATH) as PackedScene
	if player_scene == null or ai_scene == null:
		_fail("Shared player or AI scene is missing")
		return
	var holder := Node.new()
	holder.name = "SharedIdentityProbe"
	root.add_child(holder)
	var player := player_scene.instantiate()
	var ai := ai_scene.instantiate()
	holder.add_child(player)
	holder.add_child(ai)
	await process_frame
	await process_frame

	var player_visual := player.get_node_or_null("Visual")
	var ai_visual := ai.get_node_or_null("Visual")
	var player_weapons := player.get_node_or_null("WeaponManager")
	var ai_weapons := ai.get_node_or_null("WeaponManager")
	if player_visual == null or ai_visual == null or player_visual.get_script() != ai_visual.get_script():
		_fail("Player and AI must use the same CharacterVisual implementation")
	else:
		print("OK  shared CharacterVisual script")
	if player_weapons == null or ai_weapons == null or player_weapons.get_script() != ai_weapons.get_script():
		_fail("Player and AI must use the same WeaponManager implementation")
	else:
		print("OK  shared WeaponManager script")
	var player_asset := player.find_child(HERO_ASSET_NAME, true, false)
	var ai_asset := ai.find_child(HERO_ASSET_NAME, true, false)
	if player_asset == null or ai_asset == null:
		_fail("Player and AI must both instantiate HeroCharacterAsset")
	else:
		print("OK  shared HeroCharacterAsset runtime nodes")

	holder.queue_free()
	await process_frame


func _verify_generated_glbs() -> void:
	print("\n--- Generated GLB Contract ---")
	_verify_generated_manifest()
	var directory := DirAccess.open(GENERATED_ASSET_DIR)
	if directory == null:
		_fail("Generated Twin Bays asset directory is missing: %s" % GENERATED_ASSET_DIR)
		return
	var glb_paths: Array[String] = []
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.to_lower().ends_with(".glb"):
			glb_paths.append("%s/%s" % [GENERATED_ASSET_DIR, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
	glb_paths.sort()
	var has_hero := false
	var has_foreground := false
	for path in glb_paths:
		var lower_path := path.to_lower()
		has_hero = has_hero or lower_path.contains("hero")
		has_foreground = has_foreground or lower_path.contains("foreground")
		_verify_glb_runtime_texture_import(path)
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("Could not import generated GLB: %s" % path)
			continue
		var instance := packed.instantiate()
		if _find_disallowed_visual_node(instance) != null:
			_fail("Generated GLB contains collision/camera/light: %s (%s)" % [path, _find_disallowed_visual_node(instance).name])
		_verify_no_forbidden_floor_names(instance, "generated GLB %s" % path)
		if lower_path.contains("foreground"):
			_verify_foreground_glb_scope(instance, path)
			var material_count := _collect_unique_materials(instance).size()
			if material_count > 12:
				_fail("Foreground GLB exceeds 12 primary materials: %d" % material_count)
			else:
				print("OK  foreground material count: ", material_count)
		instance.free()
	if not has_hero:
		_fail("Generated directory has no Hero Kit GLB")
	if not has_foreground:
		_fail("Generated directory has no production foreground GLB")
	if has_hero and has_foreground:
		print("OK  Hero Kit and production foreground GLBs present")


func _verify_glb_runtime_texture_import(glb_path: String) -> void:
	var import_path := "%s.import" % glb_path
	if not FileAccess.file_exists(import_path):
		_fail("Generated GLB is missing its tracked runtime import contract: %s" % import_path)
		return
	var import_text := FileAccess.get_file_as_string(import_path)
	if not import_text.contains("gltf/embedded_image_handling=2"):
		_fail("Generated GLB must embed PBR textures as Basis Universal for bounded VRAM: %s" % glb_path)
		return
	print("OK  Basis Universal runtime texture import: ", glb_path.get_file())


func _verify_generated_manifest() -> void:
	var manifest := _load_json_dictionary(GENERATED_MANIFEST_PATH)
	if manifest.is_empty():
		_fail("Generated asset manifest is missing or invalid: %s" % GENERATED_MANIFEST_PATH)
		return
	if String(manifest.get("status", "")) != "approved_production":
		_fail("Twin Bays production manifest is not approved_production")
	if int(manifest.get("art_release_version", -1)) != 4:
		_fail("Twin Bays production manifest must declare Art V4")
	if String(manifest.get("candidate_id", "")) != "art_v4_convergence_01":
		_fail("Twin Bays production manifest candidate id is not the approved V4 candidate")
	if bool(manifest.get("legacy_art_v3_loaded", true)):
		_fail("Twin Bays production manifest permits legacy Art V3 loading")
	if int(manifest.get("material_count", -1)) != 8:
		_fail("Generated manifest must freeze eight primary materials")
	var production: Dictionary = manifest.get("production_foreground", {})
	var expected_anchor_count := _expected_production_anchor_count()
	if int(production.get("semantic_anchors", -1)) != expected_anchor_count:
		_fail("Production foreground manifest must record %d semantic anchors" % expected_anchor_count)
	var contracts: Dictionary = manifest.get("contracts", {})
	var expected_contracts := {
		"visual_only": true,
		"collision_in_glb": false,
		"camera_in_glb": false,
		"light_in_glb": false,
		"character_in_glb": false,
		"weapon_in_glb": false,
		"dynamic_portal_ring_in_glb": false,
		"floor_water_marks": false,
		"structure_frozen": true,
		"editable_blend_unbatched": true,
		"export_static_batched_by_material": true,
	}
	for contract_name in expected_contracts:
		if not contracts.has(contract_name) or contracts[contract_name] != expected_contracts[contract_name]:
			_fail("Generated manifest contract mismatch: %s" % contract_name)
	var semantic_anchors: Array = manifest.get("semantic_anchors", [])
	for removed_name in REMOVED_CORNER_PILLARS:
		if "Anchor_%s" % removed_name in semantic_anchors:
			_fail("Generated manifest still contains removed corner pillar: %s" % removed_name)
	for retired_name in RETIRED_PORTAL_TOWERS:
		if "Anchor_%s" % retired_name in semantic_anchors:
			_fail("Generated manifest still contains retired portal wall: %s" % retired_name)
	for removed_name in REMOVED_INNER_COVERS + REMOVED_SOUTH_WALL_SECTIONS:
		if "Anchor_%s" % removed_name in semantic_anchors:
			_fail("Generated manifest still contains removed gameplay geometry: %s" % removed_name)
	for collection_name in ["covers", "pickup_markers", "portal_pipes"]:
		for raw_entry in _layout.get(collection_name, []):
			var entry := raw_entry as Dictionary
			var expected_anchor := "Anchor_%s" % String(entry.get("node_name", ""))
			if expected_anchor not in semantic_anchors:
				_fail("Generated manifest missing semantic anchor: %s" % expected_anchor)
	var special_marker := _layout.get("special_pickup_marker", {}) as Dictionary
	var special_anchor := "Anchor_%s" % String(special_marker.get("node_name", ""))
	if special_anchor not in semantic_anchors:
		_fail("Generated manifest missing special pickup anchor: %s" % special_anchor)
	var outputs: Dictionary = manifest.get("outputs", {})
	var output_hashes: Dictionary = manifest.get("output_sha256", {})
	for output_name in ["blend", "hero_glb", "foreground_glb", "hero_preview", "foreground_preview"]:
		var relative_path := String(outputs.get(output_name, ""))
		var expected_hash := String(output_hashes.get(output_name, ""))
		var resource_path := "res://%s" % relative_path
		if relative_path.is_empty() or not FileAccess.file_exists(resource_path):
			_fail("Generated manifest output is missing: %s" % output_name)
		elif expected_hash.is_empty() or FileAccess.get_sha256(resource_path) != expected_hash:
			_fail("Generated manifest output hash mismatch: %s" % output_name)
	_verify_pbr_texture_manifest(manifest)
	_verify_export_consolidation(manifest)
	if int(manifest.get("material_count", -1)) == 8 and int(production.get("semantic_anchors", -1)) == expected_anchor_count:
		print("OK  manifest: %d production anchors, 8 materials, output hashes, visual-only contracts" % expected_anchor_count)


func _verify_art_v4_production_authority() -> void:
	print("\n--- Art V4 Production Authority ---")
	if not FileAccess.file_exists(ART_PROFILE_PATH):
		_fail("Twin Bays Art V4 profile is missing")
	if not FileAccess.file_exists(PRODUCTION_FOREGROUND_PATH):
		_fail("Twin Bays Art V4 production foreground is missing")
	if not FileAccess.file_exists(ARENA_SCRIPT_PATH):
		_fail("Twin Bays production arena script is missing")
		return
	var arena_script := FileAccess.get_file_as_string(ARENA_SCRIPT_PATH)
	if not arena_script.contains(PRODUCTION_FOREGROUND_PATH):
		_fail("Production arena does not load the approved Art V4 foreground")
	if not arena_script.contains(ART_PROFILE_PATH):
		_fail("Production arena does not load the approved Art V4 profile")
	var legacy_foreground := (
		"res://assets/models/generated/twin_bays_splash_arena/"
		+ "twin_bays_splash_arena_foreground.glb"
	)
	if arena_script.contains(legacy_foreground):
		_fail("Production arena still references the legacy Art V3 foreground")
	else:
		print("OK  production arena is locked to Art V4 and rejects Art V3 fallback")


func _verify_pbr_texture_manifest(manifest: Dictionary) -> void:
	var expected_resolutions := {
		"dry_cream": 2048,
		"cyan": 1024,
		"cyan_dark": 1024,
		"coral": 1024,
	}
	var texture_sets: Dictionary = manifest.get("pbr_texture_sets", {})
	if texture_sets.size() != expected_resolutions.size():
		_fail("Generated manifest must contain four deterministic PBR texture families")
		return
	for role in expected_resolutions:
		var texture_set: Dictionary = texture_sets.get(role, {})
		if texture_set.is_empty():
			_fail("Generated manifest is missing PBR texture family: %s" % role)
			continue
		if int(texture_set.get("resolution", -1)) != int(expected_resolutions[role]):
			_fail("PBR texture resolution mismatch for %s" % role)
		var maps: Dictionary = texture_set.get("maps", {})
		var hashes: Dictionary = texture_set.get("sha256", {})
		for map_name in ["albedo", "normal", "roughness"]:
			var relative_path := String(maps.get(map_name, ""))
			var expected_hash := String(hashes.get(map_name, ""))
			var resource_path := "res://%s" % relative_path
			if relative_path.is_empty() or not FileAccess.file_exists(resource_path):
				_fail("Missing %s map for PBR family %s" % [map_name, role])
			elif expected_hash.is_empty() or FileAccess.get_sha256(resource_path) != expected_hash:
				_fail("PBR texture hash mismatch: %s/%s" % [role, map_name])
			for token in FORBIDDEN_FLOOR_TOKENS:
				if _normalize(relative_path).contains(token):
					_fail("Forbidden dry-floor token in PBR texture path: %s" % relative_path)
	print("OK  deterministic PBR maps: dry floor 2K; aqua/side/coral 1K albedo-normal-roughness")


func _verify_export_consolidation(manifest: Dictionary) -> void:
	var consolidation: Dictionary = manifest.get("export_consolidation", {})
	var source_meshes := int(consolidation.get("foreground_source_meshes", -1))
	var export_meshes := int(consolidation.get("foreground_export_meshes", -1))
	var reduction := float(consolidation.get("foreground_mesh_reduction", -1.0))
	if source_meshes <= export_meshes or export_meshes <= 0:
		_fail("Foreground source must remain modular while export meshes are consolidated")
	elif export_meshes > 12:
		_fail("Foreground export exceeds the material batching ceiling: %d" % export_meshes)
	elif reduction <= 0.50:
		_fail("Foreground export consolidation must reduce mesh count by more than 50%%")
	else:
		print("OK  editable source %d meshes -> export %d meshes (%.1f%% reduction)" % [
			source_meshes, export_meshes, reduction * 100.0,
		])


func _expected_production_anchor_count() -> int:
	var wall_sections := 0
	for raw_wall in _layout.get("walls", []):
		wall_sections += (raw_wall as Dictionary).get("sections", []).size()
	return (
		2
		+ wall_sections
		+ _layout.get("portal_pipes", []).size()
		+ _layout.get("covers", []).size()
		+ _layout.get("pickup_markers", []).size()
		+ 1
		+ _layout.get("spawns", []).size()
		+ _layout.get("portals", []).size() * 2
	)


func _verify_foreground_glb_scope(instance: Node, path: String) -> void:
	for node in _walk(instance):
		var normalized := _normalize(String(node.name))
		for forbidden in ["watersurface", "background", "backdrop", "palm", "buoy", "floatring", "slideend", "portalglow"]:
			if normalized.contains(forbidden):
				_fail("Foreground GLB contains out-of-scope node %s in %s" % [node.name, path])


func _verify_four_layer_contract() -> void:
	print("\n--- Four-Layer Scene Contract ---")
	_layers.clear()
	for layer_name in REQUIRED_LAYERS:
		var layer := _arena.get_node_or_null(NodePath(String(layer_name)))
		if layer == null:
			_fail("Production scene root is missing direct child: %s" % layer_name)
		else:
			_layers[layer_name] = layer
			print("OK  direct layer: ", layer_name)
	var found_removed_pillar := false
	for removed_name in REMOVED_CORNER_PILLARS:
		if _arena.find_child(String(removed_name), true, false) != null:
			found_removed_pillar = true
			_fail("Production scene still contains removed corner pillar: %s" % removed_name)
	if not found_removed_pillar:
		print("OK  four non-portal corner pillars are absent")
	var found_retired_tower := false
	for retired_name in RETIRED_PORTAL_TOWERS:
		if _arena.find_child(String(retired_name), true, false) != null:
			found_retired_tower = true
			_fail("Production scene still contains retired portal wall/collision: %s" % retired_name)
	if not found_retired_tower:
		print("OK  old portal wall bodies and hidden collisions are absent")
	for removed_name in REMOVED_INNER_COVERS + REMOVED_SOUTH_WALL_SECTIONS:
		if _arena.find_child(String(removed_name), true, false) != null:
			_fail("Removed gameplay geometry remains in the production scene: %s" % removed_name)
	var found_synthetic_landing := false
	for node in _walk(_arena):
		if _normalize(String(node.name)).contains("portallanding"):
			found_synthetic_landing = true
			_fail("Synthetic portal landing must not remain: %s" % _arena.get_path_to(node))
	if not found_synthetic_landing:
		print("OK  no synthetic portal landing geometry or collision remains")


func _verify_visual_layers_have_no_collision() -> void:
	print("\n--- Visual-Only Layers ---")
	for layer_name in [&"ForegroundVisuals", &"Backdrop"]:
		var layer: Node = _layers.get(layer_name)
		if layer == null:
			continue
		var collision_node := _find_collision_node(layer)
		if collision_node:
			_fail("%s must be collision-free; found %s (%s)" % [layer_name, collision_node.name, collision_node.get_class()])
		else:
			print("OK  collision-free layer: ", layer_name)
	var gameplay: Node = _layers.get(&"Gameplay")
	if gameplay and _find_collision_node(gameplay) == null:
		_fail("Gameplay owns no collision; production art must not replace gameplay collision")
	elif gameplay:
		print("OK  Gameplay owns the physical collision")


func _verify_scene_semantic_anchors() -> void:
	print("\n--- Production Semantic Anchors ---")
	var foreground: Node = _layers.get(&"ForegroundVisuals")
	var gameplay: Node = _layers.get(&"Gameplay")
	if foreground == null or gameplay == null or _layout.is_empty():
		return

	for collection_name in ["covers", "pickup_markers", "portal_pipes"]:
		var found := 0
		for raw_entry in _layout.get(collection_name, []):
			var entry := raw_entry as Dictionary
			var visual_anchor := _find_layout_anchor(foreground, entry)
			if visual_anchor == null:
				_fail("ForegroundVisuals missing %s anchor: %s" % [collection_name, entry.get("node_name", entry.get("id", "?"))])
				continue
			found += 1
			var expected := _entry_position(entry)
			var tolerance := _anchor_tolerance(entry, collection_name)
			if _xz_distance((visual_anchor as Node3D).global_position, expected) > tolerance:
				_fail("Visual anchor %s drifts from layout: actual=%s expected=%s tolerance=%.3f" % [
					visual_anchor.name,
					(visual_anchor as Node3D).global_position,
					expected,
					tolerance,
				])
		if found == _layout.get(collection_name, []).size():
			print("OK  ", collection_name, " visual anchors: ", found)

	for raw_entry in _layout.get("covers", []):
		var entry := raw_entry as Dictionary
		if _find_layout_anchor(gameplay, entry) == null:
			_fail("Gameplay missing collision anchor for cover: %s" % entry.get("node_name", entry.get("id", "?")))

	for raw_entry in _layout.get("pickup_markers", []):
		var entry := raw_entry as Dictionary
		var marker := _find_layout_anchor(foreground, entry)
		if marker and _find_collision_node(marker):
			_fail("Pickup marker must remain open and collision-free: %s" % marker.name)
	var special_marker := _layout.get("special_pickup_marker", {}) as Dictionary
	var special_visual := _find_layout_anchor(foreground, special_marker)
	if special_visual == null:
		_fail("ForegroundVisuals missing special pickup marker anchor")
	elif _find_collision_node(special_visual):
		_fail("Special pickup marker must remain collision-free")
	elif not _has_ground_at(_entry_position(special_marker)):
		_fail("Special pickup marker is not grounded on the central causeway")
	else:
		print("OK  grounded collision-free center special pickup marker")


func _verify_spawns_and_voids() -> void:
	print("\n--- Spawn And Void Contract ---")
	if not _arena.has_method("_get_spawn_points"):
		_fail("Production map does not expose frozen spawn points")
		return
	var actual_spawns: Array = _arena.call("_get_spawn_points")
	var expected_spawns: Array = _layout.get("spawns", [])
	if actual_spawns.size() != 4:
		_fail("Production map must expose four spawns, got %d" % actual_spawns.size())
		return
	for index in range(mini(actual_spawns.size(), expected_spawns.size())):
		var actual := actual_spawns[index] as Vector3
		var expected := _entry_position(expected_spawns[index] as Dictionary)
		if actual.distance_to(expected) > 0.01:
			_fail("Spawn %d drifted by %.4f world units" % [index, actual.distance_to(expected)])
		if not _has_ground_at(actual):
			_fail("Spawn %d has no gameplay ground: %s" % [index, actual])
	if _failures.is_empty() or actual_spawns.size() == 4:
		print("OK  four frozen spawn positions inspected")

	for point in [Vector3(0, 5, -21), Vector3(0, 5, 21)]:
		if _has_ground_at(point):
			_fail("Lethal bay was filled with gameplay collision: %s" % point)
		else:
			print("OK  lethal bay remains open: ", point)
	for point in [Vector3(-22, 5, -4), Vector3(0, 5, -4), Vector3(22, 5, -4), Vector3(0, 5, -11.5), Vector3(0, 5, 3.5)]:
		if not _has_ground_at(point):
			_fail("Frozen safe-route sample has no gameplay ground: %s" % point)
func _verify_corner_fall_openings() -> void:
	print("\n--- Four Outward Corner Fall Openings ---")
	var opening_routes := {
		"north_west": {"center": Vector2(-37.75, -29.0), "outward": Vector2(0.0, -1.0)},
		"north_east": {"center": Vector2(37.75, -29.0), "outward": Vector2(0.0, -1.0)},
		"south_west": {"center": Vector2(-40.00, 27.30), "outward": Vector2(0.0, 1.0)},
		"south_east": {"center": Vector2(40.00, 27.30), "outward": Vector2(0.0, 1.0)},
	}
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	var space_state := _arena.get_world_3d().direct_space_state
	for opening_name in opening_routes:
		var route := opening_routes[opening_name] as Dictionary
		var center := route["center"] as Vector2
		var outward := route["outward"] as Vector2
		var start := center - outward * 5.5
		var finish := center + outward * 7.0
		var blocked := false
		if not _has_ground_at(Vector3(start.x, 5.0, start.y)):
			_fail("Outward fall path does not begin on gameplay ground: %s" % opening_name)
			continue
		if _has_ground_at(Vector3(finish.x, 5.0, finish.y)):
			_fail("Outward fall path does not finish over the void: %s" % opening_name)
			continue
		for sample_index in range(17):
			var weight := float(sample_index) / 16.0
			var sample := start.lerp(finish, weight)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis.IDENTITY, Vector3(sample.x, 2.5, sample.y))
			query.collision_mask = 1
			query.collide_with_areas = false
			query.collide_with_bodies = true
			if not space_state.intersect_shape(query, 8).is_empty():
				blocked = true
				break
		if blocked:
			_fail("Player-radius outward path is blocked at corner: %s" % opening_name)
		else:
			print("OK  player-radius outward fall path: ", opening_name)


func _verify_cover_visual_collision_alignment() -> void:
	print("\n--- Cover Visual / Collision Alignment ---")
	var foreground: Node = _layers.get(&"ForegroundVisuals")
	var gameplay: Node = _layers.get(&"Gameplay")
	if foreground == null or gameplay == null:
		return
	var passed := 0
	for raw_entry in _layout.get("covers", []):
		var entry := raw_entry as Dictionary
		var visual_anchor := _find_layout_anchor(foreground, entry) as Node3D
		var collision_anchor := _find_layout_anchor(gameplay, entry) as Node3D
		if visual_anchor == null or collision_anchor == null:
			continue
		var size_values: Array = entry.get("size", [])
		if size_values.size() < 3:
			_fail("Cover layout has no size: %s" % entry.get("id", "?"))
			continue
		var visual_footprint := absf(float(size_values[0]) * float(size_values[2]))
		var visual_scale := maxf(float(size_values[0]), float(size_values[2]))
		var center_delta := _xz_distance(visual_anchor.global_position, collision_anchor.global_position)
		if center_delta > visual_scale * 0.16:
			_fail("Cover center mismatch %s: %.3f > %.3f" % [entry.get("id", "?"), center_delta, visual_scale * 0.16])
			continue
		var collision_footprint := _largest_collision_footprint(collision_anchor)
		if collision_footprint <= 0.0:
			_fail("Cover collision footprint is unavailable: %s" % entry.get("id", "?"))
			continue
		var ratio := collision_footprint / maxf(visual_footprint, 0.001)
		if ratio < 0.72:
			_fail("Cover collision footprint below 72%% for %s: %.3f" % [entry.get("id", "?"), ratio])
			continue
		passed += 1
	if passed == _layout.get("covers", []).size():
		print("OK  %d covers within center/footprint tolerances" % passed)


func _verify_dry_floor_contract() -> void:
	print("\n--- Dry-Floor Veto ---")
	var foreground: Node = _layers.get(&"ForegroundVisuals")
	var gameplay: Node = _layers.get(&"Gameplay")
	if foreground:
		_verify_no_forbidden_floor_names(foreground, "ForegroundVisuals")
		_verify_no_forbidden_materials(foreground, "ForegroundVisuals")
		for node in _walk(foreground):
			if node is Decal:
				_fail("Gameplay foreground contains forbidden Decal: %s" % node.name)
	if gameplay:
		_verify_no_forbidden_floor_names(gameplay, "Gameplay")
		_verify_no_forbidden_materials(gameplay, "Gameplay")
		for node in _walk(gameplay):
			if node is Decal:
				_fail("Gameplay layer contains forbidden Decal: %s" % node.name)
	for exact_name in ["FloorWetMarks", "FloorPuddles"]:
		if _arena.find_child(exact_name, true, false):
			_fail("Forbidden wet-floor node exists anywhere in scene: %s" % exact_name)
	print("OK  dry-floor name/material/Decal scan complete")


func _verify_backdrop_contract() -> void:
	print("\n--- Backdrop Water Contract ---")
	var backdrop: Node = _layers.get(&"Backdrop")
	if backdrop == null:
		return
	var water_nodes: Array[Node3D] = []
	for node in _walk(backdrop):
		if node is Node3D and _normalize(String(node.name)).contains("water"):
			water_nodes.append(node as Node3D)
	if water_nodes.is_empty():
		_fail("Backdrop has no semantic water surface anchor")
		return
	var floor_y := float((_layout.get("platform", {}) as Dictionary).get("floor_top_y", 1.0))
	for water in water_nodes:
		if water.global_position.y >= floor_y - 1.0:
			_fail("Backdrop water must remain well below gameplay floor: %s y=%.3f" % [water.name, water.global_position.y])
	var dynamic_water := backdrop.find_child("DynamicBackgroundWater", true, false) as MeshInstance3D
	if dynamic_water == null:
		_fail("Backdrop is missing DynamicBackgroundWater")
	else:
		var plane := dynamic_water.mesh as PlaneMesh
		if plane == null:
			_fail("DynamicBackgroundWater must use a PlaneMesh")
		elif plane.size.x < 299.9 or plane.size.y < 299.9:
			_fail("Backdrop water must cover the shared diagonal camera footprint: %s" % plane.size)
		else:
			print("OK  backdrop water covers diagonal camera footprint: ", plane.size)
	print("OK  collision-free backdrop water remains below gameplay")


func _verify_portal_visual_contract() -> void:
	print("\n--- Portal Visual Contract ---")
	var portals_layer: Node = _layers.get(&"Portals")
	if portals_layer == null:
		return
	for portal_name in ["LeftPortal", "RightPortal"]:
		var portal := portals_layer.find_child(portal_name, true, false)
		if portal == null:
			_fail("Missing production portal: %s" % portal_name)
			continue
		var ring := _find_portal_ring(portal)
		if ring == null:
			_fail("Portal has no renderable vertical ring: %s" % portal_name)
			continue
		if absf(ring.global_basis.y.normalized().dot(Vector3.UP)) > 0.20:
			_fail("Portal ring must be vertical: %s" % portal_name)
		for material in _collect_unique_materials(portal).values():
			if material is BaseMaterial3D and bool((material as BaseMaterial3D).no_depth_test):
				_fail("Portal material disables depth testing: %s" % portal_name)
			if material is ShaderMaterial:
				var shader := (material as ShaderMaterial).shader
				if shader and shader.code.to_lower().contains("depth_test_disabled"):
					_fail("Portal shader disables depth testing: %s" % portal_name)
		print("OK  depth-tested vertical portal visual: ", portal_name)


func _verify_portal_pair_contract() -> void:
	print("\n--- Portal Gameplay Contract ---")
	var portals_layer: Node = _layers.get(&"Portals")
	if portals_layer == null:
		return
	var left := portals_layer.find_child("LeftPortal", true, false) as TwinBaysPortal
	var right := portals_layer.find_child("RightPortal", true, false) as TwinBaysPortal
	if left == null or right == null:
		_fail("Portal gameplay nodes must both use TwinBaysPortal")
		return
	if left.paired_portal != right or right.paired_portal != left:
		_fail("Production portals are not paired bidirectionally")
	if left.exit_marker == null or right.exit_marker == null:
		_fail("Production portal exit marker is missing")
		return
	for portal in [left, right]:
		if absf(portal.cooldown_seconds - 0.55) > 0.001:
			_fail("Portal cooldown must remain 0.55 s: %s" % portal.name)
		if portal.collision_layer != 0 or portal.collision_mask != 1:
			_fail("Portal collision filter must remain layer 0 / mask 1: %s" % portal.name)
		if not _has_ground_at(portal.exit_marker.global_position):
			_fail("Portal exit is not safely grounded: %s" % portal.name)
		_verify_portal_mount_access(portal)
	print("OK  paired character-only portal filters, exits, and cooldown")


func _verify_portal_mount_access(portal_node: TwinBaysPortal) -> void:
	var portal_id := "left_portal" if String(portal_node.name).begins_with("Left") else "right_portal"
	var portal_data: Dictionary = {}
	for raw_portal: Variant in _layout.get("portals", []):
		var candidate := raw_portal as Dictionary
		if String(candidate.get("id", "")) == portal_id:
			portal_data = candidate
			break
	if portal_data.is_empty():
		_fail("Canonical portal data is missing for mount access: %s" % portal_id)
		return
	var mouth := _entry_position(portal_data)
	var normal := _vector3_from_array(portal_data.get("normal", []))
	if normal.length_squared() <= 0.000001:
		_fail("Portal mount normal is degenerate: %s" % portal_id)
		return
	normal = normal.normalized()
	var tangent := Vector3(-normal.z, 0.0, normal.x)
	var safe := true
	for inward_distance_value: Variant in [7.0, 10.342, 12.0]:
		var inward_distance := float(inward_distance_value)
		for lateral_offset_value: Variant in [-3.0, 0.0, 3.0]:
			var lateral_offset := float(lateral_offset_value)
			var sample: Vector3 = mouth + normal * inward_distance + tangent * lateral_offset
			if not _has_ground_at(sample + Vector3.UP * 5.0):
				safe = false
				_fail("Portal approach leaves the original platform: %s distance=%.3f lateral=%.1f" % [
					portal_id, inward_distance, lateral_offset,
				])
			if _sphere_probe_hits_wall(sample):
				safe = false
				_fail("Player-radius portal approach intersects a hidden wall: %s distance=%.3f lateral=%.1f" % [
					portal_id, inward_distance, lateral_offset,
				])
	if safe:
		print("OK  original-platform portal approach is grounded and wall-free: ", portal_id)


func _sphere_probe_hits_wall(planar_position: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, Vector3(planar_position.x, 2.5, planar_position.z))
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for hit: Dictionary in _arena.get_world_3d().direct_space_state.intersect_shape(query, 64):
		var collider := hit.get("collider") as Node
		var cursor := collider
		for _depth in range(6):
			if cursor == null:
				break
			if _normalize(String(cursor.name)).contains("wall"):
				return true
			cursor = cursor.get_parent()
	return false


func _verify_runtime_teleport() -> void:
	print("\n--- Runtime Teleport / Anti-Ping-Pong ---")
	var portals_layer: Node = _layers.get(&"Portals")
	if portals_layer == null:
		return
	var left := portals_layer.find_child("LeftPortal", true, false) as TwinBaysPortal
	var right := portals_layer.find_child("RightPortal", true, false) as TwinBaysPortal
	if left == null or right == null or left.exit_marker == null or right.exit_marker == null:
		return

	var character := BaseCharacter.new()
	character.name = "TwinBaysReleasePortalProbe"
	character.can_sleep = false
	var body_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	body_shape.shape = sphere
	body_shape.position = Vector3(0, 1.5, 0)
	character.add_child(body_shape)
	_arena.add_child(character)
	character.gravity_scale = 0.0
	character.global_position = left.global_position
	character.linear_velocity = Vector3(-18, 3, 4)
	character.angular_velocity = Vector3(0, 5, 0)
	var camera_before := _arena.call("get_runtime_camera_debug") as Dictionary
	var camera_event_serial := int(camera_before.get("discontinuity_event_serial", 0))
	left.call("_on_body_entered", character)
	await process_frame
	await physics_frame
	if character.global_position.distance_to(right.exit_marker.global_position) > 0.08:
		_fail("Left-to-right teleport missed safe exit")
	elif character.linear_velocity.length() > 0.25 or character.angular_velocity.length() > 0.05:
		_fail("Portal failed to clear unsafe character momentum")
	else:
		print("OK  left-to-right safe exit and momentum clear")
	var camera_after_left := _arena.call("get_runtime_camera_debug") as Dictionary
	if int(camera_after_left.get("discontinuity_event_serial", 0)) != camera_event_serial + 1 \
		or String(camera_after_left.get("discontinuity_phase", "idle")) != "hold":
		_fail("Runtime portal did not start the camera safety transition")
	else:
		print("OK  runtime portal starts camera hold/safety framing")

	var before_rebound := character.global_position
	right.call("_on_body_entered", character)
	await process_frame
	if character.global_position.distance_to(before_rebound) > 0.08:
		_fail("Portal cooldown failed to prevent immediate ping-pong")
	else:
		print("OK  immediate ping-pong blocked")

	character.set_meta(&"twin_bays_portal_unlock_ms", 0)
	right.call("_on_body_entered", character)
	await process_frame
	await physics_frame
	if character.global_position.distance_to(left.exit_marker.global_position) > 0.08:
		_fail("Right-to-left teleport missed safe exit")
	else:
		print("OK  right-to-left teleport")
	var camera_after_right := _arena.call("get_runtime_camera_debug") as Dictionary
	if int(camera_after_right.get("discontinuity_event_serial", 0)) != camera_event_serial + 2:
		_fail("Reverse runtime portal event did not refresh the camera transition")
	else:
		print("OK  reverse portal refreshes one shared camera transition")
	character.queue_free()
	await process_frame


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _entry_position(entry: Dictionary) -> Vector3:
	var path_values: Array = entry.get("path", [])
	if not path_values.is_empty() and path_values[0] is Array:
		return _vector3_from_array(path_values[0] as Array)
	var values: Array = entry.get("position", [])
	return _vector3_from_array(values)


func _vector3_from_array(values: Array) -> Vector3:
	if values.size() < 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _anchor_tolerance(entry: Dictionary, collection_name: String) -> float:
	if collection_name in ["covers", "pickup_markers", "special_pickup_marker"]:
		var values: Array = entry.get("size", [])
		if values.size() >= 3:
			return maxf(float(values[0]), float(values[2])) * 0.16
	return 0.35


func _find_layout_anchor(search_root: Node, entry: Dictionary) -> Node3D:
	if search_root == null:
		return null
	var targets: Array[String] = []
	for key in ["node_name", "id"]:
		var value := _normalize(String(entry.get(key, "")))
		if not value.is_empty():
			targets.append(value)
	for node in _walk(search_root):
		if not node is Node3D:
			continue
		var candidate := _normalize(String(node.name))
		for target in targets:
			if candidate == target or candidate.ends_with(target):
				return node as Node3D
	return null


func _find_collision_node(search_root: Node) -> Node:
	for node in _walk(search_root):
		if node is CollisionObject3D or node is CollisionShape3D:
			return node
		if node is CSGShape3D and (node as CSGShape3D).use_collision:
			return node
	return null


func _find_disallowed_visual_node(search_root: Node) -> Node:
	for node in _walk(search_root):
		if node is CollisionObject3D or node is CollisionShape3D or node is Camera3D or node is Light3D:
			return node
		if node is CSGShape3D and (node as CSGShape3D).use_collision:
			return node
	return null


func _find_portal_ring(search_root: Node) -> MeshInstance3D:
	for node in _walk(search_root):
		if not node is MeshInstance3D:
			continue
		var normalized := _normalize(String(node.name))
		if normalized.contains("ring") or normalized.contains("portalglow"):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh:
				return mesh_instance
	return null


func _verify_no_forbidden_floor_names(search_root: Node, scope: String) -> void:
	for node in _walk(search_root):
		var normalized := _normalize(String(node.name))
		for token in FORBIDDEN_FLOOR_TOKENS:
			if normalized.contains(token):
				_fail("Forbidden wet-floor token '%s' in %s node %s" % [token, scope, node.name])


func _verify_no_forbidden_materials(search_root: Node, scope: String) -> void:
	for material in _collect_unique_materials(search_root).values():
		var material_text := "%s %s" % [material.resource_name, material.resource_path]
		if material is ShaderMaterial:
			var shader := (material as ShaderMaterial).shader
			if shader:
				material_text += " " + shader.code
		var normalized := _normalize(material_text)
		for token in FORBIDDEN_FLOOR_TOKENS:
			if normalized.contains(token):
				_fail("Forbidden wet-floor token '%s' in %s material %s" % [token, scope, material.resource_name])


func _collect_unique_materials(search_root: Node) -> Dictionary:
	var materials: Dictionary = {}
	for node in _walk(search_root):
		if not node is MeshInstance3D:
			continue
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index)
			if material:
				materials[material.get_instance_id()] = material
	return materials


func _largest_collision_footprint(search_root: Node) -> float:
	var largest := 0.0
	for node in _walk(search_root):
		if node is CSGBox3D and (node as CSGBox3D).use_collision:
			var csg_size := (node as CSGBox3D).size
			largest = maxf(largest, absf(csg_size.x * csg_size.z))
		elif node is CSGCylinder3D and (node as CSGCylinder3D).use_collision:
			var diameter := (node as CSGCylinder3D).radius * 2.0
			largest = maxf(largest, diameter * diameter)
		elif node is CollisionShape3D:
			var shape := (node as CollisionShape3D).shape
			largest = maxf(largest, _shape_footprint(shape))
	return largest


func _shape_footprint(shape: Shape3D) -> float:
	if shape == null:
		return 0.0
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return absf(size.x * size.z)
	if shape is CylinderShape3D:
		var diameter := (shape as CylinderShape3D).radius * 2.0
		return diameter * diameter
	if shape is SphereShape3D:
		var sphere_diameter := (shape as SphereShape3D).radius * 2.0
		return sphere_diameter * sphere_diameter
	if shape is CapsuleShape3D:
		var capsule_diameter := (shape as CapsuleShape3D).radius * 2.0
		return capsule_diameter * capsule_diameter
	if shape is ConvexPolygonShape3D:
		return _points_xz_footprint((shape as ConvexPolygonShape3D).points)
	if shape is ConcavePolygonShape3D:
		return _points_xz_footprint((shape as ConcavePolygonShape3D).get_faces())
	return 0.0


func _points_xz_footprint(points: PackedVector3Array) -> float:
	if points.is_empty():
		return 0.0
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for point in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
	return maxf(0.0, max_x - min_x) * maxf(0.0, max_z - min_z)


func _has_ground_at(position: Vector3) -> bool:
	var world := root.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(position.x, 8.0, position.z),
		Vector3(position.x, -6.0, position.z)
	)
	return not world.direct_space_state.intersect_ray(query).is_empty()


func _walk(search_root: Node) -> Array[Node]:
	var nodes: Array[Node] = []
	if search_root == null:
		return nodes
	nodes.append(search_root)
	for child in search_root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _normalize(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(".", "")


func _xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
	print("FAIL ", message)


func _finish() -> void:
	await _await_match_presentation_settled(_arena)
	if _arena and is_instance_valid(_arena):
		if current_scene == _arena:
			current_scene = null
		_arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[Twin Bays Splash Arena Release Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Twin Bays Splash Arena Release Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)


func _await_match_presentation_settled(arena: Node) -> void:
	if arena == null or not is_instance_valid(arena):
		return
	var presentation := arena.find_child("PartyShooterMatchPresentation", true, false)
	if presentation == null or not presentation.has_method("get_debug_state"):
		return
	var deadline_msec := Time.get_ticks_msec() + 1800
	while is_instance_valid(presentation) and Time.get_ticks_msec() < deadline_msec:
		var state := presentation.call("get_debug_state") as Dictionary
		if String(state.get("cue_state", "idle")) in ["idle", "complete", "result_ready"]:
			break
		await create_timer(0.05, true, false, true).timeout
	await process_frame
