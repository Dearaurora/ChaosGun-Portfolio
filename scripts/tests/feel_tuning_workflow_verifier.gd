extends SceneTree

const REQUIRED_WORKFLOW_PATHS := [
	"res://docs/workflow/chaosgun-feel-tuning-loop.md",
	"res://scripts/tests/feel_tuning_probe.gd",
	"res://scripts/tests/run_feel_tuning_probe.ps1",
	"res://scripts/tests/run_feel_tuning_batch.ps1",
	"res://scripts/tests/score_feel_profiles.ps1",
	"res://resources/feel_profiles/default.json",
]
const REQUIRED_PROFILE_WEAPONS := ["pistol", "smg", "ak_rifle", "sniper"]

var _failures: Array[String] = []

class RecoilReceiver:
	extends Node3D

	var recoil_calls := 0
	var knockback_calls := 0
	var recoil_impulse := Vector3.ZERO
	var knockback_impulse := Vector3.ZERO

	func apply_recoil(impulse: Vector3) -> void:
		recoil_calls += 1
		recoil_impulse = impulse

	func apply_knockback(impulse: Vector3) -> void:
		knockback_calls += 1
		knockback_impulse = impulse

func _initialize() -> void:
	print("==================================================")
	print("[Feel Tuning Workflow Verifier]")
	print("==================================================")

	_verify_workflow_files()
	_verify_profile_set()
	await _verify_weapon_recoil_uses_recoil_channel()
	await _finish()

func _verify_workflow_files() -> void:
	for path in REQUIRED_WORKFLOW_PATHS:
		if not FileAccess.file_exists(path):
			_fail("Required feel tuning workflow file missing: %s" % path)

func _verify_profile_set() -> void:
	var dir = DirAccess.open("res://resources/feel_profiles")
	if dir == null:
		_fail("Feel profile directory missing.")
		return
	var profile_count := 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			profile_count += 1
			_verify_profile_file("res://resources/feel_profiles/%s" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	if profile_count < 5:
		_fail("Expected at least 5 feel profiles for batch comparison, found %d." % profile_count)

func _verify_profile_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not read feel profile: %s" % path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fail("Feel profile is not a JSON object: %s" % path)
		return
	var profile = parsed as Dictionary
	if not profile.has("id") or String(profile.get("id", "")).is_empty():
		_fail("Feel profile missing id: %s" % path)
	if not (profile.get("game_config", null) is Dictionary):
		_fail("Feel profile missing game_config object: %s" % path)
	var weapon_overrides = profile.get("weapon_feel_overrides", null)
	if not (weapon_overrides is Dictionary):
		_fail("Feel profile missing weapon_feel_overrides object: %s" % path)
		return
	for weapon_id in REQUIRED_PROFILE_WEAPONS:
		var weapon_values = (weapon_overrides as Dictionary).get(weapon_id, null)
		if not (weapon_values is Dictionary):
			_fail("Feel profile missing weapon override for %s: %s" % [weapon_id, path])
			continue
		if not (weapon_values as Dictionary).has("recoil_force"):
			_fail("Feel profile missing recoil_force for %s: %s" % [weapon_id, path])
		if not (weapon_values as Dictionary).has("knockback_power"):
			_fail("Feel profile missing knockback_power for %s: %s" % [weapon_id, path])

func _make_projectile_scene() -> PackedScene:
	var projectile = Area3D.new()
	projectile.set_script(load("res://scripts/weapons/projectile.gd"))
	var scene = PackedScene.new()
	var pack_result = scene.pack(projectile)
	projectile.free()
	if pack_result != OK:
		_fail("Could not build test projectile scene.")
	return scene

func _verify_weapon_recoil_uses_recoil_channel() -> void:
	var host = Node3D.new()
	host.name = "FeelTuningVerifierHost"
	root.add_child(host)
	root.set_meta("disable_runtime_audio", true)
	await process_frame

	var fire_point = Marker3D.new()
	fire_point.name = "FirePoint"
	host.add_child(fire_point)
	fire_point.global_position = Vector3.ZERO

	var receiver = RecoilReceiver.new()
	receiver.name = "RecoilReceiver"
	host.add_child(receiver)

	var data = WeaponData.new()
	data.weapon_name = "Verifier Gun"
	data.weapon_id = &"verifier"
	data.fire_rate = 99.0
	data.bullet_speed = 1.0
	data.knockback_power = 300.0
	data.recoil_force = 25.0
	data.damage = 0.0
	data.projectile_scene = _make_projectile_scene()
	data.shoot_sound = null
	data.has_infinite_ammo = true

	var game_config = root.get_node_or_null("GameConfig")
	if game_config:
		game_config.set("weapon_feel_overrides", {
			"verifier": {
				"recoil_force": 41.0,
				"knockback_power": 77.0,
			},
		})

	var weapon = Weapon.new()
	host.add_child(weapon)
	weapon.init_weapon(data)
	await process_frame

	var fired = weapon.try_fire(fire_point, Vector3.FORWARD, receiver)
	if not fired:
		_fail("Verifier weapon did not fire.")
	if receiver.recoil_calls != 1:
		_fail("Expected weapon fire to call apply_recoil exactly once, got %d." % receiver.recoil_calls)
	if receiver.knockback_calls != 0:
		_fail("Weapon fire must not call apply_knockback; got %d calls." % receiver.knockback_calls)
	if not is_equal_approx(weapon.weapon_data.recoil_force, 41.0):
		_fail("Profile override did not apply recoil_force; got %.2f." % weapon.weapon_data.recoil_force)
	if not is_equal_approx(weapon.weapon_data.knockback_power, 77.0):
		_fail("Profile override did not apply knockback_power; got %.2f." % weapon.weapon_data.knockback_power)
	if not receiver.recoil_impulse.is_equal_approx(Vector3.BACK * 41.0):
		_fail("Unexpected recoil impulse: %s" % str(receiver.recoil_impulse))

	host.queue_free()
	await process_frame
	root.set_meta("disable_runtime_audio", false)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)

func _finish() -> void:
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[Feel Tuning Workflow Verifier] PASS")
		print("==================================================")
		quit(0)
		return

	print("[Feel Tuning Workflow Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
