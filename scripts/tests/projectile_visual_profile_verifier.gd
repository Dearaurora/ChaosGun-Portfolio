extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Projectile Visual Profile Verifier]")
	print("==================================================")

	var probe := Projectile.new()
	if not probe.has_method("configure_visual_profile"):
		_fail("Projectile must expose configure_visual_profile(weapon_id, color)")
		await _finish([probe])
		return
	if not probe.has_method("get_visual_profile_debug"):
		_fail("Projectile must expose visual profile debug data for verification")
		await _finish([probe])
		return
	probe.queue_free()

	var pistol := await _make_scene_projectile(&"pistol", Color("#ffd94a"))
	var smg := await _make_scene_projectile(&"smg", Color("#65ff49"))
	var ak := await _make_scene_projectile(&"ak_rifle", Color("#ffb13b"))
	var sniper := await _make_scene_projectile(&"sniper", Color("#5ce3ff"))
	var gatling := await _make_scene_projectile(&"gatling", Color("#ffd34d"))
	var shotgun := await _make_scene_projectile(&"shotgun", Color("#d884ff"))

	_verify_short_readable_projectile(pistol, "pistol")
	_verify_short_readable_projectile(smg, "smg")
	_verify_short_readable_projectile(ak, "ak_rifle")
	_verify_short_readable_projectile(sniper, "sniper")
	_verify_short_readable_projectile(gatling, "gatling")
	_verify_short_readable_projectile(shotgun, "shotgun")
	_verify_weapon_silhouette_differences(pistol, smg, ak, sniper)
	await _finish([pistol, smg, ak, sniper, gatling, shotgun])

func _make_scene_projectile(weapon_id: StringName, color: Color) -> Projectile:
	var scene := load("res://scenes/weapons/pistol_projectile.tscn") as PackedScene
	var projectile := scene.instantiate() as Projectile
	projectile.configure_visual_profile(weapon_id, color)
	root.add_child(projectile)
	await process_frame
	return projectile

