extends SceneTree

const SCENE_PATH := "res://scenes/maps/twin_bays_splash_arena.tscn"

func _initialize() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Twin Bays splash scene could not be loaded")
		quit(1)
		return
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	await process_frame
	if String(arena.get_meta("ringout_burst_mode", "")) != "water_splash":
		push_error("Twin Bays must opt into the water splash ring-out mode")
		quit(1)
		return
	if not arena.has_method("spawn_water_fall_effect"):
		push_error("Twin Bays water splash callback is missing")
		quit(1)
		return
	arena.call("spawn_water_fall_effect", Vector3(0.0, -2.0, 0.0))
	await process_frame
	var splash := arena.find_child("WaterFallSplash", true, false)
	if splash == null:
		push_error("Twin Bays water splash node was not spawned")
		arena.queue_free()
		await process_frame
		quit(1)
		return
	print("RESULT twin_bays_ringout_splash passed=true")
	arena.queue_free()
	await process_frame
	quit(0)
