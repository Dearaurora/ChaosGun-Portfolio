extends CanvasLayer
class_name MatchHUD

const TOY_UI = preload("res://scripts/ui/toy_sunset_ui.gd")
const HUD_PLAYER_CARD = preload("res://scenes/ui/components/hud_player_card.tscn")

const PANEL_SIZE := Vector2(200, 72)
const PANEL_MARGIN := Vector2(12, 12)
const CAMERA_OCCLUSION_GUTTER := 8.0
const CAMERA_OCCLUDER_GROUP := &"party_shooter_camera_occluder"

var _characters: Array = []
var _panels: Array[Control] = []

@onready var _root: Control = $HUDRoot


static func camera_occlusion_rects(viewport_size: Vector2, panel_count: int = 4) -> Array[Rect2]:
	var ui_scale := TOY_UI.ui_scale(viewport_size)
	var footprint := (PANEL_MARGIN + PANEL_SIZE + Vector2.ONE * CAMERA_OCCLUSION_GUTTER) * ui_scale
	var right := maxf(viewport_size.x - footprint.x, 0.0)
	var bottom := maxf(viewport_size.y - footprint.y, 0.0)
	var all_rects: Array[Rect2] = [
		Rect2(Vector2.ZERO, footprint),
		Rect2(Vector2(right, 0.0), footprint),
		Rect2(Vector2(0.0, bottom), footprint),
		Rect2(Vector2(right, bottom), footprint),
	]
	return all_rects.slice(0, clampi(panel_count, 0, all_rects.size()))


func _ready() -> void:
	layer = 20
	_root.add_to_group("party_shooter_match_hud")
	get_viewport().size_changed.connect(_layout_panels)
	if not _characters.is_empty():
		call_deferred("_rebuild")


func set_characters(characters: Array) -> void:
	_characters = characters.duplicate()
	if is_node_ready():
		call_deferred("_rebuild")


func _rebuild() -> void:
	for child in _root.get_children():
		child.free()
	_panels.clear()
	for index in range(mini(_characters.size(), 4)):
		var character := _characters[index] as BaseCharacter
		if character == null:
			continue
		var panel := HUD_PLAYER_CARD.instantiate() as HudPlayerCard
		panel.name = "PlayerPanel%d" % (index + 1)
		_root.add_child(panel)
		panel.add_to_group(CAMERA_OCCLUDER_GROUP)
		panel.configure(character, index)
		_panels.append(panel)
	_layout_panels()


func _layout_panels() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ui_scale := TOY_UI.ui_scale(viewport_size)
	var scaled_panel_size := PANEL_SIZE * ui_scale
	var scaled_margin := PANEL_MARGIN * ui_scale
	for index in range(_panels.size()):
		var panel := _panels[index]
		panel.scale = Vector2.ONE * ui_scale
		match index:
			0:
				panel.position = scaled_margin
			1:
				panel.position = Vector2(viewport_size.x - scaled_panel_size.x - scaled_margin.x, scaled_margin.y)
			2:
				panel.position = Vector2(scaled_margin.x, viewport_size.y - scaled_panel_size.y - scaled_margin.y)
			_:
				panel.position = viewport_size - scaled_panel_size - scaled_margin
