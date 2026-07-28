extends "res://scripts/maps/twin_bays_art_v6_review.gd"
class_name TwinBaysArtV7Review

## Isolated V7 Benchmark Corner bridge. The full resolved V5+V6+V7 profile
## remains in memory; only the collision-free candidate foreground is swapped.

const ART_V7_FOREGROUND_SCENE_PATH := \
	"res://assets/review/twin_bays_art_v7/candidate/twin_bays_art_v7_foreground.glb"


func configure(arena: Node3D, art_profile: Dictionary) -> void:
	super.configure(arena, art_profile)
	name = "TwinBaysArtV7Review"
	set_meta("art_v7_review", true)


func _replace_foreground(foreground: Node) -> void:
	var packed := load(ART_V7_FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Art V7 review foreground is missing: %s" % ART_V7_FOREGROUND_SCENE_PATH)
		return
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		push_error("Art V7 review foreground could not be instantiated")
		return
	for child in foreground.get_children():
		foreground.remove_child(child)
		child.free()
		_replaced_visual_nodes += 1
	candidate.name = "TwinBaysArtV7BenchmarkForeground"
	candidate.set_meta("visual_only", true)
	candidate.set_meta("review_only", true)
	candidate.set_meta("benchmark_corner_candidate", true)
	foreground.add_child(candidate)
	_candidate = candidate
