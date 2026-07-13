extends Control
class_name WeaponSilhouetteIcon

const BASE_SIZE := Vector2(100, 44)

var weapon_id := "pistol"
var accent := Color.WHITE
var _origin := Vector2.ZERO
var _scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_weapon(next_weapon_id: String, next_accent: Color) -> void:
	weapon_id = next_weapon_id
	accent = next_accent
	queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_scale = minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	_origin = (size - BASE_SIZE * _scale) * 0.5

	var shadow_offset = Vector2(2.6, 2.8)
	match weapon_id:
		"smg":
			_draw_smg(shadow_offset, true)
			_draw_smg(Vector2.ZERO, false)
		"ak_rifle":
			_draw_ak_rifle(shadow_offset, true)
			_draw_ak_rifle(Vector2.ZERO, false)
		"sniper":
			_draw_sniper(shadow_offset, true)
			_draw_sniper(Vector2.ZERO, false)
		"gatling":
			_draw_gatling(shadow_offset, true)
			_draw_gatling(Vector2.ZERO, false)
		"shotgun":
			_draw_shotgun(shadow_offset, true)
			_draw_shotgun(Vector2.ZERO, false)
		_:
			_draw_pistol(shadow_offset, true)
			_draw_pistol(Vector2.ZERO, false)

func _draw_pistol(offset: Vector2, shadow: bool) -> void:
	var body = _part_color(Color("#ff6b72"), shadow)
	var barrel = _part_color(body.lerp(Color.WHITE, 0.22), shadow)
	var grip = _part_color(Color("#1f2634"), shadow)
	var metal = _part_color(Color("#eef4f6"), shadow)

	_stroke(Vector2(25, 21), Vector2(62, 21), body, 14, offset)
	_stroke(Vector2(58, 20), Vector2(88, 20), barrel, 8, offset)
	_poly([Vector2(39, 26), Vector2(54, 26), Vector2(49, 42), Vector2(34, 42)], grip, offset)
	_stroke(Vector2(34, 13), Vector2(57, 13), metal, 4, offset)
	_arc(Vector2(43, 29), 8, 18, 164, grip, 2.4, offset)
	_stroke(Vector2(73, 16), Vector2(85, 16), metal, 2.2, offset)

func _draw_smg(offset: Vector2, shadow: bool) -> void:
	var body = _part_color(Color("#65ff49"), shadow)
	var barrel = _part_color(Color("#e7ffd9"), shadow)
	var grip = _part_color(Color("#1b2432"), shadow)
	var mag = _part_color(Color("#41505f"), shadow)

	_stroke(Vector2(12, 22), Vector2(25, 22), grip, 9, offset)
	_stroke(Vector2(24, 20), Vector2(62, 20), body, 16, offset)
	_stroke(Vector2(58, 19), Vector2(90, 19), barrel, 8, offset)
	_stroke(Vector2(34, 11), Vector2(51, 11), barrel, 5, offset)
	_poly([Vector2(39, 28), Vector2(53, 28), Vector2(51, 43), Vector2(38, 43)], mag, offset)
	_poly([Vector2(27, 29), Vector2(38, 29), Vector2(34, 42), Vector2(23, 42)], grip, offset)
	_arc(Vector2(37, 29), 7, 18, 165, grip, 2.4, offset)

func _draw_ak_rifle(offset: Vector2, shadow: bool) -> void:
	var body = _part_color(Color("#ffb13b"), shadow)
	var barrel = _part_color(Color("#ffe0a3"), shadow)
	var grip = _part_color(Color("#20202a"), shadow)
	var mag = _part_color(Color("#5c6170"), shadow)

	_poly([Vector2(6, 23), Vector2(22, 15), Vector2(27, 21), Vector2(15, 30)], grip, offset)
	_stroke(Vector2(27, 20), Vector2(64, 20), body, 15, offset)
	_stroke(Vector2(60, 19), Vector2(93, 19), barrel, 7, offset)
	_stroke(Vector2(82, 15), Vector2(94, 15), barrel, 2.5, offset)
	_poly([Vector2(44, 28), Vector2(58, 29), Vector2(55, 43), Vector2(42, 40)], mag, offset)
	_poly([Vector2(30, 29), Vector2(41, 29), Vector2(37, 42), Vector2(27, 42)], grip, offset)
	_stroke(Vector2(35, 12), Vector2(53, 12), barrel, 3.5, offset)

