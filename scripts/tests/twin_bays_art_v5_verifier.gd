extends SceneTree

const PROFILE_PATH := "res://resources/maps/twin_bays_art_v5.json"
const FOREGROUND_PATH := "res://assets/review/twin_bays_art_v5/candidate/twin_bays_art_v5_foreground.glb"
const WaterMaterials = preload("res://scripts/maps/twin_bays_water_materials.gd")
const BackdropScript = preload("res://scripts/maps/twin_bays_splash_backdrop.gd")


func _initialize() -> void:
	var profile := _load_json(PROFILE_PATH)
	if profile.is_empty() or int(profile.get("version", 0)) != 5:
		_fail("Art V5 profile is missing or invalid")
		return
	if not ResourceLoader.exists(FOREGROUND_PATH):
		_fail("Art V5 foreground is not imported")
		return
	var packed := load(FOREGROUND_PATH) as PackedScene
	var foreground := packed.instantiate() as Node3D if packed else null
	if foreground == null:
		_fail("Art V5 foreground cannot be instantiated")
		return
	root.add_child(foreground)
	var collision_count := 0
	var mesh_count := 0
	var material_names: Dictionary = {}
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
						material_names[material.resource_name] = true
	if collision_count != 0:
		_fail("Art V5 foreground contains collision/navigation nodes: %d" % collision_count)
		return
	if mesh_count <= 0 or mesh_count > 12:
		_fail("Art V5 foreground mesh batches are outside 1..12: %d" % mesh_count)
		return
	if material_names.size() > 12:
		_fail("Art V5 foreground exceeds the 12-material ceiling: %d" % material_names.size())
		return

	var tide_art := profile.get("tide_art", {}) as Dictionary
	var shader_path := WaterMaterials.shader_path_for_config(tide_art)
	if shader_path != "res://assets/shaders/twin_bays_water_master_v5.gdshader":
		_fail("Art V5 shallow-water shader routing is wrong: %s" % shader_path)
		return

	var backdrop := BackdropScript.new() as TwinBaysSplashBackdrop
	root.add_child(backdrop)
	backdrop.rebuild()
	backdrop.apply_art_review_profile(profile)
	if not bool(backdrop.get_meta("art_v5_active", false)) \
			or not bool(backdrop.get_meta("art_v5_review", false)):
		_fail("Art V5 backdrop profile did not activate")
		return
	var backdrop_debug := backdrop.get_ambient_motion_debug()
	if int(backdrop_debug.get("palm_count", -1)) != 0:
		_fail("Art V5 backdrop duplicated baked static palms")
		return
	if int(backdrop_debug.get("water_entry_count", 0)) != 6:
		_fail("Art V5 backdrop lost the two three-layer portal water entries")
		return

	print("OK  Art V5 foreground batches: %d" % mesh_count)
	print("OK  Art V5 foreground materials: %d" % material_names.size())
	print("OK  Art V5 foreground collision/navigation: 0")
	print("OK  Art V5 backdrop static dressing is GLB-owned")
	print("OK  Art V5 water shader route: %s" % shader_path)
	print("TWIN_BAYS_ART_V5_RUNTIME_CONTRACT_PASS")
	quit(0)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _walk(search_root: Node) -> Array[Node]:
	var nodes: Array[Node] = [search_root]
	for child in search_root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _fail(message: String) -> void:
	push_error("TWIN_BAYS_ART_V5_RUNTIME_CONTRACT_FAIL %s" % message)
	quit(1)
