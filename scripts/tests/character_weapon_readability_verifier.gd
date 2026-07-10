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
		_verify_weapon_proxy_nodes(visual, String(weapon_id))
		_verify_weapon_asset_tint(visual, debug, String(weapon_id))

	_verify_weapon_silhouette_steps(profiles)
	await _finish(visual)

func _verify_weapon_pose(debug: Dictionary, weapon_id: String) -> void:
	var holder_position := debug.get("holder_position", Vector3.ZERO) as Vector3
	var holder_scale := float(debug.get("holder_scale", 0.0))
	if holder_position.x < 1.04:
		_fail("%s weapon holder should sit outside the body silhouette on local X, got %.2f" % [weapon_id, holder_position.x])
	if holder_position.z > -1.22:
		_fail("%s weapon holder should push forward from the body silhouette, got z %.2f" % [weapon_id, holder_position.z])
	if holder_position.y < 1.38:
		_fail("%s weapon holder should be raised above feet/shadow clutter, got y %.2f" % [weapon_id, holder_position.y])
	if holder_scale < 1.30:
		_fail("%s weapon holder should be large enough for party-camera readability, scale %.2f" % [weapon_id, holder_scale])

	var length := float(debug.get("silhouette_length", 0.0))
	var width := float(debug.get("silhouette_width", 0.0))
	if length < 0.70:
		_fail("%s silhouette length too small to read, %.2f" % [weapon_id, length])
	if width < 0.18:
		_fail("%s silhouette width too thin to separate from body, %.2f" % [weapon_id, width])
	if not bool(debug.get("has_outline", false)):
		_fail("%s weapon needs a dark outline layer" % weapon_id)

func _verify_weapon_proxy_nodes(visual: CharacterVisual, weapon_id: String) -> void:
	var holder := visual.get_node_or_null("WeaponHolder")
	if holder == null:
		_fail("%s missing WeaponHolder" % weapon_id)
		return
	var proxy := holder.get_node_or_null("WeaponReadability")
	if proxy == null:
		_fail("%s missing WeaponReadability proxy" % weapon_id)
		return
	if proxy.get_node_or_null("WeaponReadabilityOutline") == null:
		_fail("%s missing outline root" % weapon_id)
	if proxy.get_node_or_null("WeaponReadabilityAccent") == null:
		_fail("%s missing accent root" % weapon_id)

func _verify_weapon_asset_tint(visual: CharacterVisual, debug: Dictionary, weapon_id: String) -> void:
	var holder := visual.get_node_or_null("WeaponHolder")
	if holder == null:
		return
	var asset := holder.get_node_or_null("WeaponAsset")
	if asset == null:
		return
	var accent := debug.get("accent_color", Color.WHITE) as Color
	var tinted_meshes := _count_tinted_asset_meshes(asset, accent)
	if tinted_meshes <= 0:
		_fail("%s WeaponAsset should be tinted to the same category color as the readable silhouette" % weapon_id)

func _count_tinted_asset_meshes(node: Node, accent: Color) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var mat := mesh_instance.material_override as StandardMaterial3D
		if mat != null and _color_distance(mat.albedo_color, accent) < 0.40:
			count += 1
	for child in node.get_children():
		count += _count_tinted_asset_meshes(child, accent)
	return count

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
