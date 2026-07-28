extends Area3D
class_name MomentumCircuitRandomTeleporter

signal teleported(character: BaseCharacter, source_id: String, destination_id: String)
signal teleport_rejected(character: BaseCharacter, source_id: String, reason: StringName)
signal landing_cooldown_started(teleporter_id: String, duration: float)
signal landing_cooldown_finished(teleporter_id: String)

var teleporter_id := ""
var trigger_radius := 2.75
var trigger_height := 2.4
var cooldown_seconds := 0.65
var landing_cooldown_seconds := 3.0
var arrival_height := 1.25
var occupied_radius := 2.6
var occupied_retry_seconds := 0.25
var _destinations: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _character_cooldowns: Dictionary = {}
var _retry_cooldowns: Dictionary = {}
var _teleport_count := 0
var _last_destination := ""
var _landing_cooldown_remaining := 0.0
var _safe_candidate_count := 0
var _occupied_rejection_count := 0

func configure(id: String, radius: float, height: float, cooldown: float, landing_cooldown: float, arrival: float, seed_value: int, occupancy_radius: float = 2.6, retry_seconds: float = 0.25) -> void:
	teleporter_id = id
	trigger_radius = radius
	trigger_height = height
	cooldown_seconds = cooldown
	landing_cooldown_seconds = landing_cooldown
	arrival_height = arrival
	occupied_radius = maxf(0.0, occupancy_radius)
	occupied_retry_seconds = maxf(0.05, retry_seconds)
	_rng.seed = seed_value + id.hash()
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 0
	set_meta("teleport_random", true)
	set_meta("layout_id", id)

func set_destinations(destinations: Array) -> void:
	_destinations.clear()
	for value: Variant in destinations:
		if value is Node3D:
			_destinations.append(value as Node3D)

func get_debug_state() -> Dictionary:
	var cooldown_progress := 1.0
	if landing_cooldown_seconds > 0.0:
		cooldown_progress = 1.0 - clampf(_landing_cooldown_remaining / landing_cooldown_seconds, 0.0, 1.0)
	return {
		"id": teleporter_id,
		"teleport_count": _teleport_count,
		"last_destination": _last_destination,
		"landing_cooldown_seconds": landing_cooldown_seconds,
		"landing_cooldown_remaining": _landing_cooldown_remaining,
		"available": _landing_cooldown_remaining <= 0.0,
		"cooldown_progress": cooldown_progress,
		"safe_candidate_count": _safe_candidate_count,
		"occupied_rejection_count": _occupied_rejection_count,
		"retry_remaining": _largest_remaining(_retry_cooldowns),
	}

func test_step(delta: float) -> void:
	_step_cooldowns(delta)

func _physics_process(delta: float) -> void:
	_step_cooldowns(delta)
	if _landing_cooldown_remaining > 0.0:
		return
	for node in get_tree().get_nodes_in_group("player"):
		if not node is BaseCharacter:
			continue
		var character := node as BaseCharacter
		if character.is_dead or character.is_game_over or character.is_scripted_traversal_active():
			continue
		if character.global_position.distance_to(global_position) > trigger_radius:
			continue
		if absf(character.global_position.y - global_position.y) > trigger_height:
			continue
		_try_teleport(character)

func _step_cooldowns(delta: float) -> void:
	for key in _character_cooldowns.keys().duplicate():
		_character_cooldowns[key] = float(_character_cooldowns[key]) - delta
		if float(_character_cooldowns[key]) <= 0.0:
			_character_cooldowns.erase(key)
	for key in _retry_cooldowns.keys().duplicate():
		_retry_cooldowns[key] = float(_retry_cooldowns[key]) - delta
		if float(_retry_cooldowns[key]) <= 0.0:
			_retry_cooldowns.erase(key)
	if _landing_cooldown_remaining > 0.0:
		var previous := _landing_cooldown_remaining
		_landing_cooldown_remaining = maxf(0.0, _landing_cooldown_remaining - delta)
		if previous > 0.0 and _landing_cooldown_remaining <= 0.0:
			landing_cooldown_finished.emit(teleporter_id)

func _try_teleport(character: BaseCharacter) -> void:
	if _landing_cooldown_remaining > 0.0:
		return
	var key := character.get_instance_id()
	if _character_cooldowns.has(key) or _retry_cooldowns.has(key):
		return
	var choices: Array[Node3D] = []
	for destination in _destinations:
		if is_instance_valid(destination) and destination != self and not _is_destination_occupied(destination, character):
			choices.append(destination)
	_safe_candidate_count = choices.size()
	if choices.is_empty():
		_retry_cooldowns[key] = occupied_retry_seconds
		_occupied_rejection_count += 1
		teleport_rejected.emit(character, teleporter_id, &"all_destinations_occupied")
		return
	var destination := choices[_rng.randi_range(0, choices.size() - 1)] as MomentumCircuitRandomTeleporter
	_character_cooldowns[key] = cooldown_seconds
	destination._character_cooldowns[key] = landing_cooldown_seconds
	destination._begin_landing_cooldown()
	character.global_position = destination.global_position + Vector3.UP * arrival_height
	character.reset_physics_interpolation()
	character.linear_velocity = Vector3.ZERO
	character.angular_velocity = Vector3.ZERO
	_teleport_count += 1
	_last_destination = destination.teleporter_id
	teleported.emit(character, teleporter_id, destination.teleporter_id)
	destination.teleported.emit(character, teleporter_id, destination.teleporter_id)

func _begin_landing_cooldown() -> void:
	_landing_cooldown_remaining = landing_cooldown_seconds
	landing_cooldown_started.emit(teleporter_id, landing_cooldown_seconds)

func _is_destination_occupied(destination: Node3D, traveler: BaseCharacter) -> bool:
	if not is_inside_tree():
		return false
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var occupant := node as BaseCharacter
		if occupant == null or occupant == traveler or occupant.is_dead or occupant.is_game_over:
			continue
		var offset := occupant.global_position - destination.global_position
		if Vector2(offset.x, offset.z).length() <= occupied_radius and absf(offset.y) <= trigger_height + arrival_height:
			return true
	return false

func _largest_remaining(values: Dictionary) -> float:
	var result := 0.0
	for value: Variant in values.values():
		result = maxf(result, float(value))
	return result
