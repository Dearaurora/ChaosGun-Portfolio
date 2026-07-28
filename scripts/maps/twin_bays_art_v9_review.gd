extends "res://scripts/maps/twin_bays_art_v8_review.gd"
class_name TwinBaysArtV9Review

## Isolated V9 foreground bridge. Runtime water and light remain the retained
## V8 look; only the collision-free foreground GLB adds soft cap modules.

const ART_V9_FOREGROUND_SCENE_PATH := \
	"res://assets/review/twin_bays_art_v9/candidate/twin_bays_art_v9_foreground.glb"


func configure(arena: Node3D, art_profile: Dictionary) -> void:
	super.configure(arena, art_profile)
	name = "TwinBaysArtV9Review"
	set_meta("art_v9_review", true)
	set_meta("soft_cap_modules_candidate", true)


func _replace_foreground(foreground: Node) -> void:
	var packed := load(ART_V9_FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Art V9 review foreground is missing: %s" % ART_V9_FOREGROUND_SCENE_PATH)
		return
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		push_error("Art V9 review foreground could not be instantiated")
		return
	for child in foreground.get_children():
		foreground.remove_child(child)
		child.free()
		_replaced_visual_nodes += 1
	candidate.name = "TwinBaysArtV9SoftCapForeground"
	candidate.set_meta("visual_only", true)
	candidate.set_meta("review_only", true)
	candidate.set_meta("soft_cap_modules_candidate", true)
	foreground.add_child(candidate)
	_candidate = candidate
