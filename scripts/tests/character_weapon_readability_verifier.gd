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
	var muzzle_positions := {}
	for weapon_id in [&"pistol", &"smg", &"ak_rifle", &"sniper", &"gatling", &"shotgun"]:
		visual.set_weapon_visual(weapon_id)
		await process_frame
		var debug := visual.call("get_weapon_readability_debug") as Dictionary
		profiles[String(weapon_id)] = debug
		_verify_weapon_pose(debug, String(weapon_id))
		_verify_weapon_asset(visual, String(weapon_id))
		_verify_character_pose_meshes(visual, String(weapon_id))
		_verify_no_torso_intersection(visual, String(weapon_id))
		muzzle_positions[String(weapon_id)] = visual.get_weapon_muzzle_local_position(weapon_id)

	_verify_weapon_silhouette_steps(profiles)
	_verify_muzzle_positions(muzzle_positions)
	await _verify_weapon_switch_settle(visual)
	await _finish(visual)

func _verify_weapon_pose(debug: Dictionary, weapon_id: String) -> void:
	var holder_position := debug.get("holder_base_position", Vector3.ZERO) as Vector3
	var expected_positions := {
		"pistol": Vector3(0.0, 1.39, -0.72),
		"smg": Vector3(-0.12, 1.35, -0.83),
		"ak_rifle": Vector3(-0.18, 1.34, -0.92),
		"sniper": Vector3(-0.18, 1.35, -0.96),
		"gatling": Vector3(-0.10, 1.27, -0.88),
		"shotgun": Vector3(-0.14, 1.31, -0.90),
	}
	var expected_scales := {
		"pistol": 1.0,
		"smg": 0.84,
		"ak_rifle": 0.74,
		"sniper": 0.68,
		"gatling": 0.66,
		"shotgun": 0.72,
	}
	var expected_poses := {
		"pistol": "hold_pistol",
		"smg": "hold_smg",
		"ak_rifle": "hold_ak",
		"sniper": "hold_sniper",
		"gatling": "hold_gatling",
		"shotgun": "hold_shotgun",
	}
	var expected_position := expected_positions.get(weapon_id, Vector3.ZERO) as Vector3
	var holder_scale := float(debug.get("holder_scale", 0.0))
	if holder_position.distance_to(expected_position) > 0.02:
		_fail("%s weapon holder should use its authored hand-fit position %s, got %s" % [weapon_id, expected_position, holder_position])
	if holder_scale < 0.95 or holder_scale > 1.05:
		_fail("%s weapon holder scale should preserve hand contact and silhouette, got %.2f" % [weapon_id, holder_scale])
	if absf(float(debug.get("asset_scale", 0.0)) - float(expected_scales[weapon_id])) > 0.01:
		_fail("%s weapon asset scale does not match its rig-fit profile" % weapon_id)
	if absf(float(debug.get("asset_rotation_y", 0.0)) - 180.0) > 0.1:
		_fail("%s asset must face Godot -Z instead of back into the torso" % weapon_id)
	if not bool(debug.get("uses_hero_rig", false)):
		_fail("%s should use the approved hero rig" % weapon_id)
	if String(debug.get("weapon_pose", "")) != String(expected_poses[weapon_id]):
		_fail("%s should activate %s, got %s" % [weapon_id, expected_poses[weapon_id], debug.get("weapon_pose", "")])

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
	if String(debug.get("muzzle_anchor_source", "")) != "authored_model":
		_fail("%s should derive its muzzle anchor from the authored GLB marker" % weapon_id)

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
	for required_part in ["HeroCloudBody", "HeroSleeve.L", "HeroSleeve.R", "HeroWristCuff.L", "HeroWristCuff.R", "FacePanel", "EyeL", "EyeR"]:
		if _find_descendant(visual, required_part) == null:
			_fail("%s character asset is missing authored part %s" % [weapon_id, required_part])
	var skeleton := _find_skeleton(visual)
	if skeleton == null or skeleton.get_bone_count() < 15:
		_fail("%s character should use the complete 15-bone hero rig" % weapon_id)
	var animation_player := _find_animation_player(visual)
	var pose_names := {
		"pistol": &"hold_pistol",
		"smg": &"hold_smg",
		"ak_rifle": &"hold_ak",
		"sniper": &"hold_sniper",
		"gatling": &"hold_gatling",
		"shotgun": &"hold_shotgun",
	}
	var expected_pose := pose_names.get(weapon_id, &"hold_pistol") as StringName
	if animation_player == null or not animation_player.has_animation(expected_pose):
		_fail("%s character is missing rig pose %s" % [weapon_id, expected_pose])
	elif animation_player.assigned_animation != expected_pose:
		_fail("%s character did not activate rig pose %s" % [weapon_id, expected_pose])

