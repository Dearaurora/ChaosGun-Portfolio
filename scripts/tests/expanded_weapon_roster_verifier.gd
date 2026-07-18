extends SceneTree

const MAP_SCENE_PATH := "res://scenes/maps/open_ringout_slice.tscn"

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Expanded Weapon Roster Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	_verify_weapon_data()
	_verify_spawn_pools()
	await _verify_shotgun_runtime_shot()
	await _verify_map_tuning()
	await _finish()

func _verify_weapon_data() -> void:
	var smg := WeaponData.create_smg()
	var gatling := WeaponData.create_gatling()
	var shotgun := WeaponData.create_shotgun()
	if smg.knockback_power < 70.0:
		_fail("SMG base knockback should be buffed by one tier")
	if gatling.magazine_size != 200:
		_fail("Gatling must carry exactly 200 rounds")
	if gatling.fire_mode != WeaponData.FireMode.FULL_AUTO or gatling.fire_rate < 16.0:
		_fail("Gatling must be a fast full-auto weapon")
	if gatling.recoil_force >= smg.recoil_force:
		_fail("Gatling recoil should stay lower than SMG recoil")
	if gatling.knockback_power < 50.0 or gatling.knockback_power > 80.0:
		_fail("Gatling per-shot knockback should stay in the medium tier")
	if shotgun.magazine_size != 10:
		_fail("Shotgun must carry exactly 10 shells")
	if shotgun.fire_rate > 1.2 or shotgun.recoil_force < 7.0 or shotgun.recoil_force > 14.0:
		_fail("Shotgun should fire slowly with medium recoil")
	if shotgun.projectiles_per_shot != 5 or shotgun.pellet_spread_degrees < 10.0:
		_fail("Shotgun should fire a readable five-pellet spread")
	if shotgun.close_range_knockback_multiplier < 1.8 or shotgun.far_range_knockback_multiplier > 0.75:
		_fail("Shotgun knockback must strongly favor close range")
	if gatling.projectile_scene == null or shotgun.projectile_scene == null:
		_fail("New weapons must load authored projectile scenes")
	print("OK  Gatling, shotgun, and buffed SMG data tiers")

func _verify_spawn_pools() -> void:
	var spawner := WeaponSpawner.new()
	var center_ids := spawner.get_spawn_pool_ids_debug("fixed")
	var outer_ids := spawner.get_spawn_pool_ids_debug("random")
	if &"gatling" in center_ids or &"sniper" in center_ids:
		_fail("Center spawn pool must exclude Gatling and Sniper")
	for expected_id in [&"smg", &"ak_rifle", &"shotgun"]:
		if expected_id not in center_ids:
			_fail("Center spawn pool is missing %s" % String(expected_id))
	for expected_id in [&"smg", &"ak_rifle", &"shotgun", &"gatling", &"sniper"]:
		if expected_id not in outer_ids:
			_fail("Outer spawn pool is missing %s" % String(expected_id))
	spawner.free()
	print("OK  deterministic center and outer island weapon pools")

func _verify_shotgun_runtime_shot() -> void:
	var stage := Node3D.new()
	stage.name = "ShotgunRuntimeStage"
	root.add_child(stage)
	current_scene = stage
	await process_frame
	var marker := Marker3D.new()
	stage.add_child(marker)
	marker.global_position = Vector3(0.0, 2.0, 0.0)
	var shooter := Node3D.new()
	stage.add_child(shooter)
	var weapon := Weapon.new()
	stage.add_child(weapon)
	weapon.init_weapon(WeaponData.create_shotgun())
	if not weapon.try_fire(marker, Vector3.RIGHT, shooter):
		_fail("Shotgun should fire from a ready state")
	var pellets: Array[Projectile] = []
	for child in stage.get_children():
		if child is Projectile:
			pellets.append(child as Projectile)
	if pellets.size() != 5:
		_fail("One shotgun shell should create five pellets, got %d" % pellets.size())
	if weapon.current_ammo != 9:
		_fail("One shotgun blast should consume one shell, got %d ammo" % weapon.current_ammo)
	var has_positive_z := false
	var has_negative_z := false
	for pellet in pellets:
		has_positive_z = has_positive_z or pellet.direction.z > 0.01
		has_negative_z = has_negative_z or pellet.direction.z < -0.01
		if absf(pellet.direction.y) > 0.001:
			_fail("Shotgun fan should remain on the firing plane")
	if not has_positive_z or not has_negative_z:
		_fail("Shotgun pellets should fan to both sides of the center line")

	var falloff_probe := Projectile.new()
	falloff_probe.configure_knockback_falloff(Vector3.ZERO, 2.2, 5.0, 26.0, 0.55)
	var close_force := falloff_probe.get_knockback_multiplier_for_distance(2.0)
	var mid_force := falloff_probe.get_knockback_multiplier_for_distance(15.5)
	var far_force := falloff_probe.get_knockback_multiplier_for_distance(32.0)
	if not (close_force > mid_force and mid_force > far_force):
		_fail("Shotgun knockback multiplier should decrease monotonically with distance")
	if absf(close_force - 2.2) > 0.01 or absf(far_force - 0.55) > 0.01:
		_fail("Shotgun knockback falloff endpoints are incorrect")
	falloff_probe.free()
	stage.queue_free()
	await process_frame
	print("OK  five-pellet shot, single-shell ammo use, and distance falloff")

