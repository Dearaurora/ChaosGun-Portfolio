extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Character Weapon Readability Verifier]")
	print("==================================================")

	var visual := CharacterVisual.new()
	visual.name = "WeaponReadabilityVisual"
	root.add_child(visual)
	await process_frame
	await process_frame

	if not visual.has_method("get_weapon_readability_debug"):
		_fail("CharacterVisual must expose get_weapon_readability_debug()")
		await _finish(visual)
		return

	var profiles := {}
	for weapon_id in [&"pistol", &"smg", &"ak_rifle", &"sniper"]:
		visual.set_weapon_visual(weapon_id)
		await process_frame
		var debug := visual.call("get_weapon_readability_debug") as Dictionary
		profiles[String(weapon_id)] = debug
		_verify_weapon_pose(debug, String(weapon_id))
		_verify_weapon_asset(visual, String(weapon_id))
		_verify_character_pose_meshes(visual, String(weapon_id))
		_verify_no_torso_intersection(visual, String(weapon_id))

	_verify_weapon_silhouette_steps(profiles)
	await _finish(visual)

func _verify_weapon_pose(debug: Dictionary, weapon_id: String) -> void:
	var holder_position := debug.get("holder_position", Vector3.ZERO) as Vector3
	var holder_scale := float(debug.get("holder_scale", 0.0))
	if absf(holder_position.x) > 0.10:
		_fail("%s weapon holder should be centered between both hands, got x %.2f" % [weapon_id, holder_position.x])
	if holder_position.z < -1.55 or holder_position.z > -1.35:
		_fail("%s weapon holder should remain in the chest clearance plane, got z %.2f" % [weapon_id, holder_position.z])
	if holder_position.y < 0.95 or holder_position.y > 1.12:
		_fail("%s weapon holder should align with modeled hands, got y %.2f" % [weapon_id, holder_position.y])
	if holder_scale < 0.95 or holder_scale > 1.05:
		_fail("%s weapon holder scale should preserve hand contact and silhouette, got %.2f" % [weapon_id, holder_scale])
	if absf(float(debug.get("asset_rotation_y", 0.0)) - 180.0) > 0.1:
		_fail("%s asset must face Godot -Z instead of back into the torso" % weapon_id)

	var length := float(debug.get("silhouette_length", 0.0))
	var width := float(debug.get("silhouette_width", 0.0))
	if length < 0.70:
		_fail("%s silhouette length too small to read, %.2f" % [weapon_id, length])
	if width < 0.18:
		_fail("%s silhouette width too thin to separate from body, %.2f" % [weapon_id, width])
	if not bool(debug.get("has_asset", false)):
		_fail("%s should load its authored GLB asset" % weapon_id)
	if bool(debug.get("uses_proxy", true)):
		_fail("%s should not overlay the obsolete readability proxy when its GLB loads" % weapon_id)

func _verify_weapon_asset(visual: CharacterVisual, weapon_id: String) -> void:
	var holder := visual.get_node_or_null("WeaponHolder")
	if holder == null:
		_fail("%s missing WeaponHolder" % weapon_id)
		return
	if holder.get_node_or_null("WeaponReadability") != null:
		_fail("%s still contains the obsolete WeaponReadability proxy" % weapon_id)
	var asset := holder.get_node_or_null("WeaponAsset")
	if asset == null:
		_fail("%s missing WeaponAsset" % weapon_id)
		return
	var stats := {"meshes": 0, "shaded": 0, "colors": []}
	_collect_asset_material_stats(asset, stats)
	if int(stats["meshes"]) < 3:
		_fail("%s should contain a multipart authored silhouette" % weapon_id)
	if int(stats["shaded"]) != int(stats["meshes"]):
		_fail("%s materials should use scene lighting instead of flat unshaded tint" % weapon_id)
	if (stats["colors"] as Array).size() < 2:
		_fail("%s should preserve at least two authored material color families" % weapon_id)

