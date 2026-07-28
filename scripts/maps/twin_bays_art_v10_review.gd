extends "res://scripts/maps/twin_bays_art_v9_review.gd"
class_name TwinBaysArtV10Review

## Isolated V10 bridge. The only new geometry is a set of narrow visual seam
## rings joined into the existing portal-recess material batch.

const ART_V10_FOREGROUND_SCENE_PATH := \
	"res://assets/review/twin_bays_art_v10/candidate/twin_bays_art_v10_foreground.glb"


func configure(arena: Node3D, art_profile: Dictionary) -> void:
	super.configure(arena, art_profile)
	name = "TwinBaysArtV10Review"
	set_meta("art_v10_review", true)
	set_meta("front_bumper_seams_candidate", true)


func _replace_foreground(foreground: Node) -> void:
	var packed := load(ART_V10_FOREGROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Art V10 review foreground is missing: %s" % ART_V10_FOREGROUND_SCENE_PATH)
		return
	var candidate := packed.instantiate() as Node3D
	if candidate == null:
		push_error("Art V10 review foreground could not be instantiated")
		return
	for child in foreground.get_children():
		foreground.remove_child(child)
		child.free()
		_replaced_visual_nodes += 1
	candidate.name = "TwinBaysArtV10FrontBumperForeground"
	candidate.set_meta("visual_only", true)
	candidate.set_meta("review_only", true)
	candidate.set_meta("front_bumper_seams_candidate", true)
	foreground.add_child(candidate)
	_candidate = candidate
