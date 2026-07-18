extends SceneTree

## Deterministic, scene-independent verification for Momentum Circuit gravity.
## The controller is stepped through its public test hook so wall-clock timing,
## rendering, and a complete match are not part of the mechanism gate.

const CONTROLLER_SCRIPT_PATH := "res://scripts/maps/momentum_circuit_gravity_controller.gd"
const ACTIVATOR_SCRIPT_PATH := "res://scripts/maps/momentum_circuit_gravity_activator.gd"
const ANCHOR_SCRIPT_PATH := "res://scripts/maps/momentum_circuit_stabilizer_anchor.gd"
const CHARACTER_SCRIPT_PATH := "res://scripts/player/base_character.gd"
const EPSILON := 0.02

const FROZEN_CONFIG := {
	"gravity": {
		"corridor_x_min": 2.0,
		"corridor_y_min": -4.0,
		"corridor_y_max": 7.0,
		"warning_seconds": 1.25,
		"active_seconds": 4.0,
		"reverse_warning_seconds": 0.65,
		"recovery_seconds": 0.75,
		"global_guard_seconds": 0.75,
		"acceleration": 28.0,
		"max_field_axis_speed": 18.0,
		"stabilizer_outer_radius": 5.5,
		"stabilizer_core_radius": 2.75,
		"anchor_clear_seconds": 0.45,
		"ai_probe_distance": 7.0,
		"ai_resist_weight": 0.55,
	}
}

var _failures: Array[String] = []
var _fixture_serial := 0


func _initialize() -> void:
	print("==================================================")
	print("[Momentum Circuit Mechanics Verifier]")
	print("==================================================")
	root.set_meta("disable_runtime_audio", true)

	if not _verify_scripts_available():
		await _finish()
		return
	await _verify_public_contract_and_state_machine()
	await _verify_activator_cooldowns_and_rejections()
	await _verify_corridor_force_and_velocity_isolation()
	await _verify_stabilizer_falloff_and_core_braking()
	await _verify_kill_credit_rules()
	await _verify_ai_danger_bias()

	await _finish()


func _verify_scripts_available() -> bool:
	for path in [CONTROLLER_SCRIPT_PATH, ACTIVATOR_SCRIPT_PATH, ANCHOR_SCRIPT_PATH, CHARACTER_SCRIPT_PATH]:
		if not ResourceLoader.exists(path):
			_fail("Required mechanism script is missing: %s" % path)
	return _failures.is_empty()


func _verify_public_contract_and_state_machine() -> void:
	print("\n--- Public API And State Machine ---")
	var fixture := _new_fixture([])
	var controller: Node3D = fixture["controller"]
	var activators: Array = fixture["activators"]
	var attacker: RigidBody3D = _add_character(fixture, "Attacker", Vector3(10.0, 1.0, 0.0))

	for method_name in [&"request_toggle", &"get_debug_state", &"get_character_context", &"get_ai_movement_bias", &"test_step"]:
		_assert(controller.has_method(method_name), "Controller public method missing: %s" % method_name)
	for signal_name in [&"state_changed", &"activation_accepted", &"activation_rejected", &"character_stabilized"]:
		_assert(controller.has_signal(signal_name), "Controller public signal missing: %s" % signal_name)
	var initial := _debug(controller)
	_assert_state(initial, "idle", 0, 0)
	_assert_close(float(initial.get("warning_seconds", NAN)), 1.25, "warning duration")
	_assert_close(float(initial.get("active_seconds", NAN)), 4.0, "active duration")
	_assert_close(float(initial.get("reversing_seconds", NAN)), 0.65, "reversing duration")
	_assert_close(float(initial.get("recovery_seconds", NAN)), 0.75, "recovery duration")

	var accepted := bool(controller.call("request_toggle", activators[0], attacker))
	_assert(accepted, "First activation must be accepted")
	var warning := _debug(controller)
	_assert_state(warning, "warning", 0, 1)
	_assert(int(warning.get("activation_serial", 0)) == 1, "First activation serial must be 1")
	_assert_close(float(warning.get("state_time_remaining", warning.get("state_remaining", NAN))), 1.25, "initial warning remaining")

	controller.call("test_step", 1.24)
	_assert_state(_debug(controller), "warning", 0, 1)
	controller.call("test_step", 0.01)
	_assert_state(_debug(controller), "active", 1, 1)

	accepted = bool(controller.call("request_toggle", activators[1], attacker))
	_assert(accepted, "Activation during ACTIVE must begin reversal once guard elapsed")
	var reversing := _debug(controller)
	_assert_state(reversing, "reversing", 1, -1)
	_assert_close(float(reversing.get("state_time_remaining", reversing.get("state_remaining", NAN))), 0.65, "reversal warning remaining")
	controller.call("test_step", 0.65)
	_assert_state(_debug(controller), "active", -1, -1)

	controller.call("test_step", 4.0)
	var recovery := _debug(controller)
	_assert_state(recovery, "recovery", -1, -1)
	_assert_close(float(recovery.get("field_strength", NAN)), 1.0, "recovery starts at full strength")
	controller.call("test_step", 0.375)
	_assert_close(float(_debug(controller).get("field_strength", NAN)), 0.5, "recovery midpoint strength")
	controller.call("test_step", 0.375)
	_assert_state(_debug(controller), "idle", 0, 0)
	print("OK  idle -> warning -> active -> reversing -> active -> recovery -> idle")
	await _release_fixture(fixture)


