extends Node3D
class_name MomentumCircuitShockwave

## Closed-curve shockwave controller used by Momentum Circuit.
## path_curve is authored in this node's local space and must repeat its first
## point as its final point so the baked path is genuinely closed.

signal warning_started(direction: int, activator: Node3D)
signal wave_started(direction: int, activator: Node3D)
signal character_affected(
	character: BaseCharacter,
	impulse: Vector3,
	curve_offset: float,
	activation_serial: int
)
signal activation_finished(activation_serial: int, affected_count: int)
signal activation_rejected(reason: StringName, activator: Node3D)

enum State {
	IDLE,
	WARNING,
	TRAVELLING,
}

const WARNING_SECONDS := 1.5
const EFFECT_RADIUS := 5.0
const HORIZONTAL_IMPULSE := 65.0
const CLOSED_POINT_TOLERANCE := 0.05
const MIN_CURVE_LENGTH := 0.1
const WAVE_VISUAL_COLOR := Color("#ffbb3e")

@export var path_curve: Curve3D = null
@export_range(0.1, 200.0, 0.1) var travel_speed := 28.0
@export_range(0.1, 5.0, 0.1) var curve_offset_tolerance := 5.0
@export_flags_3d_physics var character_collision_mask := 1

var state: State = State.IDLE
var travel_direction := 1
var warning_remaining := 0.0
var start_curve_offset := 0.0
var current_curve_offset := 0.0
var current_wave_world_position := Vector3.ZERO
var distance_travelled := 0.0
var activation_count := 0
var completed_activation_count := 0
var rejected_activation_count := 0
var affected_count_current := 0
var affected_count_total := 0
var last_impulse := Vector3.ZERO
var last_activator_instance_id := 0

var _curve_length := 0.0
var _activation_serial := 0
var _activator: Node3D = null
var _credited_activator: BaseCharacter = null
var _affected_character_ids: Dictionary = {}
var _wave_visual: MeshInstance3D = null
var _visual_time := 0.0


func _ready() -> void:
	_curve_length = path_curve.get_baked_length() if path_curve != null else 0.0
	_build_wave_visual()
	_update_wave_position()
	_update_wave_visual(0.0)


func _physics_process(delta: float) -> void:
	match state:
		State.WARNING:
			warning_remaining = maxf(0.0, warning_remaining - delta)
			if warning_remaining <= 0.0:
				_begin_travel()
		State.TRAVELLING:
			_advance_wave(delta)
	_update_wave_visual(delta)


func configure_path(curve_value: Curve3D) -> void:
	path_curve = curve_value
	_curve_length = path_curve.get_baked_length() if path_curve != null else 0.0
	_update_wave_position()


func activate(direction: int = 1, activator: Node3D = null) -> bool:
	return _start_activation(direction, activator, activator)


## Starts at a map activator while independently crediting the attacking character.
func activate_from(
	origin: Node3D,
	direction: int = 1,
	credit_source: Node3D = null
) -> bool:
	return _start_activation(direction, origin, credit_source)


func _start_activation(
	direction: int,
	origin: Node3D,
	credit_source: Node3D
) -> bool:
	if state != State.IDLE:
		rejected_activation_count += 1
		activation_rejected.emit(&"already_active", origin)
		return false
	if not _validate_closed_path():
		rejected_activation_count += 1
		activation_rejected.emit(&"invalid_closed_path", origin)
		return false
	if travel_speed <= 0.0:
		rejected_activation_count += 1
		activation_rejected.emit(&"invalid_speed", origin)
		return false

	_curve_length = path_curve.get_baked_length()
	travel_direction = 1 if direction >= 0 else -1
	warning_remaining = WARNING_SECONDS
	start_curve_offset = _curve_offset_near(origin)
	current_curve_offset = start_curve_offset
	distance_travelled = 0.0
	affected_count_current = 0
	_affected_character_ids.clear()
	_activator = origin
	_credited_activator = _resolve_credit(credit_source)
	last_activator_instance_id = origin.get_instance_id() if is_instance_valid(origin) else 0
	_activation_serial += 1
	activation_count += 1
	state = State.WARNING
	_update_wave_position()
	warning_started.emit(travel_direction, origin)
	return true


func is_active() -> bool:
	return state != State.IDLE


func get_state_name() -> StringName:
	match state:
		State.WARNING:
			return &"warning"
		State.TRAVELLING:
			return &"travelling"
	return &"idle"


