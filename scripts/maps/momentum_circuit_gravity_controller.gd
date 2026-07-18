extends Node3D
class_name MomentumCircuitGravityController

## Shared horizontal pseudo-gravity field for Momentum Circuit.
##
## The controller records only the X velocity that it contributes.  Field
## acceleration, reversal/recovery braking, and stabilizer braking therefore
## never rewrite a character's complete velocity or its vertical component.

signal state_changed(
	previous_state: StringName,
	state: StringName,
	direction: int,
	activation_serial: int
)
signal activation_accepted(activator: Node3D, direction: int, attacker: Node3D)
signal activation_rejected(reason: StringName, activator: Node3D)
signal character_stabilized(character: BaseCharacter, stabilized: bool)

enum State {
	IDLE,
	WARNING,
	ACTIVE,
	REVERSING,
	RECOVERY,
}

const DEFAULT_CORRIDOR_MIN_X := 2.0
const DEFAULT_CORRIDOR_MIN_Y := -4.0
const DEFAULT_CORRIDOR_MAX_Y := 7.0
const DEFAULT_WARNING_SECONDS := 1.25
const DEFAULT_ACTIVE_SECONDS := 4.0
const DEFAULT_REVERSING_SECONDS := 0.65
const DEFAULT_RECOVERY_SECONDS := 0.75
const DEFAULT_GLOBAL_GUARD_SECONDS := 0.75
const DEFAULT_ACCELERATION := 28.0
const DEFAULT_MAX_CONTRIBUTION_SPEED := 18.0
const DEFAULT_ANCHOR_OUTER_RADIUS := 5.5
const DEFAULT_ANCHOR_CORE_RADIUS := 2.75
const DEFAULT_ANCHOR_CLEAR_SECONDS := 0.45
const DEFAULT_AI_PROBE_DISTANCE := 7.0
const DEFAULT_AI_RESIST_WEIGHT := 0.55
const DEFAULT_COLLISION_MASK := 1
const EPSILON := 0.0001

@export var corridor_min_x := DEFAULT_CORRIDOR_MIN_X
@export var corridor_min_y := DEFAULT_CORRIDOR_MIN_Y
@export var corridor_max_y := DEFAULT_CORRIDOR_MAX_Y
@export var warning_seconds := DEFAULT_WARNING_SECONDS
@export var active_seconds := DEFAULT_ACTIVE_SECONDS
@export var reversing_seconds := DEFAULT_REVERSING_SECONDS
@export var recovery_seconds := DEFAULT_RECOVERY_SECONDS
@export var global_guard_seconds := DEFAULT_GLOBAL_GUARD_SECONDS
@export var field_acceleration := DEFAULT_ACCELERATION
@export var max_contribution_speed := DEFAULT_MAX_CONTRIBUTION_SPEED
@export var anchor_outer_radius := DEFAULT_ANCHOR_OUTER_RADIUS
@export var anchor_core_radius := DEFAULT_ANCHOR_CORE_RADIUS
@export var anchor_clear_seconds := DEFAULT_ANCHOR_CLEAR_SECONDS
@export var ai_probe_distance := DEFAULT_AI_PROBE_DISTANCE
@export var ai_resist_weight := DEFAULT_AI_RESIST_WEIGHT
@export_flags_3d_physics var ground_collision_mask := DEFAULT_COLLISION_MASK

var state: State = State.IDLE
var direction := 0
var pending_direction := 0
var state_time_remaining := 0.0
var global_guard_remaining := 0.0
var activation_count := 0
var activation_serial := 0
var rejected_activation_count := 0
var last_activator_instance_id := 0
var last_attacker_instance_id := 0

var _last_requested_direction := 0
var _credited_attacker: BaseCharacter = null
var _anchors: Array[Node3D] = []
var _outer_outline_xz := PackedVector2Array()
var _character_contexts: Dictionary = {}
var _characters_in_core: Dictionary = {}


func _ready() -> void:
	add_to_group(&"party_shooter_ai_hazard_provider")
	add_to_group(&"momentum_circuit_gravity_controller")
	_connect_anchors()


func _physics_process(delta: float) -> void:
	test_step(delta)


