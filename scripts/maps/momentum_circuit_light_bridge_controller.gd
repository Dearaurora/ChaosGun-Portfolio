extends Node3D
class_name MomentumCircuitLightBridgeController

signal bridge_state_changed(state: StringName, active_bridge_id: String, next_bridge_id: String)
signal bridge_switched(previous_bridge_id: String, active_bridge_id: String, switch_serial: int)
signal traversal_started(character: BaseCharacter, bridge_id: String, origin_bank: Vector3, destination_bank: Vector3)
signal traversal_bounced(character: BaseCharacter, bridge_id: String, return_bank: Vector3)
signal traversal_completed(character: BaseCharacter, bridge_id: String, result: StringName)

const STATE_ACTIVE := &"ACTIVE"
const STATE_WARNING := &"WARNING"
const STATE_SWITCHING := &"SWITCHING"
const TRAVERSAL_CROSSING := &"crossing"
const TRAVERSAL_RETURNING := &"returning"

var _config: Dictionary = {}
var _specs: Dictionary = {}
var _order: Array[String] = []
var _collision_shapes: Dictionary = {}
var _active_order_index := 0
var _state: StringName = STATE_ACTIVE
var _state_elapsed := 0.0
var _switch_serial := 0
var _configured := false
var _traversals: Dictionary = {}
var _arrival_lockouts: Dictionary = {}
var _traversal_started_count := 0
var _traversal_completed_count := 0
var _collision_bounce_count := 0
var _warning_return_count := 0


func configure(config: Dictionary) -> void:
	_release_all_traversals()
	_config = config.duplicate(true)
	_specs.clear()
	_order.clear()
	_collision_shapes.clear()
	for value: Variant in _config.get("order", []):
		_order.append(String(value))
	for value: Variant in _config.get("bridges", []):
		var spec := (value as Dictionary).duplicate(true)
		_specs[String(spec.get("id", ""))] = spec
	_active_order_index = 0
	_state = STATE_ACTIVE
	_state_elapsed = 0.0
	_switch_serial = 0
	_arrival_lockouts.clear()
	_traversal_started_count = 0
	_traversal_completed_count = 0
	_collision_bounce_count = 0
	_warning_return_count = 0
	_build_collision_bodies()
	_configured = _order.size() == 3 and _collision_shapes.size() == 3
	if not is_in_group(&"momentum_circuit_light_bridge_controller"):
		add_to_group(&"momentum_circuit_light_bridge_controller")
	if not is_in_group(&"party_shooter_ai_hazard_provider"):
		add_to_group(&"party_shooter_ai_hazard_provider")
	_apply_collision_state()
	_emit_state_changed()


func _physics_process(delta: float) -> void:
	_step_arrival_lockouts(delta)
	if _state == STATE_ACTIVE or _state == STATE_WARNING:
		_scan_for_traversals()
	_step_traversals(delta)
	_advance(delta)


func test_step(delta: float) -> void:
	_advance(delta)


func test_scan_for_traversals() -> void:
	_scan_for_traversals()


func test_traversal_step(delta: float) -> void:
	_step_arrival_lockouts(delta)
	_step_traversals(delta)


