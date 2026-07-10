extends RefCounted
class_name RuntimeGlobals

static func game_config() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("GameConfig")
	return null

static func game_feel() -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_node_or_null("GameFeel")
	return null

static func active_scene(tree: SceneTree) -> Node:
	if tree == null:
		return null
	if tree.current_scene:
		return tree.current_scene
	if tree.root == null or tree.root.get_child_count() == 0:
		return null
	return tree.root.get_child(tree.root.get_child_count() - 1)

static func runtime_audio_disabled() -> bool:
	var main_loop = Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).root.get_meta("disable_runtime_audio", false)
	return false
