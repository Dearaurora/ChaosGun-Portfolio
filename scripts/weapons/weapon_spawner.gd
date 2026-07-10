extends Node
class_name WeaponSpawner

const RuntimeGlobals = preload("res://scripts/globals/runtime_globals.gd")

@export var initial_delay: float = 20.0
@export var stay_duration: float = 30.0
@export var respawn_cooldown: float = 10.0
@export var max_active_pickups: int = 1
@export var spawn_margin: float = 10.0
@export var map_half_size: float = 50.0

var custom_spawn_points: Array = []
var custom_spawn_clusters: Array = []
var fixed_spawn_points: Array = []
var random_spawn_points: Array = []
var random_spawn_interval: float = 15.0
var random_stay_duration: float = 4.5

var _active_pickups: Array[Node3D] = []
var _pickup_scene: PackedScene

func _ready() -> void:
	_pickup_scene = load("res://scenes/weapons/weapon_pickup.tscn")
	_start_spawn_timer_after_scene_config()

func _start_spawn_timer_after_scene_config() -> void:
	await get_tree().process_frame
	_start_spawn_timer()

func _start_spawn_timer() -> void:
	if _uses_controlled_spawn_mode():
		get_tree().create_timer(initial_delay).timeout.connect(_start_controlled_spawn_cycle)
	else:
		get_tree().create_timer(initial_delay).timeout.connect(_fill_pickups)

func _uses_controlled_spawn_mode() -> bool:
	return not fixed_spawn_points.is_empty() or not random_spawn_points.is_empty()

func _start_controlled_spawn_cycle() -> void:
	_fill_fixed_pickups()
	_try_spawn_random_pickup()
	_schedule_next_random_pickup()

func _schedule_next_random_pickup() -> void:
	if not _uses_controlled_spawn_mode():
		return
	get_tree().create_timer(random_spawn_interval).timeout.connect(
		func() -> void:
			_try_spawn_random_pickup()
			_schedule_next_random_pickup()
	)

func _fill_fixed_pickups() -> void:
	_prune_invalid_pickups()
	for index in range(fixed_spawn_points.size()):
		if _has_active_fixed_pickup(index):
			continue
		var spawn_position := fixed_spawn_points[index] as Vector3
		_spawn_pickup_at(spawn_position, -1, "fixed", stay_duration, index)

func _try_spawn_random_pickup() -> void:
	_prune_invalid_pickups()
	if random_spawn_points.is_empty():
		return
	if _has_active_spawn_kind("random"):
		return
	var spawn_position := _pick_point_from_pool(random_spawn_points)
	_spawn_pickup_at(spawn_position, -1, "random", random_stay_duration)

func _fill_pickups() -> void:
	if _uses_controlled_spawn_mode():
		_fill_fixed_pickups()
		return
	_prune_invalid_pickups()
	if max_active_pickups <= 0:
		return

	for cluster_id in _get_unused_cluster_ids():
		if _active_pickups.size() >= max_active_pickups:
			return
		_spawn_weapon(cluster_id)

	var missing_pickups = max(0, max_active_pickups - _active_pickups.size())
	for _i in range(missing_pickups):
		_spawn_weapon()

func _spawn_weapon(preferred_cluster_id: int = -1) -> void:
	_prune_invalid_pickups()
	if max_active_pickups <= 0 or _active_pickups.size() >= max_active_pickups:
		return
	var spawn_slot = _pick_spawn_slot(preferred_cluster_id)
	var spawn_position = spawn_slot.get("position", Vector3.ZERO) as Vector3
	var cluster_id = int(spawn_slot.get("cluster_id", -1))
	_spawn_pickup_at(spawn_position, cluster_id, "pooled", stay_duration)

func _spawn_pickup_at(
	spawn_position: Vector3,
	cluster_id: int = -1,
	spawn_kind: String = "pooled",
	expiry_duration: float = -1.0,
	fixed_spawn_index: int = -1
) -> void:
	_prune_invalid_pickups()
	if max_active_pickups <= 0 or _active_pickups.size() >= max_active_pickups:
		return

	var scene_root = RuntimeGlobals.active_scene(get_tree())
	if scene_root == null:
		return

	var pickup = _pickup_scene.instantiate() as Node3D
	if pickup == null:
		return

	var factories = WeaponData.get_spawnable_weapons()
	var factory = factories.pick_random() as Callable
	var weapon_data = factory.call() as WeaponData

	scene_root.add_child(pickup)
	pickup.global_position = spawn_position
	pickup.setup(weapon_data)
	if cluster_id >= 0:
		pickup.set_meta("spawn_cluster_id", cluster_id)
	pickup.set_meta("spawn_kind", spawn_kind)
	if fixed_spawn_index >= 0:
		pickup.set_meta("fixed_spawn_index", fixed_spawn_index)
	pickup.picked_up.connect(_on_picked_up.bind(pickup))
	_active_pickups.append(pickup)
	var pickup_id = pickup.get_instance_id()
	var lifetime = expiry_duration if expiry_duration > 0.0 else stay_duration

	get_tree().create_timer(lifetime).timeout.connect(
		func() -> void:
			_on_expired(pickup_id)
	)