func _verify_activator_cooldowns_and_rejections() -> void:
	print("\n--- Shoot-Only Activation And Cooldowns ---")
	var fixture := _new_fixture([])
	var controller: Node3D = fixture["controller"]
	var activators: Array = fixture["activators"]
	var activator_a: Node3D = activators[0]
	var activator_b: Node3D = activators[1]
	var attacker: RigidBody3D = _add_character(fixture, "Shooter", Vector3(10.0, 1.0, 0.0))

	for activator in activators:
		_assert(activator.has_method("apply_hit"), "Activator must preserve apply_hit weapon protocol")
		_assert(not activator is Area3D, "Shoot-only activator must not be an Area3D contact trigger")

	activator_a.call("apply_hit", Vector3.RIGHT * 10.0, 1.0, attacker, &"smg")
	var a_debug := _debug(activator_a)
	_assert(int(a_debug.get("activation_count", 0)) == 1, "First projectile hit must activate node A")
	_assert_close(float(a_debug.get("cooldown_remaining", NAN)), 8.0, "node A cooldown")
	activator_a.call("apply_hit", Vector3.RIGHT, 1.0, attacker, &"smg")
	a_debug = _debug(activator_a)
	_assert(int(a_debug.get("activation_count", 0)) == 1, "Node A cannot reactivate during its 8 second cooldown")
	_assert(int(a_debug.get("ignored_cooldown_hit_count", 0)) == 1, "Node A must record ignored cooldown hit")

	activator_b.call("apply_hit", Vector3.RIGHT, 1.0, attacker, &"shotgun")
	var b_debug := _debug(activator_b)
	_assert(int(b_debug.get("activation_count", 0)) == 0, "Global 0.75 second guard must reject node B")
	_assert_close(float(b_debug.get("cooldown_remaining", NAN)), 0.0, "rejected global-guard hit does not consume node B cooldown")
	controller.call("test_step", 0.75)
	activator_b.call("apply_hit", Vector3.RIGHT, 1.0, attacker, &"shotgun")
	b_debug = _debug(activator_b)
	_assert(int(b_debug.get("activation_count", 0)) == 0, "WARNING transition remains busy after global guard expires")
	_assert_close(float(b_debug.get("cooldown_remaining", NAN)), 0.0, "transition-busy rejection does not consume cooldown")
	controller.call("test_step", 0.50)
	activator_b.call("apply_hit", Vector3.RIGHT, 1.0, attacker, &"shotgun")
	b_debug = _debug(activator_b)
	_assert(int(b_debug.get("activation_count", 0)) == 1, "Node B must reverse the active field")
	_assert_close(float(b_debug.get("cooldown_remaining", NAN)), 8.0, "node B cooldown after accepted reversal")
	activator_a.call("_physics_process", 8.0)
	_assert(bool(_debug(activator_a).get("ready", false)), "Node cooldown must finish after 8 seconds")
	print("OK  projectile-only protocol, per-node cooldown, global guard, rejection semantics")
	await _release_fixture(fixture)


