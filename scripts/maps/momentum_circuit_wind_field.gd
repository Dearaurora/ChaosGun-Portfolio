extends Node3D
class_name MomentumCircuitWindFieldController

signal wind_rescue_started(character: BaseCharacter, hole_id: String, start_position: Vector3, landing_position: Vector3)
signal wind_rescue_landed(character: BaseCharacter, hole_id: String, landing_position: Vector3)

var _holes: Array[Dictionary] = []
var _config: Dictionary = {}
var _flights: Dictionary = {}
var _rescue_count := 0
var _last_rescue := {}

func configure(holes: Array, config: Dictionary) -> void:
	_holes.clear()
	_config = config.duplicate(true)
	for value in holes:
		if not value is Dictionary:
			continue
		var hole := (value as Dictionary).duplicate(true)
		hole["polygon"] = _to_polygon(hole.get("outline_world_xz", []))
		hole["center"] = _to_center(hole)
		_holes.append(hole)

func get_debug_state() -> Dictionary:
	return {
		"hole_count": _holes.size(),
		"active_flights": _flights.size(),
		"rescue_count": _rescue_count,
		"last_rescue": _last_rescue.duplicate(true),
	}

func _physics_process(delta: float) -> void:
	_update_flights(delta)
	for node in get_tree().get_nodes_in_group("player"):
		if not node is BaseCharacter:
			continue
		var character := node as BaseCharacter
		if character.is_dead or character.is_game_over or character.is_scripted_traversal_active():
			continue
		var hole := _find_hole(character.global_position)
		if hole.is_empty():
			continue
		if character.global_position.y > float(hole.get("top_y", 1.0)) - float(_config.get("catch_depth", -0.35)):
			continue
		if character.global_position.y < float(_config.get("bottom_depth", -8.0)):
			continue
		_start_rescue(character, hole)

func _start_rescue(character: BaseCharacter, hole: Dictionary) -> void:
	var id := character.get_instance_id()
	if _flights.has(id):
		return
	var landing := _find_landing(character.global_position, hole)
	if landing == Vector3.INF:
		return
	if not character.begin_scripted_traversal(self):
		return
	var start := character.global_position
	var distance := start.distance_to(landing)
	var duration := clampf(distance / 24.0, float(_config.get("flight_min_seconds", 0.9)), float(_config.get("flight_max_seconds", 1.25)))
	_flights[id] = {
		"character": character,
		"hole_id": String(hole.get("id", "hole")),
		"start": start,
		"landing": landing,
		"elapsed": 0.0,
		"duration": duration,
		"release": false,
		"release_elapsed": 0.0,
	}
	_rescue_count += 1
	_last_rescue = {"character": character.name, "hole_id": String(hole.get("id", "hole")), "start": start, "landing": landing}
	wind_rescue_started.emit(character, String(hole.get("id", "hole")), start, landing)

func _update_flights(delta: float) -> void:
	for key in _flights.keys().duplicate():
		var flight := _flights[key] as Dictionary
		var character := flight.get("character") as BaseCharacter
		if not is_instance_valid(character) or character.is_dead:
			_flights.erase(key)
			continue
		if not bool(flight.get("release", false)):
			flight["elapsed"] = float(flight.get("elapsed", 0.0)) + delta
			var t := clampf(float(flight["elapsed"]) / float(flight["duration"]), 0.0, 1.0)
			var start: Vector3 = flight["start"]
			var landing: Vector3 = flight["landing"]
			var apex := float(_config.get("apex_height", 8.0))
			var position := start.lerp(landing, t)
			position.y = lerpf(start.y, landing.y, t) + 4.0 * apex * t * (1.0 - t)
			character.update_scripted_traversal_position(self, position)
			if t >= 0.92:
				flight["release"] = true
				flight["release_elapsed"] = 0.0
				character.update_scripted_traversal_position(self, landing + Vector3.UP * float(_config.get("landing_release_height", 2.0)))
				character.release_scripted_traversal(self, Vector3(0.0, -8.0, 0.0))
			continue
		flight["release_elapsed"] = float(flight.get("release_elapsed", 0.0)) + delta
		if character.is_on_floor() or float(flight["release_elapsed"]) >= float(_config.get("landing_timeout_seconds", 1.1)):
			character.global_position = flight["landing"]
			character.linear_velocity = Vector3.ZERO
			wind_rescue_landed.emit(character, String(flight["hole_id"]), flight["landing"])
			_flights.erase(key)

func _find_hole(position: Vector3) -> Dictionary:
	for hole in _holes:
		if _point_in_polygon(Vector2(position.x, position.z), hole.get("polygon", PackedVector2Array())):
			return hole
	return {}

func _find_landing(position: Vector3, hole: Dictionary) -> Vector3:
	var polygon: PackedVector2Array = hole.get("polygon", PackedVector2Array())
	if polygon.size() < 3:
		return Vector3.INF
	var center: Vector2 = hole.get("center", Vector2(position.x, position.z))
	var outward := Vector2(position.x, position.z) - center
	if outward.length_squared() < 0.01:
		outward = Vector2.RIGHT
	outward = outward.normalized()
	var opposite := -outward
	var best := center
	var best_projection := -INF
	for point in polygon:
		var projection := (point - center).dot(opposite)
		if projection > best_projection:
			best_projection = projection
			best = point
	var candidate := best + opposite * float(_config.get("landing_inset", 2.2))
	var landing := _raycast_landing(candidate)
	if landing != Vector3.INF:
		return landing
	for angle in [15.0, -15.0, 30.0, -30.0, 45.0, -45.0, 60.0, -60.0]:
		var rotated := opposite.rotated(deg_to_rad(angle))
		landing = _raycast_landing(best + rotated * float(_config.get("landing_inset", 2.2)))
		if landing != Vector3.INF:
			return landing
	return Vector3.INF

func _raycast_landing(candidate: Vector2) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(Vector3(candidate.x, 8.0, candidate.y), Vector3(candidate.x, -4.0, candidate.y))
	query.collision_mask = 1
	query.collide_with_areas = false
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.INF
	return (result["position"] as Vector3) + Vector3.UP * 1.05

func _to_polygon(value: Variant) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if value is Array:
		for point in value as Array:
			if point is Array and (point as Array).size() >= 2:
				polygon.append(Vector2(float(point[0]), float(point[1])))
	return polygon

func _to_center(hole: Dictionary) -> Vector2:
	var value: Variant = hole.get("center_world_xz", hole.get("center_world", hole.get("center", [0.0, 0.0])))
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	var polygon: PackedVector2Array = hole.get("polygon", PackedVector2Array())
	var center := Vector2.ZERO
	for point in polygon: center += point
	return center / maxf(1.0, polygon.size())

func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var j := polygon.size() - 1
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[j]
		if ((a.y > point.y) != (b.y > point.y)) and point.x < (b.x - a.x) * (point.y - a.y) / maxf(0.00001, b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside
