extends "res://scripts/maps/twin_bays_art_v5_review.gd"
class_name TwinBaysArtV6Review

## Isolated Art V6 bridge. Lighting/profile behavior is inherited from V5;
## only the collision-free candidate foreground path changes.

const ART_V6_FOREGROUND_SCENE_PATH := \
	"res://assets/review/twin_bays_art_v6/candidate/twin_bays_art_v6_foreground.glb"


func configure(arena: Node3D, art_profile: Dictionary) -> void:
	super.configure(arena, art_profile)
	name = "TwinBaysArtV6Review"
	set_meta("art_v6_review", true)


func _replace_foreground(foreground: Node) -> void:
	var packed := load(ART_V6_FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Art V6 review foreground is missing: %s" % ART_V6_FOREGROUND_SCENE_PATH)
		return
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		push_error("Art V6 review foreground could not be instantiated")
		return
	for child in foreground.get_children():
		foreground.remove_child(child)
		child.free()
		_replaced_visual_nodes += 1
	candidate.name = "TwinBaysArtV6ReviewForeground"
	candidate.set_meta("visual_only", true)
	candidate.set_meta("review_only", true)
	candidate.set_meta("professional_finish_candidate", true)
	foreground.add_child(candidate)
	_candidate = candidate