func get_debug_state() -> Dictionary:
	var duration := _duration_for_state(_state)
	var enabled_ids: Array[String] = []
	for bridge_id: String in _collision_shapes:
		var shape := _collision_shapes[bridge_id] as CollisionShape3D
		if is_instance_valid(shape) and not shape.disabled:
			enabled_ids.append(bridge_id)
	enabled_ids.sort()
	var traversing_ids: Array[int] = []
	var returning_count := 0
	for id_value: Variant in _traversals:
		var character_id := int(id_value)
		traversing_ids.append(character_id)
		var traversal := _traversals.get(character_id, {}) as Dictionary
		if StringName(traversal.get("mode", TRAVERSAL_CROSSING)) == TRAVERSAL_RETURNING:
			returning_count += 1
	traversing_ids.sort()
	return {
		"state": String(_state),
		"active_bridge_id": _active_bridge_id(),
		"next_bridge_id": _next_bridge_id(),
		"state_elapsed": _state_elapsed,
		"state_duration": duration,
		"state_progress": clampf(_state_elapsed / maxf(duration, 0.001), 0.0, 1.0),
		"active_seconds": float(_config.get("active_seconds", 8.0)),
		"warning_seconds": float(_config.get("warning_seconds", 2.0)),
		"switching_seconds": float(_config.get("switching_seconds", 0.45)),
		"bridge_width": float(_config.get("width", 4.0)),
		"bridge_count": _specs.size(),
		"order": _order.duplicate(),
		"collision_enabled_ids": enabled_ids,
		"switch_serial": _switch_serial,
		"configured": _configured,
		"forced_traversal_enabled": bool(_config.get("forced_traversal_enabled", false)),
		"traversal_speed": float(_config.get("traversal_speed", 13.0)),
		"bounce_speed": float(_config.get("bounce_speed", 15.0)),
		"active_traversal_count": _traversals.size(),
		"returning_traversal_count": returning_count,
		"traversing_character_ids": traversing_ids,
		"traversal_started_count": _traversal_started_count,
		"traversal_completed_count": _traversal_completed_count,
		"collision_bounce_count": _collision_bounce_count,
		"warning_return_count": _warning_return_count,
	}


func get_bridge_specs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for bridge_id: String in _order:
		result.append((_specs.get(bridge_id, {}) as Dictionary).duplicate(true))
	return result


func get_ai_movement_bias(ai: Node) -> Dictionary:
	var none := {"direction": Vector3.ZERO, "weight": 0.0, "reason": "not_on_warning_bridge"}
	if _state != STATE_WARNING or not ai is Node3D:
		return none
	var bridge_id := _active_bridge_id()
	var spec := _specs.get(bridge_id, {}) as Dictionary
	if spec.is_empty():
		return none
	var point := (ai as Node3D).global_position
	var segment := _segment_world(spec)
	var start := segment[0] as Vector3
	var finish := segment[1] as Vector3
	var flat_segment := Vector2(finish.x - start.x, finish.z - start.z)
	var flat_offset := Vector2(point.x - start.x, point.z - start.z)
	var projection := flat_offset.dot(flat_segment) / maxf(flat_segment.length_squared(), 0.001)
	if projection < 0.0 or projection > 1.0:
		return none
	var closest := Geometry3D.get_closest_point_to_segment(point, start, finish)
	var width := float(_config.get("width", 4.0))
	if Vector2(point.x - closest.x, point.z - closest.z).length() > width * 0.5 + 0.35:
		return none
	if absf(point.y - float(_config.get("top_y", 1.06))) > 2.2:
		return none
	var use_start := point.distance_squared_to(start) <= point.distance_squared_to(finish)
	var bank_direction := (start - finish).normalized() if use_start else (finish - start).normalized()
	var destination := (start if use_start else finish) + bank_direction * 1.6
	var direction := destination - point
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return none
	return {
		"direction": direction.normalized(),
		"weight": float(_config.get("ai_warning_bias_weight", 0.85)),
		"reason": "warning_bridge_nearest_bank",
		"bridge_id": bridge_id,
	}


func _scan_for_traversals() -> void:
	if not _configured or (_state != STATE_ACTIVE and _state != STATE_WARNING) or not bool(_config.get("forced_traversal_enabled", false)):
		return
	var bridge_id := _active_bridge_id()
	var spec := _specs.get(bridge_id, {}) as Dictionary
	if spec.is_empty():
		return
	var candidates: Array[BaseCharacter] = []
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		if not node is BaseCharacter:
			continue
		var character := node as BaseCharacter
		var character_id := character.get_instance_id()
		if character.is_dead or character.is_game_over or character.is_scripted_traversal_active():
			continue
		if _arrival_lockouts.has(character_id):
			continue
		if _is_character_inside_capture(character, spec):
			candidates.append(character)
	candidates.sort_custom(func(a: BaseCharacter, b: BaseCharacter) -> bool: return a.get_instance_id() < b.get_instance_id())
	for character: BaseCharacter in candidates:
		if is_instance_valid(character) and not character.is_scripted_traversal_active():
			_start_traversal(character, bridge_id, spec, _state == STATE_WARNING)


