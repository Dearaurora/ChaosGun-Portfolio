extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	print("==================================================")
	print("[Weapon Spawn Visual Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var premium := WeaponSpawnPedestal.new()
	stage.add_child(premium)
	premium.configure(true)
	premium.set_state(WeaponSpawnPedestal.VisualState.PREWARM, Color("#31bde8"))
	var outer := WeaponSpawnPedestal.new()
	stage.add_child(outer)
	outer.configure(false)
	outer.set_state(WeaponSpawnPedestal.VisualState.ACTIVE, Color("#79d946"))
	await process_frame
	premium.call("_process", 1.0)
	outer.call("_process", 1.0)
	_verify_pedestal(premium, true, 6)
	_verify_pedestal(outer, false, 4)

	var pickup_scene := load("res://scenes/weapons/weapon_pickup.tscn") as PackedScene
	for data in [WeaponData.create_pistol(), WeaponData.create_smg(), WeaponData.create_ak_rifle(), WeaponData.create_sniper(), WeaponData.create_gatling(), WeaponData.create_shotgun()]:
		var pickup := pickup_scene.instantiate() as WeaponPickup
		stage.add_child(pickup)
		pickup.setup(data)
		await process_frame
		if pickup.get_node_or_null("ToyPickupVisual/PickupWeaponIcon/WeaponAsset") == null:
			_fail("Pickup must use generated weapon asset for %s" % String(data.weapon_id))
		pickup.configure_spawn_presentation("fixed")
		var base := pickup.get_node_or_null("ToyPickupVisual/PickupBase") as MeshInstance3D
		if base == null or base.visible:
			_fail("Externally managed pickup should hide its fallback base")
		pickup.queue_free()
		await process_frame

	var player := Node3D.new()
	player.name = "PickupTestCharacter"
	var weapon_manager := WeaponManager.new()
	weapon_manager.name = "WeaponManager"
	player.add_child(weapon_manager)
	var collect_pickup := pickup_scene.instantiate() as WeaponPickup
	if collect_pickup:
		stage.add_child(player)
		stage.add_child(collect_pickup)
		collect_pickup.setup(WeaponData.create_smg())
		await process_frame
		collect_pickup.call("_on_body_entered", player)
		await process_frame
		if stage.get_node_or_null("PickupCollectVisual") == null:
			_fail("Pickup should detach a short collect visual toward the character")
	else:
		_fail("Pickup scene must instantiate for collect feedback")

	await _finish([premium, outer, player, collect_pickup, stage])

func _verify_pedestal(pedestal: WeaponSpawnPedestal, premium: bool, lights: int) -> void:
	var debug := pedestal.get_visual_debug()
	if bool(debug.get("premium", not premium)) != premium:
		_fail("Pedestal premium role mismatch")
	if int(debug.get("light_count", 0)) != lights:
		_fail("Pedestal light count mismatch for premium=%s" % premium)
	if pedestal.get_node_or_null("StateRing") == null or pedestal.get_node_or_null("StateDisc") == null:
		_fail("Pedestal must expose deterministic state ring and disc")
	var orbit_angle := float(debug.get("orbit_angle", 0.0))
	if orbit_angle < 0.35:
		_fail("Active pedestal status lights must visibly orbit")
	var status_light := pedestal.get_node_or_null("StatusLight_0") as MeshInstance3D
	var light_radius := float(debug.get("light_radius", 0.0))
	var expected_position := Vector3(cos(orbit_angle) * light_radius, -0.12, sin(orbit_angle) * light_radius)
	if status_light == null or status_light.position.distance_to(expected_position) > 0.01:
		_fail("Pedestal status lights are not synchronized with the P25 orbit phase")

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
		print("[Weapon Spawn Visual Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Weapon Spawn Visual Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)