## Deterministic state-machine hook used by headless mechanism verification.
func test_step(delta: float) -> void:
	var remaining := maxf(0.0, delta)
	var transition_guard := 0
	while remaining > EPSILON and transition_guard < 16:
		transition_guard += 1
		var segment := remaining
		if state != State.IDLE:
			segment = minf(segment, maxf(0.0, state_time_remaining))
		if segment > EPSILON:
			global_guard_remaining = maxf(0.0, global_guard_remaining - segment)
			_update_characters(segment)
			if state != State.IDLE:
				state_time_remaining = maxf(0.0, state_time_remaining - segment)
			remaining -= segment
		if state != State.IDLE and state_time_remaining <= EPSILON:
			_complete_state()
			continue
		if segment <= EPSILON:
			break


## Applies production values and registers stabilizer anchors.  Values may be
## provided directly or inside a `gravity` dictionary.
func configure(config: Dictionary = {}, anchors: Array = []) -> void:
	var values := config
	if config.get("gravity") is Dictionary:
		values = config.get("gravity") as Dictionary
	var anchor_values: Dictionary = {}
	if config.get("anchors") is Dictionary:
		anchor_values = config.get("anchors") as Dictionary

	corridor_min_x = _number(
		values,
		"corridor_min_x",
		_number(values, "corridor_x_min", corridor_min_x)
	)
	corridor_min_y = _number(
		values,
		"corridor_min_y",
		_number(values, "corridor_y_min", corridor_min_y)
	)
	corridor_max_y = _number(
		values,
		"corridor_max_y",
		_number(values, "corridor_y_max", corridor_max_y)
	)
	warning_seconds = _number(values, "warning_seconds", warning_seconds)
	active_seconds = _number(values, "active_seconds", active_seconds)
	reversing_seconds = _number(
		values,
		"reversing_seconds",
		_number(values, "reverse_warning_seconds", reversing_seconds)
	)
	recovery_seconds = _number(values, "recovery_seconds", recovery_seconds)
	global_guard_seconds = _number(values, "global_guard_seconds", global_guard_seconds)
	field_acceleration = _number(values, "acceleration", field_acceleration)
	max_contribution_speed = _number(
		values,
		"max_contribution_speed",
		_number(
			values,
			"max_field_axis_speed",
			_number(values, "speed_cap", max_contribution_speed)
		)
	)
	anchor_outer_radius = _number(
		values,
		"anchor_outer_radius",
		_number(
			values,
			"stabilizer_outer_radius",
			_number(anchor_values, "outer_radius", anchor_outer_radius)
		)
	)
	anchor_core_radius = _number(
		values,
		"anchor_core_radius",
		_number(
			values,
			"stabilizer_core_radius",
			_number(anchor_values, "core_radius", anchor_core_radius)
		)
	)
	anchor_clear_seconds = _number(
		values,
		"anchor_clear_seconds",
		_number(anchor_values, "brake_seconds", anchor_clear_seconds)
	)
	ai_probe_distance = _number(values, "ai_probe_distance", ai_probe_distance)
	ai_resist_weight = _number(values, "ai_resist_weight", ai_resist_weight)
	ground_collision_mask = int(values.get("ground_collision_mask", ground_collision_mask))

	_outer_outline_xz = _packed_outline(
		values.get("outer_outline_world_xz", config.get("outer_outline_world_xz", []))
	)
	_anchors.clear()
	for value: Variant in anchors:
		var anchor := value as Node3D
		if anchor != null and is_instance_valid(anchor):
			_anchors.append(anchor)
	_connect_anchors()


## Requests the next global direction.  Rejected requests do not mutate any
## node cooldown; the activator starts its cooldown only after a true result.
func request_toggle(activator: Node3D, attacker: Node3D = null) -> bool:
	if global_guard_remaining > 0.0:
		_reject_activation(activator, attacker, &"global_guard")
		return false
	if state == State.WARNING or state == State.REVERSING:
		_reject_activation(activator, attacker, &"transition_busy")
		return false

	var next_direction := 1 if activation_count == 0 else -_last_requested_direction
	_last_requested_direction = next_direction
	pending_direction = next_direction
	_credited_attacker = _resolve_credit(attacker)
	last_activator_instance_id = (
		activator.get_instance_id() if is_instance_valid(activator) else 0
	)
	last_attacker_instance_id = attacker.get_instance_id() if is_instance_valid(attacker) else 0
	global_guard_remaining = global_guard_seconds
	activation_count += 1
	activation_serial += 1

	if state == State.ACTIVE:
		_set_state(State.REVERSING, reversing_seconds)
	else:
		_set_state(State.WARNING, warning_seconds)
	activation_accepted.emit(activator, next_direction, attacker)
	return true


