extends Area3D
class_name MomentumCircuitPortal

## Character-only momentum portal used by Momentum Circuit.
## Tangents passed to configure_pair() are world-space horizontal directions.

signal character_teleported(
	character: BaseCharacter,
	from_portal: MomentumCircuitPortal,
	destination: Marker3D,
	exit_velocity: Vector3
)
signal teleport_rejected(character: BaseCharacter, reason: StringName)

const COOLDOWN_META := &"momentum_circuit_portal_unlock_ms"
const COOLDOWN_SECONDS := 0.9
const MIN_ENTRY_SPEED := 4.0
const INTENT_DWELL_SECONDS := 0.18
const MOMENTUM_RETENTION := 0.9
const NORMAL_SPEED_CAP := 38.0
const BOOSTED_SPEED_CAP := 48.0

var destination_marker: Marker3D = null
var source_tangent := Vector3.ZERO
var destination_tangent := Vector3.ZERO

var teleport_count := 0
var speed_entry_teleport_count := 0
var dwell_teleport_count := 0
var rejected_non_character_count := 0
var rejected_cooldown_count := 0
var rejected_speed_count := 0
var rejected_invalid_count := 0
var last_entry_horizontal_speed := 0.0
var last_exit_horizontal_speed := 0.0
var last_used_boosted_cap := false

var _dwell_started_ms_by_character: Dictionary = {}
var _pending_character_ids: Dictionary = {}
var _boosted_character_ids: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if _dwell_started_ms_by_character.is_empty():
		return
	var now_ms := Time.get_ticks_msec()
	for key: Variant in _dwell_started_ms_by_character.keys():
		if not is_instance_valid(key):
			_dwell_started_ms_by_character.erase(key)
			continue
		var character := key as BaseCharacter
		if character == null or character.is_dead or character.is_game_over:
			_dwell_started_ms_by_character.erase(key)
			continue
		if not overlaps_body(character):
			_dwell_started_ms_by_character.erase(key)
			continue

		var horizontal_speed := _horizontal(character.linear_velocity).length()
		if horizontal_speed >= MIN_ENTRY_SPEED:
			_try_queue_teleport(character, false, false)
			continue

		var dwell_started_ms := int(_dwell_started_ms_by_character.get(key, now_ms))
		if now_ms - dwell_started_ms >= int(INTENT_DWELL_SECONDS * 1000.0):
			_try_queue_teleport(character, true, false)


func configure_pair(
	destination_exit: Marker3D,
	source_tangent_world: Vector3,
	destination_tangent_world: Vector3
) -> void:
	destination_marker = destination_exit
	source_tangent = _horizontal(source_tangent_world).normalized()
	destination_tangent = _horizontal(destination_tangent_world).normalized()


func is_configured() -> bool:
	return (
		is_instance_valid(destination_marker)
		and source_tangent.length_squared() > 0.99
		and destination_tangent.length_squared() > 0.99
	)


## Opts one character into the 48 u/s cap. The opt-in is consumed on teleport.
func opt_in_boosted_cap(character: BaseCharacter, enabled: bool = true) -> void:
	if character == null or not is_instance_valid(character):
		return
	var character_id := character.get_instance_id()
	if enabled:
		_boosted_character_ids[character_id] = true
	else:
		_boosted_character_ids.erase(character_id)


## Programmatic entry point. It keeps the same speed/cooldown rules as body entry.
func try_teleport(character: BaseCharacter, use_boosted_cap: bool = false) -> bool:
	return _try_queue_teleport(character, false, use_boosted_cap)


func get_cooldown_remaining(character: BaseCharacter) -> float:
	if character == null or not is_instance_valid(character):
		return 0.0
	var unlock_ms := int(character.get_meta(COOLDOWN_META, 0))
	return maxf(0.0, float(unlock_ms - Time.get_ticks_msec()) / 1000.0)


func get_debug_state() -> Dictionary:
	return {
		"configured": is_configured(),
		"cooldown_seconds": COOLDOWN_SECONDS,
		"minimum_entry_speed": MIN_ENTRY_SPEED,
		"intent_dwell_seconds": INTENT_DWELL_SECONDS,
		"momentum_retention": MOMENTUM_RETENTION,
		"normal_speed_cap": NORMAL_SPEED_CAP,
		"boosted_speed_cap": BOOSTED_SPEED_CAP,
		"teleport_count": teleport_count,
		"speed_entry_teleport_count": speed_entry_teleport_count,
		"dwell_teleport_count": dwell_teleport_count,
		"rejected_non_character_count": rejected_non_character_count,
		"rejected_cooldown_count": rejected_cooldown_count,
		"rejected_speed_count": rejected_speed_count,
		"rejected_invalid_count": rejected_invalid_count,
		"last_entry_horizontal_speed": last_entry_horizontal_speed,
		"last_exit_horizontal_speed": last_exit_horizontal_speed,
		"last_used_boosted_cap": last_used_boosted_cap,
		"dwell_character_count": _dwell_started_ms_by_character.size(),
		"pending_character_count": _pending_character_ids.size(),
	}


