extends SceneTree

const TeleporterScript = preload("res://scripts/maps/momentum_circuit_random_teleporter.gd")

var _failures: Array[String] = []
var _cooldown_start_count := 0
var _cooldown_finish_count := 0


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit Teleporter Cooldown Verifier]")
	print("==================================================")
	var world := Node3D.new()
	root.add_child(world)
	var source := _make_teleporter("portal_a", Vector3.ZERO)
	var destination := _make_teleporter("portal_b", Vector3(10.0, 0.0, 0.0))
	world.add_child(source)
	world.add_child(destination)
	source.set_destinations([source, destination])
	destination.set_destinations([source, destination])
	destination.landing_cooldown_started.connect(_on_cooldown_started)
	destination.landing_cooldown_finished.connect(_on_cooldown_finished)
	var character := BaseCharacter.new()
	character.name = "TeleportCooldownProbe"
	character.freeze = true
	character.position = Vector3.ZERO
	world.add_child(character)
	await process_frame
	source.set_physics_process(false)
	destination.set_physics_process(false)

	source.call("_try_teleport", character)
	var source_debug := source.get_debug_state() as Dictionary
	var destination_debug := destination.get_debug_state() as Dictionary
	if int(source_debug.get("teleport_count", 0)) != 1:
		_fail("Source pad did not perform the initial teleport")
	if absf(float(destination_debug.get("landing_cooldown_remaining", 0.0)) - 3.0) > 0.001:
		_fail("Destination pad must start a full 3-second cooldown on arrival")
	if bool(destination_debug.get("available", true)):
		_fail("Destination pad must be unavailable immediately after landing")

	destination.call("_try_teleport", character)
	if int((destination.get_debug_state() as Dictionary).get("teleport_count", 0)) != 0:
		_fail("Destination pad retriggered immediately after landing")
	destination.test_step(2.99)
	destination.call("_try_teleport", character)
	if int((destination.get_debug_state() as Dictionary).get("teleport_count", 0)) != 0:
		_fail("Destination pad retriggered before the 3-second cooldown ended")
	destination.test_step(0.02)
	if not bool((destination.get_debug_state() as Dictionary).get("available", false)):
		_fail("Destination pad did not become available after 3 seconds")
	destination.call("_try_teleport", character)
	if int((destination.get_debug_state() as Dictionary).get("teleport_count", 0)) != 1:
		_fail("Destination pad did not resume teleporting after cooldown")
	if _cooldown_start_count != 1 or _cooldown_finish_count != 1:
		_fail("Destination cooldown start/finish signals were not emitted exactly once")
	var returned_source := source.get_debug_state() as Dictionary
	if absf(float(returned_source.get("landing_cooldown_remaining", 0.0)) - 3.0) > 0.001:
		_fail("The new landing pad must start its own 3-second cooldown")

	world.queue_free()
	await process_frame
	await _verify_occupied_destination_retry()
	_finish()


func _make_teleporter(id: String, position: Vector3) -> MomentumCircuitRandomTeleporter:
	var teleporter := TeleporterScript.new() as MomentumCircuitRandomTeleporter
	teleporter.name = id
	teleporter.position = position
	teleporter.configure(id, 2.75, 2.4, 0.65, 3.0, 1.25, 71337)
	return teleporter


func _verify_occupied_destination_retry() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var source := _make_teleporter("occupied_source", Vector3.ZERO)
	world.add_child(source)
	var destinations: Array[MomentumCircuitRandomTeleporter] = []
	for index in range(3):
		var destination := _make_teleporter(
			"occupied_destination_%d" % index,
			Vector3(12.0 + float(index) * 8.0, 0.0, 0.0)
		)
		world.add_child(destination)
		destinations.append(destination)
	source.set_destinations([source] + destinations)
	var traveler := BaseCharacter.new()
	traveler.name = "OccupiedRetryTraveler"
	traveler.freeze = true
	world.add_child(traveler)
	var occupants: Array[BaseCharacter] = []
	for index in range(destinations.size()):
		var occupant := BaseCharacter.new()
		occupant.name = "DestinationOccupant%d" % index
		occupant.freeze = true
		occupant.position = destinations[index].position
		occupant.add_to_group(&"player")
		world.add_child(occupant)
		occupants.append(occupant)
	await process_frame
	source.set_physics_process(false)
	source.call("_try_teleport", traveler)
	var debug := source.get_debug_state() as Dictionary
	if int(debug.get("teleport_count", -1)) != 0:
		_fail("All-occupied destinations must reject instead of teleporting")
	if int(debug.get("safe_candidate_count", -1)) != 0:
		_fail("All-occupied destination scan must report zero safe candidates")
	if int(debug.get("occupied_rejection_count", 0)) != 1:
		_fail("Occupied rejection telemetry did not increment")
	if absf(float(debug.get("retry_remaining", 0.0)) - 0.25) > 0.001:
		_fail("Occupied retry must begin at 0.25 seconds")
	if float(debug.get("landing_cooldown_remaining", 0.0)) > 0.0:
		_fail("Occupied rejection must not consume landing cooldown")
	occupants[0].position += Vector3(0.0, 0.0, 6.0)
	source.test_step(0.26)
	source.call("_try_teleport", traveler)
	debug = source.get_debug_state() as Dictionary
	if int(debug.get("teleport_count", 0)) != 1:
		_fail("Teleporter did not retry successfully after one destination became safe")
	if String(debug.get("last_destination", "")) != destinations[0].teleporter_id:
		_fail("Safe-destination filter selected an occupied pad")
	world.queue_free()
	await process_frame


func _on_cooldown_started(_id: String, _duration: float) -> void:
	_cooldown_start_count += 1


func _on_cooldown_finished(_id: String) -> void:
	_cooldown_finish_count += 1


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT momentum_circuit_teleporter_cooldown passed=true landing_pad_cooldown=3.0 occupied_radius=2.6 retry=0.25")
		print("[Momentum Circuit Teleporter Cooldown Verifier] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_teleporter_cooldown passed=false failures=%d" % _failures.size())
	print("[Momentum Circuit Teleporter Cooldown Verifier] FAIL")
	quit(1)