func get_debug_state() -> Dictionary:
	return {
		"state": get_state_name(),
		"state_id": int(state),
		"direction": direction,
		"pending_direction": pending_direction,
		"field_strength": _field_strength(),
		"state_time_remaining": state_time_remaining,
		"state_remaining": state_time_remaining,
		"global_guard_remaining": global_guard_remaining,
		"activation_count": activation_count,
		"activation_serial": activation_serial,
		"rejected_activation_count": rejected_activation_count,
		"last_activator_instance_id": last_activator_instance_id,
		"last_attacker_instance_id": last_attacker_instance_id,
		"corridor_min_x": corridor_min_x,
		"corridor_min_y": corridor_min_y,
		"corridor_max_y": corridor_max_y,
		"warning_seconds": warning_seconds,
		"active_seconds": active_seconds,
		"reversing_seconds": reversing_seconds,
		"recovery_seconds": recovery_seconds,
		"global_guard_seconds": global_guard_seconds,
		"acceleration": field_acceleration,
		"max_field_axis_speed": max_contribution_speed,
		"max_contribution_speed": max_contribution_speed,
		"anchor_outer_radius": anchor_outer_radius,
		"anchor_core_radius": anchor_core_radius,
		"anchor_clear_seconds": anchor_clear_seconds,
		"anchor_count": _anchors.size(),
		"tracked_character_count": _character_contexts.size(),
		"stabilized_character_count": _characters_in_core.size(),
		"corridor_x_min": corridor_min_x,
		"corridor_y_min": corridor_min_y,
		"corridor_y_max": corridor_max_y,
		"outer_outline_point_count": _outer_outline_xz.size(),
	}


func get_character_context(character: Node3D) -> Dictionary:
	if character == null or not is_instance_valid(character):
		return {}
	var anchor_context := _stabilizer_context(character.global_position)
	var tracked: Dictionary = _character_contexts.get(character.get_instance_id(), {})
	return {
		"in_corridor": _is_in_corridor(character.global_position),
		"environment_velocity_x": float(tracked.get("environment_velocity_x", 0.0)),
		"field_direction": direction,
		"field_strength": _field_strength(),
		"stabilizer_strength": float(anchor_context.get("strength", 0.0)),
		"in_stabilizer_core": bool(anchor_context.get("in_core", false)),
		"stabilizer_anchor": anchor_context.get("anchor"),
		"credited_attacker_instance_id": (
			_credited_attacker.get_instance_id()
			if is_instance_valid(_credited_attacker)
			else 0
		),
	}


## Generic AI hazard-provider contract.  The AI only resists when the field is
## affecting its corridor and the probe in the force direction finds no floor.
func get_ai_movement_bias(character: Node3D) -> Dictionary:
	if character == null or not is_instance_valid(character):
		return {}
	if direction == 0 or _field_strength() <= EPSILON:
		return {}
	if not _is_in_corridor(character.global_position):
		return {}
	var anchor_context := _stabilizer_context(character.global_position)
	if float(anchor_context.get("strength", 0.0)) >= 1.0 - EPSILON:
		return {}
	var force_direction := Vector3(float(direction), 0.0, 0.0)
	if _has_safe_ground(character, force_direction, ai_probe_distance):
		return {}
	return {
		"direction": -force_direction,
		"weight": ai_resist_weight,
	}


func get_state_name() -> StringName:
	match state:
		State.WARNING:
			return &"warning"
		State.ACTIVE:
			return &"active"
		State.REVERSING:
			return &"reversing"
		State.RECOVERY:
			return &"recovery"
	return &"idle"


func _complete_state() -> void:
	match state:
		State.WARNING:
			direction = pending_direction
			_set_state(State.ACTIVE, active_seconds)
		State.ACTIVE:
			_set_state(State.RECOVERY, recovery_seconds)
		State.REVERSING:
			direction = pending_direction
			_set_state(State.ACTIVE, active_seconds)
		State.RECOVERY:
			direction = 0
			pending_direction = 0
			_set_state(State.IDLE, 0.0)


func _set_state(next_state: State, duration: float) -> void:
	var previous_state := get_state_name()
	state = next_state
	state_time_remaining = maxf(0.0, duration)
	state_changed.emit(previous_state, get_state_name(), direction, activation_serial)