func _is_character_inside_capture(character: BaseCharacter, spec: Dictionary) -> bool:
	var segment := _segment_world(spec)
	var start := segment[0] as Vector3
	var finish := segment[1] as Vector3
	var point := character.global_position
	var flat_segment := Vector2(finish.x - start.x, finish.z - start.z)
	var flat_offset := Vector2(point.x - start.x, point.z - start.z)
	var length := flat_segment.length()
	if length <= 0.001:
		return false
	var projection := flat_offset.dot(flat_segment) / maxf(flat_segment.length_squared(), 0.001)
	var inset_ratio := clampf(float(_config.get("capture_inset", 0.65)) / length, 0.0, 0.45)
	if projection < inset_ratio or projection > 1.0 - inset_ratio:
		return false
	var closest2 := Vector2(start.x, start.z) + flat_segment * projection
	var lateral_distance := Vector2(point.x, point.z).distance_to(closest2)
	if lateral_distance > float(_config.get("width", 4.0)) * 0.5 + float(_config.get("capture_lateral_margin", 0.30)):
		return false
	return absf(point.y - float(_config.get("top_y", 1.06))) <= float(_config.get("capture_vertical_range", 2.6))


func _start_traversal(character: BaseCharacter, bridge_id: String, spec: Dictionary, force_return: bool) -> void:
	if not character.begin_scripted_traversal(self):
		return
	var segment := _segment_world(spec)
	var start := segment[0] as Vector3
	var finish := segment[1] as Vector3
	var direction := (finish - start).normalized()
	var projection := _projection_on_segment(character.global_position, start, finish)
	var clearance := float(_config.get("bank_clearance", 1.6))
	var origin := start - direction * clearance
	var destination := finish + direction * clearance
	if projection > 0.5:
		origin = finish + direction * clearance
		destination = start - direction * clearance
	var travel_y := maxf(character.global_position.y, float(_config.get("top_y", 1.06)) + 0.65)
	origin.y = travel_y
	destination.y = travel_y
	var path_start := character.global_position
	path_start.y = travel_y
	var character_id := character.get_instance_id()
	var speed := maxf(float(_config.get("traversal_speed", 13.0)), 0.1)
	var traversal := {
		"character": character,
		"bridge_id": bridge_id,
		"origin": origin,
		"destination": destination,
		"path_start": path_start,
		"path_end": destination,
		"elapsed": 0.0,
		"duration": maxf(path_start.distance_to(destination) / speed, 0.12),
		"mode": TRAVERSAL_CROSSING,
		"saved_invincible": character.is_invincible,
	}
	character.is_invincible = true
	_traversals[character_id] = traversal
	_traversal_started_count += 1
	traversal_started.emit(character, bridge_id, origin, destination)
	if force_return:
		_warning_return_count += 1
		_set_traversal_returning(character_id)
	if _count_traversals_on_bridge(bridge_id) >= 2:
		_bounce_all_on_bridge(bridge_id)


func _step_traversals(delta: float) -> void:
	if delta <= 0.0 or _traversals.is_empty():
		return
	var completed: Array[int] = []
	for id_value: Variant in _traversals.keys():
		var character_id := int(id_value)
		var traversal := _traversals.get(character_id, {}) as Dictionary
		var character_value: Variant = traversal.get("character")
		if not is_instance_valid(character_value):
			completed.append(character_id)
			continue
		var character := character_value as BaseCharacter
		if not character.is_inside_tree():
			_finish_traversal(character_id, true)
			continue
		if character.is_dead or character.is_game_over or not character.is_scripted_traversal_active():
			_finish_traversal(character_id, true)
			continue
		var duration := maxf(float(traversal.get("duration", 0.12)), 0.001)
		var elapsed := minf(float(traversal.get("elapsed", 0.0)) + delta, duration)
		traversal["elapsed"] = elapsed
		_traversals[character_id] = traversal
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var eased := progress * progress * (3.0 - 2.0 * progress)
		var position := (traversal.get("path_start", character.global_position) as Vector3).lerp(
			traversal.get("path_end", character.global_position) as Vector3,
			eased
		)
		position.y += sin(progress * PI) * float(_config.get("arc_height", 0.35))
		character.update_scripted_traversal_position(self, position)
		if progress >= 1.0:
			completed.append(character_id)
	for character_id: int in completed:
		if _traversals.has(character_id):
			_finish_traversal(character_id, false)