func _verify_no_torso_intersection(visual: CharacterVisual, weapon_id: String) -> void:
	var torso := _find_descendant(visual, "HeroCloudBody") as MeshInstance3D
	var asset := visual.get_node_or_null("WeaponHolder/WeaponAsset")
	var holder := visual.get_node_or_null("WeaponHolder") as Node3D
	var skeleton := _find_skeleton(visual)
	if torso == null or asset == null or holder == null or skeleton == null:
		_fail("%s cannot evaluate hand fit without rig, torso, holder, and WeaponAsset" % weapon_id)
		return
	var torso_points: Array[Vector3] = []
	var weapon_points: Array[Vector3] = []
	_collect_mesh_bounds(torso, torso_points)
	_collect_mesh_bounds(asset, weapon_points)
	if torso_points.is_empty() or weapon_points.is_empty():
		_fail("%s cannot evaluate empty mesh bounds" % weapon_id)
		return
	var torso_front_z := INF
	var weapon_min := Vector3(INF, INF, INF)
	var weapon_max := Vector3(-INF, -INF, -INF)
	for point in torso_points:
		torso_front_z = minf(torso_front_z, point.z)
	for point in weapon_points:
		weapon_min = weapon_min.min(point)
		weapon_max = weapon_max.max(point)
	var root_clearance := torso_front_z - holder.global_position.z
	if root_clearance < 0.08:
		_fail("%s weapon root sits behind the suit front, clearance %.3f" % [weapon_id, root_clearance])
	for hand_name in [&"Hand.L", &"Hand.R"]:
		var bone_index := skeleton.find_bone(hand_name)
		if bone_index < 0:
			_fail("%s is missing %s" % [weapon_id, hand_name])
			continue
		var hand_position := skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin
		var distance := _distance_to_bounds(hand_position, weapon_min, weapon_max)
		if distance > 0.42:
			_fail("%s %s is %.3f units away from the weapon grip envelope" % [weapon_id, hand_name, distance])
	print("OK  %s rig hands fit weapon envelope" % weapon_id)

func _distance_to_bounds(point: Vector3, bounds_min: Vector3, bounds_max: Vector3) -> float:
	var delta := Vector3(
		maxf(maxf(bounds_min.x - point.x, point.x - bounds_max.x), 0.0),
		maxf(maxf(bounds_min.y - point.y, point.y - bounds_max.y), 0.0),
		maxf(maxf(bounds_min.z - point.z, point.z - bounds_max.z), 0.0)
	)
	return delta.length()

func _find_descendant(node: Node, target_name: String) -> Node:
	var normalized_name := String(node.name).to_lower().replace(".", "").replace("_", "")
	var normalized_target := target_name.to_lower().replace(".", "").replace("_", "")
	if normalized_name == normalized_target:
		return node
	for child in node.get_children():
		var found := _find_descendant(child, target_name)
		if found != null:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
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
	var gatling_profile := profiles["gatling"] as Dictionary
	var shotgun_profile := profiles["shotgun"] as Dictionary
	if float(gatling_profile.get("silhouette_width", 0.0)) <= float(ak_profile.get("silhouette_width", 0.0)):
		_fail("Gatling should have the widest heavy-weapon silhouette")
	if not bool(gatling_profile.get("has_magazine", false)) or not bool(gatling_profile.get("has_stock", false)):
		_fail("Gatling silhouette should expose ammo and stock mass")
	if bool(shotgun_profile.get("has_magazine", true)) or not bool(shotgun_profile.get("has_stock", false)):
		_fail("Shotgun silhouette should read as a stocked tube-fed weapon")
	else:
		print("OK  readable held-weapon silhouette steps")

func _verify_muzzle_positions(positions: Dictionary) -> void:
	var pistol := positions["pistol"] as Vector3
	var smg := positions["smg"] as Vector3
	var ak := positions["ak_rifle"] as Vector3
	var sniper := positions["sniper"] as Vector3
	if not (pistol.z > smg.z and smg.z > ak.z and ak.z > sniper.z):
		_fail("Muzzle anchors should advance with authored weapon length")
	for weapon_id in positions:
		var point := positions[weapon_id] as Vector3
		if point.y < 1.35 or point.y > 1.70:
			_fail("%s authored muzzle height is outside the held-weapon envelope: %s" % [weapon_id, point])
		if point.z > -1.60 or point.z < -2.55:
			_fail("%s authored muzzle depth is outside the held-weapon envelope: %s" % [weapon_id, point])
	print("OK  authored per-weapon muzzle anchor progression")

func _verify_weapon_switch_settle(visual: CharacterVisual) -> void:
	visual.set_weapon_visual(&"pistol")
	await create_timer(0.07).timeout
	var active_debug := visual.get_motion_debug()
	var active_amount := float(active_debug.get("weapon_switch_settle", 0.0))
	if active_amount < 0.35:
		_fail("Weapon switching should produce a visible short hand-and-weapon settle")
	await create_timer(0.24).timeout
	var settled_debug := visual.get_motion_debug()
	if float(settled_debug.get("weapon_switch_settle", 1.0)) > 0.02:
		_fail("Weapon switch settle should finish without leaving pose drift")
	else:
		print("OK  short weapon-switch settle returns to authored hand fit")

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
