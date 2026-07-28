extends "res://scripts/maps/momentum_circuit_environment_dressing_v8.gd"
class_name MomentumCircuitEnvironmentDressingV9

## V9 uses the approved energy-array matte for the complex tower/gantry
## composition.  Runtime low-poly geometry is reserved for traffic, where
## parallax and motion add value without trying to imitate the painted detail.


func configure(config: Dictionary, camera: Camera3D = null) -> void:
	super.configure(config, camera)
	set_meta("environment_version", 9)
	set_meta("composition_contract", "no_edge_clipping_clean_gameplay_basin")


func get_debug_state() -> Dictionary:
	var debug := super.get_debug_state()
	debug["version"] = 9
	debug["composition_contract"] = String(
		get_meta("composition_contract", "")
	)
	debug["static_landmark_count"] = int(
		(_config.get("instances", []) as Array).size()
	)
	debug["active_motion_system_count"] = (
		1 if not (_config.get("traffic_routes", []) as Array).is_empty() else 0
	)
	return debug