func _bounce_all_on_bridge(bridge_id: String) -> void:
	_collision_bounce_count += 1
	for id_value: Variant in _traversals.keys():
		var character_id := int(id_value)
		var traversal := _traversals.get(character_id, {}) as Dictionary
		if String(traversal.get("bridge_id", "")) != bridge_id:
			continue
		_set_traversal_returning(character_id)


func _set_traversal_returning(character_id: int) -> void:
	if not _traversals.has(character_id):
		return
	var traversal := _traversals.get(character_id, {}) as Dictionary
	var character_value: Variant = traversal.get("character")
	if not is_instance_valid(character_value):
		return
	var character := character_value as BaseCharacter
	if not character.is_inside_tree():
		_finish_traversal(character_id, true)
		return
	var return_bank := traversal.get("origin", character.global_position) as Vector3
	var path_start := character.global_position
	var speed := maxf(float(_config.get("bounce_speed", 15.0)), 0.1)
	traversal["path_start"] = path_start
	traversal["path_end"] = return_bank
	traversal["elapsed"] = 0.0
	traversal["duration"] = maxf(path_start.distance_to(return_bank) / speed, 0.12)
	traversal["mode"] = TRAVERSAL_RETURNING
	_traversals[character_id] = traversal
	traversal_bounced.emit(character, String(traversal.get("bridge_id", "")), return_bank)


func _finish_traversal(character_id: int, force_origin: bool) -> void:
	if not _traversals.has(character_id):
		return
	var traversal := _traversals.get(character_id, {}) as Dictionary
	_traversals.erase(character_id)
	var character_value: Variant = traversal.get("character")
	if not is_instance_valid(character_value):
		return
	var character := character_value as BaseCharacter
	if not character.is_inside_tree():
		character.is_invincible = bool(traversal.get("saved_invincible", false))
		character.release_scripted_traversal(self, Vector3.ZERO)
		return
	var mode := StringName(traversal.get("mode", TRAVERSAL_CROSSING))
	var landing := traversal.get("origin" if force_origin else "path_end", character.global_position) as Vector3
	character.update_scripted_traversal_position(self, landing)
	character.is_invincible = bool(traversal.get("saved_invincible", false))
	character.release_scripted_traversal(self, Vector3.ZERO)
	_arrival_lockouts[character_id] = float(_config.get("arrival_lockout", 0.40))
	_traversal_completed_count += 1
	traversal_completed.emit(character, String(traversal.get("bridge_id", "")), mode)


func _step_arrival_lockouts(delta: float) -> void:
	if delta <= 0.0 or _arrival_lockouts.is_empty():
		return
	for id_value: Variant in _arrival_lockouts.keys():
		var character_id := int(id_value)
		var remaining := float(_arrival_lockouts.get(character_id, 0.0)) - delta
		if remaining <= 0.0:
			_arrival_lockouts.erase(character_id)
		else:
			_arrival_lockouts[character_id] = remaining


func _count_traversals_on_bridge(bridge_id: String) -> int:
	var count := 0
	for traversal_value: Variant in _traversals.values():
		var traversal := traversal_value as Dictionary
		if String(traversal.get("bridge_id", "")) == bridge_id:
			count += 1
	return count


func _projection_on_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var flat_segment := Vector2(finish.x - start.x, finish.z - start.z)
	var flat_offset := Vector2(point.x - start.x, point.z - start.z)
	return clampf(flat_offset.dot(flat_segment) / maxf(flat_segment.length_squared(), 0.001), 0.0, 1.0)


func _release_all_traversals() -> void:
	for id_value: Variant in _traversals.keys():
		_finish_traversal(int(id_value), true)
	_traversals.clear()


func _exit_tree() -> void:
	_release_all_traversals()


func _advance(delta: float) -> void:
	if not _configured or delta <= 0.0:
		return
	var remaining := delta
	var guard := 0
	while remaining > 0.000001 and guard < 16:
		guard += 1
		var duration := _duration_for_state(_state)
		var until_transition := maxf(0.0, duration - _state_elapsed)
		if remaining + 0.000001 < until_transition:
			_state_elapsed += remaining
			remaining = 0.0
		else:
			remaining = maxf(0.0, remaining - until_transition)
			_state_elapsed = duration
			_transition_state()


func _transition_state() -> void:
	match _state:
		STATE_ACTIVE:
			_state = STATE_WARNING
			_state_elapsed = 0.0
			_emit_state_changed()
		STATE_WARNING:
			_state = STATE_SWITCHING
			_state_elapsed = 0.0
			_apply_collision_state()
			_emit_state_changed()
		STATE_SWITCHING:
			var previous := _active_bridge_id()
			_active_order_index = (_active_order_index + 1) % _order.size()
			_switch_serial += 1
			_state = STATE_ACTIVE
			_state_elapsed = 0.0
			_apply_collision_state()
			bridge_switched.emit(previous, _active_bridge_id(), _switch_serial)
			_emit_state_changed()


func _duration_for_state(state: StringName) -> float:
	match state:
		STATE_WARNING:
			return float(_config.get("warning_seconds", 2.0))
		STATE_SWITCHING:
			return float(_config.get("switching_seconds", 0.45))
		_:
			return float(_config.get("active_seconds", 8.0))


func _active_bridge_id() -> String:
	return _order[_active_order_index] if not _order.is_empty() else ""


func _next_bridge_id() -> String:
	return _order[(_active_order_index + 1) % _order.size()] if not _order.is_empty() else ""


func _emit_state_changed() -> void:
	bridge_state_changed.emit(_state, _active_bridge_id(), _next_bridge_id())


func _build_collision_bodies() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for bridge_id: String in _order:
		var spec := _specs.get(bridge_id, {}) as Dictionary
		var segment := _segment_world(spec)
		var start := segment[0] as Vector3
		var finish := segment[1] as Vector3
		var direction := finish - start
		var length := Vector2(direction.x, direction.z).length()
		var thickness := float(_config.get("thickness", 0.18))
		var body := StaticBody3D.new()
		body.name = "LightBridgeCollision_%s" % bridge_id
		body.collision_layer = 1
		body.collision_mask = 1
		body.position = (start + finish) * 0.5 - Vector3.UP * thickness * 0.5
		body.rotation.y = atan2(direction.x, direction.z)
		body.add_to_group(&"momentum_circuit_light_bridge_collision")
		body.set_meta("bridge_id", bridge_id)
		body.set_meta("hole_id", String(spec.get("hole_id", "")))
		add_child(body)
		var collision := CollisionShape3D.new()
		collision.name = "BridgeCollision"
		var box := BoxShape3D.new()
		box.size = Vector3(float(_config.get("width", 4.0)), thickness, length)
		collision.shape = box
		body.add_child(collision)
		_collision_shapes[bridge_id] = collision


func _apply_collision_state() -> void:
	var enabled_id := _active_bridge_id() if _state != STATE_SWITCHING else ""
	for bridge_id: String in _collision_shapes:
		var shape := _collision_shapes[bridge_id] as CollisionShape3D
		shape.disabled = bridge_id != enabled_id


func _segment_world(spec: Dictionary) -> Array[Vector3]:
	var start_values := spec.get("start_xz", []) as Array
	var end_values := spec.get("end_xz", []) as Array
	var top_y := float(_config.get("top_y", 1.06))
	return [
		Vector3(float(start_values[0]), top_y, float(start_values[1])),
		Vector3(float(end_values[0]), top_y, float(end_values[1])),
	]
