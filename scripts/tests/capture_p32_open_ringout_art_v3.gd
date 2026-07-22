extends SceneTree

## Capture-only preview gate for the opt-in P32 Open Ring-Out art layer.
## The instantiated scene keeps the production map script, collision, camera,
## HUD, weapons, and character runtime; only map art visibility is overridden.

const SCENE_PATH := "res://scenes/tests/p32_open_ringout_art_v3_preview.tscn"
const PREVIEW_ROOT_NAME := "OpenRingoutArtV3Preview"
const ART_SCENE_PATH := "res://assets/models/generated/open_ringout_art_v3/open_ringout_art_v3.glb"

var _arena: Node3D = null
var _failures: Array[String] = []

func _initialize() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("P32 art preview capture requires a render-capable display driver")
		return
	if not ResourceLoader.exists(ART_SCENE_PATH):
		_fail("P32 art GLB is missing: %s" % ART_SCENE_PATH)
		return

	var packed_scene := load(SCENE_PATH) as PackedScene
	if packed_scene == null:
		_fail("Could not load P32 preview scene: %s" % SCENE_PATH)
		return

	_arena = packed_scene.instantiate() as Node3D
	if _arena == null:
		_fail("Could not instantiate P32 preview scene")
		return
	root.add_child(_arena)
	current_scene = _arena

	await process_frame
	await process_frame
	await physics_frame
	await RenderingServer.frame_post_draw

	_verify_preview_contract()
	if _failures.is_empty():
		_save_requested_capture()
	if _failures.is_empty():
		print("P32_OPEN_RINGOUT_ART_V3_PREVIEW_PASS")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)

func _verify_preview_contract() -> void:
	if not bool(_arena.get("p32_open_ringout_art_preview")):
		_fail("P32 preview scene did not enable the opt-in art flag")
	var art_root := _arena.get_node_or_null(PREVIEW_ROOT_NAME)
	if art_root == null:
		_fail("P32 preview root is missing: %s" % PREVIEW_ROOT_NAME)
	elif art_root.get_child_count() == 0:
		_fail("P32 preview root has no instantiated GLB visual")
	for legacy_root_name in [
		"OpenRingoutDressing",
		"OpenRingoutPlayable",
		"OpenRingoutCovers",
		"OpenRingoutEdgeGlow",
		"OpenRingoutAbyss",
		"OpenRingoutBackdrop",
		"OpenRingoutArt",
		"OpenRingoutBlenderVisuals",
	]:
		var legacy_root := _arena.get_node_or_null(legacy_root_name)
		if legacy_root and legacy_root.visible:
			_fail("Legacy map art remains visible in P32 preview: %s" % legacy_root_name)
	if _arena.get_node_or_null("OpenRingoutPlayable") == null:
		_fail("Production playable collision root is missing")
	if _arena.get_node_or_null("GlobalCamera") == null:
		_fail("Production camera is missing")
	if _arena.get_node_or_null("OpenRingoutHUD") == null:
		_fail("Production HUD is missing")

func _save_requested_capture() -> void:
	var output := _argument_value("--output=", "")
	if output.is_empty():
		return
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Could not read the rendered preview viewport")
		return
	var absolute := ProjectSettings.globalize_path(output) if output.begins_with("res://") else output
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK or image.save_png(absolute) != OK:
		_fail("Could not save P32 preview capture: %s" % output)

func _argument_value(prefix: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix).strip_edges()
	return fallback

func _fail(message: String) -> void:
	_failures.append(message)
