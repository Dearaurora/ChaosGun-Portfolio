extends Node
class_name MomentumCircuitAIDirector

## Map-local, one-shot interaction policy for Momentum Circuit.  It never
## changes an AI's target, state, navigation, auto-aim, or weapon balance: it
## only offers a precise, opportunistic shot when toggling the field can help
## an otherwise safe AI threaten an exposed enemy.

signal ai_interaction_fired(ai: BaseCharacter, activator: Node3D, direction: int)

const MAX_ACTIVATOR_DISTANCE := 24.0
const ENEMY_DANGER_PROBE_DISTANCE := 10.0
const AI_DECISION_COOLDOWN_SECONDS := 4.0
const GLOBAL_INTERACTION_PACING_SECONDS := 6.5
const GROUND_COLLISION_MASK := 1

var _controller: Node = null
var _activators: Array[Node3D] = []
var _cooldown_until: Dictionary = {}
var _global_cooldown_until := 0.0
var _request_serial := 0
var _requests_offered := 0
var _shots_fired := 0
var _rejected_for_safety := 0


func _ready() -> void:
	add_to_group(&"party_shooter_ai_interaction_provider")
	call_deferred("_auto_bind")


func configure(gravity_controller: Node, activators: Array = []) -> void:
	_controller = gravity_controller if is_instance_valid(gravity_controller) else null
	_activators.clear()
	for value: Variant in activators:
		var activator := value as Node3D
		if activator != null and is_instance_valid(activator):
			_activators.append(activator)
	_sort_activators()


## Optional shared-AI contract.  An empty response means this map has no
## interaction to make this frame, so normal enemy/pickup behavior continues
## unchanged.  Returned requests are ephemeral; they do not become AI targets.
func get_ai_interaction_request(ai: Node3D) -> Dictionary:
	if not _ensure_bindings() or ai == null or not is_instance_valid(ai):
		return {}
	var character := ai as BaseCharacter
	if character == null or character.is_dead or character.is_game_over:
		return {}
	if character.has_method("is_fleeing_edge") and bool(character.call("is_fleeing_edge")):
		return {}
	if _cooldown_remaining(character) > 0.0:
		return {}
	if _now_seconds() < _global_cooldown_until:
		return {}
	var controller_debug := _controller.call("get_debug_state") as Dictionary
	if not _controller_is_ready(controller_debug):
		return {}
	var next_direction := int(_controller.call("preview_next_direction"))
	if next_direction == 0:
		return {}
	var active_direction := int(controller_debug.get("direction", 0))
	if String(controller_debug.get("state", "")) == "active" \
		and active_direction != 0 \
		and _is_force_edge_danger(character, active_direction):
		_rejected_for_safety += 1
		return {}
	if _is_force_edge_danger(character, next_direction):
		_rejected_for_safety += 1
		return {}
	var activator := _nearest_visible_ready_activator(character)
	if activator == null:
		return {}
	var threatened_enemy := _find_threatened_enemy(character, next_direction)
	if threatened_enemy == null:
		return {}
	_request_serial += 1
	_requests_offered += 1
	return {
		"provider": self,
		"request_id": _request_serial,
		"target": activator,
		"aim_position": activator.global_position + Vector3.UP * 0.60,
		"max_distance": MAX_ACTIVATOR_DISTANCE,
		"decision_cooldown": AI_DECISION_COOLDOWN_SECONDS,
		"reason": &"enemy_exposed_to_next_gravity_direction",
		"direction": next_direction,
		"threatened_enemy": threatened_enemy,
	}


## The shared AI calls this only after WeaponManager.try_fire.  Cooldown starts
## on a real shot, not on an unavailable weapon or a rejected request.
func commit_ai_interaction_shot(ai: Node3D, request: Dictionary, fired: bool) -> void:
	if not fired or ai == null or not is_instance_valid(ai):
		return
	if request.get("provider") != self:
		return
	var character := ai as BaseCharacter
	var activator := request.get("target") as Node3D
	if character == null or activator == null or not is_instance_valid(activator):
		return
	_cooldown_until[character.get_instance_id()] = _now_seconds() + AI_DECISION_COOLDOWN_SECONDS
	_global_cooldown_until = _now_seconds() + GLOBAL_INTERACTION_PACING_SECONDS
	_shots_fired += 1
	ai_interaction_fired.emit(character, activator, int(request.get("direction", 0)))


