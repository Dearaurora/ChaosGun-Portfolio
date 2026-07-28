extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const PROFILE_PATH := "res://resources/maps/twin_bays_art_v5.json"
const MANIFEST_PATH := \
	"res://assets/review/twin_bays_art_v5/candidate/twin_bays_art_v5_manifest.json"
const REVIEW_SCRIPT = preload("res://scripts/maps/twin_bays_art_v5_review.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	print("[Twin Bays Art V5 Review Verifier]")
	var profile := _load_json(PROFILE_PATH)
	var manifest := _load_json(MANIFEST_PATH)
	_expect(int(profile.get("version", 0)) == 5, "profile declares Art V5")
	_expect(
		String(profile.get("status", "")) == "isolated_camera_target_candidate",
		"profile remains isolated"
	)
	var review := manifest.get("review", {}) as Dictionary
	var candidate_id := String((profile.get("review", {}) as Dictionary).get("candidate_id", ""))
	_expect(candidate_id == "art_v5_camera_convergence_01", "candidate id is frozen")
	_expect(String(review.get("candidate_id", "")) == candidate_id, "manifest binds candidate id")
	_expect(not bool(review.get("golden_update_allowed", true)), "candidate cannot update Golden")
	_expect(
		not bool(review.get("production_foreground_overwritten", true)),
		"candidate does not overwrite production"
	)
	var protection := review.get("production_protection", {}) as Dictionary
	_expect(bool(protection.get("byte_identical", false)), "V4 production protection passed")
	var protected_before := protection.get("before", {}) as Dictionary
	var protected_after := protection.get("after", {}) as Dictionary
	_expect(protected_before == protected_after, "protected V4 hashes are unchanged")
	for relative_path_variant: Variant in protected_after.keys():
		var relative_path := String(relative_path_variant)
		_expect(
			FileAccess.get_sha256("res://" + relative_path).to_lower()
				== String(protected_after[relative_path_variant]),
			"protected production hash: %s" % relative_path
		)
	_expect(
		String(manifest.get("layout_sha256", "")) == FileAccess.get_sha256(
			"res://resources/maps/twin_bays_layout_v1.json"
		).to_lower(),
		"manifest binds current layout"
	)
	_expect(
		String(manifest.get("art_profile_sha256", "")) == FileAccess.get_sha256(PROFILE_PATH).to_lower(),
		"manifest binds current Art V5 profile"
	)
	var outputs := manifest.get("outputs", {}) as Dictionary
	var output_hashes := manifest.get("output_sha256", {}) as Dictionary
	for role in ["hero_glb", "foreground_glb"]:
		var output_path := "res://" + String(outputs.get(role, ""))
		_expect(
			FileAccess.get_sha256(output_path).to_lower() == String(output_hashes.get(role, "")),
			"candidate output hash: %s" % role
		)
	_expect(int(manifest.get("material_count", 99)) <= 12, "candidate respects material budget")
	var visual_geometry := profile.get("visual_geometry", {}) as Dictionary
	_expect(
		bool(visual_geometry.get("wall_continuous_sweep", false)),
		"wall caps use continuous swept geometry"
	)
	_expect(
		not bool(visual_geometry.get("wall_cap_segment_cushions", true)),
		"modular wall-cap boxes are disabled"
	)
	_expect(
		bool(visual_geometry.get("wall_cap_visual_module_seams", false)),
		"continuous caps retain camera-readable module seams"
	)
	var surface_families := profile.get("surface_families", {}) as Dictionary
	var cyan_surface := surface_families.get("cyan", {}) as Dictionary
	var coral_surface := surface_families.get("coral", {}) as Dictionary
	_expect(
		String(cyan_surface.get("seam_axis", "")) == "horizontal",
		"cyan wall material forbids square tile grids"
	)
	_expect(
		String(coral_surface.get("seam_axis", "")) == "none",
		"coral soft cap material is seamless"
	)
	var geometry_audit := manifest.get("geometry_audit", {}) as Dictionary
	var wall_contract := geometry_audit.get("wall_visual_contract", {}) as Dictionary
	var expected_wall_sections := int(wall_contract.get("expected_section_count", -1))
	_expect(bool(wall_contract.get("enabled", false)), "manifest binds continuous wall contract")
	_expect(
		int(wall_contract.get("continuous_cap_count", -1)) == expected_wall_sections,
		"every wall section has one continuous soft cap"
	)
	_expect(
		int(wall_contract.get("smoothed_body_count", -1)) == expected_wall_sections,
		"every wall section has a smoothed body"
	)
	_expect(
		int(wall_contract.get("modular_cushion_count", -1)) == 0,
		"manifest contains no modular cap cushions"
	)
	_expect(
		int(wall_contract.get("visual_module_seam_count", 0)) >= expected_wall_sections,
		"manifest records visual-only cap module seams"
	)
	var shaders := manifest.get("runtime_shaders", {}) as Dictionary
	for shader_role in ["shallow_water", "backdrop_water", "portal_water"]:
		var shader_record := shaders.get(shader_role, {}) as Dictionary
		var shader_path := "res://" + String(shader_record.get("path", ""))
		_expect(
			FileAccess.get_sha256(shader_path).to_lower() == String(shader_record.get("sha256", "")),
			"candidate shader hash: %s" % shader_role
		)
	var runtime_textures := manifest.get("runtime_textures", {}) as Dictionary
	var caustics := runtime_textures.get("backdrop_caustics", {}) as Dictionary
	var caustics_path := "res://" + String(caustics.get("path", ""))
	_expect(
		ResourceLoader.exists(caustics_path)
			and FileAccess.get_sha256(caustics_path).to_lower()
				== String(caustics.get("sha256", "")),
		"candidate binds deterministic backdrop caustics"
	)
	_expect(
		int(caustics.get("width", 0)) <= 2048
			and int(caustics.get("height", 0)) <= 2048
			and int(caustics.get("material_batch_growth", -1)) == 0,
		"backdrop caustics respect texture and batch budgets"
	)

	var packed := load(SCENE_PATH) as PackedScene
	var arena := packed.instantiate() as Node3D if packed else null
	_expect(arena != null, "production arena instantiates")
	if arena:
		root.add_child(arena)
		current_scene = arena
		await process_frame
		var bridge: Node = REVIEW_SCRIPT.new()
		arena.add_child(bridge)
		bridge.configure(arena, profile)
		var state: Dictionary = bridge.get_debug_state()
		_expect(bool(state.get("full_map_foreground_loaded", false)), "V5 foreground loads")
		_expect(int(state.get("collision_nodes", -1)) == 0, "V5 foreground is visual-only")
		_expect(int(state.get("art_version", 0)) == 5, "review bridge applies Art V5")
		_expect(String(state.get("candidate_id", "")) == candidate_id, "runtime binds candidate id")
		arena.queue_free()
		await process_frame

	if _failures.is_empty():
		print("[Twin Bays Art V5 Review Verifier] PASS")
		quit(0)
		return
	for failure in _failures:
		print("- ", failure)
	print("[Twin Bays Art V5 Review Verifier] FAIL")
	quit(1)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("missing JSON: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_fail("invalid JSON: %s" % path)
		return {}
	return parsed as Dictionary


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("OK  ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
