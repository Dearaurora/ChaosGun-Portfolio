extends SceneTree

const PRODUCTION_CONFIG_PATH := "res://resources/maps/momentum_circuit_production_v2.json"
const WEAPON_IDS := [&"pistol", &"smg", &"ak_rifle", &"shotgun", &"gatling", &"sniper"]
const CORE_COLOR := Color("#FFF8D8")
const GOLD_COLOR := Color("#FFC83D")
const MIN_CORE_CONTRAST := 0.18

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit Projectile Readability Verifier]")
	print("==================================================")
	var config := _load_json(PRODUCTION_CONFIG_PATH)
	if config.is_empty():
		_fail("Production v2 config is missing")
		_finish()
		return
	var style := config.get("surface_style", {}) as Dictionary
	var local_surfaces := {
		"main_deck": Color(String(style.get("base_color", "#FFFFFF"))),
		"deep_inset": Color(String(style.get("inset_color", "#FFFFFF"))),
		"panel_seam": Color(String(style.get("seam_color", "#FFFFFF"))),
	}
	var core_luminance := _relative_luminance(CORE_COLOR)
	var gold_luminance := _relative_luminance(GOLD_COLOR)
	for surface_name: String in local_surfaces:
		var floor_luminance := _relative_luminance(local_surfaces[surface_name])
		var core_delta := absf(core_luminance - floor_luminance)
		var gold_delta := absf(gold_luminance - floor_luminance)
		if core_delta < MIN_CORE_CONTRAST:
			_fail("Warm-white core contrast on %s is %.3f, below %.2f" % [surface_name, core_delta, MIN_CORE_CONTRAST])
		if gold_delta < MIN_CORE_CONTRAST:
			_fail("Gold outer glow contrast on %s is %.3f, below %.2f" % [surface_name, gold_delta, MIN_CORE_CONTRAST])
		print("%s core_delta=%.3f gold_delta=%.3f" % [surface_name, core_delta, gold_delta])

	var factories := {
		&"pistol": WeaponData.create_pistol,
		&"smg": WeaponData.create_smg,
		&"ak_rifle": WeaponData.create_ak_rifle,
		&"shotgun": WeaponData.create_shotgun,
		&"gatling": WeaponData.create_gatling,
		&"sniper": WeaponData.create_sniper,
	}
	for weapon_id: StringName in WEAPON_IDS:
		var weapon := (factories[weapon_id] as Callable).call() as WeaponData
		if weapon == null or weapon.projectile_scene == null:
			_fail("%s has no production projectile scene" % weapon_id)
			continue
		var projectile := weapon.projectile_scene.instantiate() as Projectile
		if projectile == null:
			_fail("%s projectile does not implement Projectile" % weapon_id)
			continue
		root.add_child(projectile)
		await process_frame
		projectile.configure_visual_profile(weapon_id, Color("#E96525"))
		var debug := projectile.get_visual_profile_debug()
		if debug.get("core_color", Color.BLACK) != Color("#FFF8D8"):
			_fail("%s core color no longer matches the shared warm-white contract" % weapon_id)
		if debug.get("shell_color", Color.BLACK) != Color("#FFC83D"):
			_fail("%s shell color no longer matches the shared gold contract" % weapon_id)
		if int(debug.get("build_count", 0)) < 1:
			_fail("%s did not build its production projectile visual profile" % weapon_id)
		projectile.queue_free()

	_finish()


func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _linear(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT momentum_circuit_projectile_readability passed=true weapons=6 minimum_delta=0.18")
		print("[Momentum Circuit Projectile Readability Verifier] PASS")
		quit(0)
	else:
		print("RESULT momentum_circuit_projectile_readability passed=false failures=%d" % _failures.size())
		quit(1)
