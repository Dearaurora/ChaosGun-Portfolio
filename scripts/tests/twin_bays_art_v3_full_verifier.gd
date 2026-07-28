extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const ART_PATH := "res://resources/maps/twin_bays_art_v3.json"
const TIDE_PATH := "res://resources/maps/twin_bays_tide_v1.json"
const LAYOUT_PATH := "res://resources/maps/twin_bays_layout_v1.json"
const MANIFEST_PATH := "res://assets/review/twin_bays_art_v3/full_map/twin_bays_art_v3_full_manifest.json"
const POLICY_PATH := "res://resources/validation/twin_bays_verification_policy_v1.json"
const ReviewScript = preload("res://scripts/maps/twin_bays_art_v3_review.gd")

var _failed := false


func _initialize() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
			match_config.SlotType.EMPTY,
		]
	var packed := load(SCENE_PATH) as PackedScene
	var arena := packed.instantiate() as Node3D if packed else null
	_check(arena != null, "production arena instantiates")
	if arena == null:
		_finish()
		return
	root.add_child(arena)
	current_scene = arena
	await process_frame
	await process_frame

	var art := _read_json(ART_PATH)
	var manifest := _read_json(MANIFEST_PATH)
	var policy := _read_json(POLICY_PATH)
	var review_contract := manifest.get("review", {}) as Dictionary
	var gates := policy.get("human_approval_gates", {}) as Dictionary
	var hero_gate := gates.get("art_v3_hero_candidate", {}) as Dictionary
	var full_gate := gates.get("art_v3_full_map", {}) as Dictionary

	_check(String(hero_gate.get("status", "")) == "approved", "Hero gate is approved")
	_check(String(full_gate.get("status", "")) == "pending", "full-map gate remains pending")
	_check(String(hero_gate.get("reviewed_layout_sha256", "")) == FileAccess.get_sha256(LAYOUT_PATH).to_lower(), "Hero approval binds current layout")
	_check(String(hero_gate.get("reviewed_art_sha256", "")) == FileAccess.get_sha256(ART_PATH).to_lower(), "Hero approval binds current Art V3")
	_check(String(hero_gate.get("reviewed_tide_sha256", "")) == FileAccess.get_sha256(TIDE_PATH).to_lower(), "Hero approval binds current Tide V1")
	_check(String(manifest.get("layout_sha256", "")) == FileAccess.get_sha256(LAYOUT_PATH).to_lower(), "full candidate binds current layout")
	_check(String(manifest.get("art_profile_sha256", "")) == FileAccess.get_sha256(ART_PATH).to_lower(), "full candidate binds current Art V3")
	_check(String(manifest.get("tide_profile_sha256", "")) == FileAccess.get_sha256(TIDE_PATH).to_lower(), "full candidate binds current Tide V1")
	_check(String(review_contract.get("status", "")) == "candidate_pending_human_approval", "full candidate remains review-only")
	_check(bool(review_contract.get("golden_update_allowed", true)) == false, "Golden remains locked")
	_check(bool((review_contract.get("production_protection", {}) as Dictionary).get("byte_identical", false)), "production outputs are byte-identical")
	_check(_protected_hashes_match(review_contract), "current production files still match protected hashes")
	_check(int(manifest.get("material_count", 99)) <= 12, "full candidate respects material budget")
	var runtime_shaders := manifest.get("runtime_shaders", {}) as Dictionary
	for shader_name in ["shallow_water", "backdrop_water"]:
		var shader_record := runtime_shaders.get(shader_name, {}) as Dictionary
		var shader_path := "res://%s" % String(shader_record.get("path", ""))
		_check(FileAccess.file_exists(shader_path), "%s runtime shader exists" % shader_name)
		if FileAccess.file_exists(shader_path):
			_check(String(shader_record.get("sha256", "")) == FileAccess.get_sha256(shader_path).to_lower(), "%s runtime shader hash matches" % shader_name)
		_check(bool(shader_record.get("precompiled_project_resource", false)), "%s shader is precompiled" % shader_name)
	var foreground_stats := manifest.get("production_foreground", {}) as Dictionary
	_check(int(foreground_stats.get("mesh_objects", 99)) <= 12, "full foreground is batched by material")
	_check(int(foreground_stats.get("semantic_anchors", 0)) >= 33, "full foreground retains semantic anchors")
	var audit := manifest.get("geometry_audit", {}) as Dictionary
	_check(bool(audit.get("production_outline_covers_safe_collision", false)), "visible platform covers safe collision")
	_check(bool(audit.get("portal_mouths_mounted_on_platform", false)), "portal mouths remain mounted")
	_check(float(audit.get("south_wall_boundary_max_gap", 99.0)) <= 0.12, "south walls remain flush to boundary")

	var review := ReviewScript.new() as TwinBaysArtV3Review
	arena.add_child(review)
	review.configure(arena, art, &"full_map")
	var state := review.get_debug_state()
	_check(bool(state.get("full_map_foreground_loaded", false)), "full review foreground is active")
	_check(String(state.get("scope", "")) == "full_map", "review scope is full map")
	_check(int(state.get("replaced_visual_nodes", 0)) == 1, "one production visual layer was replaced")
	_check(int(state.get("collision_nodes", -1)) == 0, "full review GLB has no collision or navigation")
	var full_root := arena.find_child("TwinBaysArtV3FullReviewForeground", true, false)
	_check(full_root != null, "full review foreground exists in runtime tree")
	if full_root:
		_check(_count_nodes_of_type(full_root, "MeshInstance3D") == int(foreground_stats.get("mesh_objects", -1)), "runtime mesh count matches manifest")

	var tide := arena.get_node_or_null("TwinBaysTideController") as TwinBaysTideController
	_check(tide != null, "tide controller exists")
	if tide:
		tide.apply_art_review_profile(art)
		tide.set_debug_phase(&"high", 0.5)
		var tide_state := tide.get_debug_state()
		_check(bool(tide_state.get("water_materials_unified", false)), "full candidate uses unified water materials")
		_check(int(tide_state.get("transparent_batch_count", 99)) <= 3, "full candidate respects transparent batch budget")
		tide.set_debug_phase(&"draining", 0.0)
		var drain_state := tide.get_debug_state()
		_check(float(drain_state.get("residue_coverage", 0.0)) >= 0.135 and float(drain_state.get("residue_coverage", 0.0)) <= 0.165, "drain-start coverage remains near 15 percent")

	for evidence_value: Variant in full_gate.get("evidence", []):
		var evidence := "res://%s" % String(evidence_value)
		_check(FileAccess.file_exists(evidence), "full-map evidence exists: %s" % evidence)

	await create_timer(1.40).timeout
	if tide:
		tide.stop_cycle()
	current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	_finish()


func _protected_hashes_match(review_contract: Dictionary) -> bool:
	var protection := review_contract.get("production_protection", {}) as Dictionary
	var expected := protection.get("after", {}) as Dictionary
	if expected.is_empty():
		return false
	for relative_path: Variant in expected:
		var resource_path := "res://%s" % String(relative_path)
		if not FileAccess.file_exists(resource_path):
			return false
		if FileAccess.get_sha256(resource_path).to_lower() != String(expected[relative_path]).to_lower():
			return false
	return true


func _count_nodes_of_type(search_root: Node, type_name: String) -> int:
	var count := 1 if search_root.is_class(type_name) else 0
	for child in search_root.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_check(false, "JSON exists: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_check(false, "JSON parses: %s" % path)
		return {}
	return parsed as Dictionary


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK  ", label)
	else:
		_failed = true
		push_error("FAIL  %s" % label)


func _finish() -> void:
	if _failed:
		print("TWIN_BAYS_ART_V3_FULL_VERIFY_FAIL")
		quit(1)
	else:
		print("TWIN_BAYS_ART_V3_FULL_VERIFY_PASS")
		quit(0)