func _pick_spawn_slot(preferred_cluster_id: int = -1) -> Dictionary:
	if not custom_spawn_clusters.is_empty():
		var cluster_ids: Array[int] = []
		if preferred_cluster_id >= 0 and preferred_cluster_id < custom_spawn_clusters.size():
			cluster_ids.append(preferred_cluster_id)
		else:
			for cluster_index in range(custom_spawn_clusters.size()):
				cluster_ids.append(cluster_index)

		while not cluster_ids.is_empty():
			var cluster_id = cluster_ids.pick_random()
			cluster_ids.erase(cluster_id)
			var points = _get_cluster_points(cluster_id)
			if points.is_empty():
				continue
			return {
				"position": _pick_point_from_pool(points),
				"cluster_id": cluster_id,
			}

	if not custom_spawn_points.is_empty():
		return {
			"position": _pick_point_from_pool(custom_spawn_points),
			"cluster_id": -1,
		}

	var half = map_half_size - spawn_margin
	return {
		"position": Vector3(randf_range(-half, half), 1.5, randf_range(-half, half)),
		"cluster_id": -1,
	}

func _pick_point_from_pool(points: Array) -> Vector3:
	var available_points: Array[Vector3] = []
	for point in points:
		var candidate = point as Vector3
		if not _spawn_point_is_occupied(candidate):
			available_points.append(candidate)
	var pool = available_points if not available_points.is_empty() else points
	return pool.pick_random() as Vector3

func _get_cluster_points(cluster_id: int) -> Array:
	if cluster_id < 0 or cluster_id >= custom_spawn_clusters.size():
		return []
	var cluster_points = custom_spawn_clusters[cluster_id]
	return cluster_points if cluster_points is Array else []

func _get_unused_cluster_ids() -> Array[int]:
	if custom_spawn_clusters.is_empty():
		return []

	var active_cluster_ids: Dictionary = {}
	for pickup in _active_pickups:
		if is_instance_valid(pickup) and pickup.has_meta("spawn_cluster_id"):
			active_cluster_ids[int(pickup.get_meta("spawn_cluster_id"))] = true

	var unused_cluster_ids: Array[int] = []
	for cluster_id in range(custom_spawn_clusters.size()):
		if not active_cluster_ids.has(cluster_id):
			unused_cluster_ids.append(cluster_id)
	return unused_cluster_ids

func _has_active_spawn_kind(spawn_kind: String) -> bool:
	for pickup in _active_pickups:
		if is_instance_valid(pickup) and String(pickup.get_meta("spawn_kind", "pooled")) == spawn_kind:
			return true
	return false

func _has_active_fixed_pickup(fixed_spawn_index: int) -> bool:
	for pickup in _active_pickups:
		if not is_instance_valid(pickup):
			continue
		if String(pickup.get_meta("spawn_kind", "pooled")) != "fixed":
			continue
		if int(pickup.get_meta("fixed_spawn_index", -1)) == fixed_spawn_index:
			return true
	return false

func _spawn_point_is_occupied(point: Vector3) -> bool:
	for pickup in _active_pickups:
		if is_instance_valid(pickup) and pickup.global_position.distance_to(point) < 0.5:
			return true
	return false

func _on_picked_up(pickup: Node3D) -> void:
	var spawn_kind := String(pickup.get_meta("spawn_kind", "pooled"))
	var fixed_spawn_index := int(pickup.get_meta("fixed_spawn_index", -1))
	_remove_pickup(pickup)
	_schedule_refill(spawn_kind, fixed_spawn_index)

func _on_expired(pickup_id: int) -> void:
	var pickup = instance_from_id(pickup_id) as Node3D
	var spawn_kind := "pooled"
	var fixed_spawn_index := -1
	if is_instance_valid(pickup):
		spawn_kind = String(pickup.get_meta("spawn_kind", "pooled"))
		fixed_spawn_index = int(pickup.get_meta("fixed_spawn_index", -1))
		pickup.queue_free()
	_remove_pickup(pickup)
	_schedule_refill(spawn_kind, fixed_spawn_index)

func _schedule_refill(spawn_kind: String = "pooled", _fixed_spawn_index: int = -1) -> void:
	if _uses_controlled_spawn_mode():
		if spawn_kind == "fixed":
			get_tree().create_timer(respawn_cooldown).timeout.connect(_fill_fixed_pickups)
		return
	get_tree().create_timer(respawn_cooldown).timeout.connect(_fill_pickups)

func _remove_pickup(pickup: Node3D) -> void:
	_active_pickups = _active_pickups.filter(
		func(existing: Node3D) -> bool:
			return is_instance_valid(existing) and existing != pickup
	)

func _prune_invalid_pickups() -> void:
	_active_pickups = _active_pickups.filter(
		func(pickup: Node3D) -> bool:
			return is_instance_valid(pickup)
	)