func _verify_map_tuning() -> void:
	var packed := load(MAP_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Could not load open ring-out map")
		return
	var arena := packed.instantiate()
	var spawner := arena.get_node_or_null("WeaponSpawner") as WeaponSpawner
	arena.set("weapon_spawner", spawner)
	arena.call("_apply_shared_runtime_config")
	arena.call("_configure_map_runtime")
	var game_config := root.get_node_or_null("GameConfig")
	var overrides = game_config.get("weapon_feel_overrides") if game_config else null
	if not (overrides is Dictionary):
		_fail("Map must provide weapon feel overrides")
	else:
		var smg_override = (overrides as Dictionary).get("smg", {})
		var gatling_override = (overrides as Dictionary).get("gatling", {})
		var shotgun_override = (overrides as Dictionary).get("shotgun", {})
		if float(smg_override.get("knockback_power", 0.0)) < 65.0:
			_fail("Open ring-out SMG knockback override was not buffed")
		if gatling_override.is_empty() or shotgun_override.is_empty():
			_fail("Open ring-out must tune both new weapons")
		else:
			_verify_balance_envelope(overrides as Dictionary, game_config)
	if spawner == null:
		_fail("Open ring-out is missing WeaponSpawner")
	else:
		if spawner.fixed_spawn_points.size() != 1:
			_fail("Open ring-out should keep one center weapon point")
		if spawner.random_spawn_points.size() != 4:
			_fail("Open ring-out should expose four outer-island random points")
	arena.free()
	print("OK  open ring-out balance overrides and four outer island points")

func _verify_balance_envelope(overrides: Dictionary, game_config: Node) -> void:
	var knockback_multiplier := float(game_config.get("knockback_multiplier"))
	var smg := WeaponData.create_smg()
	var gatling := WeaponData.create_gatling()
	var shotgun := WeaponData.create_shotgun()
	var smg_force := float((overrides["smg"] as Dictionary)["knockback_power"]) * knockback_multiplier
	var gatling_force := float((overrides["gatling"] as Dictionary)["knockback_power"]) * knockback_multiplier
	var shotgun_force := float((overrides["shotgun"] as Dictionary)["knockback_power"]) * knockback_multiplier
	var sniper_force := float((overrides["sniper"] as Dictionary)["knockback_power"]) * knockback_multiplier
	var ak_force := float((overrides["ak_rifle"] as Dictionary)["knockback_power"]) * knockback_multiplier
	var gatling_sustained := gatling_force * gatling.fire_rate
	var smg_sustained := smg_force * smg.fire_rate
	if gatling_force >= smg_force:
		_fail("Gatling per-shot force should stay below the buffed SMG tier")
	if gatling_sustained <= smg_sustained or gatling_sustained > smg_sustained * 1.35:
		_fail("Gatling sustained force should be stronger but bounded against SMG")
	var gatling_damage_per_second := float((overrides["gatling"] as Dictionary)["damage"]) * gatling.fire_rate
	var smg_damage_per_second := float((overrides["smg"] as Dictionary)["damage"]) * smg.fire_rate
	if gatling_damage_per_second > smg_damage_per_second * 1.15:
		_fail("Gatling damage throughput should not invalidate the SMG")
	var shotgun_close := shotgun_force * shotgun.projectiles_per_shot * shotgun.close_range_knockback_multiplier
	var shotgun_far := shotgun_force * shotgun.projectiles_per_shot * shotgun.far_range_knockback_multiplier
	if shotgun_close <= ak_force * 2.0 or shotgun_close >= sniper_force:
		_fail("Close shotgun blast should sit below sniper force but well above one AK hit")
	if shotgun_far >= ak_force:
		_fail("Far shotgun blast should fall below one AK hit")
	if shotgun_close / shotgun_far < 3.5:
		_fail("Shotgun close-range advantage should remain pronounced")
	print("OK  tuned force envelope: Gatling %.0f/s, SMG %.0f/s, Shotgun %.0f close / %.0f far, Sniper %.0f" % [gatling_sustained, smg_sustained, shotgun_close, shotgun_far, sniper_force])

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	root.set_meta("disable_runtime_audio", false)
	print("\n==================================================")
	if _failures.is_empty():
		print("[Expanded Weapon Roster Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Expanded Weapon Roster Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