func _verify_short_readable_projectile(projectile: Projectile, label: String) -> void:
	var profile := projectile.call("get_visual_profile_debug") as Dictionary
	var body_length := float(profile.get("body_length", 99.0))
	var body_radius := float(profile.get("body_radius", 0.0))
	var trail_length := float(profile.get("trail_length", 99.0))
	var trail_alpha := float(profile.get("trail_alpha", 1.0))
	if body_length < 0.45 or body_length > 0.90:
		_fail("%s bullet body should be long enough to direction-read, length %.2f" % [label, body_length])
	if body_radius < 0.085 or body_radius > 0.20:
		_fail("%s bullet radius should stay readable without becoming egg-shaped, radius %.2f" % [label, body_radius])
	if trail_length <= 0.15 or trail_length > 1.25:
		_fail("%s bullet trail should be short, got %.2f" % [label, trail_length])
	if trail_alpha > 0.46:
		_fail("%s trail alpha should stay low enough not to cover combat, alpha %.2f" % [label, trail_alpha])

	var core := _find_mesh(projectile, "BulletCore")
	var rim := _find_mesh(projectile, "BulletRim")
	var trail := _find_mesh(projectile, "ShortTrail")
	var trajectory_underlay := _find_mesh(projectile, "TrajectoryUnderlay")
	var trajectory_core := _find_mesh(projectile, "TrajectoryCore")
	var lead_spark := _find_mesh(projectile, "LeadSpark")
	var trail_core := _find_mesh(projectile, "ShortTrailCore")
	if core == null:
		_fail("%s missing BulletCore mesh" % label)
	if rim == null:
		_fail("%s missing dark BulletRim mesh" % label)
	if trail == null:
		_fail("%s missing ShortTrail mesh" % label)
	if trail_core == null:
		_fail("%s missing the white ShortTrailCore layer" % label)
	if trajectory_underlay != null or trajectory_core != null:
		_fail("%s should not stack a second trajectory ribbon over the shot tracer" % label)
	if lead_spark != null or _find_mesh(projectile, "BulletHotCenter") != null:
		_fail("%s should keep its white core connected to the water-drop body" % label)
	if String(profile.get("shape", "")) != "yellow_white_teardrop":
		_fail("%s should preserve the shared yellow-white water-drop silhouette" % label)

	var placeholder := projectile.get_node_or_null("MeshInstance3D")
	if placeholder is MeshInstance3D and (placeholder as MeshInstance3D).visible:
		_fail("%s should hide the old spherical placeholder mesh" % label)

	if core:
		if not (core.mesh is ArrayMesh):
			_fail("%s core should use authored round-nose water-drop geometry" % label)
		var core_mat := core.material_override as StandardMaterial3D
		if core_mat == null or not core_mat.emission_enabled or core_mat.emission_energy_multiplier < 1.05 or core_mat.emission_energy_multiplier > 1.35:
			_fail("%s core should use a controlled luminous white material" % label)
		elif minf(core_mat.albedo_color.r, minf(core_mat.albedo_color.g, core_mat.albedo_color.b)) < 0.80:
			_fail("%s core should remain warm white instead of inheriting the weapon color" % label)
	if rim:
		if not (rim.mesh is ArrayMesh):
			_fail("%s shell should use authored round-nose water-drop geometry" % label)
		var rim_mat := rim.material_override as StandardMaterial3D
		if rim_mat == null:
			_fail("%s yellow shell should have a material" % label)
		else:
			var rim_color := rim_mat.albedo_color
			if rim_color.r < 0.90 or rim_color.g < 0.60 or rim_color.b > 0.38:
				_fail("%s shell should read as warm arcade yellow" % label)
	if trail:
		if not (trail.mesh is ArrayMesh):
			_fail("%s trail should use a tapered ribbon mesh" % label)
		var trail_mat := trail.material_override as StandardMaterial3D
		if trail_mat == null or trail_mat.albedo_color.a > 0.52:
			_fail("%s yellow trail material should stay translucent" % label)
	if trail_core:
		if not (trail_core.mesh is ArrayMesh):
			_fail("%s white trail core should share the tapered ribbon silhouette" % label)
		var trail_core_mat := trail_core.material_override as StandardMaterial3D
		if trail_core_mat == null or trail_core_mat.albedo_color.a < 0.50 or trail_core_mat.albedo_color.a > 0.70:
			_fail("%s white trail core should be bright but short-lived" % label)

func _verify_weapon_silhouette_differences(pistol: Projectile, smg: Projectile, ak: Projectile, sniper: Projectile) -> void:
	var pistol_profile := pistol.call("get_visual_profile_debug") as Dictionary
	var smg_profile := smg.call("get_visual_profile_debug") as Dictionary
	var ak_profile := ak.call("get_visual_profile_debug") as Dictionary
	var sniper_profile := sniper.call("get_visual_profile_debug") as Dictionary

	if float(smg_profile["body_radius"]) >= float(ak_profile["body_radius"]):
		_fail("SMG bullet should be smaller than rifle bullet")
	if float(sniper_profile["body_length"]) <= float(pistol_profile["body_length"]):
		_fail("Sniper bullet should have the longest readable dash")
	if float(sniper_profile["trail_length"]) > 1.25:
		_fail("Sniper trail should still stay shorter than a beam")
	for profile in [pistol_profile, smg_profile, ak_profile, sniper_profile]:
		if String(profile.get("shape", "")) != "yellow_white_teardrop":
			_fail("Every weapon must keep the approved yellow-white water-drop bullet language")
	print("OK  shared yellow-white water-drop silhouette with weapon-specific scale")

func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == mesh_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child, mesh_name)
		if found:
			return found
	return null

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish(nodes: Array) -> void:
	for node in nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	await process_frame

	print("\n==================================================")
	if _failures.is_empty():
		print("[Projectile Visual Profile Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Projectile Visual Profile Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
