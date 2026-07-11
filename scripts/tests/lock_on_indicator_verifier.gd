extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	print("==================================================")
	print("[Lock-On Indicator Verifier]")
	print("==================================================")

	var scene := load("res://scenes/characters/player.tscn") as PackedScene
	var player := scene.instantiate() as PlayerCharacter if scene else null
	if player == null:
		_fail("Player scene must instantiate")
		await _finish([])
		return
	root.add_child(player)
	await process_frame

	var indicator := player.call("_ensure_lock_indicator") as MeshInstance3D
	if indicator == null:
		_fail("Lock-on indicator must be created")
	else:
		if not (indicator.mesh is TorusMesh):
			_fail("Lock-on indicator must use a ground ring instead of a head disc")
		if indicator.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			_fail("Lock-on indicator must not cast a shadow")
		var material := indicator.material_override as StandardMaterial3D
		if material == null or material.albedo_color.a > 0.60:
			_fail("Lock-on ground ring must remain visually restrained")

	await _finish([player, indicator])


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish(nodes: Array) -> void:
	for node in nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[Lock-On Indicator Verifier] PASS")
		quit(0)
		return
	print("[Lock-On Indicator Verifier] FAIL")
	quit(1)