func get_debug_state() -> Dictionary:
	return {
		"state": get_state_name(),
		"warning_seconds": WARNING_SECONDS,
		"warning_remaining": warning_remaining,
		"travel_speed": travel_speed,
		"travel_direction": travel_direction,
		"start_curve_offset": start_curve_offset,
		"effect_radius": EFFECT_RADIUS,
		"curve_offset_tolerance": curve_offset_tolerance,
		"horizontal_impulse": HORIZONTAL_IMPULSE,
		"curve_is_closed": _validate_closed_path(),
		"curve_length": _curve_length,
		"current_curve_offset": current_curve_offset,
		"current_wave_world_position": current_wave_world_position,
		"distance_travelled": distance_travelled,
		"activation_serial": _activation_serial,
		"activation_count": activation_count,
		"completed_activation_count": completed_activation_count,
		"rejected_activation_count": rejected_activation_count,
		"affected_count_current": affected_count_current,
		"affected_count_total": affected_count_total,
		"last_impulse": last_impulse,
		"last_activator_instance_id": last_activator_instance_id,
		"wave_visual_visible": is_instance_valid(_wave_visual) and _wave_visual.visible,
	}


func _begin_travel() -> void:
	state = State.TRAVELLING
	warning_remaining = 0.0
	current_curve_offset = start_curve_offset
	distance_travelled = 0.0
	_update_wave_position()
	wave_started.emit(travel_direction, _activator)
	_affect_characters_at_current_position()


func _advance_wave(delta: float) -> void:
	var remaining_distance := minf(
		travel_speed * maxf(0.0, delta),
		maxf(0.0, _curve_length - distance_travelled)
	)
	if remaining_distance <= 0.0:
		_finish_activation()
		return

	# Substeps keep a fast wave from tunnelling through a character between ticks.
	var sample_spacing := maxf(0.25, EFFECT_RADIUS * 0.4)
	var substep_count := maxi(1, int(ceil(remaining_distance / sample_spacing)))
	var substep_distance := remaining_distance / float(substep_count)
	for _index in range(substep_count):
		distance_travelled += substep_distance
		current_curve_offset = _wrap_offset(
			current_curve_offset + float(travel_direction) * substep_distance
		)
		_update_wave_position()
		_affect_characters_at_current_position()

	if distance_travelled >= _curve_length - 0.001:
		_finish_activation()


func _finish_activation() -> void:
	if state == State.IDLE:
		return
	var finished_serial := _activation_serial
	var finished_affected_count := affected_count_current
	state = State.IDLE
	warning_remaining = 0.0
	completed_activation_count += 1
	_activator = null
	_credited_activator = null
	_affected_character_ids.clear()
	activation_finished.emit(finished_serial, finished_affected_count)


func _affect_characters_at_current_position() -> void:
	if path_curve == null or _curve_length <= MIN_CURVE_LENGTH:
		return
	for character: BaseCharacter in _collect_candidate_characters():
		if character == null or not is_instance_valid(character):
			continue
		if character.is_dead or character.is_game_over:
			continue
		var character_id := character.get_instance_id()
		if _affected_character_ids.has(character_id):
			continue
		if character.global_position.distance_to(current_wave_world_position) > EFFECT_RADIUS:
			continue

		var closest_offset := path_curve.get_closest_offset(to_local(character.global_position))
		if _cyclic_offset_distance(closest_offset, current_curve_offset) > curve_offset_tolerance:
			continue

		var impulse_direction := _world_travel_tangent(current_curve_offset)
		if impulse_direction.length_squared() <= 0.0001:
			continue
		var impulse := impulse_direction * HORIZONTAL_IMPULSE
		_affected_character_ids[character_id] = true
		if is_instance_valid(_credited_activator):
			character.last_hit_by = _credited_activator
		character.sleeping = false
		character.apply_central_impulse(impulse)
		last_impulse = impulse
		affected_count_current += 1
		affected_count_total += 1
		character_affected.emit(character, impulse, current_curve_offset, _activation_serial)