func _verify_corridor_force_and_velocity_isolation() -> void:
	print("\n--- Corridor Force And Velocity Isolation ---")
	var fixture := _new_fixture([])
	var controller: Node3D = fixture["controller"]
	var activators: Array = fixture["activators"]
	var attacker: RigidBody3D = _add_character(fixture, "FieldOwner", Vector3(25.0, 1.0, -10.0))
	var inside: RigidBody3D = _add_character(fixture, "Inside", Vector3(10.0, 1.0, 0.0))
	var outside_x: RigidBody3D = _add_character(fixture, "OutsideX", Vector3(1.99, 1.0, 0.0))
	var outside_y: RigidBody3D = _add_character(fixture, "OutsideY", Vector3(10.0, 7.01, 0.0))
	inside.linear_velocity = Vector3(25.0, 3.5, 4.0)
	# Same baseline as the in-corridor body makes the next physics tick a
	# control sample for the normal character damping path.
	outside_x.linear_velocity = Vector3(25.0, 3.5, 4.0)
	outside_y.linear_velocity = Vector3(6.0, -2.0, 1.0)

	controller.call("request_toggle", activators[0], attacker)
	controller.call("test_step", 1.25)
	var inside_y_before := inside.linear_velocity.y
	var inside_z_before := inside.linear_velocity.z
	var outside_x_before := outside_x.linear_velocity
	var outside_y_before := outside_y.linear_velocity
	controller.call("test_step", 1.0)

	var inside_context := controller.call("get_character_context", inside) as Dictionary
	var outside_x_context := controller.call("get_character_context", outside_x) as Dictionary
	var outside_y_context := controller.call("get_character_context", outside_y) as Dictionary
	_assert(bool(inside_context.get("in_corridor", false)), "X>=2 and -4<=Y<=7 character must be in corridor")
	_assert(not bool(outside_x_context.get("in_corridor", true)), "X<2 character must be outside corridor")
	_assert(not bool(outside_y_context.get("in_corridor", true)), "Y>7 character must be outside corridor")
	_assert_close(float(inside_context.get("environment_velocity_x", NAN)), 18.0, "field contribution capped at 18 u/s")
	_assert_close(inside.linear_velocity.y, inside_y_before, "field preserves vertical velocity")
	_assert_close(inside.linear_velocity.z, inside_z_before, "field preserves orthogonal horizontal velocity")
	_assert_vector_close(outside_x.linear_velocity, outside_x_before, "X-outside velocity remains unchanged")
	_assert_vector_close(outside_y.linear_velocity, outside_y_before, "Y-outside velocity remains unchanged")
	await physics_frame
	_assert(
		inside.linear_velocity.x > outside_x.linear_velocity.x + 15.0,
		"Field must add its contribution on top of the same pre-existing horizontal velocity"
	)

	inside.linear_velocity = Vector3.ZERO
	controller.call("test_step", 0.10)
	var contribution_after_tenth := absf(float((controller.call("get_character_context", inside) as Dictionary).get("environment_velocity_x", NAN)))
	_assert(contribution_after_tenth <= 18.0 + EPSILON, "Recorded environmental contribution must never exceed 18 u/s")
	print("OK  X>=2/Y=-4..7 corridor, +28 acceleration, 18 cap, Y/Z isolation")
	await _release_fixture(fixture)


