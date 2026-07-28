extends Node
class_name MomentumCircuitDemoTelemetry

## Runtime-only map telemetry for Demo playtests.  It records observations and
## exposes a serializable summary; it deliberately does not write files or
## alter combat, spawns, weapons, or match flow.

signal telemetry_event_recorded(event_name: StringName, payload: Dictionary)

const WARNING_TO_DEATH_WINDOW_SECONDS := 5.5
const FIELD_DEATH_WINDOW_SECONDS := 4.75

var _arena: Node = null
var _controller: Node = null
var _weapon_spawner: Node = null
var _elapsed := 0.0
var _last_warning_time := -INF
var _last_field_time := -INF
var _activation_events: Array[Dictionary] = []
var _field_deaths: Array[Dictionary] = []
var _warning_to_deaths: Array[Dictionary] = []
var _anchor_rescues: Array[Dictionary] = []
var _respawn_damage: Array[Dictionary] = []
var _respawn_deaths: Array[Dictionary] = []
var _pickup_events: Array[Dictionary] = []
var _first_pickup_time := -1.0
var _pickup_candidates: Array[Vector3] = []
var _candidate_pickup_counts: Dictionary = {}
var _character_state: Dictionary = {}
var _observed_pickups: Dictionary = {}
var _bridge_switch_events: Array[Dictionary] = []
var _teleport_events: Array[Dictionary] = []
var _teleport_rejections: Array[Dictionary] = []
var _last_teleport_key := ""
var _last_teleport_msec := 0


func _ready() -> void:
	add_to_group(&"momentum_circuit_demo_telemetry")
	call_deferred("_auto_bind")


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	_auto_bind()
	_observe_characters()
	_observe_pickups()


func configure(arena: Node, gravity_controller: Node = null, weapon_spawner: Node = null) -> void:
	_arena = arena if is_instance_valid(arena) else null
	_weapon_spawner = weapon_spawner if is_instance_valid(weapon_spawner) else null
	_bind_controller(gravity_controller)
	_refresh_pickup_candidates()

func bind_demo_mechanisms(bridge_controller: Node, teleporters: Array[Node3D]) -> void:
	if is_instance_valid(bridge_controller) and bridge_controller.has_signal("bridge_switched"):
		var bridge_callback := Callable(self, "_on_bridge_switched")
		if not bridge_controller.is_connected("bridge_switched", bridge_callback):
			bridge_controller.connect("bridge_switched", bridge_callback)
	for teleporter: Node3D in teleporters:
		if teleporter.has_signal("teleported"):
			var teleported_callback := Callable(self, "_on_demo_teleported")
			if not teleporter.is_connected("teleported", teleported_callback):
				teleporter.connect("teleported", teleported_callback)
		if teleporter.has_signal("teleport_rejected"):
			var rejected_callback := Callable(self, "_on_demo_teleport_rejected")
			if not teleporter.is_connected("teleport_rejected", rejected_callback):
				teleporter.connect("teleport_rejected", rejected_callback)


func reset() -> void:
	_elapsed = 0.0
	_last_warning_time = -INF
	_last_field_time = -INF
	_activation_events.clear()
	_field_deaths.clear()
	_warning_to_deaths.clear()
	_anchor_rescues.clear()
	_respawn_damage.clear()
	_respawn_deaths.clear()
	_pickup_events.clear()
	_first_pickup_time = -1.0
	_candidate_pickup_counts.clear()
	_character_state.clear()
	_observed_pickups.clear()
	_bridge_switch_events.clear()
	_teleport_events.clear()
	_teleport_rejections.clear()
	_last_teleport_key = ""
	_last_teleport_msec = 0


func record_activation(activator: Node3D, direction: int, attacker: Node3D = null) -> void:
	var event := {
		"time": _elapsed,
		"activator_id": String(activator.get_meta("layout_id", activator.name)) if is_instance_valid(activator) else "",
		"direction": direction,
		"attacker_instance_id": attacker.get_instance_id() if is_instance_valid(attacker) else 0,
	}
	_activation_events.append(event)
	_last_warning_time = _elapsed
	_emit_event(&"activation", event)


func record_field_death(character: BaseCharacter, reason: StringName = &"field") -> void:
	if character == null:
		return
	var event := _character_event(character)
	event["reason"] = reason
	_field_deaths.append(event)
	if _elapsed - _last_warning_time <= WARNING_TO_DEATH_WINDOW_SECONDS:
		var warning_event := event.duplicate(true)
		warning_event["warning_to_death_seconds"] = maxf(0.0, _elapsed - _last_warning_time)
		_warning_to_deaths.append(warning_event)
	_emit_event(&"field_death", event)


