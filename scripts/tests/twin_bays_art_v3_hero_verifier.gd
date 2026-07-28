extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const ART_PATH := "res://resources/maps/twin_bays_art_v3.json"
const REVIEW_MANIFEST_PATH := "res://assets/review/twin_bays_art_v3/twin_bays_art_v3_hero_review_manifest.json"
const POLICY_PATH := "res://resources/validation/twin_bays_verification_policy_v1.json"
const ReviewScript = preload("res://scripts/maps/twin_bays_art_v3_review.gd")

var _failed := false


func _initialize() -> void:
	var match_config := root.get_node_or_null("MatchConfig")
	if match_config:
		match_config.slots = [match_config.SlotType.EMPTY, match_config.SlotType.EMPTY, match_config.SlotType.EMPTY, match_config.SlotType.EMPTY]
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
	var manifest := _read_json(REVIEW_MANIFEST_PATH)
	var policy := _read_json(POLICY_PATH)
	_check(String(art.get("status", "")) == "hero_review_candidate", "Art V3 remains a candidate")
	_check(String(manifest.get("status", "")) == "hero_approved_full_map_pending", "Hero manifest records approval without releasing production")
	_check(not bool((manifest.get("contracts", {}) as Dictionary).get("golden_update_allowed", true)), "Golden update is locked")
	_check(bool((manifest.get("production_protection", {}) as Dictionary).get("byte_identical", false)), "production outputs are byte-identical")
	_check(_protected_hashes_match(manifest), "current production outputs still match the protected hashes")
	var gates := policy.get("human_approval_gates", {}) as Dictionary
	var hero_gate := gates.get("art_v3_hero_candidate", {}) as Dictionary
	_check(String(hero_gate.get("status", "")) == "approved", "human Hero gate is approved")
	_check(String(hero_gate.get("reviewed_layout_sha256", "")) == FileAccess.get_sha256("res://resources/maps/twin_bays_layout_v1.json").to_lower(), "Hero approval binds current layout")
	_check(String(hero_gate.get("reviewed_art_sha256", "")) == FileAccess.get_sha256(ART_PATH).to_lower(), "Hero approval binds current Art V3")
	_check(String(hero_gate.get("reviewed_tide_sha256", "")) == FileAccess.get_sha256("res://resources/maps/twin_bays_tide_v1.json").to_lower(), "Hero approval binds current Tide V1")

	var tide := arena.get_node_or_null("TwinBaysTideController") as TwinBaysTideController
	_check(tide != null, "tide controller exists")
	if tide:
		_check(tide.find_child("HighTideDangerFoamPuffs", true, false) != null, "production foam remains unchanged before review opt-in")
	var review := ReviewScript.new() as TwinBaysArtV3Review
	arena.add_child(review)
	review.configure(arena, art)
	var review_state := review.get_debug_state()
	_check(bool(review_state.get("configured", false)), "Hero review controller configured")
	_check(int(review_state.get("overridden_surfaces", 0)) > 0, "Hero review overrides production surfaces")
	_check(int(review_state.get("collision_nodes", -1)) == 0, "Hero review adds no collision or navigation")
	_check(int(review_state.get("shared_review_materials", 99)) <= 8, "Hero review materials remain shared")
	if tide:
		tide.apply_art_review_profile(art)
		tide.set_debug_phase(&"high", 0.5)
		var tide_state := tide.get_debug_state()
		_check(bool(tide_state.get("art_review_active", false)), "review tide art is active")
		_check(bool(tide_state.get("water_materials_unified", false)), "high tide and residue use the shared water material authority")
		_check(String(tide_state.get("water_master_shader_path", "")) == "res://assets/shaders/twin_bays_water_master.gdshader", "shared water shader is a precompiled project resource")
		_check(int(tide_state.get("water_master_material_count", 0)) >= 4, "flood and three residue layers are shared-master instances")
		_check(int(tide_state.get("transparent_batch_count", 99)) <= int((art.get("budgets", {}) as Dictionary).get("transparent_batch_max", 3)), "transparent review budget is respected")
		_check(is_equal_approx(float(tide_state.get("speed_multiplier", 0.0)), 0.90), "tide gameplay speed remains 0.90")
		_check(is_equal_approx(float(tide_state.get("damp_multiplier", 0.0)), 1.25), "tide gameplay damping remains 1.25")
		_check(tide.find_child("HighTideDangerFoamBatch", true, false) != null, "review uses one batched intermittent danger-foam mesh")
		tide.set_debug_phase(&"draining", 0.0)
		var drain_start := tide.get_debug_state()
		_check(bool(drain_start.get("water_materials_unified", false)), "drain visuals retain the shared lit water material")
		var start_puddles := int(drain_start.get("residue_puddle_count", 0))
		_check(String(drain_start.get("residue_topology", "")) == "concept_aligned_area_puddles", "drain review uses area-shaped puddles, not ribbons")
		_check(start_puddles >= 6, "drain start has a readable family of puddles and droplets")
		_check(float(drain_start.get("residue_coverage", 0.0)) >= 0.135 and float(drain_start.get("residue_coverage", 0.0)) <= 0.165, "drain start visual coverage remains near 15 percent")
		var shallow := tide.get("_shallow_water") as TwinBaysShallowWater
		_check(shallow != null, "review shallow-water interaction provider exists")
		if shallow:
			var shallow_start := shallow.get_debug_state()
			_check(String(shallow_start.get("residue_topology", "")) == "concept_aligned_area_puddles", "interaction query uses the same puddle topology")
			_check(int(shallow_start.get("residue_puddle_count", -1)) == start_puddles, "visible and interactive drain-start puddle counts match")
			_check(absf(float(shallow_start.get("residue_visual_query_coverage", -1.0)) - float(drain_start.get("residue_coverage", 0.0))) <= 0.001, "visible and interactive drain-start coverage matches")
		tide.set_debug_phase(&"draining", 0.5)
		var drain_mid := tide.get_debug_state()
		_check(float(drain_mid.get("residue_coverage", 0.0)) >= 0.065 and float(drain_mid.get("residue_coverage", 0.0)) <= 0.095, "drain midpoint visual coverage remains near 8 percent")
		_check(int(drain_mid.get("residue_puddle_count", 0)) != start_puddles, "drain topology changes its residual pool count by nine seconds")
	var backdrop := arena.find_child("SplashBackdropVisuals", true, false)
	_check(backdrop != null and backdrop.has_method("apply_art_review_profile"), "backdrop review bridge exists")
	if backdrop:
		backdrop.call("apply_art_review_profile", art)
		_check(bool(backdrop.get_meta("art_v3_review", false)), "backdrop review profile applied")

	for evidence_value: Variant in hero_gate.get("evidence", []):
		var evidence := "res://%s" % String(evidence_value)
		_check(FileAccess.file_exists(evidence), "evidence exists: %s" % evidence)
	var required_modes := (art.get("hero_review", {}) as Dictionary).get("required_modes", []) as Array
	_check(required_modes.size() == 5, "five Hero review states are required")
	# The production scene starts the shared READY/GO tween chain. Let that bounded
	# presentation complete before teardown so the verifier itself cannot leak it.
	await create_timer(1.40).timeout
	if tide:
		tide.stop_cycle()
	current_scene = null
	arena.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	_finish()


func _protected_hashes_match(manifest: Dictionary) -> bool:
	var protection := manifest.get("production_protection", {}) as Dictionary
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


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "JSON exists: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
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
		print("TWIN_BAYS_ART_V3_HERO_VERIFY_FAIL")
		quit(1)
	else:
		print("TWIN_BAYS_ART_V3_HERO_VERIFY_PASS")
		quit(0)