func _verify_stabilizer_falloff_and_core_braking() -> void:
	print("\n--- Stabilizer Falloff And Core Braking ---")
	var fixture := _new_fixture([Vector3(10.0, 1.0, 0.0)])
	var controller: Node3D = fixture["controller"]
	var activators: Array = fixture["activators"]
	var anchors: Array = fixture["anchors"]
	var anchor: Node3D = anchors[0]
	var attacker: RigidBody3D = _add_character(fixture, "AnchorOwner", Vector3(25.0, 1.0, -10.0))
	var target: RigidBody3D = _add_character(fixture, "AnchorTarget", Vector3(20.0, 1.0, 0.0))
	controller.call("request_toggle", activators[0], attacker)
	controller.call("test_step", 1.25)
	controller.call("test_step", 0.30)
	var accumulated := controller.call("get_character_context", target) as Dictionary
	_assert(float(accumulated.get("environment_velocity_x", 0.0)) > 0.0, "Target must accumulate field velocity outside anchor")

	var preserved_y := 6.25
	target.linear_velocity.y = preserved_y
	target.global_position = anchor.global_position
	var core_context := controller.call("get_character_context", target) as Dictionary
	_assert(bool(core_context.get("in_stabilizer_core", false)), "Target at anchor center must be in core")
	_assert_close(float(core_context.get("stabilizer_strength", NAN)), 1.0, "anchor core strength")
	controller.call("test_step", 0.45)
	var cleared := controller.call("get_character_context", target) as Dictionary
	_assert_close(float(cleared.get("environment_velocity_x", NAN)), 0.0, "core clears recorded environment contribution in 0.45 seconds")
	_assert_close(target.linear_velocity.y, preserved_y, "anchor braking preserves vertical velocity")

	var midpoint_position := anchor.global_position + Vector3(4.125, 0.0, 0.0)
	_assert_close(float(anchor.call("get_stabilization_strength", midpoint_position)), 0.5, "smooth falloff midpoint", 0.001)
	_assert_close(float(anchor.call("get_stabilization_strength", anchor.global_position + Vector3(5.5, 0.0, 0.0))), 0.0, "outer radius boundary")
	_assert(bool(anchor.call("contains_core", anchor.global_position + Vector3(2.75, 0.0, 0.0))), "core radius includes 2.75 boundary")
	target.global_position = midpoint_position
	target.linear_velocity = Vector3.ZERO
	controller.call("test_step", 0.10)
	var midpoint_context := controller.call("get_character_context", target) as Dictionary
	_assert_close(float(midpoint_context.get("stabilizer_strength", NAN)), 0.5, "reported midpoint stabilizer strength", 0.001)
	_assert_close(float(midpoint_context.get("environment_velocity_x", NAN)), 1.4, "half-strength field acceleration", 0.03)
	print("OK  5.5 outer radius, 2.75 core, smooth falloff, 0.45 second contribution clear")
	await _release_fixture(fixture)


func _verify_kill_credit_rules() -> void:
	print("\n--- Field Kill Credit ---")
	var fixture := _new_fixture([])
	var controller: Node3D = fixture["controller"]
	var activators: Array = fixture["activators"]
	var enemy: RigidBody3D = _add_character(fixture, "Enemy", Vector3(25.0, 1.0, -10.0))
	var victim: RigidBody3D = _add_character(fixture, "Victim", Vector3(10.0, 1.0, 0.0))
	controller.call("request_toggle", activators[0], enemy)
	controller.call("test_step", 1.25)
	controller.call("test_step", 0.10)
	_assert(victim.get("last_hit_by") == enemy, "Latest enemy activator must receive field ring-out credit")
	var context := controller.call("get_character_context", victim) as Dictionary
	_assert(int(context.get("credited_attacker_instance_id", 0)) == enemy.get_instance_id(), "Character context must expose credited attacker")
	await _release_fixture(fixture)

	fixture = _new_fixture([])
	controller = fixture["controller"]
	activators = fixture["activators"]
	enemy = _add_character(fixture, "PriorEnemy", Vector3(25.0, 1.0, -10.0))
	victim = _add_character(fixture, "SelfTrigger", Vector3(10.0, 1.0, 0.0))
	victim.set("last_hit_by", enemy)
	controller.call("request_toggle", activators[0], victim)
	controller.call("test_step", 1.25)
	controller.call("test_step", 0.10)
	_assert(victim.get("last_hit_by") == enemy, "Self-trigger must not erase existing enemy credit")
	print("OK  latest enemy credit applied; self-trigger preserves prior enemy credit")
	await _release_fixture(fixture)


func _verify_ai_danger_bias() -> void:
	print("\n--- AI Hazard Provider ---")
	var fixture := _new_fixture([])
	var controller: Node3D = fixture["controller"]
	var activators: Array = fixture["activators"]
	var attacker: RigidBody3D = _add_character(fixture, "AIFieldOwner", Vector3(25.0, 1.0, -10.0))
	var probe: RigidBody3D = _add_character(fixture, "AIProbe", Vector3(10.0, 1.0, 0.0))
	controller.call("request_toggle", activators[0], attacker)
	controller.call("test_step", 1.25)
	var bias := controller.call("get_ai_movement_bias", probe) as Dictionary
	_assert(not bias.is_empty(), "Active corridor with no ground seven units down-force must produce AI bias")
	var direction := bias.get("direction", Vector3.ZERO) as Vector3
	_assert_vector_close(direction, Vector3.LEFT, "AI resists +X field toward -X")
	_assert_close(float(bias.get("weight", NAN)), 0.55, "AI resistance weight")
	probe.global_position.x = 1.0
	_assert((controller.call("get_ai_movement_bias", probe) as Dictionary).is_empty(), "AI outside corridor must receive no gravity bias")
	_assert(controller.is_in_group(&"party_shooter_ai_hazard_provider"), "Controller must register generic AI hazard-provider group")
	print("OK  seven-unit unsafe-ground probe yields opposite 0.55 movement bias")
	await _release_fixture(fixture)


