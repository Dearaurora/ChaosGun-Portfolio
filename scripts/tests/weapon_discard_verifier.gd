extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Weapon Discard Verifier]")
	print("==================================================")
	var host := Node3D.new()
	root.add_child(host)
	var manager := WeaponManager.new()
	host.add_child(manager)
	await process_frame

	var drops := [0]
	var switched_ids: Array[StringName] = []
	manager.weapon_dropped.connect(func(_position: Vector3): drops[0] += 1)
	manager.weapon_switched.connect(func(data: WeaponData): switched_ids.append(data.weapon_id))

	if manager.current_weapon != manager.sidearm or manager.get_current_weapon_name() != "Pistol":
		_fail("Weapon manager must start on the permanent pistol")
	if manager.discard_current_weapon():
		_fail("Discard should do nothing while the pistol is equipped")

	manager.equip_weapon(WeaponData.create_smg())
	if manager.primary == null or manager.current_weapon != manager.primary:
		_fail("Picking up a primary must equip it before discard testing")
	elif manager.current_weapon.weapon_data.weapon_id != &"smg":
		_fail("Expected SMG before discard")

	if not manager.discard_current_weapon():
		_fail("A non-pistol weapon should be discardable")
	if manager.primary != null:
		_fail("Discard must clear the primary slot so it cannot be switched back")
	if manager.current_weapon != manager.sidearm:
		_fail("Discard must immediately select the permanent pistol")
	elif manager.current_weapon.weapon_data.weapon_id != &"pistol":
		_fail("Discard fallback weapon must be the pistol")
	if drops[0] != 1:
		_fail("Discard should emit exactly one world-drop event")
	if switched_ids.is_empty() or switched_ids.back() != &"pistol":
		_fail("Discard should publish the pistol as the active weapon")
	if manager.discard_current_weapon():
		_fail("Repeated discard on the pistol must remain a no-op")
	if drops[0] != 1:
		_fail("Pistol discard must not emit another drop event")

	await process_frame
	if _failures.is_empty():
		print("OK  primary weapon discarded and permanently cleared")
		print("OK  active weapon returned to infinite-ammo pistol")
		print("[Weapon Discard Verifier] PASS")
		quit(0)
		return
	print("[Weapon Discard Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