func _on_body_entered(body: Node3D) -> void:
	var character := body as BaseCharacter
	if character == null:
		rejected_non_character_count += 1
		return
	if character.is_dead or character.is_game_over:
		return
	if not is_configured():
		rejected_invalid_count += 1
		teleport_rejected.emit(character, &"invalid_configuration")
		return
	if get_cooldown_remaining(character) > 0.0:
		rejected_cooldown_count += 1
		teleport_rejected.emit(character, &"cooldown")
		return

	_dwell_started_ms_by_character[character] = Time.get_ticks_msec()
	if _horizontal(character.linear_velocity).length() >= MIN_ENTRY_SPEED:
		_try_queue_teleport(character, false, false)


func _on_body_exited(body: Node3D) -> void:
	if body is BaseCharacter:
		_dwell_started_ms_by_character.erase(body)


func _try_queue_teleport(
	character: BaseCharacter,
	allow_dwell_entry: bool,
	force_boosted_cap: bool
) -> bool:
	if character == null or not is_instance_valid(character):
		rejected_invalid_count += 1
		return false
	if character.is_dead or character.is_game_over or not is_configured():
		rejected_invalid_count += 1
		teleport_rejected.emit(character, &"invalid_state")
		return false

	var character_id := character.get_instance_id()
	if _pending_character_ids.has(character_id):
		return false
	if get_cooldown_remaining(character) > 0.0:
		rejected_cooldown_count += 1
		teleport_rejected.emit(character, &"cooldown")
		return false

	var entry_velocity := character.linear_velocity
	var horizontal_speed := _horizontal(entry_velocity).length()
	last_entry_horizontal_speed = horizontal_speed
	if horizontal_speed < MIN_ENTRY_SPEED and not allow_dwell_entry:
		rejected_speed_count += 1
		teleport_rejected.emit(character, &"entry_speed")
		return false

	var use_boosted_cap := force_boosted_cap or _boosted_character_ids.has(character_id)
	_boosted_character_ids.erase(character_id)
	_dwell_started_ms_by_character.erase(character)
	_pending_character_ids[character_id] = true
	character.set_meta(
		COOLDOWN_META,
		Time.get_ticks_msec() + int(COOLDOWN_SECONDS * 1000.0)
	)
	if allow_dwell_entry:
		dwell_teleport_count += 1
	else:
		speed_entry_teleport_count += 1
	call_deferred(
		"_teleport_character",
		character,
		entry_velocity,
		use_boosted_cap,
		character_id
	)
	return true


func _teleport_character(
	character: BaseCharacter,
	entry_velocity: Vector3,
	use_boosted_cap: bool,
	character_id: int
) -> void:
	_pending_character_ids.erase(character_id)
	if (
		character == null
		or not is_instance_valid(character)
		or not is_instance_valid(destination_marker)
	):
		rejected_invalid_count += 1
		return

	var horizontal_velocity := _horizontal(entry_velocity)
	var rotation_angle := source_tangent.signed_angle_to(destination_tangent, Vector3.UP)
	var exit_horizontal := horizontal_velocity.rotated(Vector3.UP, rotation_angle) * MOMENTUM_RETENTION
	var speed_cap := BOOSTED_SPEED_CAP if use_boosted_cap else NORMAL_SPEED_CAP
	if exit_horizontal.length() > speed_cap:
		exit_horizontal = exit_horizontal.normalized() * speed_cap
	var exit_velocity := Vector3(
		exit_horizontal.x,
		maxf(0.0, entry_velocity.y),
		exit_horizontal.z
	)

	var destination_transform := character.global_transform
	destination_transform.origin = destination_marker.global_position
	character.global_transform = destination_transform
	character.linear_velocity = exit_velocity
	character.sleeping = false
	if character.is_inside_tree():
		PhysicsServer3D.body_set_state(
			character.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			destination_transform
		)
		PhysicsServer3D.body_set_state(
			character.get_rid(),
			PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY,
			exit_velocity
		)
		PhysicsServer3D.body_set_state(
			character.get_rid(),
			PhysicsServer3D.BODY_STATE_SLEEPING,
			false
		)
	character.reset_physics_interpolation()

	teleport_count += 1
	last_exit_horizontal_speed = exit_horizontal.length()
	last_used_boosted_cap = use_boosted_cap
	character_teleported.emit(character, self, destination_marker, exit_velocity)


func _horizontal(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)