func _draw_sniper(offset: Vector2, shadow: bool) -> void:
	var body = _part_color(Color("#5ce3ff"), shadow)
	var barrel = _part_color(Color("#d9f6ff"), shadow)
	var grip = _part_color(Color("#192231"), shadow)
	var scope = _part_color(Color("#eefcff"), shadow)

	_poly([Vector2(6, 24), Vector2(21, 17), Vector2(27, 22), Vector2(15, 30)], grip, offset)
	_stroke(Vector2(24, 21), Vector2(61, 21), body, 12, offset)
	_stroke(Vector2(58, 20), Vector2(97, 20), barrel, 5, offset)
	_stroke(Vector2(33, 10), Vector2(63, 10), scope, 6, offset)
	_circle(Vector2(34, 10), 5, scope, offset)
	_circle(Vector2(64, 10), 5, scope, offset)
	_poly([Vector2(33, 28), Vector2(45, 28), Vector2(41, 42), Vector2(30, 42)], grip, offset)
	_stroke(Vector2(73, 15), Vector2(96, 15), barrel, 2.0, offset)

func _draw_gatling(offset: Vector2, shadow: bool) -> void:
	var body = _part_color(Color("#ffd34d"), shadow)
	var barrel = _part_color(Color("#8d99a7"), shadow)
	var dark = _part_color(Color("#1d2431"), shadow)
	var status = _part_color(Color("#61e2e5"), shadow)

	_poly([Vector2(5, 24), Vector2(20, 16), Vector2(27, 22), Vector2(15, 31)], dark, offset)
	_stroke(Vector2(25, 20), Vector2(58, 20), body, 17, offset)
	_circle(Vector2(62, 20), 10, body, offset)
	for y in [15.0, 20.0, 25.0]:
		_stroke(Vector2(64, y), Vector2(96, y), barrel, 3.2, offset)
	_poly([Vector2(35, 28), Vector2(54, 28), Vector2(55, 43), Vector2(34, 43)], body, offset)
	_stroke(Vector2(31, 10), Vector2(52, 10), dark, 5, offset)
	_circle(Vector2(31, 18), 2.5, status, offset)

func _draw_shotgun(offset: Vector2, shadow: bool) -> void:
	var body = _part_color(Color("#d884ff"), shadow)
	var barrel = _part_color(Color("#dce4ed"), shadow)
	var dark = _part_color(Color("#202432"), shadow)
	var trim = _part_color(Color("#f4dba2"), shadow)

	_poly([Vector2(5, 24), Vector2(23, 15), Vector2(29, 21), Vector2(14, 31)], dark, offset)
	_stroke(Vector2(26, 20), Vector2(57, 20), body, 14, offset)
	_stroke(Vector2(55, 18), Vector2(96, 18), barrel, 5, offset)
	_stroke(Vector2(55, 24), Vector2(91, 24), dark, 3.5, offset)
	_stroke(Vector2(60, 20), Vector2(78, 20), body.lerp(Color.WHITE, 0.12), 12, offset)
	for x in [62.0, 68.0, 74.0]:
		_stroke(Vector2(x, 14), Vector2(x, 26), trim, 1.5, offset)
	_poly([Vector2(29, 28), Vector2(41, 28), Vector2(37, 42), Vector2(27, 42)], dark, offset)

func _part_color(color: Color, shadow: bool) -> Color:
	return Color(0, 0, 0, 0.48) if shadow else color

func _pt(point: Vector2, offset: Vector2 = Vector2.ZERO) -> Vector2:
	return _origin + (point + offset) * _scale

func _w(value: float) -> float:
	return value * _scale

func _stroke(from_point: Vector2, to_point: Vector2, color: Color, width: float, offset: Vector2) -> void:
	var from = _pt(from_point, offset)
	var to = _pt(to_point, offset)
	var radius = _w(width) * 0.5
	draw_line(from, to, color, _w(width), true)
	draw_circle(from, radius, color, true, -1.0, true)
	draw_circle(to, radius, color, true, -1.0, true)

func _poly(points: Array[Vector2], color: Color, offset: Vector2) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(_pt(point, offset))
	draw_colored_polygon(packed, color)

func _circle(point: Vector2, radius: float, color: Color, offset: Vector2) -> void:
	draw_circle(_pt(point, offset), _w(radius), color, true, -1.0, true)

func _arc(center: Vector2, radius: float, start_deg: float, end_deg: float, color: Color, width: float, offset: Vector2) -> void:
	draw_arc(_pt(center, offset), _w(radius), deg_to_rad(start_deg), deg_to_rad(end_deg), 12, color, _w(width), true)
