extends SceneTree

var _failures: Array[String] = []
var _stage: Node3D = null

func _initialize() -> void:
	print("==================================================")
	print("[Powerup System Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)
	_stage = Node3D.new()
	_stage.name = "PowerupTestStage"
	root.add_child(_stage)
	current_scene = _stage
	_build_floor()

	var player_scene := load("res://scenes/characters/player.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerCharacter if player_scene else null
	if player == null:
		_fail("Player scene must instantiate")
		await _finish()
		return
	player.name = "PowerupOwner"
	player.position = Vector3(0.0, 0.08, 0.0)
	player.add_to_group("player")
	_stage.add_child(player)
	await process_frame
	await process_frame
	player.freeze = true
	player.set_process(false)
	player.set_physics_process(false)

	await _verify_speed(player)
	await _verify_fury(player)
	await _verify_pickup_visuals()
	await _verify_clone(player)
	_verify_center_pool_contract()
	await _finish()

func _verify_speed(player: PlayerCharacter) -> void:
	print("\n--- Speed Powerup ---")
	var baseline := player.get_movement_speed()
	if not player.apply_powerup(PowerupCatalog.SPEED):
		_fail("Speed powerup was rejected")
		return
	var state := player.get_powerup_state_debug()
	if not is_equal_approx(player.get_movement_speed(), baseline * 2.0):
		_fail("Speed must double actual movement force")
	if absf(float(state.get("speed_remaining", 0.0)) - 10.0) > 0.1:
		_fail("Speed duration must start at 10 seconds")
	var aura := player.get_node_or_null("SpeedPowerupAura") as PowerupAura
	if aura == null:
		_fail("Speed must create a green foot aura")
	else:
		var visual := aura.get_visual_debug()
		if int(visual.get("effect_piece_count", 0)) < 6:
			_fail("Speed aura is missing wind gust pieces")
	var controller := player.get_node_or_null("PowerupController")
	controller.call("_process", 10.1)
	await process_frame
	if not is_equal_approx(player.movement_speed_multiplier, 1.0):
		_fail("Speed multiplier did not reset after 10 seconds")
	print("OK  2.0x movement for 10 seconds with green wind aura")

func _verify_fury(player: PlayerCharacter) -> void:
	print("\n--- Fury Powerup ---")
	if not player.apply_powerup(PowerupCatalog.FURY):
		_fail("Fury powerup was rejected")
		return
	var state := player.get_powerup_state_debug()
	if not is_equal_approx(player.get_outgoing_knockback_multiplier(), 1.5):
		_fail("Fury must apply a 1.5x outgoing knockback multiplier")
	if absf(float(state.get("fury_remaining", 0.0)) - 10.0) > 0.1:
		_fail("Fury duration must start at 10 seconds")
	var aura := player.get_node_or_null("FuryPowerupAura") as PowerupAura
	if aura == null:
		_fail("Fury must create a red foot aura")
	else:
		var visual := aura.get_visual_debug()
		if int(visual.get("effect_piece_count", 0)) < 7:
			_fail("Fury aura is missing flame pieces")

	player.weapon_manager.current_weapon.fire_cooldown = 0.0
	player.weapon_manager.try_fire(player.weapon_point, Vector3.FORWARD, player)
	await process_frame
	var projectile := _find_stage_projectile()
	if projectile == null:
		_fail("Fury integration did not spawn a projectile")
	else:
		var config := root.get_node_or_null("GameConfig")
		var global_multiplier := float(config.get("knockback_multiplier")) if config else 1.8
		var expected := player.weapon_manager.current_weapon.weapon_data.knockback_power * global_multiplier * 1.5
		if not is_equal_approx(projectile.knockback_power, expected):
			_fail("Fury multiplier was not captured by the fired projectile")
		projectile.queue_free()

	var controller := player.get_node_or_null("PowerupController")
	controller.call("_process", 10.1)
	await process_frame
	if not is_equal_approx(player.outgoing_knockback_multiplier, 1.0):
		_fail("Fury multiplier did not reset after 10 seconds")
	print("OK  1.5x projectile knockback for 10 seconds with red flame aura")

func _verify_pickup_visuals() -> void:
	print("\n--- Powerup Pickups ---")
	var packed := load("res://scenes/powerups/powerup_pickup.tscn") as PackedScene
	if packed == null:
		_fail("Powerup pickup scene is missing")
		return
	for index in range(PowerupCatalog.get_center_powerups().size()):
		var powerup_id := PowerupCatalog.get_center_powerups()[index]
		var pickup := packed.instantiate() as PowerupPickup
		_stage.add_child(pickup)
		pickup.position = Vector3(-6.0 + float(index) * 6.0, 1.5, 5.0)
		pickup.setup(powerup_id)
		var visual := pickup.get_visual_debug()
		if StringName(visual.get("powerup_id", &"")) != powerup_id:
			_fail("Powerup pickup visual has the wrong identity: %s" % String(powerup_id))
		if not bool(visual.get("has_icon", false)):
			_fail("Powerup pickup is missing its authored icon: %s" % String(powerup_id))
		if powerup_id == PowerupCatalog.CLONE:
			if _count_prefixed(pickup, "CloneVisorBand_") != 2:
				_fail("Clone pickup should keep a face band visible through its full rotation")
			if _count_prefixed(pickup, "CloneFaceSignal_") != 4:
				_fail("Clone pickup should expose front and back face signals")
		pickup.queue_free()
	await process_frame
	print("OK  speed, clone, and fury use distinct pickup silhouettes")

func _verify_clone(player: PlayerCharacter) -> void:
	print("\n--- Clone Powerup ---")
	var owner_color := player.get_visual().body_color
	player.weapon_manager.equip_weapon(WeaponData.create_ak_rifle())
	player.weapon_manager.current_weapon.current_ammo = 17
	if not player.apply_powerup(PowerupCatalog.CLONE):
		_fail("Clone powerup was rejected")
		return
	await process_frame
	await process_frame
	var clones := get_nodes_in_group("temporary_clone")
	if clones.size() != 1 or not (clones[0] is CloneCharacter):
		_fail("Clone powerup must spawn one AI-controlled clone")
		return
	var clone := clones[0] as CloneCharacter
	if not clone.is_friendly_to(player) or clone.get_combat_identity() != player:
		_fail("Clone and owner must share one combat identity")
	if not clone.get_visual().body_color.is_equal_approx(owner_color):
		_fail("Clone body color must be indistinguishable from its owner")
	if absf(clone.remaining_lifetime - 15.0) > 0.2:
		_fail("Clone lifetime must start at 15 seconds")
	if clone.weapon_manager.current_weapon.weapon_data.weapon_id != &"ak_rifle":
		_fail("Clone must initially mirror the owner's held weapon")
	elif clone.weapon_manager.current_weapon.current_ammo != 17:
		_fail("Clone must initially mirror the owner's visible ammo state")

	var weapon_pickup_scene := load("res://scenes/weapons/weapon_pickup.tscn") as PackedScene
	var weapon_pickup := weapon_pickup_scene.instantiate() as WeaponPickup
	_stage.add_child(weapon_pickup)
	weapon_pickup.position = clone.position
	weapon_pickup.setup(WeaponData.create_smg())
	weapon_pickup.call("_on_body_entered", clone)
	if not clone.weapon_manager.has_primary():
		_fail("Clone AI must be able to pick up weapons")

	var powerup_scene := load("res://scenes/powerups/powerup_pickup.tscn") as PackedScene
	var speed_pickup := powerup_scene.instantiate() as PowerupPickup
	_stage.add_child(speed_pickup)
	speed_pickup.position = clone.position
	speed_pickup.setup(PowerupCatalog.SPEED)
	speed_pickup.call("_on_body_entered", clone)
	if not is_equal_approx(clone.movement_speed_multiplier, 2.0):
		_fail("Clone AI must be able to pick up powerups")
	await process_frame

	var nearby_pickup := powerup_scene.instantiate() as PowerupPickup
	_stage.add_child(nearby_pickup)
	nearby_pickup.position = clone.position + Vector3.RIGHT
	nearby_pickup.setup(PowerupCatalog.FURY)
	if clone.call("_find_nearby_pickup") != nearby_pickup:
		_fail("Armed clone AI must still seek nearby powerups")
	clone.set("_target", null)
	nearby_pickup.queue_free()
	await process_frame
	clone.call("_find_target")
	if clone.get("_target") == player:
		_fail("Clone AI must never target its owner")

	var enemy_scene := load("res://scenes/characters/ai_character.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as AICharacter
	enemy.name = "CloneTestEnemy"
	enemy.position = clone.position + Vector3(8.0, 0.0, 0.0)
	enemy.add_to_group("player")
	_stage.add_child(enemy)
	enemy.freeze = true
	enemy.set_process(false)
	enemy.set_physics_process(false)
	clone.set("_target", null)
	clone.call("_find_target")
	if clone.get("_target") != enemy:
		_fail("Clone AI must identify non-owner characters as enemies")
	var clone_shots := [0]
	clone.weapon_manager.weapon_fired.connect(func(_data: WeaponData): clone_shots[0] += 1)
	clone.weapon_manager.is_switching = false
	clone.weapon_manager.current_weapon.fire_cooldown = 0.0
	clone.call("_do_shoot", 0.0)
	if clone_shots[0] != 1:
		_fail("Clone AI must actively fire its weapon at enemies")

	clone.call("_process", 15.1)
	await process_frame
	if is_instance_valid(clone):
		_fail("Clone did not disappear when its 15-second lifecycle ended")
	var dissolve_found := false
	for effect in get_nodes_in_group("clone_dissolve_effect"):
		if effect.name == "CloneMistBreak":
			dissolve_found = true
	if not dissolve_found:
		_fail("Clone disappearance must create the gentle mist-break effect")

	if not player.apply_powerup(PowerupCatalog.CLONE):
		_fail("Could not spawn a second clone for abyss cleanup testing")
		return
	await process_frame
	var abyss_clone: CloneCharacter = null
	for candidate in get_nodes_in_group("temporary_clone"):
		if candidate is CloneCharacter:
			abyss_clone = candidate as CloneCharacter
	if abyss_clone == null:
		_fail("Second clone was not created for abyss cleanup testing")
		return
	abyss_clone.global_position.y = -140.0
	abyss_clone.call("_check_fall")
	await process_frame
	if is_instance_valid(abyss_clone):
		_fail("Clone must dissolve instead of respawning after falling into the abyss")
	print("OK  identical AI clone picks up content and dissolves without a tell")

func _verify_center_pool_contract() -> void:
	print("\n--- Center Mixed Pool ---")
	var spawner := WeaponSpawner.new()
	spawner.center_powerups_enabled = true
	var contents := spawner.get_center_content_pool_ids_debug()
	for expected in [
		"weapon:smg",
		"weapon:ak_rifle",
		"weapon:shotgun",
		"powerup:speed",
		"powerup:clone",
		"powerup:fury",
	]:
		if expected not in contents:
			_fail("Center mixed pool is missing %s" % expected)
	spawner.free()
	print("OK  center draw bag contains three weapons and three powerups")

func _find_stage_projectile() -> Projectile:
	for child in _stage.get_children():
		if child is Projectile:
			return child as Projectile
	return null

func _count_prefixed(node: Node, prefix: String) -> int:
	var count := 1 if String(node.name).begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_prefixed(child, prefix)
	return count

func _build_floor() -> void:
	var floor := StaticBody3D.new()
	floor.name = "TestFloor"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 1.0, 40.0)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)
	_stage.add_child(floor)

func _finish() -> void:
	await create_timer(0.72).timeout
	if _stage and is_instance_valid(_stage):
		_stage.queue_free()
		_stage = null
	await process_frame
	await process_frame
	print("\n==================================================")
	if _failures.is_empty():
		print("[Powerup System Verifier] PASS")
		print("==================================================")
		quit(0)
		return
	print("[Powerup System Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	print("==================================================")
	quit(1)

func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)
