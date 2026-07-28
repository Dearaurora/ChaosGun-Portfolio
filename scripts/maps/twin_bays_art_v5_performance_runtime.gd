extends "res://scripts/maps/twin_bays_splash_arena.gd"

## Performance-only direct Art V5 route. It avoids loading the Art V4 foreground
## before swapping to the isolated candidate, which would inflate GPU memory.

const ART_V5_FOREGROUND_SCENE_PATH := \
	"res://assets/review/twin_bays_art_v5/candidate/twin_bays_art_v5_foreground.glb"
const ART_V5_PROFILE_PATH := "res://resources/maps/twin_bays_art_v5.json"


func _ready() -> void:
	set_meta("art_v5_performance_direct", true)
	super._ready()


func _load_art_profile() -> Dictionary:
	if not FileAccess.file_exists(ART_V5_PROFILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_V5_PROFILE_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _build_twin_bays_foreground(parent: Node3D) -> void:
	var packed := load(ART_V5_FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Twin Bays Art V5 performance foreground is missing")
		return
	var foreground := packed.instantiate() as Node3D
	if foreground == null:
		push_error("Twin Bays Art V5 performance foreground could not be instantiated")
		return
	foreground.name = "TwinBaysArtV5PerformanceForeground"
	foreground.set_meta("visual_only", true)
	foreground.set_meta("review_only", true)
	foreground.set_meta("layout_source", TwinBaysLayoutScript.DEFAULT_PATH)
	parent.add_child(foreground)