func _collect_asset_material_stats(node: Node, stats: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface_index in range(mesh_instance.get_surface_override_material_count()):
			var mat := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
			if mat == null:
				continue
			stats["meshes"] = int(stats["meshes"]) + 1
			if mat.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				stats["shaded"] = int(stats["shaded"]) + 1
			var colors := stats["colors"] as Array
			var is_new_color := true
			for existing in colors:
				if _color_distance(existing as Color, mat.albedo_color) < 0.18:
					is_new_color = false
			if is_new_color:
				colors.append(mat.albedo_color)
	for child in node.get_children():
		_collect_asset_material_stats(child, stats)

func _verify_character_pose_meshes(visual: CharacterVisual, weapon_id: String) -> void:
	var counts := {"pistol_visible": 0, "long_visible": 0, "pistol_total": 0, "long_total": 0}
	_count_pose_meshes(visual, counts)
	if int(counts["pistol_total"]) < 4 or int(counts["long_total"]) < 4:
		_fail("%s character asset should contain complete pistol and long-gun pose sets" % weapon_id)
	var wants_pistol := weapon_id == "pistol"
	if wants_pistol and (int(counts["pistol_visible"]) < 4 or int(counts["long_visible"]) != 0):
		_fail("pistol should show only the close-grip arm pose")
	if not wants_pistol and (int(counts["long_visible"]) < 4 or int(counts["pistol_visible"]) != 0):
		_fail("%s should show only the long-gun support pose" % weapon_id)

func _count_pose_meshes(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var lower_name := String(mesh_instance.name).to_lower()
		if lower_name.contains("posepistol"):
			counts["pistol_total"] = int(counts["pistol_total"]) + 1
			if mesh_instance.visible:
				counts["pistol_visible"] = int(counts["pistol_visible"]) + 1
		elif lower_name.contains("poselong"):
			counts["long_total"] = int(counts["long_total"]) + 1
			if mesh_instance.visible:
				counts["long_visible"] = int(counts["long_visible"]) + 1
	for child in node.get_children():
		_count_pose_meshes(child, counts)

func _verify_no_torso_intersection(visual: CharacterVisual, weapon_id: String) -> void:
	var torso := _find_descendant(visual, "Body") as MeshInstance3D
	var asset := visual.get_node_or_null("WeaponHolder/WeaponAsset")
	if torso == null or asset == null:
		_fail("%s cannot evaluate torso clearance without Body and WeaponAsset" % weapon_id)
		return
	var torso_points: Array[Vector3] = []
	var weapon_points: Array[Vector3] = []
	_collect_mesh_bounds(torso, torso_points)
	_collect_mesh_bounds(asset, weapon_points)
	if torso_points.is_empty() or weapon_points.is_empty():
		_fail("%s cannot evaluate empty mesh bounds" % weapon_id)
		return
	var torso_front_z := INF
	var weapon_rear_z := -INF
	for point in torso_points:
		torso_front_z = minf(torso_front_z, point.z)
	for point in weapon_points:
		weapon_rear_z = maxf(weapon_rear_z, point.z)
	var clearance := torso_front_z - weapon_rear_z
	if clearance < 0.04:
		_fail("%s penetrates the torso depth plane, clearance %.3f" % [weapon_id, clearance])
	else:
		print("OK  %s torso clearance %.3f" % [weapon_id, clearance])

func _find_descendant(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_descendant(child, target_name)
		if found != null:
			return found
	return null

func _collect_mesh_bounds(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		for x in [0.0, 1.0]:
			for y in [0.0, 1.0]:
				for z in [0.0, 1.0]:
					var local_point := bounds.position + bounds.size * Vector3(x, y, z)
					points.append(mesh_instance.global_transform * local_point)
	for child in node.get_children():
		_collect_mesh_bounds(child, points)

func _color_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _verify_weapon_silhouette_steps(profiles: Dictionary) -> void:
	var pistol := float((profiles["pistol"] as Dictionary).get("silhouette_length", 0.0))
	var smg := float((profiles["smg"] as Dictionary).get("silhouette_length", 0.0))
	var ak := float((profiles["ak_rifle"] as Dictionary).get("silhouette_length", 0.0))
	var sniper := float((profiles["sniper"] as Dictionary).get("silhouette_length", 0.0))
	if not (pistol < smg and smg < ak and ak < sniper):
		_fail("Weapon silhouettes should step pistol < smg < ak < sniper, got %.2f %.2f %.2f %.2f" % [pistol, smg, ak, sniper])

	var smg_profile := profiles["smg"] as Dictionary
	var ak_profile := profiles["ak_rifle"] as Dictionary
	var sniper_profile := profiles["sniper"] as Dictionary
	if not bool(smg_profile.get("has_magazine", false)):
		_fail("SMG silhouette should have a magazine marker")
	if not bool(ak_profile.get("has_magazine", false)) or not bool(ak_profile.get("has_stock", false)):
		_fail("AK silhouette should have magazine and stock markers")
	if not bool(sniper_profile.get("has_scope", false)):
		_fail("Sniper silhouette should have a scope marker")
	else:
		print("OK  readable held-weapon silhouette steps")

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(visual: Node) -> void:
	if visual and is_instance_valid(visual):
		visual.queue_free()
	await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Character Weapon Readability Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Character Weapon Readability Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