func record_anchor_rescue(character: BaseCharacter) -> void:
	if character == null:
		return
	var event := _character_event(character)
	_anchor_rescues.append(event)
	_emit_event(&"anchor_rescue", event)


func record_respawn_damage(character: BaseCharacter, damage: float) -> void:
	if character == null or damage <= 0.0:
		return
	var event := _character_event(character)
	event["damage"] = damage
	_respawn_damage.append(event)
	_emit_event(&"respawn_damage", event)


func record_respawn_death(character: BaseCharacter, reason: StringName = &"death") -> void:
	if character == null:
		return
	var event := _character_event(character)
	event["reason"] = reason
	_respawn_deaths.append(event)
	_emit_event(&"respawn_death", event)


func record_pickup(pickup: Node3D) -> void:
	if pickup == null:
		return
	var candidate_index := _nearest_candidate_index(pickup.global_position)
	var event := {
		"time": _elapsed,
		"content_id": String(pickup.get_meta("pickup_content_id", "")),
		"candidate_index": candidate_index,
		"position": pickup.global_position,
	}
	_pickup_events.append(event)
	if _first_pickup_time < 0.0:
		_first_pickup_time = _elapsed
	if candidate_index >= 0:
		_candidate_pickup_counts[candidate_index] = int(_candidate_pickup_counts.get(candidate_index, 0)) + 1
	_emit_event(&"pickup", event)


func get_summary() -> Dictionary:
	return {
		"elapsed_seconds": _elapsed,
		"activations": _activation_events.duplicate(true),
		"activation_count": _activation_events.size(),
		"field_deaths": _field_deaths.duplicate(true),
		"field_death_count": _field_deaths.size(),
		"warning_to_deaths": _warning_to_deaths.duplicate(true),
		"warning_to_death_count": _warning_to_deaths.size(),
		"anchor_rescues": _anchor_rescues.duplicate(true),
		"anchor_rescue_count": _anchor_rescues.size(),
		"respawn_damage": _respawn_damage.duplicate(true),
		"respawn_damage_count": _respawn_damage.size(),
		"respawn_deaths": _respawn_deaths.duplicate(true),
		"respawn_death_count": _respawn_deaths.size(),
		"first_pickup_time": _first_pickup_time,
		"pickup_count": _pickup_events.size(),
		"pickup_candidate_distribution": _candidate_pickup_counts.duplicate(true),
		"bridge_switch_count": _bridge_switch_events.size(),
		"bridge_switches": _bridge_switch_events.duplicate(true),
		"teleport_count": _teleport_events.size(),
		"teleports": _teleport_events.duplicate(true),
		"teleport_rejection_count": _teleport_rejections.size(),
		"teleport_rejections": _teleport_rejections.duplicate(true),
	}


func _on_bridge_switched(previous_bridge_id: String, active_bridge_id: String, switch_serial: int) -> void:
	var event := {
		"time": _elapsed,
		"previous_bridge_id": previous_bridge_id,
		"active_bridge_id": active_bridge_id,
		"switch_serial": switch_serial,
	}
	_bridge_switch_events.append(event)
	_emit_event(&"bridge_switched", event)


func _on_demo_teleported(character: BaseCharacter, source_id: String, destination_id: String) -> void:
	var key := "%d:%s:%s" % [character.get_instance_id(), source_id, destination_id]
	var now := Time.get_ticks_msec()
	if key == _last_teleport_key and now - _last_teleport_msec < 40:
		return
	_last_teleport_key = key
	_last_teleport_msec = now
	var event := _character_event(character)
	event["source_id"] = source_id
	event["destination_id"] = destination_id
	_teleport_events.append(event)
	_emit_event(&"teleported", event)


func _on_demo_teleport_rejected(character: BaseCharacter, source_id: String, reason: StringName) -> void:
	var event := _character_event(character)
	event["source_id"] = source_id
	event["reason"] = reason
	_teleport_rejections.append(event)
	_emit_event(&"teleport_rejected", event)


func _auto_bind() -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(_arena):
		_arena = get_tree().current_scene
	if not is_instance_valid(_controller):
		_bind_controller(get_tree().get_first_node_in_group(&"momentum_circuit_gravity_controller"))
	if not is_instance_valid(_weapon_spawner) and is_instance_valid(_arena):
		_weapon_spawner = _arena.get_node_or_null("WeaponSpawner")
	if _pickup_candidates.is_empty():
		_refresh_pickup_candidates()