func _new_fixture(anchor_positions: Array[Vector3]) -> Dictionary:
	_fixture_serial += 1
	var host := Node3D.new()
	host.name = "MomentumMechanicsFixture%d" % _fixture_serial
	root.add_child(host)

	var controller_script := load(CONTROLLER_SCRIPT_PATH) as Script
	var controller := controller_script.new() as Node3D
	controller.name = "GravityController"
	host.add_child(controller)
	controller.set_physics_process(false)

	var anchor_script := load(ANCHOR_SCRIPT_PATH) as Script
	var anchors: Array[Node3D] = []
	for index in range(anchor_positions.size()):
		var anchor := anchor_script.new() as Node3D
		anchor.name = "StabilizerAnchor%02d" % (index + 1)
		anchor.position = anchor_positions[index]
		host.add_child(anchor)
		anchors.append(anchor)
	controller.call("configure", FROZEN_CONFIG, anchors)

	var activator_script := load(ACTIVATOR_SCRIPT_PATH) as Script
	var activators: Array[Node3D] = []
	for index in range(3):
		var activator := activator_script.new() as Node3D
		activator.name = "GravityActivator%02d" % (index + 1)
		host.add_child(activator)
		activator.set_physics_process(false)
		activator.call("configure", controller, 8.0)
		activators.append(activator)
	return {
		"host": host,
		"controller": controller,
		"activators": activators,
		"anchors": anchors,
		"characters": [],
	}


func _add_character(fixture: Dictionary, character_name: String, position: Vector3) -> RigidBody3D:
	var script := load(CHARACTER_SCRIPT_PATH) as Script
	var character := script.new() as RigidBody3D
	character.name = character_name
	character.position = position
	character.mass = 10.0
	character.add_to_group(&"player")
	(fixture["host"] as Node).add_child(character)
	character.gravity_scale = 0.0
	character.linear_velocity = Vector3.ZERO
	(fixture["characters"] as Array).append(character)
	return character


func _release_fixture(fixture: Dictionary) -> void:
	var host := fixture.get("host") as Node
	if host != null and is_instance_valid(host):
		host.queue_free()
		await process_frame
		await process_frame


func _debug(node: Node) -> Dictionary:
	if node == null or not node.has_method("get_debug_state"):
		return {}
	return node.call("get_debug_state") as Dictionary


func _assert_state(debug: Dictionary, expected_state: String, expected_direction: int, expected_pending: int) -> void:
	_assert(String(debug.get("state", "")) == expected_state, "Expected state %s, got %s" % [expected_state, debug.get("state", "<missing>")])
	_assert(int(debug.get("direction", 999)) == expected_direction, "%s direction must be %d" % [expected_state, expected_direction])
	_assert(int(debug.get("pending_direction", 999)) == expected_pending, "%s pending direction must be %d" % [expected_state, expected_pending])


func _assert_vector_close(actual: Vector3, expected: Vector3, label: String, tolerance: float = EPSILON) -> void:
	if not _finite_vector(actual) or actual.distance_to(expected) > tolerance:
		_fail("%s differs: %s != %s (tolerance %.4f)" % [label, actual, expected, tolerance])


func _assert_close(actual: float, expected: float, label: String, tolerance: float = EPSILON) -> void:
	if not is_finite(actual) or absf(actual - expected) > tolerance:
		_fail("%s differs: %.6f != %.6f (tolerance %.6f)" % [label, actual, expected, tolerance])


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	root.set_meta("disable_runtime_audio", false)
	await process_frame
	print("==================================================")
	if _failures.is_empty():
		print("RESULT momentum_circuit_mechanics passed=true failures=0")
		print("[Momentum Circuit Mechanics Verifier] PASS")
		quit(0)
		return
	print("RESULT momentum_circuit_mechanics passed=false failures=%d" % _failures.size())
	print("[Momentum Circuit Mechanics Verifier] FAIL")
	for failure in _failures:
		print("- ", failure)
	quit(1)
