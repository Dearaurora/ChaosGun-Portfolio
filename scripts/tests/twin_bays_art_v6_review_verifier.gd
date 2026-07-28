extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"
const BASE_PROFILE_PATH := "res://resources/maps/twin_bays_art_v5.json"
const PROFILE_PATH := "res://resources/maps/twin_bays_art_v6.json"
const MANIFEST_PATH := \
	"res://assets/review/twin_bays_art_v6/candidate/twin_bays_art_v6_manifest.json"
const FOREGROUND_PATH := \
	"res://assets/review/twin_bays_art_v6/candidate/twin_bays_art_v6_foreground.glb"
const REVIEW_SCRIPT = preload("res://scripts/maps/twin_bays_art_v6_review.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	print("[Twin Bays Art V6 Review Verifier]")
	var base_profile := _load_json(BASE_PROFILE_PATH)
	var override := _load_json(PROFILE_PATH)
	var manifest := _load_json(MANIFEST_PATH)
	_expect(int(override.get("version", 0)) == 6, "override declares Art V6")
	_expect(
		String(override.get("status", "")) == "isolated_professional_finish_candidate",
		"candidate remains isolated"
	)
	_expect(
		String(override.get("base_profile_sha256", ""))
			== FileAccess.get_sha256(BASE_PROFILE_PATH).to_lower(),
		"V6 binds the current V5 base"
	)
	var profile := _deep_merge_dictionary(base_profile, override)
	var candidate_id := String((override.get("review", {}) as Dictionary).get("candidate_id", ""))
	var review := manifest.get("review", {}) as Dictionary
	_expect(candidate_id == "art_v6_professional_finish_01", "candidate id is frozen")
	_expect(String(review.get("candidate_id", "")) == candidate_id, "manifest binds candidate id")
	_expect(not bool(review.get("golden_update_allowed", true)), "candidate cannot update Golden")
	_expect(
		not bool(review.get("production_foreground_overwritten", true))
			and not bool(review.get("art_v5_foreground_overwritten", true)),
		"candidate does not overwrite V4 production or V5"
	)
	var protection := review.get("production_and_v5_protection", {}) as Dictionary
	_expect(bool(protection.get("byte_identical", false)), "V4/V5 protection passed")
	var protected_before := protection.get("before", {}) as Dictionary
	var protected_after := protection.get("after", {}) as Dictionary
	_expect(protected_before == protected_after, "protected hashes are unchanged")
	for relative_path_variant: Variant in protected_after:
		var relative_path := String(relative_path_variant)
		_expect(
			FileAccess.get_sha256("res://" + relative_path).to_lower()
				== String(protected_after[relative_path_variant]),
			"protected hash: %s" % relative_path
		)

	var inheritance := manifest.get("profile_inheritance", {}) as Dictionary
	_expect(
		String(inheritance.get("base_profile_sha256", ""))
			== FileAccess.get_sha256(BASE_PROFILE_PATH).to_lower(),
		"manifest binds V5 inheritance"
	)
	_expect(
		String(inheritance.get("override_profile_sha256", ""))
			== FileAccess.get_sha256(PROFILE_PATH).to_lower(),
		"manifest binds V6 override"
	)
	_expect(
		String(manifest.get("art_profile_sha256", ""))
			== FileAccess.get_sha256(PROFILE_PATH).to_lower(),
		"candidate manifest binds Art V6"
	)
	_expect(
		String(manifest.get("layout_sha256", ""))
			== FileAccess.get_sha256("res://resources/maps/twin_bays_layout_v1.json").to_lower(),
		"manifest binds current layout"
	)
	var outputs := manifest.get("outputs", {}) as Dictionary
	var output_hashes := manifest.get("output_sha256", {}) as Dictionary
	for role in ["hero_glb", "foreground_glb"]:
		var output_path := "res://" + String(outputs.get(role, ""))
		_expect(
			FileAccess.get_sha256(output_path).to_lower() == String(output_hashes.get(role, "")),
			"candidate output hash: %s" % role
		)
	_expect(int(manifest.get("material_count", 99)) <= 12, "material budget")
	_expect(
		int((manifest.get("production_foreground", {}) as Dictionary).get("mesh_objects", 99)) <= 12,
		"foreground batch budget"
	)

	var visual := profile.get("visual_geometry", {}) as Dictionary
	_expect(float(visual.get("wall_cap_depth_multiplier", 0.0)) >= 8.0, "hero wall-cap mass")
	_expect(bool(visual.get("platform_contact_foam_scallops", false)), "front foam language")
	_expect(
		not bool(visual.get("platform_contact_bay_foam_scallops", true)),
		"rejected bay-foam geometry remains disabled"
	)
	var backdrop := profile.get("backdrop", {}) as Dictionary
	_expect(
		float(backdrop.get("caustic_tile_world_size", 0.0)) == 38.0,
		"camera-scale caustic refinement"
	)
	_expect(
		not bool(backdrop.get("hero_parasols", true))
			and not bool(backdrop.get("hero_foreground_floaters", true)),
		"rejected prop-heavy pass remains disabled"
	)

	var packed_foreground := load(FOREGROUND_PATH) as PackedScene
	var foreground := packed_foreground.instantiate() as Node3D if packed_foreground else null
	_expect(foreground != null, "V6 foreground imports")
	if foreground:
		root.add_child(foreground)
		var collision_count := 0
		var mesh_count := 0
		var materials: Dictionary = {}
		for node in _walk(foreground):
			if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D:
				collision_count += 1
			if node is MeshInstance3D:
				mesh_count += 1
				var mesh := (node as MeshInstance3D).mesh
				if mesh:
					for surface_index in range(mesh.get_surface_count()):
						var material := mesh.surface_get_material(surface_index)
						if material:
							materials[material.resource_name] = true
		_expect(collision_count == 0, "V6 foreground is visual-only")
		_expect(mesh_count <= 12, "runtime mesh batches remain bounded")
		_expect(materials.size() <= 12, "runtime materials remain bounded")
		foreground.queue_free()
		await process_frame

	var packed_arena := load(SCENE_PATH) as PackedScene
	var arena := packed_arena.instantiate() as Node3D if packed_arena else null
	_expect(arena != null, "production arena instantiates")
	if arena:
		root.add_child(arena)
		current_scene = arena
		await process_frame
		var bridge: Node = REVIEW_SCRIPT.new()
		arena.add_child(bridge)
		bridge.configure(arena, profile)
		var state: Dictionary = bridge.get_debug_state()
		_expect(bool(state.get("full_map_foreground_loaded", false)), "V6 bridge loads candidate")
		_expect(int(state.get("collision_nodes", -1)) == 0, "V6 bridge adds no collision")
		_expect(int(state.get("art_version", 0)) == 6, "V6 resolved profile applies")
		_expect(String(state.get("candidate_id", "")) == candidate_id, "runtime binds candidate id")
		arena.queue_free()
		await process_frame

	if _failures.is_empty():
		print("[Twin Bays Art V6 Review Verifier] PASS")
		quit(0)
		return
	for failure in _failures:
		print("- ", failure)
	print("[Twin Bays Art V6 Review Verifier] FAIL")
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


func _deep_merge_dictionary(parent: Dictionary, override: Dictionary) -> Dictionary:
	var merged := parent.duplicate(true)
	for key: Variant in override:
		var value: Variant = override[key]
		if value is Dictionary and merged.get(key) is Dictionary:
			merged[key] = _deep_merge_dictionary(merged[key] as Dictionary, value as Dictionary)
		else:
			merged[key] = value
	return merged


func _walk(search_root: Node) -> Array[Node]:
	var nodes: Array[Node] = [search_root]
	for child in search_root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("OK  ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