func _collect_candidate_characters() -> Array[BaseCharacter]:
	var candidates: Array[BaseCharacter] = []
	var seen_ids: Dictionary = {}
	if is_inside_tree() and get_world_3d() != null:
		var sphere := SphereShape3D.new()
		sphere.radius = EFFECT_RADIUS
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, current_wave_world_position)
		query.collision_mask = character_collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = false
		for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 64):
			var character := result.get("collider") as BaseCharacter
			if character == null:
				continue
			var character_id := character.get_instance_id()
			if not seen_ids.has(character_id):
				seen_ids[character_id] = true
				candidates.append(character)

	# Group fallback also covers test doubles whose collision shape is disabled.
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"player"):
			var character := node as BaseCharacter
			if character == null:
				continue
			var character_id := character.get_instance_id()
			if not seen_ids.has(character_id):
				seen_ids[character_id] = true
				candidates.append(character)
	return candidates


func _world_travel_tangent(offset: float) -> Vector3:
	var sample_delta := minf(0.25, _curve_length * 0.01)
	if sample_delta <= 0.0:
		return Vector3.ZERO
	var before := path_curve.sample_baked(_wrap_offset(offset - sample_delta), true)
	var after := path_curve.sample_baked(_wrap_offset(offset + sample_delta), true)
	var local_tangent := after - before
	var world_tangent := global_transform.basis * local_tangent
	world_tangent.y = 0.0
	if world_tangent.length_squared() <= 0.0001:
		return Vector3.ZERO
	return world_tangent.normalized() * float(travel_direction)


func _curve_offset_near(origin: Node3D) -> float:
	if (
		path_curve == null
		or _curve_length <= MIN_CURVE_LENGTH
		or origin == null
		or not is_instance_valid(origin)
	):
		return 0.0
	return path_curve.get_closest_offset(to_local(origin.global_position))


func _update_wave_position() -> void:
	if path_curve == null or _curve_length <= MIN_CURVE_LENGTH:
		current_wave_world_position = global_position
		return
	current_wave_world_position = to_global(path_curve.sample_baked(_wrap_offset(current_curve_offset), true))


func _build_wave_visual() -> void:
	if is_instance_valid(_wave_visual):
		return
	_wave_visual = MeshInstance3D.new()
	_wave_visual.name = "TravellingWaveVisual"
	var ring := TorusMesh.new()
	ring.inner_radius = 1.6
	ring.outer_radius = 2.35
	ring.rings = 36
	ring.ring_segments = 10
	_wave_visual.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(
		WAVE_VISUAL_COLOR.r,
		WAVE_VISUAL_COLOR.g,
		WAVE_VISUAL_COLOR.b,
		0.82
	)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = WAVE_VISUAL_COLOR
	material.emission_energy_multiplier = 0.55
	_wave_visual.material_override = material
	_wave_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wave_visual.visible = false
	add_child(_wave_visual)


func _update_wave_visual(delta: float) -> void:
	if not is_instance_valid(_wave_visual):
		return
	_visual_time += maxf(0.0, delta)
	_wave_visual.visible = state != State.IDLE
	if not _wave_visual.visible:
		return
	_wave_visual.global_position = current_wave_world_position + Vector3(0.0, 0.14, 0.0)
	var pulse := 1.0
	if state == State.WARNING:
		pulse = 0.88 + 0.16 * (0.5 + 0.5 * sin(_visual_time * 12.0))
	else:
		pulse = 0.96 + 0.08 * (0.5 + 0.5 * sin(_visual_time * 18.0))
	_wave_visual.scale = Vector3.ONE * pulse


func _validate_closed_path() -> bool:
	if path_curve == null or path_curve.get_point_count() < 3:
		return false
	var baked_length := path_curve.get_baked_length()
	if baked_length <= MIN_CURVE_LENGTH:
		return false
	var first_point := path_curve.get_point_position(0)
	var last_point := path_curve.get_point_position(path_curve.get_point_count() - 1)
	return first_point.distance_to(last_point) <= CLOSED_POINT_TOLERANCE


func _wrap_offset(offset: float) -> float:
	if _curve_length <= MIN_CURVE_LENGTH:
		return 0.0
	return fposmod(offset, _curve_length)


func _cyclic_offset_distance(first: float, second: float) -> float:
	var direct_distance := absf(first - second)
	return minf(direct_distance, maxf(0.0, _curve_length - direct_distance))


func _resolve_credit(activator: Node3D) -> BaseCharacter:
	if activator is BaseCharacter:
		return (activator as BaseCharacter).get_combat_identity()
	if activator != null and activator.has_method("get_combat_identity"):
		var identity: Variant = activator.call("get_combat_identity")
		if identity is BaseCharacter:
			return identity as BaseCharacter
	return null