func _reject_activation(activator: Node3D, attacker: Node3D, reason: StringName) -> void:
	var _unused_attacker := attacker
	rejected_activation_count += 1
	activation_rejected.emit(reason, activator)


func _update_characters(delta: float) -> void:
	if not is_inside_tree():
		return
	var live_ids: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var character := node as BaseCharacter
		if character == null or not is_instance_valid(character):
			continue
		var character_id := character.get_instance_id()
		live_ids[character_id] = true
		var context := _context_for(character)
		_decay_recorded_velocity(character, context, delta)
		if character.is_dead or character.is_game_over or character.freeze:
			context["environment_velocity_x"] = 0.0
			if _characters_in_core.erase(character_id):
				character_stabilized.emit(character, false)
			continue

		var anchor_context := _stabilizer_context(character.global_position)
		var anchor_strength := float(anchor_context.get("strength", 0.0))
		var in_core := bool(anchor_context.get("in_core", false))
		if in_core:
			_clear_environment_velocity(
				character,
				context,
				delta,
				anchor_clear_seconds
			)
			if not _characters_in_core.has(character_id):
				_characters_in_core[character_id] = true
				character_stabilized.emit(character, true)
		else:
			if _characters_in_core.erase(character_id):
				character_stabilized.emit(character, false)

		if not _is_in_corridor(character.global_position) or in_core:
			continue
		match state:
			State.ACTIVE:
				_apply_active_field(character, context, delta, 1.0 - anchor_strength)
			State.REVERSING:
				_clear_environment_velocity(character, context, delta, reversing_seconds)
			State.RECOVERY:
				_clear_environment_velocity(character, context, delta, recovery_seconds)

	for character_id: Variant in _character_contexts.keys():
		if not live_ids.has(character_id):
			_character_contexts.erase(character_id)
			_characters_in_core.erase(character_id)


func _context_for(character: BaseCharacter) -> Dictionary:
	var character_id := character.get_instance_id()
	if not _character_contexts.has(character_id):
		_character_contexts[character_id] = {
			"character": weakref(character),
			"environment_velocity_x": 0.0,
		}
	return _character_contexts[character_id] as Dictionary


func _apply_active_field(
	character: BaseCharacter,
	context: Dictionary,
	delta: float,
	strength: float
) -> void:
	if direction == 0 or strength <= EPSILON:
		return
	var current := float(context.get("environment_velocity_x", 0.0))
	var target := float(direction) * max_contribution_speed
	var next := move_toward(current, target, field_acceleration * strength * delta)
	var delta_velocity := next - current
	if absf(delta_velocity) <= EPSILON:
		return
	_apply_environment_velocity_delta(character, context, delta_velocity)
	_assign_field_credit(character)


func _clear_environment_velocity(
	character: BaseCharacter,
	context: Dictionary,
	delta: float,
	clear_seconds: float
) -> float:
	var current := float(context.get("environment_velocity_x", 0.0))
	if absf(current) <= EPSILON:
		context["environment_velocity_x"] = 0.0
		return 0.0
	var clear_rate := max_contribution_speed / maxf(clear_seconds, EPSILON)
	var next := move_toward(current, 0.0, clear_rate * delta)
	var removed := current - next
	_apply_environment_velocity_delta(character, context, -removed)
	return absf(removed)


func _apply_environment_velocity_delta(
	character: BaseCharacter,
	context: Dictionary,
	delta_velocity_x: float
) -> void:
	if absf(delta_velocity_x) <= EPSILON:
		return
	character.sleeping = false
	# Add only our delta to the current velocity.  Existing X knockback and all
	# Y/Z motion remain untouched, including for deterministic disabled-body tests.
	character.linear_velocity += Vector3(delta_velocity_x, 0.0, 0.0)
	context["environment_velocity_x"] = (
		float(context.get("environment_velocity_x", 0.0)) + delta_velocity_x
	)


func _decay_recorded_velocity(
	character: BaseCharacter,
	context: Dictionary,
	delta: float
) -> void:
	var current := float(context.get("environment_velocity_x", 0.0))
	if absf(current) <= EPSILON:
		context["environment_velocity_x"] = 0.0
		return
	# A disabled body is a deterministic verifier fixture: no physics damping is
	# integrated, so its recorded contribution must not be decayed either.
	if character.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var config := get_node_or_null("/root/GameConfig")
	var damping := 0.5
	if character.is_on_floor():
		damping = 2.0
	if config != null:
		var key := "character_horizontal_damp" if character.is_on_floor() else "character_air_horizontal_damp"
		var configured: Variant = config.get(key)
		if configured is float or configured is int:
			damping = float(configured)
	context["environment_velocity_x"] = current * maxf(0.0, 1.0 - damping * delta)


