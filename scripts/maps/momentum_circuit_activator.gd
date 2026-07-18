extends StaticBody3D
class_name MomentumCircuitActivator

## Shootable direction selector for a MomentumCircuitShockwave.
## configure() receives world-space tangent and side-axis directions.

signal activated(
	activator: MomentumCircuitActivator,
	direction: int,
	attacker: Node3D,
	weapon_id: StringName
)
signal activation_failed(reason: StringName, attacker: Node3D)
signal cooldown_finished(activator: MomentumCircuitActivator)

const COOLDOWN_SECONDS := 8.0

var controller: MomentumCircuitShockwave = null
var tangent := Vector3.FORWARD
var side_axis := Vector3.RIGHT

var cooldown_remaining := 0.0
var ready_hit_count := 0
var activation_count := 0
var ignored_cooldown_hit_count := 0
var failed_activation_count := 0
var missing_attacker_count := 0
var selected_direction := 1
var last_attacker_instance_id := 0
var last_weapon_id: StringName = &""
var last_hit_impulse := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return
	var previous_remaining := cooldown_remaining
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if previous_remaining > 0.0 and cooldown_remaining <= 0.0:
		cooldown_finished.emit(self)


func configure(
	shockwave_controller: MomentumCircuitShockwave,
	tangent_world: Vector3,
	side_axis_world: Vector3 = Vector3.ZERO
) -> void:
	controller = shockwave_controller
	tangent = _horizontal(tangent_world).normalized()
	if tangent.length_squared() <= 0.0001:
		tangent = Vector3.FORWARD

	var horizontal_side := _horizontal(side_axis_world)
	if horizontal_side.length_squared() <= 0.0001:
		horizontal_side = tangent.cross(Vector3.UP)
	side_axis = horizontal_side.normalized()


func is_ready_to_activate() -> bool:
	return cooldown_remaining <= 0.0


func apply_hit(
	impulse: Vector3,
	damage: float = 0.0,
	attacker: Node3D = null,
	weapon_id: StringName = &""
) -> void:
	# Damage is intentionally ignored: the node is a durable map mechanism.
	var _unused_damage := damage
	if not is_ready_to_activate():
		ignored_cooldown_hit_count += 1
		return

	# Lock before invoking the controller so same-frame/high-rate hits cannot
	# select a second direction, even if a signal callback re-enters apply_hit().
	cooldown_remaining = COOLDOWN_SECONDS
	ready_hit_count += 1
	last_hit_impulse = impulse
	last_weapon_id = weapon_id
	last_attacker_instance_id = attacker.get_instance_id() if is_instance_valid(attacker) else 0
	selected_direction = _select_direction(attacker)

	if controller == null or not is_instance_valid(controller):
		failed_activation_count += 1
		activation_failed.emit(&"missing_controller", attacker)
		return
	var accepted := (
		controller.activate_from(self, selected_direction, attacker)
		if controller.has_method("activate_from")
		else controller.activate(selected_direction, attacker)
	)
	if not accepted:
		failed_activation_count += 1
		activation_failed.emit(&"controller_rejected", attacker)
		return

	activation_count += 1
	activated.emit(self, selected_direction, attacker, weapon_id)


func get_debug_state() -> Dictionary:
	return {
		"ready": is_ready_to_activate(),
		"cooldown_seconds": COOLDOWN_SECONDS,
		"cooldown_remaining": cooldown_remaining,
		"controller_valid": is_instance_valid(controller),
		"tangent": tangent,
		"side_axis": side_axis,
		"selected_direction": selected_direction,
		"ready_hit_count": ready_hit_count,
		"activation_count": activation_count,
		"ignored_cooldown_hit_count": ignored_cooldown_hit_count,
		"failed_activation_count": failed_activation_count,
		"missing_attacker_count": missing_attacker_count,
		"last_attacker_instance_id": last_attacker_instance_id,
		"last_weapon_id": last_weapon_id,
		"last_hit_impulse": last_hit_impulse,
	}


func _select_direction(attacker: Node3D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		missing_attacker_count += 1
		return 1
	var attacker_delta := _horizontal(attacker.global_position - global_position)
	var side_projection := attacker_delta.dot(side_axis)
	if absf(side_projection) <= 0.001:
		# The tangent supplies a deterministic tie-breaker for an attacker exactly
		# on the configured side-axis divider.
		side_projection = attacker_delta.dot(tangent)
	return 1 if side_projection >= 0.0 else -1


func _horizontal(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)