func _bind_controller(controller: Node) -> void:
	if controller == _controller:
		return
	if is_instance_valid(_controller):
		_disconnect_if_connected(_controller, &"activation_accepted", Callable(self, "_on_activation_accepted"))
		_disconnect_if_connected(_controller, &"state_changed", Callable(self, "_on_state_changed"))
		_disconnect_if_connected(_controller, &"character_stabilized", Callable(self, "_on_character_stabilized"))
	_controller = controller if is_instance_valid(controller) else null
	if not is_instance_valid(_controller):
		return
	_connect_if_available(_controller, &"activation_accepted", Callable(self, "_on_activation_accepted"))
	_connect_if_available(_controller, &"state_changed", Callable(self, "_on_state_changed"))
	_connect_if_available(_controller, &"character_stabilized", Callable(self, "_on_character_stabilized"))


func _on_activation_accepted(activator: Node3D, direction: int, attacker: Node3D) -> void:
	record_activation(activator, direction, attacker)


func _on_state_changed(_previous: StringName, state: StringName, _direction: int, _serial: int) -> void:
	if state == &"warning":
		_last_warning_time = _elapsed
	if state == &"active":
		_last_field_time = _elapsed


func _on_character_stabilized(character: BaseCharacter, stabilized: bool) -> void:
	if not stabilized or not is_instance_valid(_controller):
		return
	var debug := _controller.call("get_debug_state") as Dictionary
	var context := _controller.call("get_character_context", character) as Dictionary
	var active_state := String(debug.get("state", "")) in ["active", "reversing", "recovery"]
	var recorded_velocity := absf(float(context.get("environment_velocity_x", 0.0)))
	if active_state or recorded_velocity > 0.25:
		record_anchor_rescue(character)


func _observe_characters() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var character := node as BaseCharacter
		if character == null:
			continue
		var id := character.get_instance_id()
		var previous: Dictionary = _character_state.get(id, {
			"dead": character.is_dead,
			"hp": character.current_hp,
			"respawn_started": -INF,
		})
		var was_dead := bool(previous.get("dead", false))
		var hp_before := float(previous.get("hp", character.current_hp))
		var respawn_started := float(previous.get("respawn_started", -INF))
		if was_dead and not character.is_dead:
			respawn_started = _elapsed
		if not was_dead and character.is_dead:
			var field_context: Dictionary = (
				_controller.call("get_character_context", character)
				if is_instance_valid(_controller) and _controller.has_method("get_character_context")
				else {}
			)
			var has_field_velocity := absf(float(field_context.get("environment_velocity_x", 0.0))) > 0.25
			if has_field_velocity and _elapsed - _last_field_time <= FIELD_DEATH_WINDOW_SECONDS:
				record_field_death(character)
			if _elapsed - respawn_started <= WARNING_TO_DEATH_WINDOW_SECONDS:
				record_respawn_death(character)
		if not character.is_dead and character.current_hp < hp_before - 0.01 \
			and _elapsed - respawn_started <= WARNING_TO_DEATH_WINDOW_SECONDS:
			record_respawn_damage(character, hp_before - character.current_hp)
		_character_state[id] = {
			"dead": character.is_dead,
			"hp": character.current_hp,
			"respawn_started": respawn_started,
		}


func _observe_pickups() -> void:
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"weapon_pickup"):
		var pickup := node as Node3D
		if pickup == null:
			continue
		var id := pickup.get_instance_id()
		if _observed_pickups.has(id):
			continue
		_observed_pickups[id] = true
		if pickup.has_signal("picked_up"):
			pickup.connect("picked_up", func() -> void: record_pickup(pickup), Object.CONNECT_ONE_SHOT)


func _refresh_pickup_candidates() -> void:
	_pickup_candidates.clear()
	if not is_instance_valid(_weapon_spawner):
		return
	var raw: Variant = _weapon_spawner.get("custom_spawn_points")
	if raw is Array:
		for value: Variant in raw:
			if value is Vector3:
				_pickup_candidates.append(value as Vector3)


func _nearest_candidate_index(position: Vector3) -> int:
	if _pickup_candidates.is_empty():
		return -1
	var best_index := -1
	var best_distance := INF
	for index in range(_pickup_candidates.size()):
		var distance := position.distance_to(_pickup_candidates[index])
		if distance < best_distance:
			best_index = index
			best_distance = distance
	return best_index


func _character_event(character: BaseCharacter) -> Dictionary:
	return {
		"time": _elapsed,
		"character_instance_id": character.get_instance_id(),
		"character_name": String(character.name),
		"position": character.global_position,
	}


func _connect_if_available(source: Node, signal_name: StringName, callback: Callable) -> void:
	if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
		source.connect(signal_name, callback)


func _disconnect_if_connected(source: Node, signal_name: StringName, callback: Callable) -> void:
	if source.has_signal(signal_name) and source.is_connected(signal_name, callback):
		source.disconnect(signal_name, callback)


func _emit_event(event_name: StringName, payload: Dictionary) -> void:
	telemetry_event_recorded.emit(event_name, payload)