func get_debug_state() -> Dictionary:
	var live_cooldowns := 0
	for value: Variant in _cooldown_until.values():
		if float(value) > _now_seconds():
			live_cooldowns += 1
	return {
		"controller_valid": is_instance_valid(_controller),
		"activator_count": _activators.size(),
		"max_activator_distance": MAX_ACTIVATOR_DISTANCE,
		"enemy_danger_probe_distance": ENEMY_DANGER_PROBE_DISTANCE,
		"ai_decision_cooldown_seconds": AI_DECISION_COOLDOWN_SECONDS,
		"global_interaction_pacing_seconds": GLOBAL_INTERACTION_PACING_SECONDS,
		"requests_offered": _requests_offered,
		"shots_fired": _shots_fired,
		"safety_rejections": _rejected_for_safety,
		"active_ai_cooldowns": live_cooldowns,
	}


func _auto_bind() -> void:
	if not is_instance_valid(_controller) and is_inside_tree():
		_controller = get_tree().get_first_node_in_group(&"momentum_circuit_gravity_controller")
	if _activators.is_empty() and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"momentum_circuit_gravity_activator"):
			var activator := node as Node3D
			if activator != null:
				_activators.append(activator)
		_sort_activators()


func _ensure_bindings() -> bool:
	if not is_instance_valid(_controller) or _activators.is_empty():
		_auto_bind()
	return is_instance_valid(_controller) and not _activators.is_empty() \
		and _controller.has_method("get_debug_state") \
		and _controller.has_method("preview_next_direction")


func _controller_is_ready(debug: Dictionary) -> bool:
	var state := String(debug.get("state", ""))
	if state != "idle" and state != "active":
		return false
	return float(debug.get("global_guard_remaining", 0.0)) <= 0.001


func _nearest_visible_ready_activator(ai: BaseCharacter) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance := INF
	for activator: Node3D in _activators:
		if not is_instance_valid(activator) or not _activator_is_ready(activator):
			continue
		var distance := ai.global_position.distance_to(activator.global_position)
		if distance > MAX_ACTIVATOR_DISTANCE or distance >= nearest_distance:
			continue
		if not _has_line_of_sight(ai, activator):
			continue
		nearest = activator
		nearest_distance = distance
	return nearest


func _activator_is_ready(activator: Node3D) -> bool:
	return activator.has_method("is_ready_to_activate") \
		and bool(activator.call("is_ready_to_activate"))


func _find_threatened_enemy(ai: BaseCharacter, direction: int) -> BaseCharacter:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var enemy := node as BaseCharacter
		if enemy == null or enemy == ai or enemy.is_dead or enemy.is_game_over:
			continue
		if ai.is_friendly_to(enemy):
			continue
		if not _character_is_in_corridor(enemy):
			continue
		if _is_force_edge_danger(enemy, direction):
			return enemy
	return null


func _character_is_in_corridor(character: BaseCharacter) -> bool:
	if not _controller.has_method("get_character_context"):
		return false
	var context := _controller.call("get_character_context", character) as Dictionary
	return bool(context.get("in_corridor", false))


func _is_force_edge_danger(character: BaseCharacter, direction: int) -> bool:
	if not _character_is_in_corridor(character):
		return false
	var world := _world_3d()
	if world == null:
		return false
	var probe_direction := Vector3(float(direction), 0.0, 0.0)
	var origin := character.global_position + probe_direction * ENEMY_DANGER_PROBE_DISTANCE + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 12.0)
	query.collision_mask = GROUND_COLLISION_MASK
	query.collide_with_areas = false
	query.exclude = _player_rids()
	return world.direct_space_state.intersect_ray(query).is_empty()


func _has_line_of_sight(ai: BaseCharacter, activator: Node3D) -> bool:
	var world := _world_3d()
	if world == null:
		return false
	var origin := ai.weapon_point.global_position if ai.weapon_point else ai.global_position + Vector3.UP
	var destination := activator.global_position + Vector3.UP * 0.60
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collide_with_areas = false
	query.hit_from_inside = true
	query.exclude = [ai.get_rid()]
	var hit := world.direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == activator


func _player_rids() -> Array[RID]:
	var result: Array[RID] = []
	if not is_inside_tree():
		return result
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var body := node as CollisionObject3D
		if body != null:
			result.append(body.get_rid())
	return result


func _world_3d() -> World3D:
	var spatial_controller := _controller as Node3D
	if spatial_controller != null and spatial_controller.is_inside_tree():
		return spatial_controller.get_world_3d()
	for activator: Node3D in _activators:
		if is_instance_valid(activator) and activator.is_inside_tree():
			return activator.get_world_3d()
	return null


func _cooldown_remaining(ai: BaseCharacter) -> float:
	var deadline := float(_cooldown_until.get(ai.get_instance_id(), 0.0))
	return maxf(0.0, deadline - _now_seconds())


func _sort_activators() -> void:
	_activators.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return String(a.get_meta("layout_id", a.name)) < String(b.get_meta("layout_id", b.name))
	)


func _now_seconds() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0