func _assign_field_credit(character: BaseCharacter) -> void:
	if not is_instance_valid(_credited_attacker):
		return
	if _credited_attacker == character:
		# Self-triggering never erases an existing enemy's credit.
		return
	character.last_hit_by = _credited_attacker


func _resolve_credit(candidate: Node3D) -> BaseCharacter:
	var character := candidate as BaseCharacter
	if character == null or not is_instance_valid(character):
		return null
	return character.get_combat_identity()


func _field_strength() -> float:
	match state:
		State.ACTIVE:
			return 1.0
		State.REVERSING:
			return clampf(
				state_time_remaining / maxf(reversing_seconds, EPSILON),
				0.0,
				1.0
			)
		State.RECOVERY:
			return clampf(
				state_time_remaining / maxf(recovery_seconds, EPSILON),
				0.0,
				1.0
			)
	return 0.0


func _is_in_corridor(world_position: Vector3) -> bool:
	if world_position.x < corridor_min_x:
		return false
	if world_position.y < corridor_min_y or world_position.y > corridor_max_y:
		return false
	if _outer_outline_xz.size() >= 3:
		return Geometry2D.is_point_in_polygon(
			Vector2(world_position.x, world_position.z),
			_outer_outline_xz
		)
	return true


func _stabilizer_context(world_position: Vector3) -> Dictionary:
	var best_strength := 0.0
	var best_anchor: Node3D = null
	var best_in_core := false
	for anchor: Node3D in _anchors:
		if not is_instance_valid(anchor):
			continue
		var strength := 0.0
		if anchor.has_method("get_stabilization_strength"):
			strength = float(anchor.call("get_stabilization_strength", world_position))
		else:
			var distance := _horizontal_distance(anchor.global_position, world_position)
			strength = _radial_stabilizer_strength(distance)
		if strength <= best_strength:
			continue
		best_strength = strength
		best_anchor = anchor
		if anchor.has_method("contains_core"):
			best_in_core = bool(anchor.call("contains_core", world_position))
		else:
			best_in_core = (
				_horizontal_distance(anchor.global_position, world_position) <= anchor_core_radius
			)
	return {
		"anchor": best_anchor,
		"strength": best_strength,
		"in_core": best_in_core,
	}


func _radial_stabilizer_strength(distance: float) -> float:
	if distance >= anchor_outer_radius:
		return 0.0
	if distance <= anchor_core_radius:
		return 1.0
	var span := maxf(anchor_outer_radius - anchor_core_radius, EPSILON)
	var value := clampf((anchor_outer_radius - distance) / span, 0.0, 1.0)
	return value * value * (3.0 - 2.0 * value)


func _connect_anchors() -> void:
	for anchor: Node3D in _anchors:
		if is_instance_valid(anchor) and anchor.has_method("configure"):
			anchor.call("configure", self, anchor_outer_radius, anchor_core_radius)


func _has_safe_ground(character: Node3D, probe_direction: Vector3, distance: float) -> bool:
	if not is_inside_tree() or get_world_3d() == null:
		return true
	var origin := character.global_position + probe_direction.normalized() * distance + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 12.0)
	query.collision_mask = ground_collision_mask
	query.collide_with_areas = false
	var exclusions: Array[RID] = []
	for node: Node in get_tree().get_nodes_in_group(&"player"):
		var body := node as CollisionObject3D
		if body != null:
			exclusions.append(body.get_rid())
	query.exclude = exclusions
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _number(values: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = values.get(key, fallback)
	return float(value) if value is float or value is int else fallback


func _packed_outline(value: Variant) -> PackedVector2Array:
	var result := PackedVector2Array()
	if value is PackedVector2Array:
		return value as PackedVector2Array
	if not value is Array:
		return result
	for point: Variant in value as Array:
		if point is Vector2:
			result.append(point as Vector2)
		elif point is Array and (point as Array).size() >= 2:
			result.append(Vector2(float(point[0]), float(point[1])))
	return result


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
