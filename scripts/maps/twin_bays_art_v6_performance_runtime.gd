extends "res://scripts/maps/twin_bays_splash_arena.gd"

## Performance-only direct Art V6 route. V5 remains untouched and the merged
## profile is resolved in memory from the frozen V5 base plus V6 override.

const ART_V6_FOREGROUND_SCENE_PATH := \
	"res://assets/review/twin_bays_art_v6/candidate/twin_bays_art_v6_foreground.glb"
const ART_V5_PROFILE_PATH := "res://resources/maps/twin_bays_art_v5.json"
const ART_V6_PROFILE_PATH := "res://resources/maps/twin_bays_art_v6.json"


func _ready() -> void:
	set_meta("art_v6_performance_direct", true)
	super._ready()


func _load_art_profile() -> Dictionary:
	var base_profile := _load_json_dictionary(ART_V5_PROFILE_PATH)
	var override := _load_json_dictionary(ART_V6_PROFILE_PATH)
	if base_profile.is_empty() or override.is_empty():
		return {}
	return _deep_merge_dictionary(base_profile, override)


func _build_twin_bays_foreground(parent: Node3D) -> void:
	var packed := load(ART_V6_FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Twin Bays Art V6 performance foreground is missing")
		return
	var foreground := packed.instantiate() as Node3D
	if foreground == null:
		push_error("Twin Bays Art V6 performance foreground could not be instantiated")
		return
	foreground.name = "TwinBaysArtV6PerformanceForeground"
	foreground.set_meta("visual_only", true)
	foreground.set_meta("review_only", true)
	foreground.set_meta("layout_source", TwinBaysLayoutScript.DEFAULT_PATH)
	parent.add_child(foreground)


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _deep_merge_dictionary(parent: Dictionary, override: Dictionary) -> Dictionary:
	var merged := parent.duplicate(true)
	for key: Variant in override:
		var value: Variant = override[key]
		if value is Dictionary and merged.get(key) is Dictionary:
			merged[key] = _deep_merge_dictionary(merged[key] as Dictionary, value as Dictionary)
		else:
			merged[key] = value
	return merged
